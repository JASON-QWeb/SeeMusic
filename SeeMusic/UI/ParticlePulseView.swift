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
    @State private var paletteIndex: Int = 0
    @State private var paletteTargetIndex: Int = 0
    @State private var paletteBlend: CGFloat = 0
    @State private var nextPaletteSwitch: Double = 0
    
    // 粒子数据
    @State private var particles: [Particle] = []
    private let particleCount = 220
    
    private typealias PaletteStop = (h: CGFloat, s: CGFloat, b: CGFloat)
    private typealias Palette = [PaletteStop]
    private let paletteTransitionDuration: Double = 3.6
    private let paletteSwitchRange: ClosedRange<Double> = 20...30
    private let palettes: [Palette] = [
        [
            (h: 0.58, s: 0.82, b: 0.72),
            (h: 0.62, s: 0.80, b: 0.74),
            (h: 0.68, s: 0.82, b: 0.76),
            (h: 0.74, s: 0.80, b: 0.74),
            (h: 0.80, s: 0.78, b: 0.72)
        ],
        [
            (h: 0.78, s: 0.82, b: 0.74),
            (h: 0.84, s: 0.84, b: 0.76),
            (h: 0.90, s: 0.82, b: 0.74),
            (h: 0.96, s: 0.80, b: 0.72),
            (h: 0.02, s: 0.78, b: 0.70)
        ],
        [
            (h: 0.02, s: 0.84, b: 0.72),
            (h: 0.05, s: 0.86, b: 0.74),
            (h: 0.08, s: 0.86, b: 0.76),
            (h: 0.12, s: 0.84, b: 0.76),
            (h: 0.16, s: 0.82, b: 0.74)
        ],
        [
            (h: 0.62, s: 0.80, b: 0.70),
            (h: 0.66, s: 0.82, b: 0.72),
            (h: 0.70, s: 0.84, b: 0.74),
            (h: 0.76, s: 0.82, b: 0.74),
            (h: 0.84, s: 0.80, b: 0.72)
        ]
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
                    let paletteA = palettes[paletteIndex]
                    let paletteB = palettes[paletteTargetIndex]
                    let idle = idleBreathLevel(rms: smoothedRMS)
                    let breath = CGFloat(0.5 + 0.5 * sin(time * 1.1)) * idle
                    let rotation = rotationAngle
                    
                    for particle in particles {
                        let (position, particleSize, opacity, bulge) = calculateParticle(
                            particle: particle,
                            center: center,
                            radius: radius,
                            rms: smoothedRMS,
                            beat: smoothedBeat,
                            climax: smoothedClimax,
                            breath: breath,
                            rotation: rotation
                        )
                        
                        let anglePhase = Double((particle.angle + CGFloat(rotation)) / (2 * .pi))
                        let colorPhase = wrap01(Double(particle.radius) * 0.15 + anglePhase * 0.10)
                        let colorA = paletteColor(phase: colorPhase, palette: paletteA)
                        let colorB = paletteColor(phase: colorPhase, palette: paletteB)
                        let palette = blendPalette(colorA, colorB, paletteBlend)
                        let hue = clamp(palette.h + bulge * 0.06, 0.0, 1.0)
                        let saturation = clamp(palette.s + smoothedRMS * 0.12 + breath * 0.08, 0.0, 1.0)
                        let brightness = clamp(palette.b + smoothedRMS * 0.25 + bulge * 0.55 + breath * 0.20, 0.0, 1.0)
                        let particleColor = Color(
                            hue: hue,
                            saturation: saturation,
                            brightness: brightness
                        )
                        
                        let haloSize = particleSize * (1.6 + breath * 0.2)
                        context.fill(
                            Circle().path(in: CGRect(
                                x: position.x - haloSize / 2,
                                y: position.y - haloSize / 2,
                                width: haloSize,
                                height: haloSize
                            )),
                            with: .color(particleColor.opacity(opacity * 0.12))
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
            rotationAngle = 0
            rotationDirection = 1
            nextRotationSwitch = Double.random(in: 20...30)
            setupPaletteState()
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
        climax: CGFloat,
        breath: CGFloat,
        rotation: Double
    ) -> (CGPoint, CGFloat, CGFloat, CGFloat) {
        let activeRadius = 0.35 + rms * 0.55 + climax * 0.10
        let range = max(0.0, 1.0 - particle.radius / max(0.001, activeRadius))
        let edgeDamp = pow(1.0 - particle.radius, 0.6)
        let envelope = range * edgeDamp
        
        let beatGate = clamp((rms - 0.03) / 0.06, 0.0, 1.0)
        let beatSoft = pow(beat, 1.3) * beatGate
        let freq = 2.6 + rms * 5.5 + beatSoft * 6.0
        let freqValue = Double(freq)
        let wave = sin(time * freqValue - Double(particle.radius) * 6.0 + Double(particle.phase))
        let harmonic = 0.4 * sin(time * (freqValue * 1.7) + Double(particle.radius) * 9.0 + Double(particle.phase) * 1.3)
        
        let ringSpeed = 0.9 + rms * 0.6
        let ringPos = (time * Double(ringSpeed)).truncatingRemainder(dividingBy: 1.0)
        let ringWidth = 0.12 + rms * 0.10
        let ring = exp(-pow(Double((particle.radius - CGFloat(ringPos)) / ringWidth), 2.0))
        let impact = beatSoft * CGFloat(ring) * 0.12 * edgeDamp
        
        let amp = 0.03 + rms * 0.10 + beatSoft * 0.04 + climax * 0.08 + breath * 0.02
        let z = (CGFloat(wave) + CGFloat(harmonic)) * amp * envelope + impact
        let bulge = clamp(z, -0.18, 0.18)
        
        let angle = particle.angle + particle.jitter + CGFloat(rotation)
        let scale = 1.0 + bulge
        let x = center.x + cos(angle) * particle.radius * radius * scale
        let y = center.y + sin(angle) * particle.radius * radius * scale
        
        let size = particle.baseSize * (0.75 + rms * 0.35 + bulge * 1.6 + breath * 0.12)
        let opacity = clamp(0.25 + rms * 0.35 + bulge * 0.9 + breath * 0.12, 0.12, 1.0)
        
        return (CGPoint(x: x, y: y), size, opacity, bulge)
    }
    
    // 启动动画
    private func startAnimation() {
        timer?.invalidate()
        let fps = config.frameRateMode.fps
        let delta = 1.0 / fps
        let newTimer = Timer(timeInterval: 1.0 / fps, repeats: true) { _ in
            Task { @MainActor in
                self.time += delta
                self.updateFeatures()
                self.updateRotation(delta: delta)
                self.updatePalette(delta: delta)
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
        let beatAttack: CGFloat = 0.24
        let beatRelease: CGFloat = 0.10
        let climaxFactor: CGFloat = 0.25
        smoothedRMS += (targetRMS - smoothedRMS) * smoothFactor
        let beatAlpha = targetBeat > smoothedBeat ? beatAttack : beatRelease
        smoothedBeat += (targetBeat - smoothedBeat) * beatAlpha
        smoothedClimax += (targetClimax - smoothedClimax) * climaxFactor
    }
    
    private func updateRotation(delta: Double) {
        let speed = 0.10 + Double(smoothedRMS) * 0.08
        rotationAngle += rotationDirection * speed * delta
        if rotationAngle > Double.pi * 2 || rotationAngle < -Double.pi * 2 {
            rotationAngle = rotationAngle.truncatingRemainder(dividingBy: Double.pi * 2)
        }
        if time >= nextRotationSwitch {
            rotationDirection *= -1
            nextRotationSwitch = time + Double.random(in: 20...30)
        }
    }
    
    private func setupPaletteState() {
        guard !palettes.isEmpty else { return }
        paletteIndex = Int.random(in: 0..<palettes.count)
        paletteTargetIndex = paletteIndex
        paletteBlend = 0
        nextPaletteSwitch = time + Double.random(in: paletteSwitchRange)
    }
    
    private func updatePalette(delta: Double) {
        guard palettes.count > 1 else { return }
        if paletteIndex != paletteTargetIndex {
            let step = CGFloat(delta / paletteTransitionDuration)
            paletteBlend = min(1.0, paletteBlend + step)
            if paletteBlend >= 1.0 {
                paletteIndex = paletteTargetIndex
                paletteBlend = 0
                nextPaletteSwitch = time + Double.random(in: paletteSwitchRange)
            }
            return
        }
        if time >= nextPaletteSwitch {
            var nextIndex = paletteIndex
            while nextIndex == paletteIndex {
                nextIndex = Int.random(in: 0..<palettes.count)
            }
            paletteTargetIndex = nextIndex
            paletteBlend = 0
        }
    }
    
    private func paletteColor(phase: Double, palette: Palette) -> PaletteStop {
        let count = palette.count
        guard count > 1 else { return palette.first ?? (0.6, 0.8, 0.7) }
        let wrapped = wrap01(phase)
        let scaled = wrapped * Double(count)
        let index = Int(floor(scaled)) % count
        let nextIndex = (index + 1) % count
        let local = CGFloat(scaled - Double(index))
        let current = palette[index]
        let next = palette[nextIndex]
        return (
            h: lerpHue(current.h, next.h, local),
            s: lerp(current.s, next.s, local),
            b: lerp(current.b, next.b, local)
        )
    }
    
    private func blendPalette(_ from: PaletteStop, _ to: PaletteStop, _ t: CGFloat) -> PaletteStop {
        (
            h: lerpHue(from.h, to.h, t),
            s: lerp(from.s, to.s, t),
            b: lerp(from.b, to.b, t)
        )
    }
    
    private func idleBreathLevel(rms: CGFloat) -> CGFloat {
        clamp((0.06 - rms) / 0.06, 0.0, 1.0)
    }
    
    private func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
        start + (end - start) * t
    }
    
    private func lerpHue(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
        var delta = end - start
        if abs(delta) > 0.5 {
            delta = delta > 0 ? delta - 1.0 : delta + 1.0
        }
        var value = start + delta * t
        if value < 0 { value += 1.0 }
        if value > 1 { value -= 1.0 }
        return value
    }
    
    private func wrap01(_ value: Double) -> Double {
        value - floor(value)
    }
    
    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

#Preview {
    ParticlePulseView()
        .frame(width: 200, height: 200)
}
