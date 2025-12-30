import SwiftUI

// 主内容视图 - 根据主题切换不同的可视化效果
struct ContentView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var audioService = AudioCaptureService.shared
    
    // 调整大小控制状态
    @State private var showResizeHandle = false
    @State private var hideTimer: Timer?
    
    var body: some View {
        ZStack {
            // 根据主题选择不同的视图
            switch config.theme {
            case .classic, .minimal, .neon:
                // 波浪类主题
                WaveView()
            case .equalizer:
                // 音响柱状图主题
                EqualizerView()
            case .particle:
                // 粒子脉冲主题
                ParticlePulseView()
            }
            
            // 调整大小的边框指示器
            if showResizeHandle {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 4, dash: [10]))
                    .foregroundColor(Color.white.opacity(0.3))
                    .allowsHitTesting(false) // 允许穿透点击
                    .transition(.opacity)
            }
        }
        .frame(
            width: config.theme.recommendedSize.width,
            height: config.theme.recommendedSize.height
        )
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                if isHovering {
                    // 鼠标进入：立即显示，取消隐藏计时器
                    showResizeHandle = true
                    hideTimer?.invalidate()
                    hideTimer = nil
                } else {
                    // 鼠标移出：延迟 2秒 隐藏
                    hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showResizeHandle = false
                        }
                    }
                }
            }
        }
        .onAppear {
            // 统一启动音频捕获
            startAudioCapture()
        }
        .onDisappear {
            // 统一停止音频捕获
            stopAudioCapture()
            hideTimer?.invalidate()
        }
        .onChange(of: config.theme) { oldValue, newValue in
            // 主题切换时通知窗口调整大小
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        }
    }
    
    // 启动音频捕获
    private func startAudioCapture() {
        print("[SeeMusic] 🚀 ContentView 启动音频捕获...")
        Task {
            await audioService.start()
            print("[SeeMusic] 🎧 音频服务已启动: isCapturing=\(audioService.isCapturing)")
        }
    }
    
    // 停止音频捕获
    private func stopAudioCapture() {
        Task {
            await audioService.stop()
        }
    }
}

// 主题切换通知
extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}

#Preview {
    ContentView()
}
