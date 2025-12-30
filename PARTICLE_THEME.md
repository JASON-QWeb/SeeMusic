# 粒子鼓面主题 (Particle Drumhead)

## 0. 目标

实现“鼓面膜”可视化效果（主流鼓面音频可视化风格）：
- **鼓面**：由大量粒子组成的圆形膜面
- **震动**：音量越大，鼓面振幅越大、跳动频率越快
- **范围**：音量越大，震动范围从中心扩展到边缘
- **冲击**：节拍触发“冲击环”向外扩散
- **边缘固定**：边缘振幅被抑制，强调膜面张力

---

## 1. 布局参数

| 参数 | 值 | 说明 |
|------|------|------|
| particleCount | 220 | 粒子数量（鼓面密度） |
| radius | size * 0.44 | 鼓面半径 |
| windowSize | 200×200 | 正方形窗口 |

---

## 2. 粒子属性

```swift
struct Particle {
    radius: CGFloat    // 0..1，距中心的归一化半径
    angle: CGFloat     // 0..2π，角度
    baseSize: CGFloat  // 粒子基础尺寸
    phase: CGFloat     // 相位偏移
    jitter: CGFloat    // 轻微角度抖动
}
```

---

## 3. 初始化分布（均匀鼓面）

使用 **Fermat Spiral（金角螺旋）** 保证鼓面均匀铺点：

```swift
let golden = π * (3 - sqrt(5))
let t = i + 0.5
let r = sqrt(t / count)
let θ = t * golden
```

加入 `jitter` 打散螺旋痕迹，仍保持稳定分布。

---

## 4. 平滑参数

```swift
let smoothFactor: CGFloat = 0.20   // RMS 平滑
let beatFactor: CGFloat = 0.35     // Beat 平滑
let climaxFactor: CGFloat = 0.25   // Climax 平滑
```

---

## 5. 鼓面振动模型（核心策略）

### 震动范围（音量越大范围越广）
```swift
activeRadius = 0.35 + rms * 0.55 + climax * 0.10
range = clamp(1 - r / activeRadius, 0, 1)
edgeDamp = pow(1 - r, 0.6)          // 边缘固定
envelope = range * edgeDamp
```

### 频率（音量越大跳动越快）
```swift
freq = 2.8 + rms * 6.0 + beat * 8.0
```

### 震幅
```swift
amp = 0.03 + rms * 0.10 + beat * 0.05 + climax * 0.08
```

### 鼓面波形（主模态 + 次模态）
```swift
wave = sin(t * freq - r * 6 + phase)
harmonic = 0.4 * sin(t * freq * 1.7 + r * 9 + phase * 1.3)
```

### 节拍冲击环（主流“击鼓”视觉）
```swift
ringPos = (t * ringSpeed) % 1
ringSpeed = 0.9 + rms * 0.6
ringWidth = 0.10 + rms * 0.08
impact = beat * exp(-((r - ringPos) / ringWidth)^2) * 0.14 * edgeDamp
```

### 最终位移（鼓面鼓起/下陷）
```swift
z = (wave + harmonic) * amp * envelope + impact
bulge = clamp(z, -0.18, 0.18)
```

---

## 6. 位置映射（鼓面鼓起）

```swift
x = center.x + cos(angle + jitter) * radius * r * (1 + bulge)
y = center.y + sin(angle + jitter) * radius * r * (1 + bulge)
```

---

## 7. 大小与透明度

```swift
size = baseSize * (0.75 + rms * 0.35 + bulge * 1.6)
opacity = clamp(0.25 + rms * 0.35 + bulge * 0.9, 0.12, 1.0)
```

---

## 8. 颜色

```swift
Color(
    hue: 0.35,                                  // 绿色
    saturation: 0.55 + rms * 0.20,
    brightness: 0.25 + rms * 0.45 + bulge * 0.6
)
```

---

## 9. 渲染层次

1. **外发光**：`opacity * 0.20`，尺寸 `× 2.2`
2. **核心粒子**：`opacity`，原始尺寸

---

## 10. CSS 参考（网页原型/视觉标注）

```css
:root {
  --drum-size: 200px;
  --drum-core: hsl(126 58% 54%);
  --drum-glow: hsl(126 80% 65% / 0.22);
  --drum-bg: radial-gradient(circle at center, #0f1f15 0%, #090f0b 55%, #020202 100%);
}

.drumhead-stage {
  width: var(--drum-size);
  height: var(--drum-size);
  position: relative;
  border-radius: 24px;
  overflow: hidden;
  background: var(--drum-bg);
  display: grid;
  place-items: center;
}

.drumhead-particle {
  position: absolute;
  border-radius: 50%;
  background: var(--drum-core);
  box-shadow: 0 0 10px 2px var(--drum-glow);
  mix-blend-mode: screen;
}
```

---

## 11. 代码文件

| 文件 | 说明 |
|------|------|
| `UI/ParticlePulseView.swift` | 主视图实现 |
| `Core/Config.swift` | 主题枚举定义 |
