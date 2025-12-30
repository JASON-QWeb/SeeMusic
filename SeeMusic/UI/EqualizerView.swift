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
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        VStack(spacing: blockSpacing) {
                            // 从上到下渲染方块
                            ForEach(0..<blockCount, id: \.self) { reverseIndex in
                                let blockIndex = blockCount - 1 - reverseIndex
                                let isActive = shouldActivate(column: columnIndex, block: blockIndex)
                                
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
    
    // 方块颜色：红黄绿渐变
    private func blockColor(blockIndex: Int, isActive: Bool) -> Color {
        if !isActive {
            // 未激活：极暗的半透明背景，保留“底槽”感
            return Color(red: 0.08, green: 0.08, blue: 0.08, opacity: 0.4)
        }
        
        // 激活：经典的谱分析仪配色
        if blockIndex >= blockCount - 2 {
            // Top 2: 红色 (警示/高潮)
            return Color(red: 1.0, green: 0.2, blue: 0.2)
        } else if blockIndex >= blockCount - 5 {
            // Mid 3: 黄色 (过渡)
            return Color(red: 1.0, green: 0.85, blue: 0.0)
        } else {
            // Bottom: 绿色 (正常)
            return Color(red: 0.2, green: 1.0, blue: 0.4)
        }
    }
    
    // 启动动画
    private func startAnimation() {
        let fps = config.frameRateMode.fps
        let newTimer = Timer(timeInterval: 1.0 / fps, repeats: true) { [self] _ in
            Task { @MainActor in
                updateFeatures()
            }
        }
        RunLoop.current.add(newTimer, forMode: .common)
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
        
        // 不同的平滑参数
        let attackFast: CGFloat = 0.5   // 极快，灵动
        let attackSlow: CGFloat = 0.35  // 较快，沉稳
        let releaseFast: CGFloat = 0.25 // 较快回落
        let releaseSlow: CGFloat = 0.15 // 慢速回落，保持惯性
        
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
        smoothedBeat += (rawBeat - smoothedBeat) * 0.5
        
        updateColumnHeights()
    }
    
    // 更新各列高度 - 模拟频谱分析仪
    private func updateColumnHeights() {
        // 分解能量分量
        let bass = smoothedBeat * 0.8 + smoothedLowEnergy * 0.4
        let mid = smoothedRMS * 1.2
        let randomHigh = CGFloat.random(in: 0...0.15)
        let treble = smoothedRMS * 0.6 + randomHigh
        
        // 预计算5个频段高度 (0.0 - 1.0)
        var h: [CGFloat] = [0, 0, 0, 0, 0]
        
        // Col 1: Bass (鼓点主力)
        h[0] = bass * 1.2
        
        // Col 2: Low-Mid (Bass与整体的过渡)
        h[1] = bass * 0.6 + mid * 0.4
        
        // Col 3: Mid (人声主力)
        h[2] = mid * 1.1
        
        // Col 4: High-Mid (人声泛音)
        h[3] = mid * 0.7 + treble * 0.3
        
        // Col 5: High (高频噪点/空气感)
        h[4] = treble * 0.9
        
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
