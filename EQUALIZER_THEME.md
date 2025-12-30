# 音响柱状图主题 (Equalizer)

## 0. 目标

实现类似音频均衡器的柱状图可视化效果：
- **动态范围宽**：从1格（静音）到10格（非常响）有完整的过渡
- **敏感律动**：小音量变化也能产生可见的跳动
- **节奏感**：每列错开跳动，产生"波浪"效果
- **真实感**：模拟真实音响设备的响应特性

---

## 1. 问题分析

### 当前问题
- 静音 → 1格
- 有声音 → 直接逼近10格
- **原因**：RMS 值从 0 到 0.3 的跳跃映射到 10% 到 90%，中间没有过渡

### 解决方案
使用 **对数映射 + gamma 压缩**，让：
- 小音量：占用更多的视觉空间（1-5格）
- 中等音量：在中间区域波动（4-7格）
- 大音量：才接近满格（8-10格）

---

## 2. 映射曲线设计

### 输入范围
```
RMS 原始值: 0.0 ~ 0.8（通常不超过0.5）
人声能量:   0.0 ~ 0.8
```

### 映射公式
```swift
// 第一步：对数映射，扩展小值
// log(1 + x * 10) / log(11) 把 0-1 映射到 0-1，但小值被放大
func logMap(_ x: CGFloat) -> CGFloat {
    return log(1 + x * 10) / log(11)
}

// 第二步：gamma 压缩，进一步扩展小值
// gamma < 1 时，小值被放大，大值被压缩
func gammaCompress(_ x: CGFloat, gamma: CGFloat = 0.6) -> CGFloat {
    return pow(x, gamma)
}

// 综合映射
func mapToHeight(_ rms: CGFloat) -> CGFloat {
    let logged = logMap(rms)
    let compressed = gammaCompress(logged, gamma: 0.5)
    // 映射到 10%-90% 区间
    return 0.1 + compressed * 0.8
}
```

### 映射效果表
| RMS 原始值 | 对数映射 | gamma(0.5) | 格数(共10格) |
|-----------|---------|------------|-------------|
| 0.00 | 0.00 | 0.00 | 1 |
| 0.02 | 0.08 | 0.28 | 3 |
| 0.05 | 0.18 | 0.42 | 4 |
| 0.10 | 0.30 | 0.55 | 5 |
| 0.20 | 0.46 | 0.68 | 6 |
| 0.30 | 0.58 | 0.76 | 7 |
| 0.50 | 0.74 | 0.86 | 8 |
| 0.80 | 0.89 | 0.94 | 9 |
| 1.00 | 1.00 | 1.00 | 10 |

---

## 3. 跳动效果

### 随机抖动
每帧给每列添加独立的随机偏移：
```swift
let jitter = CGFloat.random(in: -0.08...0.08)
```

### 相位波动
让每列以不同相位缓慢波动：
```swift
let phase = sin(time * 3 + columnIndex * 0.8) * 0.05
```

### 节拍响应
检测到节拍时短暂增加高度：
```swift
let beatPulse = beat * 0.15  // 节拍时额外增加15%
```

---

## 4. 平滑参数

### Attack/Release
```swift
attackFactor = 0.35   // 快速响应
releaseFactor = 0.12  // 慢速衰减，保持跳动惯性
beatFactor = 0.5      // 节拍快速响应
```

---

## 5. 最终公式

```swift
// 1. 获取原始音频特征
let rawRMS = audioService.currentFeatures.rms
let rawLow = audioService.currentFeatures.lowEnergy
let rawBeat = audioService.currentFeatures.beat

// 2. 对数映射
let logRMS = log(1 + rawRMS * 10) / log(11)
let logLow = log(1 + rawLow * 10) / log(11)

// 3. gamma 压缩 (gamma = 0.5)
let compRMS = pow(logRMS, 0.5)
let compLow = pow(logLow, 0.5)

// 4. 平滑处理
smoothedRMS = attack/release smooth of compRMS
smoothedLow = attack/release smooth of compLow
smoothedBeat = smooth of rawBeat

// 5. 综合计算基础高度
let baseLevel = max(smoothedRMS, smoothedLow * 0.8)

// 6. 每列独立计算
for i in 0..<columnCount {
    let jitter = random(-0.08, 0.08)
    let phase = sin(time * 3 + i * 0.8) * 0.05 * baseLevel
    let beatPulse = smoothedBeat * 0.15
    
    // 映射到 10% - 95% 区间
    let height = 0.10 + (baseLevel + jitter + phase + beatPulse) * 0.85
    columnHeights[i] = clamp(height, 0.10, 0.95)
}
```

---

## 6. 代码文件

| 文件 | 说明 |
|------|------|
| `UI/EqualizerView.swift` | 主视图实现 |
| `Core/Config.swift` | 主题枚举定义 |
