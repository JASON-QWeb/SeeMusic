# 音响柱状图主题 (Equalizer)

## 0. 目标

实现类似音频均衡器的柱状图可视化效果：
- **5列方块**：模拟频谱分析器
- **绿色渐变**：底部深绿，顶部亮绿
- **实时响应**：各列随音量起伏
- **差异化响应**：各列有不同的频率特性

---

## 1. 布局参数

| 参数 | 值 | 说明 |
|------|------|------|
| columnCount | 5 | 列数 |
| blockCount | 10 | 每列最多方块数 |
| blockSpacing | 3 | 方块间距 |
| windowSize | 200×200 | 正方形窗口 |

---

## 2. 视觉效果

### 方块状态
- **未激活**：深灰色 `Color(white: 0.2)`
- **激活**：绿色渐变，从底部到顶部亮度递增
- **顶部方块**：最亮 `hue: 0.35, saturation: 0.9, brightness: 1.0`

### 颜色计算
```swift
// 激活方块颜色
brightness = 0.5 + intensity * 0.4
saturation = 0.7 + intensity * 0.2
Color(hue: 0.35, saturation: saturation, brightness: brightness)
```

---

## 3. 平滑参数

```swift
let smoothFactor: CGFloat = 0.25    // RMS/人声平滑
let beatFactor: CGFloat = 0.5       // 节拍平滑
```

---

## 4. 高度计算

### 基础高度
```swift
baseLevel = smoothedRMS * 1.5 + smoothedLowEnergy * 0.8
beatBoost = smoothedBeat * 0.4
```

### 频率权重（模拟频谱分析器）
```swift
frequencyWeights = [0.9, 0.7, 0.5, 0.6, 0.8]  // 左右两侧响应更强
phaseOffsets = [0, 0.2, 0.4, 0.3, 0.1]        // 相位错开产生波动效果
```

### 综合计算
```swift
noise = random(-0.08...0.08)
freqContribution = smoothedLowEnergy * frequencyWeights[i]
phase = sin(time * 3 + phaseOffsets[i] * π) * 0.08

height = baseLevel + freqContribution + beatBoost + noise + phase
columnHeights[i] = clamp(height, 0.08, 0.95)
```

---

## 5. 激活方块数量

```swift
activeBlocks = max(1, min(blockCount, Int(height * blockCount)))
inactiveBlocks = blockCount - activeBlocks
```

---

## 6. 代码文件

| 文件 | 说明 |
|------|------|
| `UI/EqualizerView.swift` | 主视图实现 |
| `Core/Config.swift` | 主题枚举定义 |
