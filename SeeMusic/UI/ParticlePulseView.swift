import SwiftUI

// 3D 粒子脉冲圆面视图 - 绿色粒子组成的椭圆，随音量颤动
struct ParticlePulseView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var audioService = AudioCaptureService.shared
    
    // 状态
    @State private var isHovering = false
    @State private var smoothedRMS: CGFloat = 0.0
    @State private var smoothedBeat: CGFloat = 0.0
    @State private var smoothedClimax: CGFloat = 0.0
    @State private var time: Double = 0
    @State private var timer: Timer?
    
    // 粒子数据
    @State private var particles: [Particle] = []
    private let particleCount = 60
    
    struct Particle: Identifiable {
        let id = UUID()
        var baseX: CGFloat
        var baseY: CGFloat
        var baseSize: CGFloat
        var depth: CGFloat
        var phase: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size * 0.38
            
            ZStack {
                // 粒子画布
                Canvas { context, canvasSize in
                    for particle in particles {
                        let (position, particleSize, opacity) = calculateParticle(
                            particle: particle,
                            center: center,
                            radius: radius,
                            rms: smoothedRMS,
                            beat: smoothedBeat
                        )
                        
                        let particleColor = Color(
                            hue: 0.35,
                            saturation: 0.6 + particle.depth * 0.3,
                            brightness: 0.4 + particle.depth * 0.5 + smoothedRMS * 0.2
                        )
                        
                        // 外发光
                        context.fill(
                            Circle().path(in: CGRect(
                                x: position.x - particleSize * 1.2,
                                y: position.y - particleSize * 1.2,
                                width: particleSize * 2.4,
                                height: particleSize * 2.4
                            )),
                            with: .color(particleColor.opacity(opacity * 0.25))
                        )
                        
                        // 核心粒子
                        context.fill(
                            Circle().path(in: CGRect(
                                x: position.x - particleSize / 2,
                                y: position.y - particleSize / 2,
                                width: particleSize,
                                height: particleSize
                            )),
                            with: .color(particleColor.opacity(opacity))
                        )
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
            initializeParticles()
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
    
    // 初始化粒子
    private func initializeParticles() {
        particles = (0..<particleCount).map { i in
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let r = sqrt(CGFloat.random(in: 0...1))
            let x = 0.5 + cos(angle) * r * 0.42
            let y = 0.5 + sin(angle) * r * 0.38
            
            return Particle(
                baseX: x,
                baseY: y,
                baseSize: CGFloat.random(in: 4...9),
                depth: CGFloat.random(in: 0.2...1),
                phase: CGFloat.random(in: 0...(2 * .pi))
            )
        }
    }
    
    // 计算粒子
    private func calculateParticle(
        particle: Particle,
        center: CGPoint,
        radius: CGFloat,
        rms: CGFloat,
        beat: CGFloat
    ) -> (CGPoint, CGFloat, CGFloat) {
        let pulseScale = 1.0 + rms * 0.25 + beat * 0.15
        let tremor = sin(time * 6 + Double(particle.phase)) * 0.015 * (rms * 2 + beat)
        let tremorX = cos(time * 5 + Double(particle.phase) * 1.3) * 0.012 * (rms * 2 + beat)
        let depthPush = rms * particle.depth * 0.12
        
        let offsetX = (particle.baseX - 0.5) * 2 * radius * pulseScale
        let offsetY = (particle.baseY - 0.5) * 2 * radius * 0.9 * pulseScale
        
        let x = center.x + offsetX + tremor * radius + tremorX * radius
        let y = center.y + offsetY + tremor * radius * 0.7
        
        let sizeFactor = 0.5 + particle.depth * 0.5 + depthPush
        let size = particle.baseSize * sizeFactor * (1 + beat * 0.2)
        let opacity = 0.35 + particle.depth * 0.6 + rms * 0.15
        
        return (CGPoint(x: x, y: y), size, min(1.0, opacity))
    }
    
    // 启动动画
    private func startAnimation() {
        timer?.invalidate()
        let fps = config.frameRateMode.fps
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            Task { @MainActor in
                time += 1.0 / fps
                updateFeatures()
            }
        }
    }
    
    // 更新音频特征
    private func updateFeatures() {
        let targetRMS: CGFloat
        let targetBeat: CGFloat
        let targetClimax: CGFloat
        
        if audioService.isCapturing {
            targetRMS = CGFloat(audioService.currentFeatures.rms)
            targetBeat = CGFloat(audioService.currentFeatures.beat)
            targetClimax = CGFloat(audioService.currentFeatures.climaxLevel)
        } else {
            targetRMS = 0.02
            targetBeat = 0.0
            targetClimax = 0.0
        }
        
        let smoothFactor: CGFloat = 0.18
        let beatFactor: CGFloat = 0.4
        smoothedRMS += (targetRMS - smoothedRMS) * smoothFactor
        smoothedBeat += (targetBeat - smoothedBeat) * beatFactor
        smoothedClimax += (targetClimax - smoothedClimax) * smoothFactor
    }
}

#Preview {
    ParticlePulseView()
        .frame(width: 200, height: 200)
}
