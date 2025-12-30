# 粒子鼓面主题 (Particle Drumhead)

## 0. 目标

实现“鼓面膜”可视化效果（主流鼓面音频可视化风格）：
- **鼓面**：由大量粒子组成的圆形膜面
- **震动**：音量越大，鼓面振幅越大、跳动频率越快
- **范围**：音量越大，震动范围从中心扩展到边缘
- **冲击**：节拍触发“冲击环”向外扩散
- **边缘固定**：边缘振幅被抑制，强调膜面张力
- **呼吸**：无声时为呼吸灯效果，避免全暗
- **柔光**：粒子带轻微柔和光晕（不夸张）
- **旋转**：整体顺时针旋转，随机 20-30s 切换为逆时针循环
- **配色**：霓虹渐变色，缓慢切换多套主题色

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
let beatAttack: CGFloat = 0.28     // Beat 起音（更柔和）
let beatRelease: CGFloat = 0.12    // Beat 释音（消除突兀震颤）
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

### Beat 软化（避免突然震颤）
```swift
beatSoft = pow(beat, 1.2)          // 压缩尖峰
```

### 无声呼吸（避免全暗）
```swift
idle = clamp((0.06 - rms) / 0.06, 0, 1)
breath = (0.5 + 0.5 * sin(t * 1.1)) * idle
```

### 频率（音量越大跳动越快）
```swift
freq = 2.8 + rms * 6.0 + beatSoft * 8.0
```

### 震幅
```swift
amp = 0.03 + rms * 0.10 + beatSoft * 0.05 + climax * 0.08 + breath * 0.02
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
impact = beatSoft * exp(-((r - ringPos) / ringWidth)^2) * 0.14 * edgeDamp
```

### 最终位移（鼓面鼓起/下陷）
```swift
z = (wave + harmonic) * amp * envelope + impact
bulge = clamp(z, -0.18, 0.18)
```

---

## 6. 位置映射（鼓面鼓起 + 整体旋转）

```swift
rotation += dir * speed * dt
if t >= nextSwitch: dir *= -1; nextSwitch = t + random(20..30)

x = center.x + cos(angle + jitter + rotation) * radius * r * (1 + bulge)
y = center.y + sin(angle + jitter + rotation) * radius * r * (1 + bulge)
```

---

## 7. 大小与透明度

```swift
size = baseSize * (0.75 + rms * 0.35 + bulge * 1.6)
opacity = clamp(0.25 + rms * 0.35 + bulge * 0.9 + breath * 0.12, 0.12, 1.0)
```

---

## 8. 颜色（霓虹渐变调色板）

```swift
palette = [
  (h: 0.56, s: 0.80, b: 0.68),   // 青
  (h: 0.62, s: 0.78, b: 0.70),   // 蓝
  (h: 0.72, s: 0.82, b: 0.72),   // 紫
  (h: 0.84, s: 0.80, b: 0.70),   // 洋红
  (h: 0.52, s: 0.82, b: 0.66)    // 蓝绿
]
base = lerp(palette, phase = (t * 0.025 + r * 0.12 + angle * 0.08))
Color(
    hue: base.h + bulge * 0.06,
    saturation: base.s + rms * 0.12,
    brightness: base.b + rms * 0.25 + bulge * 0.55 + breath * 0.20
)
```

---

## 9. 渲染层次

1. **柔和光晕**：`opacity * 0.12`，尺寸 `× 1.6`
2. **核心粒子**：`opacity`，原始尺寸

---

## 10. CSS 参考（网页原型/视觉标注）

```css
:root {
  --drum-size: 200px;
  --drum-core: hsl(216 90% 62%);
  --drum-core-2: hsl(264 85% 66%);
  --drum-core-3: hsl(312 80% 62%);
  --drum-bg: radial-gradient(circle at center, #10142c 0%, #0a0c1f 55%, #04040a 100%);
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
  background: linear-gradient(135deg, var(--drum-core), var(--drum-core-2), var(--drum-core-3));
  mix-blend-mode: screen;
  box-shadow: 0 0 6px 1px rgba(120, 140, 255, 0.20);
}
```

---

## 11. 代码文件

| 文件 | 说明 |
|------|------|
| `UI/ParticlePulseView.swift` | 主视图实现 |
| `Core/Config.swift` | 主题枚举定义 |
