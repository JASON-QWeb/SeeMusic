# 波形可视化优化策略 (macOS)

## 0. 目标

优化桌面悬浮窗波浪可视化效果：
- **人声驱动**：人声出现时波浪高，纯伴奏/背景音乐时波浪低
- **平滑过渡**：波形变化柔和自然，不抽搐
- **边界限制**：波形不超出窗口边界，最高峰使用80%空间
- **实时响应**：波形跟随音频变化，延迟低
- **静音稳定**：静音/底噪时保持微弱呼吸感，不抖动

---

## 1. 音频特征输入

### 原始输入（每帧）
| 特征 | 范围 | 说明 |
|------|------|------|
| `rms_raw` | 0..1 | 整体能量（Root Mean Square） |
| `vocalEnergy` | 0..1 | 人声频段能量（300-3500Hz 占比） |

### 处理后输出
| 特征 | 范围 | 说明 |
|------|------|------|
| `rms_s` | 0..1 | 平滑后的 RMS |
| `low_s` | 0..1 | 平滑后的人声能量 |
| `beat` | 0..1 | 瞬态节拍强度 |
| `climaxLevel` | 0..1 | 段落高潮程度 |
| `isClimax` | bool | 是否处于高潮状态 |

---

## 2. 人声频段检测

### 频段定义
```
低频范围:    0 - 300 Hz     (贝斯、鼓)
人声范围:    300 - 3500 Hz  (主要人声频段)
高频范围:    3500 - 8000 Hz (高频谐波、齿音)
```

### 计算公式
```
vocalRatio = vocalSum / (lowSum + vocalSum + highSum)
normalized = (vocalRatio - 0.25) / 0.45
vocalEnergy = clamp(pow(normalized, 0.8), 0, 1)
```

### 效果
- 纯伴奏时 `vocalEnergy` ≈ 0.1-0.3
- 人声出现时 `vocalEnergy` ≈ 0.5-0.9

---

## 3. 噪声地板

### 参数
| 参数 | 值 | 说明 |
|------|------|------|
| NF_ALPHA | 0.995 | 噪声地板跟踪系数 |
| NF_MARGIN | 0.015 | 噪声地板边距 |
| NF_FREEZE_RMS | 0.03 | RMS 高于此值时冻结更新 |

### 逻辑
```
if rms_raw < NF_FREEZE_RMS:
    nf = NF_ALPHA * nf + (1-NF_ALPHA) * rms_raw
else:
    nf = nf  // 冻结
nf2 = nf + NF_MARGIN
```

---

## 4. 归一化与压缩

### 参数
| 参数 | 值 | 说明 |
|------|------|------|
| RMS_GAIN | 3.0 | RMS 增益 |
| LOW_GAIN | 2.2 | 人声能量增益 |
| GAMMA_RMS | 1.50 | RMS 伽马（增强对比度） |
| GAMMA_LOW | 1.60 | 人声伽马（增强对比度） |

### 公式
```
rms1 = clamp((rms_raw - nf2) * RMS_GAIN, 0, 1)
low1 = clamp((low_raw - nf2) * LOW_GAIN, 0, 1)
rms2 = pow(rms1, GAMMA_RMS)  // gamma > 1 让小值更小
low2 = pow(low1, GAMMA_LOW)
```

### 效果
- gamma = 1.5 时：0.2 → 0.09，0.5 → 0.35，0.8 → 0.72
- 安静段落更安静，响亮段落保持响亮

---

## 5. Attack/Release 平滑

### 参数
| 参数 | 值 | 说明 |
|------|------|------|
| RMS_ATTACK_MS | 40 | RMS 起音时间 |
| RMS_RELEASE_MS | 180 | RMS 释放时间 |
| LOW_ATTACK_MS | 30 | 人声起音时间 |
| LOW_RELEASE_MS | 150 | 人声释放时间 |

### 公式
```
alpha(ms) = exp(-dt / (ms/1000))

smooth(prev, x, attack, release):
    a = (x > prev) ? attack : release
    return a * prev + (1-a) * x

rms_s = smooth(rms_s, rms2, alpha(RMS_ATTACK_MS), alpha(RMS_RELEASE_MS))
low_s = smooth(low_s, low2, alpha(LOW_ATTACK_MS), alpha(LOW_RELEASE_MS))
```

---

## 6. 节拍检测

### 参数
| 参数 | 值 | 说明 |
|------|------|------|
| BEAT_DIFF_GAIN | 2.4 | 节拍差分增益 |
| BEAT_RMS_RATIO | 0.65 | RMS 差分权重 |
| BEAT_GATE | 0.05 | 静音门限 |

### 公式
```
low_diff = max(0, low_s - low_s_prev)
rms_diff = max(0, rms_s - rms_s_prev)
beat_raw = max(low_diff * BEAT_DIFF_GAIN, rms_diff * BEAT_DIFF_GAIN * BEAT_RMS_RATIO)
beat = clamp(pow(beat_raw, 0.8), 0, 1)
if rms_s < BEAT_GATE: beat = 0
```

