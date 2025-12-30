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
    @State private var columnHeights: [CGFloat] = [0.15, 0.15, 0.15, 0.15, 0.15]
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
                            // 未激活的方块（灰色渐变：底部深，顶部浅）
                            let inactive = inactiveBlocks(for: columnIndex)
                            ForEach(0..<inactive, id: \.self) { blockIndex in
                                let grayIntensity = CGFloat(inactive - blockIndex) / CGFloat(blockCount)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(white: 0.15 + grayIntensity * 0.15))
                                    .frame(width: columnWidth, height: blockHeight)
                            }
                            // 激活的方块（绿色渐变）
                            ForEach(0..<activeBlocks(for: columnIndex), id: \.self) { blockIndex in
                                let activeCount = activeBlocks(for: columnIndex)
                                let intensity = CGFloat(activeCount - blockIndex) / CGFloat(blockCount)
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
    
    // 激活的方块数量
    private func activeBlocks(for column: Int) -> Int {
        let height = columnHeights[safe: column] ?? 0.15
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
    
    // 启动动画
    private func startAnimation() {
        timer?.invalidate()
        let fps = config.frameRateMode.fps
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            Task { @MainActor in
                updateFeatures()
            }
        }
    }
    
    // 更新音频特征
    private func updateFeatures() {
        let targetRMS: CGFloat
        let targetLow: CGFloat
        let targetBeat: CGFloat
        
        if audioService.isCapturing {
            targetRMS = CGFloat(audioService.currentFeatures.rms)
            targetLow = CGFloat(audioService.currentFeatures.lowEnergy)
            targetBeat = CGFloat(audioService.currentFeatures.beat)
        } else {
            targetRMS = 0.02
            targetLow = 0.0
            targetBeat = 0.0
        }
        
        let smoothFactor: CGFloat = 0.25
        let beatFactor: CGFloat = 0.5
        smoothedRMS += (targetRMS - smoothedRMS) * smoothFactor
        smoothedLowEnergy += (targetLow - smoothedLowEnergy) * smoothFactor
        smoothedBeat += (targetBeat - smoothedBeat) * beatFactor
        
        updateColumnHeights()
    }
    
    // 更新各列高度
    private func updateColumnHeights() {
        let baseLevel = smoothedRMS * 1.5 + smoothedLowEnergy * 0.8
        let beatBoost = smoothedBeat * 0.4
        
        let frequencyWeights: [CGFloat] = [0.9, 0.7, 0.5, 0.6, 0.8]
        let phaseOffsets: [CGFloat] = [0, 0.2, 0.4, 0.3, 0.1]
        
        for i in 0..<columnCount {
            let noise = CGFloat.random(in: -0.08...0.08)
            let freqContribution = smoothedLowEnergy * frequencyWeights[i]
            let phase = sin(CFAbsoluteTimeGetCurrent() * 3 + Double(phaseOffsets[i]) * .pi) * 0.08
            let height = baseLevel + freqContribution + beatBoost + noise + phase
            columnHeights[i] = max(0.08, min(0.95, height))
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
