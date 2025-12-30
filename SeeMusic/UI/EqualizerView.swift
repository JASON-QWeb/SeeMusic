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
    @State private var columnHeights: [CGFloat] = [0.08, 0.08, 0.08, 0.08, 0.08]
    
    // 柱子逻辑映射 (用于随机交换)
    @State private var columnMapping: [Int] = [0, 1, 2, 3, 4]
    @State private var lastShuffleTime = Date()
    
    // 柱状图配置
    private let columnCount = 5
    private let blockCount = 12 // 增加分辨率
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
                // 柱状图主体
                HStack(alignment: .bottom, spacing: columnSpacing) {
                    ForEach(0..<columnCount, id: \.self) { displayIndex in
                        // 使用映射获取逻辑索引
                        let logicIndex = columnMapping[displayIndex]
                        
                        VStack(spacing: blockSpacing) {
                            // 从上到下渲染方块
                            ForEach(0..<blockCount, id: \.self) { reverseIndex in
                                let blockIndex = blockCount - 1 - reverseIndex
                                let isActive = shouldActivate(column: logicIndex, block: blockIndex)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(blockColor(blockIndex: blockIndex, isActive: isActive))
                                    .frame(width: columnWidth, height: blockHeight)
                                    // 激活时添加微弱辉光
                                    .shadow(color: isActive ? blockColor(blockIndex: blockIndex, isActive: true).opacity(0.5) : .clear, radius: 2)
                            }
                        }
                    }
                }
                .padding(10)
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
    // "最底下最深上面最淡" -> 底部高饱和度低亮度，顶部高亮度
    private func blockColor(blockIndex: Int, isActive: Bool) -> Color {
        let normalizedIndex = CGFloat(blockIndex) / CGFloat(blockCount - 1)
        
        if !isActive {
            // 未激活：底深灰 -> 顶极淡灰
            // Bottom (0.0): Opacity 0.5
            // Top (1.0): Opacity 0.05
            let inactiveOpacity = 0.5 - normalizedIndex * 0.45
            return Color.black.opacity(inactiveOpacity)
        }
        
        // 基础色相 (Hue)
        let baseColor: Color
        if blockIndex >= blockCount - 2 {
            // Top 2: 红色 (警示/高潮)
            baseColor = Color(red: 1.0, green: 0.2, blue: 0.2)
        } else if blockIndex >= blockCount - 5 {
            // Mid 3: 黄色 (过渡)
            baseColor = Color(red: 1.0, green: 0.85, blue: 0.0)
        } else {
            // Bottom: 绿色 (正常)
            baseColor = Color(red: 0.2, green: 1.0, blue: 0.4)
        }
        
        // 渐变效果：
        // 底部：深厚 (opacity 1.0)
        // 顶部：淡化 (opacity 降低)
        // 模拟 "最底下最深" -> "上面最淡"
        let fadeFactor = 1.0 - normalizedIndex * 0.4 // 顶部最淡 0.6 不透明度
        
        return baseColor.opacity(fadeFactor)
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
        if now.timeIntervalSince(lastShuffleTime) > 10.0 {
            // 每10秒随机洗牌
            withAnimation(.easeInOut(duration: 0.5)) {
                columnMapping.shuffle()
            }
            lastShuffleTime = now
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
        
        // 调慢闪烁频率 (降低 Attack/Release 速度)
        // 1. 之前太快了，人眼不适
        // 2. 更加平滑
        let attackFast: CGFloat = 0.35   // 原 0.5
        let attackSlow: CGFloat = 0.20   // 原 0.35
        let releaseFast: CGFloat = 0.15  // 原 0.25
        let releaseSlow: CGFloat = 0.08  // 原 0.15
        
        // RMS 平滑
        if rawRMS > smoothedRMS {
            smoothedRMS += (rawRMS - smoothedRMS) * attackFast
        } else {
            smoothedRMS += (rawRMS - smoothedRMS) * releaseFast
        }
        
        // 低频平滑 (沉稳)
        if rawLow > smoothedLowEnergy {
            smoothedLowEnergy += (rawLow - smoothedLowEnergy) * attackSlow
        } else {
            smoothedLowEnergy += (rawLow - smoothedLowEnergy) * releaseSlow
        }
        
        // 节拍平滑 (瞬态)
        smoothedBeat += (rawBeat - smoothedBeat) * 0.4 // 原 0.5
        
        updateColumnHeights()
    }
    
    // 更新各列高度 - 模拟频谱分析仪
    private func updateColumnHeights() {
        // 分解能量分量
        // 降低整体增益，解决 "汇聚在上层" 的问题
        let bass = smoothedBeat * 0.7 + smoothedLowEnergy * 0.3
        let mid = smoothedRMS * 0.8 // 降低 Mid 增益 (原 1.2)
        let randomHigh = CGFloat.random(in: 0...0.15)
        let treble = smoothedRMS * 0.5 + randomHigh
        
        // 预计算5个频段高度 (0.0 - 1.0)
        var h: [CGFloat] = [0, 0, 0, 0, 0]
        
        // Col 1: Bass (鼓点主力)
        h[0] = bass * 1.1
        
        // Col 2: Low-Mid (Bass与整体的过渡)
        h[1] = bass * 0.5 + mid * 0.4
        
        // Col 3: Mid (人声主力)
        // 混合更多的高频成分，让它动起来，不要死板地跟着 RMS
        h[2] = mid * 0.9 + treble * 0.2 
        
        // Col 4: High-Mid (人声泛音)
        h[3] = mid * 0.5 + treble * 0.5
        
        // Col 5: High (高频噪点/空气感)
        h[4] = treble * 0.8
        
        // 应用对数映射增强低音量表现，并限制范围
        for i in 0..<columnCount {
            // 对数映射：让小数值也能显示出高度
            // log(1 + x * 5) / log(6)
            var val = h[i]
            if val > 0 {
                val = log(1 + val * 5) / log(6)
            }
            
            // 加上微弱的随机抖动，增加模拟感
            val += CGFloat.random(in: -0.02...0.02)
            
            // 保证最低显示第1格 (1/12 ≈ 0.08)
            // 最高不超过 1.0
            columnHeights[i] = max(0.08, min(1.0, val))
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
