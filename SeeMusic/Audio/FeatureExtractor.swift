import Foundation
import AVFoundation
import Accelerate

// 特征提取器 - 从音频 buffer 提取 RMS 和低频能量
class FeatureExtractor {
    private let fftLength = 2048
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length
    
    // 用于 FFT 的缓冲区
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var window: [Float]
    private var splitComplex: DSPSplitComplex
    
    init() {
        log2n = vDSP_Length(log2(Float(fftLength)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        realBuffer = [Float](repeating: 0, count: fftLength / 2)
        imagBuffer = [Float](repeating: 0, count: fftLength / 2)
        
        // 创建 Hanning 窗
        window = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        
        splitComplex = DSPSplitComplex(realp: UnsafeMutablePointer<Float>.allocate(capacity: fftLength / 2),
                                        imagp: UnsafeMutablePointer<Float>.allocate(capacity: fftLength / 2))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
        splitComplex.realp.deallocate()
        splitComplex.imagp.deallocate()
    }
    
    func extractFeatures(from sampleBuffer: CMSampleBuffer) -> AudioFeatures {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return .zero
        }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        
        guard status == kCMBlockBufferNoErr, let data = dataPointer else {
            return .zero
        }
        
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return .zero
        }
        
        let sampleRate = asbd.pointee.mSampleRate
        let bytesPerSample = Int(asbd.pointee.mBytesPerFrame / asbd.pointee.mChannelsPerFrame)
        let channelCount = Int(asbd.pointee.mChannelsPerFrame)
        let sampleCount = length / Int(asbd.pointee.mBytesPerFrame)
        
        guard sampleCount > 0 else { return .zero }
        
        // 转换为 Float 数组
        var samples = [Float](repeating: 0, count: min(sampleCount, fftLength))
        
        if bytesPerSample == 4 { // Float32
            let floatData = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
            for i in 0..<samples.count {
                let index = i * channelCount
                if index < sampleCount * channelCount {
                    var sum: Float = 0
                    for ch in 0..<channelCount {
                        sum += floatData[index + ch]
                    }
                    samples[i] = sum / Float(channelCount)
                }
            }
        } else if bytesPerSample == 2 { // Int16
            let int16Data = UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self)
            for i in 0..<samples.count {
                let index = i * channelCount
                if index < sampleCount * channelCount {
                    var sum: Float = 0
                    for ch in 0..<channelCount {
                        sum += Float(int16Data[index + ch]) / 32768.0
                    }
                    samples[i] = sum / Float(channelCount)
                }
            }
        }
        
        // 计算 RMS（保持原始动态范围，后续在平滑器中做映射）
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        let rawRMS = min(1.0, max(0.0, rms))
        
        // 使用 FFT 计算低频能量占比
        let lowEnergy = calculateLowEnergyFFT(samples: samples, sampleRate: Float(sampleRate))
        
        return AudioFeatures(
            timestamp: CACurrentMediaTime(),
            rms: rawRMS,
            lowEnergy: lowEnergy,
            beat: 0,
            climaxLevel: 0,
            isClimax: false,
            sampleRate: sampleRate
        )
    }
    
    // 使用 FFT 计算人声频段能量（300-3000 Hz 占总能量的比例）
    // 人声出现时返回高值，纯背景音乐时返回低值
    private func calculateLowEnergyFFT(samples: [Float], sampleRate: Float) -> Float {
        guard let setup = fftSetup, !samples.isEmpty else {
            return 0
        }
        
        // 准备数据并应用窗函数
        var windowedSamples = [Float](repeating: 0, count: fftLength)
        let copyCount = min(samples.count, fftLength)
        for i in 0..<copyCount {
            windowedSamples[i] = samples[i] * window[i]
        }
        
        // 转换为 split complex 格式
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftLength / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftLength / 2))
            }
        }
        
        // 执行 FFT
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // 计算幅度谱
        var magnitudes = [Float](repeating: 0, count: fftLength / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftLength / 2))
        
        let binWidth = sampleRate / Float(fftLength)
        
        // 频段定义
        let lowFreqLimit: Float = 300.0      // 低频上限
        let vocalLowLimit: Float = 300.0     // 人声下限
        let vocalHighLimit: Float = 3500.0   // 人声上限
        let highFreqLimit: Float = 8000.0    // 高频上限
        
        let lowBins = Int(lowFreqLimit / binWidth)
        let vocalLowBins = Int(vocalLowLimit / binWidth)
        let vocalHighBins = Int(vocalHighLimit / binWidth)
        let highBins = Int(highFreqLimit / binWidth)
        
        // 计算各频段能量
        var lowSum: Float = 0
        for i in 1..<min(lowBins, magnitudes.count) {
            lowSum += magnitudes[i]
        }
        
        var vocalSum: Float = 0
        for i in vocalLowBins..<min(vocalHighBins, magnitudes.count) {
            vocalSum += magnitudes[i]
        }
        
        var highSum: Float = 0
        for i in vocalHighBins..<min(highBins, magnitudes.count) {
            highSum += magnitudes[i]
        }
        
        // 总能量
        let total = lowSum + vocalSum + highSum
        guard total > 0.001 else { return 0 }
        
        // 人声频段占比 - 人声出现时这个值高，纯伴奏时这个值低
        let vocalRatio = vocalSum / total
        
        // 对人声占比做非线性映射，增强对比度
        // 典型纯伴奏 vocalRatio ~ 0.3-0.4，人声 ~ 0.5-0.7
        let normalized = (vocalRatio - 0.25) / 0.45  // 映射到 0-1 范围
        let enhanced = powf(max(0, normalized), 0.8)  // 压缩提升对比度
        
        return min(1.0, max(0.0, enhanced))
    }
}
