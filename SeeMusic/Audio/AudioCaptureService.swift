import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

// 音频捕获服务 - 使用 ScreenCaptureKit 捕获系统音频
@MainActor
class AudioCaptureService: NSObject, ObservableObject, SCStreamDelegate {
    static let shared = AudioCaptureService()
    
    @Published var isCapturing = false
    @Published var currentFeatures: AudioFeatures = .zero
    
    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private var screenOutput: ScreenStreamOutput?
    private let featureExtractor = FeatureExtractor()
    private let featurePipeline = FeaturePipeline()
    private var isStarting = false
    
    override init() {
        super.init()
    }
    
    // 开始捕获
    func start() async {
        guard !isCapturing && !isStarting else {
            print("[SeeMusic] ⚠️ 已在捕获中或正在启动，跳过")
            return
        }
        
        isStarting = true
        featurePipeline.reset()
        
        do {
            print("[SeeMusic] 📡 获取屏幕信息...")
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            guard let display = content.displays.first else {
                print("[SeeMusic] ❌ 未找到显示器")
                isStarting = false
                return
            }
            
            print("[SeeMusic] 🖥️ 使用显示器: \(display.displayID), 尺寸: \(display.width)x\(display.height)")
            
            // 创建内容过滤器
            let filter = SCContentFilter(display: display, excludingWindows: [])
            
            // 配置流 - 关键是要设置合理的视频参数
            let config = SCStreamConfiguration()
            
            // 音频设置
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = false
            config.sampleRate = 48000
            config.channelCount = 2
            
            // 视频设置 - 需要设置合理的尺寸，不能太小
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA
            
            print("[SeeMusic] 📝 创建 SCStream...")
            
            // 创建流（使用 self 作为 delegate）
            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            
            // 设置音频输出
            let output = AudioStreamOutput { [weak self] buffer in
                Task { @MainActor in
                    self?.processAudioBuffer(buffer)
                }
            }
            
            print("[SeeMusic] 🔌 添加音频输出...")
            try newStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.seemusic.audio", qos: .userInteractive))

            let videoOutput = ScreenStreamOutput()
            try newStream.addStreamOutput(videoOutput, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.seemusic.screen", qos: .utility))
            
            // 保存引用
            self.stream = newStream
            self.streamOutput = output
            self.screenOutput = videoOutput
            
            print("[SeeMusic] ▶️ 启动捕获...")
            try await newStream.startCapture()
            
            isCapturing = true
            isStarting = false
            
            print("[SeeMusic] ✅ 音频捕获已成功启动！")
            print("[SeeMusic] 📊 配置: 采样率=\(config.sampleRate), 声道=\(config.channelCount)")
            
        } catch {
            print("[SeeMusic] ❌ 音频捕获启动失败: \(error)")
            print("[SeeMusic] 📋 错误详情: \(error.localizedDescription)")
            isCapturing = false
            isStarting = false
            stream = nil
            streamOutput = nil
            screenOutput = nil
        }
    }
    
    // 停止捕获
    func stop() async {
        guard isCapturing else { return }
        
        do {
            try await stream?.stopCapture()
            stream = nil
            streamOutput = nil
            screenOutput = nil
            isCapturing = false
            featurePipeline.reset()
            print("[SeeMusic] ⏹️ 音频捕获已停止")
        } catch {
            print("[SeeMusic] ❌ 停止捕获失败: \(error)")
        }
    }
    
    // SCStreamDelegate
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[SeeMusic] ⚠️ 流停止: \(error.localizedDescription)")
        Task { @MainActor in
            self.isCapturing = false
            self.stream = nil
            self.streamOutput = nil
            self.screenOutput = nil
            self.featurePipeline.reset()
        }
    }
    
    // 处理音频 buffer
    // private var logCounter = 0
    private func processAudioBuffer(_ buffer: CMSampleBuffer) {
        let rawFeatures = featureExtractor.extractFeatures(from: buffer)
        let params = FeaturePipeline.Parameters(
            rmsGain: Float(Config.shared.rmsGain),
            lowGain: Float(Config.shared.lowGain),
            beatDiffGain: Float(Config.shared.beatBoost),
            rmsAttackMs: Config.shared.rmsAttackMs,
            rmsReleaseMs: Config.shared.rmsReleaseMs,
            lowAttackMs: Config.shared.lowAttackMs,
            lowReleaseMs: Config.shared.lowReleaseMs
        )
        let processed = featurePipeline.process(rawFeatures, parameters: params)
        currentFeatures = processed
        
        // logCounter += 1
        // if logCounter >= 60 {
        //     logCounter = 0
        //     print("[SeeMusic] 🎵 音频: RMS=\(String(format: "%.4f", processed.rms)), Low=\(String(format: "%.4f", processed.lowEnergy))")
        // }
    }
}

// 音频流输出处理器
class AudioStreamOutput: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer) -> Void
    
    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        handler(sampleBuffer)
    }
}

// 仅用于消化视频帧，避免 SCStream 报错
class ScreenStreamOutput: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
    }
}