---

## 7. 高潮检测

### 参数
| 参数 | 值 | 说明 |
|------|------|------|
| WIN_SEC | 0.5 | 检测窗口时长 |
| CLIMAX_ATTACK_MS | 100 | 高潮起音 |
| CLIMAX_RELEASE_MS | 350 | 高潮释放 |
| HYST_ON | 0.50 | 高潮开启阈值 |
| HYST_OFF | 0.35 | 高潮关闭阈值 |

### 公式
```
energy = max(rms_s, low_s * 0.85)
mean = mean(energy over WIN_SEC)
peak = max(energy over WIN_SEC)

m = clamp((mean - 0.20) / 0.60, 0, 1)
p = clamp((peak - 0.40) / 0.50, 0, 1)
climax_raw = 0.60 * m + 0.40 * p

climax_in = max(climax_raw, beat)  // 节拍可触发高潮
climaxLevel = smooth(climaxLevel, climax_in, alpha(CLIMAX_ATTACK_MS), alpha(CLIMAX_RELEASE_MS))

// 滞回切换
OFF → ON: climaxLevel > HYST_ON
ON → OFF: climaxLevel < HYST_OFF
```

---

## 8. 视觉层平滑

### 参数（WaveView）
| 参数 | 值 | 说明 |
|------|------|------|
| smoothFactor | 0.18 | RMS/人声平滑系数 |
| beatSmooth | 0.35 | 节拍平滑系数 |
| climaxSmooth | 0.25 | 高潮平滑系数 |

### 逻辑
```
smoothedRMS += (targetRMS - smoothedRMS) * smoothFactor
smoothedLowEnergy += (targetLowEnergy - smoothedLowEnergy) * smoothFactor
smoothedBeat += (targetBeat - smoothedBeat) * beatSmooth
smoothedClimax += (targetClimax - smoothedClimax) * climaxSmooth
```

---

## 9. 视觉映射

### 振幅参数
| 参数 | 值 | 说明 |
|------|------|------|
| AMP_BASE | 0.008 | 基础振幅（极低） |
| AMP_GAIN | 0.5 | RMS 增益 |
| VOCAL_BOOST | 1.0 | 人声增益 |
| CLIMAX_BOOST | 0.8 | 高潮加成 |
| BEAT_AMP | 0.45 | 节拍脉冲 |
| SHARP_BASE | 0.10 | 基础尖锐度 |
| SHARP_BEAT | 0.70 | 节拍尖锐度 |

### 振幅计算
```
vocalDrive = lowEnergy  // 人声能量
baseAmp = AMP_BASE + AMP_GAIN * rms * sensitivity * (0.25 + vocalDrive * 0.75)
vocalLift = 1.0 + VOCAL_BOOST * vocalDrive
modeBoost = 1.0 + CLIMAX_BOOST * climax
beatLift = 1.0 + BEAT_AMP * beat
normalizedAmp = baseAmp * vocalLift * modeBoost * beatLift
```

### 边界限制
```
maxAmplitude = (窗口高度 / 2) * 0.80  // 使用80%空间
amplitude = min(maxAmplitude, baseAmplitude * waveScale * normalizedAmp)

// 绘制时硬裁剪
y = clamp(y, margin, height - margin)
```

### 尖锐度
```
sharp = SHARP_BASE + SHARP_BEAT * beat
```

---

## 10. 波形传播

### 方向
- 始终从左向右传播，不回流

### 公式
```
phase = k * (x - v * t)
v = travelBase * waveSpeed  // travelBase = 40.0
```

### 多层叠加
```
主波:   y += amplitude * sin(phase1 + propagationPhase)
次级波: y += amplitude * 0.4 * sin(phase2 + index + propagationPhase)
细节波: y += amplitude * 0.2 * sin(phase3 + index * 0.5 + propagationPhase)
尖锐波: y += amplitude * sharp * 0.22 * sin(sharpPhase + propagationPhase * 1.3)
```

---

## 11. 验收测试

| 场景 | 期望效果 |
|------|---------|
| EDM 强低音 | 节拍脉冲明显，高潮段波浪增强 |
| 纯伴奏/背景音乐 | 波浪较低，平稳 |
| 人声出现 | 波浪明显升高 |
| 古典音乐 | 波浪柔和，随旋律变化 |
| 暂停/静音 | 2秒内回落近零，无抖动 |
| 频繁切歌 | UI 稳定，无崩溃 |
| 边界测试 | 波形不超出窗口，最高使用80%空间 |

---

## 12. 代码文件对应

| 模块 | 文件 |
|------|------|
| 特征提取 | `Audio/FeatureExtractor.swift` |
| 特征处理 | `Audio/FeaturePipeline.swift` |
| 平滑处理 | `Audio/Smoother.swift` |
| 视觉渲染 | `UI/WaveView.swift` |
| 配置参数 | `Core/Config.swift` |
| 数据模型 | `Core/Models.swift` |
