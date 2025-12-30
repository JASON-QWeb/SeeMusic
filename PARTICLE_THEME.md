# 粒子脉冲主题 (Particle Pulse)

## 0. 目标

实现3D粒子脉冲可视化效果：
- **粒子圆面**：绿色粒子组成的椭圆
- **深度感**：粒子有远近层次
- **呼吸效果**：整体随音量脉动
- **颤动效果**：粒子随节拍颤抖

---

## 1. 布局参数

| 参数 | 值 | 说明 |
|------|------|------|
| particleCount | 60 | 粒子数量 |
| radius | size * 0.38 | 椭圆半径 |
| windowSize | 200×200 | 正方形窗口 |

---

## 2. 粒子属性

```swift
struct Particle {
    baseX: CGFloat      // 基础 X 位置 (0-1)
    baseY: CGFloat      // 基础 Y 位置 (0-1)
    baseSize: CGFloat   // 基础大小 (4-9)
    depth: CGFloat      // 深度 (0.2-1, 1最近)
    phase: CGFloat      // 相位偏移 (0-2π)
}
```

### 初始化分布
```swift
// 使用 sqrt 使分布更均匀
angle = random(0...2π)
r = sqrt(random(0...1))
x = 0.5 + cos(angle) * r * 0.42
y = 0.5 + sin(angle) * r * 0.38
```

---

## 3. 平滑参数

```swift
let smoothFactor: CGFloat = 0.18    // RMS 平滑
let beatFactor: CGFloat = 0.4       // 节拍平滑
```

---

## 4. 粒子动画计算

### 脉冲缩放
```swift
pulseScale = 1.0 + rms * 0.25 + beat * 0.15
```

### 颤动效果
```swift
tremor = sin(time * 6 + phase) * 0.015 * (rms * 2 + beat)
tremorX = cos(time * 5 + phase * 1.3) * 0.012 * (rms * 2 + beat)
```

### 深度影响
```swift
depthPush = rms * depth * 0.12  // 音量大时深层粒子"靠近"
```

### 位置计算
```swift
offsetX = (baseX - 0.5) * 2 * radius * pulseScale
offsetY = (baseY - 0.5) * 2 * radius * 0.9 * pulseScale

x = center.x + offsetX + tremor * radius + tremorX * radius
y = center.y + offsetY + tremor * radius * 0.7
```

### 大小计算
```swift
sizeFactor = 0.5 + depth * 0.5 + depthPush
size = baseSize * sizeFactor * (1 + beat * 0.2)
```

### 透明度计算
```swift
opacity = min(1.0, 0.35 + depth * 0.6 + rms * 0.15)
```

---

## 5. 粒子颜色

```swift
Color(
    hue: 0.35,                                    // 绿色
    saturation: 0.6 + depth * 0.3,                // 深层粒子更饱和
    brightness: 0.4 + depth * 0.5 + rms * 0.2     // 深层粒子更亮，音量大时更亮
)
```

### 渲染层次
1. **外发光**：`opacity * 0.25`，尺寸 `× 2.4`
2. **核心粒子**：`opacity`，原始尺寸

---

## 6. 代码文件

| 文件 | 说明 |
|------|------|
| `UI/ParticlePulseView.swift` | 主视图实现 |
| `Core/Config.swift` | 主题枚举定义 |
