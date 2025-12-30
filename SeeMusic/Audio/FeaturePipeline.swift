import Foundation

// 音频特征流水线：噪声地板 -> 归一化/压缩 -> 平滑 -> 鼓点/高潮检测
final class FeaturePipeline {
    struct Parameters {
        let rmsGain: Float
        let lowGain: Float
        let beatDiffGain: Float
        let rmsAttackMs: Double
        let rmsReleaseMs: Double
        let lowAttackMs: Double
        let lowReleaseMs: Double
    }

    // Noise Floor
    private let nfAlpha: Float = 0.995
    private let nfMargin: Float = 0.015
    private let nfFreezeRms: Float = 0.03

    // Normalize + Compress
    private let gammaRms: Float = 0.60
    private let gammaLow: Float = 0.70

    // Beat + Climax
    private let beatRmsRatio: Float = 0.65
    private let beatGate: Float = 0.08
    private let windowSec: Double = 0.8
    private let climaxAttackMs: Double = 180
    private let climaxReleaseMs: Double = 700
    private let hystOn: Float = 0.60
    private let hystOff: Float = 0.45

    // State
    private var noiseFloor: Float = 0
    private var rmsSmoothed: Float = 0
    private var lowSmoothed: Float = 0
    private var lastLowSmoothed: Float = 0
    private var lastRmsSmoothed: Float = 0
    private var climaxLevel: Float = 0
    private var isClimax = false
    private var lastTime: Double = 0
    private var energyWindow: [(time: Double, value: Float)] = []

    func process(_ raw: AudioFeatures, parameters: Parameters) -> AudioFeatures {
        let time = raw.timestamp
        let dt = lastTime == 0 ? (1.0 / 60.0) : max(0.001, time - lastTime)
        lastTime = time

        let rmsRaw = clamp01(raw.rms)
        let lowRaw = clamp01(raw.lowEnergy)

        // 1) Noise floor update (freeze when signal is strong)
        if rmsRaw < nfFreezeRms {
            noiseFloor = nfAlpha * noiseFloor + (1 - nfAlpha) * rmsRaw
        }
        let nf2 = noiseFloor + nfMargin

        // 2) Normalize + compress
        let rms1 = clamp01((rmsRaw - nf2) * parameters.rmsGain)
        let low1 = clamp01((lowRaw - nf2) * parameters.lowGain)
        let rms2 = powf(rms1, gammaRms)
        let low2 = powf(low1, gammaLow)

        // 3) Attack/Release smoothing
        let rmsAttackAlpha = alpha(dt: dt, ms: parameters.rmsAttackMs)
        let rmsReleaseAlpha = alpha(dt: dt, ms: parameters.rmsReleaseMs)
        let lowAttackAlpha = alpha(dt: dt, ms: parameters.lowAttackMs)
        let lowReleaseAlpha = alpha(dt: dt, ms: parameters.lowReleaseMs)

        rmsSmoothed = smooth(prev: rmsSmoothed, x: rms2, attack: rmsAttackAlpha, release: rmsReleaseAlpha)
        lowSmoothed = smooth(prev: lowSmoothed, x: low2, attack: lowAttackAlpha, release: lowReleaseAlpha)

        // 4) Beat accent (transient)
        let lowDiff = max(0, lowSmoothed - lastLowSmoothed)
        let rmsDiff = max(0, rmsSmoothed - lastRmsSmoothed)
        var beat = max(lowDiff * parameters.beatDiffGain, rmsDiff * parameters.beatDiffGain * beatRmsRatio)
        beat = clamp01(powf(beat, 0.8))
        if rmsSmoothed < beatGate {
            beat = 0
        }
        lastLowSmoothed = lowSmoothed
        lastRmsSmoothed = rmsSmoothed

        // 5) Climax detection (section-level + beat override)
        let energy = max(rmsSmoothed, lowSmoothed * 0.85)
        updateWindow(time: time, value: energy)
        let climaxRaw = computeClimaxRaw()
        let climaxAttackAlpha = alpha(dt: dt, ms: climaxAttackMs)
        let climaxReleaseAlpha = alpha(dt: dt, ms: climaxReleaseMs)
        let climaxInput = max(climaxRaw, beat)
        climaxLevel = smooth(prev: climaxLevel, x: climaxInput, attack: climaxAttackAlpha, release: climaxReleaseAlpha)

        if !isClimax && climaxLevel > hystOn {
            isClimax = true
        } else if isClimax && climaxLevel < hystOff {
            isClimax = false
        }

        return AudioFeatures(
            timestamp: time,
            rms: rmsSmoothed,
            lowEnergy: lowSmoothed,
            beat: beat,
            climaxLevel: climaxLevel,
            isClimax: isClimax,
            sampleRate: raw.sampleRate
        )
    }

    func reset() {
        noiseFloor = 0
        rmsSmoothed = 0
        lowSmoothed = 0
        lastLowSmoothed = 0
        lastRmsSmoothed = 0
        climaxLevel = 0
        isClimax = false
        lastTime = 0
        energyWindow.removeAll()
    }

    private func updateWindow(time: Double, value: Float) {
        energyWindow.append((time: time, value: value))
        let cutoff = time - windowSec
        while let first = energyWindow.first, first.time < cutoff {
            energyWindow.removeFirst()
        }
    }

    private func computeClimaxRaw() -> Float {
        guard !energyWindow.isEmpty else { return 0 }

        var sum: Float = 0
        var peak: Float = 0
        for sample in energyWindow {
            sum += sample.value
            peak = max(peak, sample.value)
        }

        let count = Float(energyWindow.count)
        let mean = sum / count

        let m = clamp01((mean - 0.35) / 0.50)
        let p = clamp01((peak - 0.55) / 0.35)

        return 0.70 * m + 0.30 * p
    }

    private func alpha(dt: Double, ms: Double) -> Float {
        guard ms > 0 else { return 0 }
        return Float(exp(-dt / (ms / 1000.0)))
    }

    private func smooth(prev: Float, x: Float, attack: Float, release: Float) -> Float {
        let a = x > prev ? attack : release
        return a * prev + (1 - a) * x
    }

    private func clamp01(_ value: Float) -> Float {
        return min(1, max(0, value))
    }
}
