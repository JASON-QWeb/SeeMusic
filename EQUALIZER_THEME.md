# 音响柱状图主题 (Equalizer)

## 0. 设计目标

打造一个**经典复古且动感十足**的频谱分析仪效果：
- **配色**：采用经典的 **绿 -> 黄 -> 红** 渐变色，模拟真实音响设备。
- **背景**：深色半透明背景，未激活方块显示极暗的“底槽”，增加层次感。
- **动态**：从低频到高频的波浪式律动，每列独立响应不同频率特性。
- **细节**：顶部“峰值保持”效果（可选），方块间微小间距。

---

## 1. 视觉设计

### 配色方案 (Gradient)
- **顶部 (Top 20%)**: 红色 (警示/高潮) - `RGB(255, 60, 60)`
- **中部 (Mid 30%)**: 黄色 (过渡) - `RGB(255, 220, 0)`
- **底部 (Bottom 50%)**: 绿色 (正常) - `RGB(60, 255, 100)`
- **未激活 (Inactive)**: 极暗的半透明黑 - `RGBA(20, 20, 20, 0.3)`

### 布局
- **列数**：5列 (代表不同频段：低、中低、中、中高、高)
- **块数**：每列 12 格 (增加分辨率)
- **间距**：列间距 4px，块间距 2px

---

## 2. 动画逻辑

为了解决“只有最后两列跳动”的问题，我们将采用**频率分段模拟**策略：

### 频段分配
1. **Col 1 (Low)**: 主要响应 **Beat (鼓点)** 和 **低频能量**。
2. **Col 2 (Low-Mid)**: 响应 **RMS (整体)** 和部分 **低频**。
3. **Col 3 (Mid)**: 响应 **人声 (Mid-High)** 和 **RMS**。
4. **Col 4 (High-Mid)**: 响应 **人声** 和快速变化的噪音。
5. **Col 5 (High)**: 响应 **RMS** 的高频抖动分量。

### 核心公式
```swift
// 基础能量
let bass = smoothedBeat * 0.8 + smoothedLow * 0.4
let mid = smoothedRMS * 1.2
let treble = smoothedRMS * 0.6 + random(0.1) // 模拟高频噪点

// 各列高度计算 (模拟频谱曲线)
h[0] = bass
h[1] = bass * 0.7 + mid * 0.3
h[2] = mid * 1.1
h[3] = mid * 0.6 + treble * 0.4
h[4] = treble * 0.8
```

---

## 3. 优化策略

### 律动优化
- **Attack/Release**: 不同的频段使用不同的响应速度。
  - 低频 (Col 1-2): Attack 快 (0.4), Release 慢 (0.15) -> 沉稳有力
  - 中高频 (Col 3-5): Attack 极快 (0.6), Release 快 (0.3) -> 灵动跳跃

### 视觉映射
- 使用 `pow(x, 0.7)` 稍微提升低音量的可视高度，避免静音时完全黑屏。
- 保持最低 1 格亮度 (1/12)，作为电源指示。

---

## 4. 代码实现计划

### 文件：`UI/EqualizerView.swift`

1. **废弃旧逻辑**：移除单一的 height 计算。
2. **重构 `updateFeatures`**：计算 Bass, Mid, Treble 三个分量。
3. **重构 `updateColumnHeights`**：基于分量计算 5 个独立高度。
4. **重构 `body`**：
   - 使用 `VStack` + `ForEach` 构建网格。
   - 根据 `activeBlocks` 动态计算颜色（绿/黄/红）。

### 代码片段预览
```swift
let color: Color
if blockIndex >= 10 { color = .red }       // Top 2
else if blockIndex >= 7 { color = .yellow } // Mid 3
else { color = .green }                     // Bottom 7
```
