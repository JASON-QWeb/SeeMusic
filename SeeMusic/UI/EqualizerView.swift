import SwiftUI

// 音响柱状图视图 - 经典红黄绿渐变，模拟频谱分析仪
struct EqualizerView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var audioService = AudioCaptureService.shared
    
    // 状态
    @State private var isHovering = false
    @State private var smoothedRMS: CGFloat = 0.0
    @State private var smoothedLowEnergy: CGFloat = 0.0
    @State private var smoothedBeat: CGFloat = 0.0
    
    // 柱子高度状态
    @State private var columnHeights: [CGFloat] = [0.08, 0.08, 0.08, 0.08, 0.08]
    // 峰值保持时间 (用于控制熄灭延迟)
    @State private var columnHoldTimers: [Date] = Array(repeating: Date(), count: 5)
    
    // 柱子逻辑映射 (用于随机交换)
    @State private var columnMapping: [Int] = [0, 1, 2, 3, 4]
    @State private var lastShuffleTime = Date()
    @State private var nextShuffleInterval: TimeInterval = 2.0 // 初始随机间隔
    
    // 柱状图配置
    private let columnCount = 5
    private let blockCount = 12
    private let blockSpacing: CGFloat = 2
    private let columnSpacing: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let totalSpacingH = CGFloat(columnCount - 1) * columnSpacing + 20 // 20 padding
            let totalSpacingV = CGFloat(blockCount - 1) * blockSpacing + 20
            
            let columnWidth = (size - totalSpacingH) / CGFloat(columnCount)
            let blockHeight = (size - totalSpacingV) / CGFloat(blockCount)
            
            ZStack {
                // 使用 Canvas 高效绘制柱状图
                Canvas { context, canvasSize in
                    let padding: CGFloat = 10
                    let availableWidth = canvasSize.width - padding * 2
                    let availableHeight = canvasSize.height - padding * 2
                    
                    let totalColumnSpacing = CGFloat(columnCount - 1) * columnSpacing
                    let totalBlockSpacing = CGFloat(blockCount - 1) * blockSpacing
                    
                    let colWidth = (availableWidth - totalColumnSpacing) / CGFloat(columnCount)
                    let blkHeight = (availableHeight - totalBlockSpacing) / CGFloat(blockCount)
                    
                    for displayIndex in 0..<columnCount {
                        let logicIndex = columnMapping[displayIndex]
                        let colX = padding + CGFloat(displayIndex) * (colWidth + columnSpacing)
                        
                        for blockIdx in 0..<blockCount {
                            let isActive = shouldActivate(column: logicIndex, block: blockIdx)
                            let color = blockColorForCanvas(blockIndex: blockIdx, isActive: isActive)
                            
                            // 从底部向上绘制 (blockIdx 0 在底部)
                            let blkY = padding + CGFloat(blockCount - 1 - blockIdx) * (blkHeight + blockSpacing)
                            
                            let rect = CGRect(x: colX, y: blkY, width: colWidth, height: blkHeight)
                            let path = RoundedRectangle(cornerRadius: 2).path(in: rect)
                            context.fill(path, with: .color(color))
                        }
                    }
                }
                .opacity(isHovering ? 0.3 : 1.0)
                
                // Hover 时显示隐藏按钮
                if isHovering {
                    VStack {
                        Button(action: hideWindow) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.slash")
                                Text("隐藏")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .background(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // 隐藏窗口
    private func hideWindow() {
        NSApp.windows.first { $0 is FloatingPanel }?.orderOut(nil)
    }
    
    // 判断方块是否激活
    private func shouldActivate(column: Int, block: Int) -> Bool {
        let height = columnHeights[safe: column] ?? 0.0
        // 将 0-1 的高度映射到 blockCount (0-11)
        // 至少亮1格 (0.08)
        let activeIndex = Int(height * CGFloat(blockCount))
        return block < activeIndex
    }
    // 方块颜色：红黄绿渐变，叠加亮度渐变
    private func blockColor(blockIndex: Int, isActive: Bool) -> Color {
        // 归一化索引 (0.0 - 1.0)
        let normalized = CGFloat(blockIndex) / CGFloat(blockCount - 1)
        
        if !isActive {
            // 未激活：底深灰 (0.6) -> 顶极淡灰 (0.1)
            // 这种渐变能让背景更有层次感，像是一个未点亮的音响面板
            let inactiveOpacity = 0.6 - normalized * 0.5
            return Color.black.opacity(inactiveOpacity)
        }
        
        // 1. 颜色分布 (Color Distribution)
        // 共12格：
        // Top 3 (9, 10, 11) -> 红色
        // Mid 4 (5, 6, 7, 8) -> 黄色
        // Bottom 5 (0, 1, 2, 3, 4) -> 绿色
        var baseHue: Double
        
        if blockIndex >= 9 {
            // Top 3: Red
            baseHue = 0.0 // 纯红
        } else if blockIndex >= 5 {
            // Mid 4: Yellow
            baseHue = 0.14 // 金黄
        } else {
            // Bottom 5: Green
            baseHue = 0.35 // 鲜绿
        }
        
        // 2. 渐变效果 (Gradient Aesthetics)
        // "最底下最深 (Deep) -> 最上面最淡 (Light)"
        
        // 饱和度 (Saturation): 底部高，顶部低
        // 亮度 (Brightness): 底部稍暗(深厚)，顶部全亮
        // 透明度 (Opacity): 底部不透明，顶部半透明(淡化)
        
        // 全局渐变因子 (0: Bottom, 1: Top)
        let globalFactor = normalized
        
        // 饱和度：0.95 -> 0.6 (顶部变淡白)
        let saturation = 0.95 - globalFactor * 0.35
        
        // 亮度：0.8(深厚) -> 1.0(亮)
        let brightness = 0.8 + globalFactor * 0.2
        
        // 透明度：1.0 -> 0.7 (顶部半透明效果)
        let opacity = 1.0 - globalFactor * 0.3
        
        // 微调颜色
        return Color(hue: baseHue,
                    saturation: saturation,
                    brightness: brightness)
                .opacity(opacity)
    }
    
    // Canvas 专用颜色计算
    private func blockColorForCanvas(blockIndex: Int, isActive: Bool) -> Color {
        let normalized = CGFloat(blockIndex) / CGFloat(blockCount - 1)
        
        if !isActive {
            let inactiveOpacity = 0.6 - normalized * 0.5
            return Color.black.opacity(inactiveOpacity)
        }
        
        var baseHue: Double
        if blockIndex >= 9 {
            baseHue = 0.0
        } else if blockIndex >= 5 {
            baseHue = 0.14
        } else {
            baseHue = 0.35
        }
        
        let globalFactor = normalized
        let saturation = 0.95 - globalFactor * 0.35
        let brightness = 0.8 + globalFactor * 0.2
        let opacity = 1.0 - globalFactor * 0.3
        
        return Color(hue: baseHue, saturation: saturation, brightness: brightness).opacity(opacity)
    }
    
    // 启动动画
    private func startAnimation() {
        let fps = config.frameRateMode.fps
        let newTimer = Timer(timeInterval: 1.0 / fps, repeats: true) { [self] _ in
            Task { @MainActor in
                updateFeatures()
                checkShuffle()
            }
        }
        RunLoop.current.add(newTimer, forMode: .common)
    }
    
    // 检查是否需要随机交换柱子
    private func checkShuffle() {
        let now = Date()
        if now.timeIntervalSince(lastShuffleTime) > nextShuffleInterval {
            // 随机洗牌
            withAnimation(.easeInOut(duration: 0.5)) {
                columnMapping.shuffle()
            }
            lastShuffleTime = now
            // 设置下一次随机间隔 (1.0 - 5.0 秒)
            nextShuffleInterval = Double.random(in: 1.0...5.0)
        }
    }
    
    // 更新音频特征
    private func updateFeatures() {
        let rawRMS: CGFloat
        let rawLow: CGFloat
        let rawBeat: CGFloat
        
        if audioService.isCapturing {
            rawRMS = CGFloat(audioService.currentFeatures.rms)
            rawLow = CGFloat(audioService.currentFeatures.lowEnergy)
            rawBeat = CGFloat(audioService.currentFeatures.beat)
        } else {
            rawRMS = 0.0
            rawLow = 0.0
            rawBeat = 0.0
        }
        
        // 一级平滑 (Input Smoothing)
        // 保持较快的响应，以便捕捉瞬态，实际的视觉平滑在 columnHeights 处理
        let attack: CGFloat = 0.4
        let release: CGFloat = 0.2
        
        if rawRMS > smoothedRMS { smoothedRMS += (rawRMS - smoothedRMS) * attack }
        else { smoothedRMS += (rawRMS - smoothedRMS) * release }
        
        if rawLow > smoothedLowEnergy { smoothedLowEnergy += (rawLow - smoothedLowEnergy) * attack }
        else { smoothedLowEnergy += (rawLow - smoothedLowEnergy) * release }
        
        smoothedBeat += (rawBeat - smoothedBeat) * 0.4
        
        updateColumnHeights()
    }
    
    // 更新各列高度
    private func updateColumnHeights() {
        // 1. 计算目标高度 (Target Heights)
        let bass = smoothedBeat * 0.7 + smoothedLowEnergy * 0.3
        let mid = smoothedRMS * 0.75 // 稍微降低
        let randomHigh = CGFloat.random(in: 0...0.12)
        let treble = smoothedRMS * 0.5 + randomHigh
        
        var targets: [CGFloat] = [0, 0, 0, 0, 0]
        targets[0] = bass * 1.1
        targets[1] = bass * 0.5 + mid * 0.4
        targets[2] = mid * 0.9 + treble * 0.2 
        targets[3] = mid * 0.5 + treble * 0.5
        targets[4] = treble * 0.8
        
        // 2. 应用平滑逻辑 (Peak Hold + Slow Decay)
        let now = Date()
        // 最小点亮保持时间 (0.15秒)
        let holdDuration: TimeInterval = 0.15
        // 线性下降速度 (每秒下降的比例，例如 0.8 表示1秒下降80%)
        // 越小下降越慢
        let decaySpeed: CGFloat = 1.5 / CGFloat(config.frameRateMode.fps) 
        
        for i in 0..<columnCount {
            var target = targets[i]
            // 对数映射处理
            if target > 0 { target = log(1 + target * 5) / log(6) }
            target += CGFloat.random(in: -0.01...0.01)
            target = max(0.08, min(1.0, target))
            
            var current = columnHeights[i]
            
            if target > current {
                // 上升：直接响应 (Attack)
                // 稍微平滑一点上升，不要瞬间满格
                let rise = (target - current) * 0.4
                current += rise
                // 更新保持计时器
                columnHoldTimers[i] = now
            } else {
                // 下降：检查保持时间
                let timeSincePeak = now.timeIntervalSince(columnHoldTimers[i])
                
                if timeSincePeak < holdDuration {
                    // 保持期：不下降 (或者非常缓慢)
                    // 也可以选择完全不动，模拟 "Peak Hold"
                } else {
                    // 释放期：线性下降
                    // 模拟重力下落效果
                    current -= decaySpeed
                    
                    // 确保不低于目标
                    if current < target { current = target }
                }
            }
            
            columnHeights[i] = current
        }
    }
}

// 安全下标访问
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    EqualizerView()
        .frame(width: 200, height: 200)
}
