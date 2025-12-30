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
    
    // 使用 FFT 计算低频能量
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
        
        // 低频范围 (0-250 Hz)
        let binWidth = sampleRate / Float(fftLength)
        let lowFreqLimit: Float = 250.0
        let lowFreqBins = Int(lowFreqLimit / binWidth)
        
        // 中频范围 (250-2000 Hz)
        let midFreqLimit: Float = 2000.0
        let midFreqBins = Int(midFreqLimit / binWidth)
        
        // 计算低频能量
        var lowSum: Float = 0
        for i in 1..<min(lowFreqBins, magnitudes.count) {
            lowSum += magnitudes[i]
        }
        
        // 计算中高频能量
        var midHighSum: Float = 0
        for i in lowFreqBins..<min(midFreqBins, magnitudes.count) {
            midHighSum += magnitudes[i]
        }
        
        // 低中频总和作为分母
        let total = lowSum + midHighSum
        guard total > 0.001 else { return 0 }
        
        // 计算低频占比（0-1）
        let lowRatio = lowSum / total
        
        // 返回标准化的低频能量
        return min(1.0, max(0.0, lowRatio))
    }
}
