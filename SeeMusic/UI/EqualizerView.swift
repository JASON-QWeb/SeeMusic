import SwiftUI

// 音响柱状图视图 - 5列绿色方块堆叠，随音量起伏
struct EqualizerView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var audioService = AudioCaptureService.shared
    
    // 状态
    @State private var isHovering = false
    @State private var smoothedRMS: CGFloat = 0.0
    @State private var smoothedLowEnergy: CGFloat = 0.0
    @State private var smoothedBeat: CGFloat = 0.0
    @State private var columnHeights: [CGFloat] = [0.1, 0.1, 0.1, 0.1, 0.1]
    @State private var timer: Timer?
    
    // 柱状图配置
    private let columnCount = 5
    private let blockCount = 10
    private let blockSpacing: CGFloat = 3
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let blockHeight = (size - CGFloat(blockCount + 1) * blockSpacing - 20) / CGFloat(blockCount)
            let columnWidth = (size - CGFloat(columnCount + 1) * blockSpacing - 20) / CGFloat(columnCount)
            
            ZStack {
                // 柱状图
                HStack(alignment: .bottom, spacing: blockSpacing) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        VStack(spacing: blockSpacing) {
                            // 未激活的方块（灰色渐变：顶部最浅，底部最深）
                            let inactive = inactiveBlocks(for: columnIndex)
                            ForEach(0..<inactive, id: \.self) { blockIndex in
                                let grayIntensity = CGFloat(blockIndex) / CGFloat(blockCount)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(white: 0.30 - grayIntensity * 0.12))
                                    .frame(width: columnWidth, height: blockHeight)
                            }
                            // 激活的方块（绿色渐变）
                            let active = activeBlocks(for: columnIndex)
                            ForEach(0..<active, id: \.self) { blockIndex in
                                let intensity = CGFloat(active - blockIndex) / CGFloat(blockCount)
                                let isTop = blockIndex == 0
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(blockColor(intensity: intensity, isTop: isTop))
                                    .frame(width: columnWidth, height: blockHeight)
                                    .shadow(color: blockColor(intensity: intensity, isTop: false).opacity(0.6), radius: 3)
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
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // 隐藏窗口
    private func hideWindow() {
        NSApp.windows.first { $0 is FloatingPanel }?.orderOut(nil)
    }
    
    // 激活的方块数量（从下往上亮）
    private func activeBlocks(for column: Int) -> Int {
        let height = columnHeights[safe: column] ?? 0.1
        return max(1, min(blockCount, Int(height * CGFloat(blockCount))))
    }
    
    // 未激活的方块数量
    private func inactiveBlocks(for column: Int) -> Int {
        return blockCount - activeBlocks(for: column)
    }
    
    // 方块颜色
    private func blockColor(intensity: CGFloat, isTop: Bool) -> Color {
        if isTop {
            return Color(hue: 0.35, saturation: 0.9, brightness: 1.0)
        }
        let brightness = 0.5 + intensity * 0.4
        let saturation = 0.7 + intensity * 0.2
        return Color(hue: 0.35, saturation: saturation, brightness: brightness)
    }
    
    // 对数映射：扩展小值，让小音量也有明显变化
    private func logMap(_ x: CGFloat) -> CGFloat {
        guard x > 0 else { return 0 }
        return log(1 + x * 10) / log(11)
    }
    
    // Gamma 压缩：进一步扩展小值
    private func gammaCompress(_ x: CGFloat, gamma: CGFloat) -> CGFloat {
        guard x > 0 else { return 0 }
        return pow(x, gamma)
    }
    
    // 启动动画
    private func startAnimation() {
        timer?.invalidate()
        let fps = config.frameRateMode.fps
        let newTimer = Timer(timeInterval: 1.0 / fps, repeats: true) { _ in
            Task { @MainActor in
                self.updateFeatures()
            }
        }
        // 添加到 common mode，确保菜单栏操作时也能运行
        RunLoop.current.add(newTimer, forMode: .common)
        timer = newTimer
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
        
        // 对数映射 + gamma 压缩
        let mappedRMS = gammaCompress(logMap(rawRMS), gamma: 0.5)
        let mappedLow = gammaCompress(logMap(rawLow), gamma: 0.5)
        
        // Attack/Release 平滑
        let attackFactor: CGFloat = 0.35
        let releaseFactor: CGFloat = 0.12
        let beatFactor: CGFloat = 0.5
        
        // RMS 平滑 (attack/release)
        if mappedRMS > smoothedRMS {
            smoothedRMS += (mappedRMS - smoothedRMS) * attackFactor
        } else {
            smoothedRMS += (mappedRMS - smoothedRMS) * releaseFactor
        }
        
        // 人声能量平滑
        if mappedLow > smoothedLowEnergy {
            smoothedLowEnergy += (mappedLow - smoothedLowEnergy) * attackFactor
        } else {
            smoothedLowEnergy += (mappedLow - smoothedLowEnergy) * releaseFactor
        }
        
        // 节拍平滑
        smoothedBeat += (rawBeat - smoothedBeat) * beatFactor
        
        // 更新各列高度
        updateColumnHeights()
    }
    
    // 更新各列高度
    private func updateColumnHeights() {
        // 基础高度：取 RMS 和人声的较大者
        let baseLevel = max(smoothedRMS, smoothedLowEnergy * 0.8)
        
        // 当前时间（用于相位波动）
        let time = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<columnCount {
            // 每列独立的随机抖动
            let jitter = CGFloat.random(in: -0.08...0.08)
            
            // 相位波动（让每列错开跳动）
            let phaseOffset = Double(i) * 0.8
            let wave = sin(time * 3 + phaseOffset) * 0.05 * (baseLevel + 0.2)
            
            // 节拍脉冲
            let beatPulse = smoothedBeat * 0.15
            
            // 综合计算高度，映射到 10% - 95% 区间
            let height = 0.10 + (baseLevel + jitter + wave + beatPulse) * 0.85
            
            // 限制范围
            columnHeights[i] = max(0.10, min(0.95, height))
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
