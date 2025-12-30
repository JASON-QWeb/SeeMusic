import Foundation

// 平滑器 - Attack/Release 平滑 + dB 映射，让波浪随音量起伏更真实
class Smoother {
    // Attack/Release 时间常数（秒）
    private let rmsAttack: Double = 0.03
    private let rmsRelease: Double = 0.25
    private let lowAttack: Double = 0.05
    private let lowRelease: Double = 0.30

    // dB 映射范围
    private let targetRangeDb: Float = 28.0
    private let minRangeDb: Float = 12.0
    private let minDb: Float = -80.0
    private let gateDb: Float = -70.0

    // 峰值/噪声地板跟踪
    private let peakRelease: Double = 1.5
    private let floorRise: Double = 6.0
    private let floorFall: Double = 1.5
    
    // 状态
    private var smoothedRMS: Float = 0
    private var smoothedLowEnergy: Float = 0
    private var lastUpdateTime: Double = 0
    private var peakDb: Float = -20.0
    private var floorDb: Float = -60.0
    
    func smooth(_ features: AudioFeatures) -> AudioFeatures {
        let currentTime = features.timestamp
        let isFirst = lastUpdateTime == 0
        let dt = isFirst ? (1.0 / 60.0) : max(0.001, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        let rmsDb = rmsToDb(features.rms)
        if isFirst {
            peakDb = rmsDb
            floorDb = max(minDb, rmsDb - targetRangeDb)
        }

        // 更新峰值与噪声地板
        let peakReleaseAlpha = smoothingAlpha(dt: dt, timeConstant: peakRelease)
        if rmsDb > peakDb {
            peakDb = rmsDb
        } else {
            peakDb += (rmsDb - peakDb) * peakReleaseAlpha
        }

        let floorRiseAlpha = smoothingAlpha(dt: dt, timeConstant: floorRise)
        let floorFallAlpha = smoothingAlpha(dt: dt, timeConstant: floorFall)
        if rmsDb < floorDb {
            floorDb += (rmsDb - floorDb) * floorFallAlpha
        } else {
            floorDb += (rmsDb - floorDb) * floorRiseAlpha
        }
        floorDb = max(floorDb, minDb)

        // 计算可视化范围
        let visualFloor = max(floorDb, peakDb - targetRangeDb)
        let effectiveFloor = min(visualFloor, peakDb - minRangeDb)
        let rangeDb = max(peakDb - effectiveFloor, minRangeDb)

        var normalizedRMS = (rmsDb - effectiveFloor) / rangeDb
        normalizedRMS = clamp01(normalizedRMS)
        if rmsDb < gateDb {
            normalizedRMS = 0
        }
        normalizedRMS = powf(normalizedRMS, 0.75)

        // Attack/Release 平滑
        let rmsAttackAlpha = smoothingAlpha(dt: dt, timeConstant: rmsAttack)
        let rmsReleaseAlpha = smoothingAlpha(dt: dt, timeConstant: rmsRelease)
        if normalizedRMS > smoothedRMS {
            smoothedRMS += (normalizedRMS - smoothedRMS) * rmsAttackAlpha
        } else {
            smoothedRMS += (normalizedRMS - smoothedRMS) * rmsReleaseAlpha
        }

        var normalizedLow = clamp01(features.lowEnergy)
        normalizedLow = powf(normalizedLow, 0.8)

        let lowAttackAlpha = smoothingAlpha(dt: dt, timeConstant: lowAttack)
        let lowReleaseAlpha = smoothingAlpha(dt: dt, timeConstant: lowRelease)
        if normalizedLow > smoothedLowEnergy {
            smoothedLowEnergy += (normalizedLow - smoothedLowEnergy) * lowAttackAlpha
        } else {
            smoothedLowEnergy += (normalizedLow - smoothedLowEnergy) * lowReleaseAlpha
        }

        // 低频增强受整体能量门控，避免静音时误触发
        let energyGate = min(1.0, smoothedRMS * 1.5)
        smoothedLowEnergy *= energyGate

        smoothedRMS = clamp01(smoothedRMS)
        smoothedLowEnergy = clamp01(smoothedLowEnergy)
        
        return AudioFeatures(
            timestamp: currentTime,
            rms: smoothedRMS,
            lowEnergy: smoothedLowEnergy,
            beat: 0,
            climaxLevel: 0,
            isClimax: false,
            sampleRate: features.sampleRate
        )
    }
    
    func reset() {
        smoothedRMS = 0
        smoothedLowEnergy = 0
        lastUpdateTime = 0
        peakDb = -20.0
        floorDb = -60.0
    }

    private func rmsToDb(_ rms: Float) -> Float {
        let safeRms = max(rms, 1e-6)
        return 20.0 * log10f(safeRms)
    }

    private func smoothingAlpha(dt: Double, timeConstant: Double) -> Float {
        guard timeConstant > 0 else { return 1.0 }
        let alpha = 1.0 - exp(-dt / timeConstant)
        return Float(alpha)
    }

    private func clamp01(_ value: Float) -> Float {
        return min(1.0, max(0.0, value))
    }
}
