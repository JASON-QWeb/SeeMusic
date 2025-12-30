import SwiftUI

// 粒子鼓面视图 - 大量粒子组成鼓面，随音量震动
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
    @State private var rotationAngle: Double = 0
    @State private var rotationDirection: Double = 1
    @State private var nextRotationSwitch: Double = 0
    
    // 粒子数据
    @State private var particles: [Particle] = []
    private let particleCount = 220
    
    private typealias PaletteStop = (h: CGFloat, s: CGFloat, b: CGFloat)
    private let paletteStops: [PaletteStop] = [
        (h: 0.56, s: 0.80, b: 0.68),
        (h: 0.62, s: 0.78, b: 0.70),
        (h: 0.72, s: 0.82, b: 0.72),
        (h: 0.84, s: 0.80, b: 0.70),
        (h: 0.52, s: 0.82, b: 0.66)
    ]
    
    struct Particle: Identifiable {
        let id = UUID()
        var radius: CGFloat
        var angle: CGFloat
        var baseSize: CGFloat
        var phase: CGFloat
        var jitter: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size * 0.44
            
            ZStack {
                // 粒子画布
                Canvas { context, canvasSize in
                    for particle in particles {
                        let (position, particleSize, opacity, bulge) = calculateParticle(
                            particle: particle,
                            center: center,
                            radius: radius,
                            rms: smoothedRMS,
                            beat: smoothedBeat,
                            climax: smoothedClimax
                        )
                        
                        let hue = clamp(0.64 + particle.radius * 0.08 + bulge * 0.08 + smoothedClimax * 0.04, 0.0, 1.0)
                        let brightness = clamp(0.25 + smoothedRMS * 0.50 + bulge * 0.6, 0.0, 1.0)
                        let saturation = clamp(0.72 + smoothedRMS * 0.18, 0.0, 1.0)
                        let particleColor = Color(
                            hue: hue,
                            saturation: saturation,
                            brightness: brightness
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
        let golden = CGFloat.pi * (3 - sqrt(5))
        particles = (0..<particleCount).map { i in
            let t = CGFloat(i) + 0.5
            let baseRadius = sqrt(t / CGFloat(particleCount))
            let radiusJitter = CGFloat.random(in: -0.012...0.012)
            let angle = t * golden
            
            return Particle(
                radius: clamp(baseRadius + radiusJitter, 0.0, 1.0),
                angle: angle,
                baseSize: CGFloat.random(in: 2.0...4.2),
                phase: CGFloat.random(in: 0...(2 * .pi)),
                jitter: CGFloat.random(in: -0.05...0.05)
            )
        }
    }
    
    // 计算粒子
    private func calculateParticle(
        particle: Particle,
        center: CGPoint,
        radius: CGFloat,
        rms: CGFloat,
        beat: CGFloat,
        climax: CGFloat
    ) -> (CGPoint, CGFloat, CGFloat, CGFloat) {
        let activeRadius = 0.35 + rms * 0.55 + climax * 0.10
        let range = max(0.0, 1.0 - particle.radius / max(0.001, activeRadius))
        let edgeDamp = pow(1.0 - particle.radius, 0.6)
        let envelope = range * edgeDamp
        
        let beatSoft = pow(beat, 1.2)
        let freq = 2.8 + rms * 6.0 + beatSoft * 8.0
        let freqValue = Double(freq)
        let wave = sin(time * freqValue - Double(particle.radius) * 6.0 + Double(particle.phase))
        let harmonic = 0.4 * sin(time * (freqValue * 1.7) + Double(particle.radius) * 9.0 + Double(particle.phase) * 1.3)
        
        let ringSpeed = 0.9 + rms * 0.6
        let ringPos = (time * Double(ringSpeed)).truncatingRemainder(dividingBy: 1.0)
        let ringWidth = 0.10 + rms * 0.08
        let ring = exp(-pow(Double((particle.radius - CGFloat(ringPos)) / ringWidth), 2.0))
        let impact = beatSoft * CGFloat(ring) * 0.14 * edgeDamp
        
        let amp = 0.03 + rms * 0.10 + beatSoft * 0.05 + climax * 0.08
        let z = (CGFloat(wave) + CGFloat(harmonic)) * amp * envelope + impact
        let bulge = clamp(z, -0.18, 0.18)
        
        let angle = particle.angle + particle.jitter
        let scale = 1.0 + bulge
        let x = center.x + cos(angle) * particle.radius * radius * scale
        let y = center.y + sin(angle) * particle.radius * radius * scale
        
        let size = particle.baseSize * (0.75 + rms * 0.35 + bulge * 1.6)
        let opacity = clamp(0.25 + rms * 0.35 + bulge * 0.9, 0.12, 1.0)
        
        return (CGPoint(x: x, y: y), size, opacity, bulge)
    }
    
    // 启动动画
    private func startAnimation() {
        timer?.invalidate()
        let fps = config.frameRateMode.fps
        let newTimer = Timer(timeInterval: 1.0 / fps, repeats: true) { _ in
            Task { @MainActor in
                self.time += 1.0 / fps
                self.updateFeatures()
            }
        }
        // 添加到 common mode，确保菜单栏操作时也能运行
        RunLoop.current.add(newTimer, forMode: .common)
        timer = newTimer
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
        
        let smoothFactor: CGFloat = 0.20
        let beatAttack: CGFloat = 0.28
        let beatRelease: CGFloat = 0.12
        let climaxFactor: CGFloat = 0.25
        smoothedRMS += (targetRMS - smoothedRMS) * smoothFactor
        let beatAlpha = targetBeat > smoothedBeat ? beatAttack : beatRelease
        smoothedBeat += (targetBeat - smoothedBeat) * beatAlpha
        smoothedClimax += (targetClimax - smoothedClimax) * climaxFactor
    }
    
    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

#Preview {
    ParticlePulseView()
        .frame(width: 200, height: 200)
}
