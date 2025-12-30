import SwiftUI

// 主内容视图 - 根据主题切换不同的可视化效果
struct ContentView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var audioService = AudioCaptureService.shared
    
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
        }
        .frame(
            width: config.windowWidth,
            height: config.windowHeight
        )
        .onAppear {
            // 统一启动音频捕获
            startAudioCapture()
        }
        .onDisappear {
            // 统一停止音频捕获
            stopAudioCapture()
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
