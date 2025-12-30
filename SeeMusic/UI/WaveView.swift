import SwiftUI

// 波浪可视化视图 - 使用真实音频特征
struct WaveView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var audioService = AudioCaptureService.shared
    @State private var time: Double = 0
    @State private var isHovering = false
    
    // 平滑后的音频特征
    @State private var smoothedRMS: CGFloat = 0.02
    @State private var smoothedLowEnergy: CGFloat = 0.0
    
    // 波浪参数
    private let baseAmplitude: CGFloat = 15
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 波浪画布
                Canvas { context, size in
                    drawWaves(context: context, size: size)
                }
                .opacity(isHovering ? 0.3 : 1.0)
                
                // Hover 时显示隐藏按钮
                if isHovering {
                    VStack {
                        Button(action: hideWindow) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.slash")
                                Text("隐藏波浪")
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
            startAudioCapture()
        }
        .onDisappear {
            stopAudioCapture()
        }
    }
    
    // 隐藏窗口
    private func hideWindow() {
        NSApp.windows.first { $0 is FloatingPanel }?.orderOut(nil)
    }
    
    // 启动音频捕获
    private func startAudioCapture() {
        print("[SeeMusic] 🚀 WaveView 启动音频捕获...")
        Task {
            await audioService.start()
            print("[SeeMusic] 🎧 音频服务已启动: isCapturing=\(audioService.isCapturing)")
            if !audioService.isCapturing {
                print("[SeeMusic] ⚠️ 音频未启动，将使用静态波浪")
            }
        }
    }
    
    // 停止音频捕获
    private func stopAudioCapture() {
        Task {
            await audioService.stop()
        }
    }
    
    // 启动动画
    private func startAnimation() {
        let fps = config.frameRateMode.fps
        Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            Task { @MainActor in
                time += 0.016
                
                // 平滑过渡音频特征
                let targetRMS: CGFloat
                let targetLowEnergy: CGFloat
                
                if audioService.isCapturing {
                    targetRMS = CGFloat(audioService.currentFeatures.rms)
                    targetLowEnergy = CGFloat(audioService.currentFeatures.lowEnergy)
                } else {
                    // 无音频时保持极低的呼吸感
                    targetRMS = 0.02
                    targetLowEnergy = 0.0
                }
                
                // 平滑插值（避免抽搐）
                let smoothFactor: CGFloat = 0.15
                smoothedRMS += (targetRMS - smoothedRMS) * smoothFactor
                smoothedLowEnergy += (targetLowEnergy - smoothedLowEnergy) * smoothFactor
            }
        }
    }
    
    // 绘制多层波浪
    private func drawWaves(context: GraphicsContext, size: CGSize) {
        let centerY = size.height / 2
        let width = size.width
        
        let rms = smoothedRMS
        let lowEnergy = smoothedLowEnergy
        
        // 波浪层配置
        let waveConfigs = getWaveConfigs()
        
        for (index, waveConfig) in waveConfigs.enumerated() {
            let sensitivity = CGFloat(config.sensitivity)
            let boost = CGFloat(config.lowEnergyBoost)
            
            // 计算振幅：基础呼吸 + RMS * 灵敏度 + 低频增强
            // 静音时保持极低振幅（呼吸感）
            let breathingAmplitude = baseAmplitude * 0.1
            let dynamicAmplitude = baseAmplitude * waveConfig.amplitudeScale * rms * sensitivity
            let lowBoostAmplitude = baseAmplitude * waveConfig.amplitudeScale * lowEnergy * boost * 0.3
            let amplitude = breathingAmplitude + dynamicAmplitude + lowBoostAmplitude
            
            // 传播速度
            let speedMultiplier = 1.0 + lowEnergy * boost * 0.2
            
            // 创建波浪路径
            var path = Path()
            let step: CGFloat = 3
            
            for x in stride(from: 0, through: width, by: step) {
                let relativeX = x / width
                
                // 多重 sin 波叠加，产生传播感
                let phase1 = relativeX * waveConfig.frequency * 2 * .pi * width - time * waveConfig.speed * speedMultiplier * 2
                let phase2 = relativeX * waveConfig.frequency * 1.5 * 2 * .pi * width - time * waveConfig.speed * speedMultiplier * 1.5
                let phase3 = relativeX * waveConfig.frequency * 0.7 * 2 * .pi * width - time * waveConfig.speed * speedMultiplier * 2.5
                
                // 增加传播感的相位偏移
                let propagationPhase = relativeX * .pi * 0.5
                
                // 叠加波形
                var y = centerY
                
                // 主波
                y += amplitude * sin(phase1 + propagationPhase)
                
                // 次级波
                y += amplitude * 0.4 * sin(phase2 + Double(index) + propagationPhase)
                
                // 细节波
                y += amplitude * 0.2 * sin(phase3 + Double(index) * 0.5 + propagationPhase)
                
                if x == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // 绘制发光效果（底层）
            context.stroke(
                path,
                with: .color(waveConfig.color.opacity(waveConfig.opacity * 0.2)),
                style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
            )
            
            // 绘制中层光晕
            context.stroke(
                path,
                with: .color(waveConfig.color.opacity(waveConfig.opacity * 0.4)),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
            
            // 绘制主波浪
            context.stroke(
                path,
                with: .color(waveConfig.color.opacity(waveConfig.opacity)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    // 获取波浪配置（根据主题）
    private func getWaveConfigs() -> [(color: Color, frequency: CGFloat, speed: CGFloat, amplitudeScale: CGFloat, opacity: Double)] {
        switch config.theme {
        case .classic:
            return [
                (Color(red: 0.4, green: 0.7, blue: 1.0), 0.015, 1.0, 1.0, 0.9),
                (Color(red: 0.3, green: 0.5, blue: 0.9), 0.012, 0.8, 0.8, 0.7),
                (Color(red: 0.5, green: 0.3, blue: 0.8), 0.018, 1.2, 0.6, 0.5),
                (Color(red: 0.2, green: 0.4, blue: 0.7), 0.008, 0.5, 0.4, 0.3),
            ]
        case .minimal:
            return [
                (Color.white, 0.015, 1.0, 1.0, 0.8),
                (Color.gray, 0.012, 0.8, 0.7, 0.5),
                (Color.white.opacity(0.5), 0.018, 1.2, 0.5, 0.3),
            ]
        case .neon:
            return [
                (Color(red: 1.0, green: 0.2, blue: 0.6), 0.015, 1.2, 1.0, 0.95),
                (Color(red: 0.2, green: 0.8, blue: 1.0), 0.012, 0.9, 0.85, 0.8),
                (Color(red: 0.8, green: 0.2, blue: 1.0), 0.018, 1.4, 0.7, 0.6),
                (Color(red: 0.2, green: 1.0, blue: 0.6), 0.008, 0.6, 0.5, 0.4),
            ]
        }
    }
}

#Preview {
    WaveView()
        .frame(width: 480, height: 140)
}
