# 问题追踪列表

| ID | 问题 | 严重程度 | 状态 | 日期 |
|---|---|---|---|---|
| 1.1 | 音频处理运行在主线程 | 高 | ❌ 未修复 | 2025-12-30 |
| 1.2 | EqualizerView 渲染效率较低 | 中 | ❌ 未修复 | 2025-12-30 |
| 1.3 | 粒子系统主线程计算负载 | 中 | ❌ 未修复 | 2025-12-30 |
| 2.1 | 内存分配优化 | 低 | ❌ 未修复 | 2025-12-30 |
| 2.2 | 屏幕录制流配置 (视频流) | 低 | ❌ 未修复 | 2025-12-30 |
| 2.3 | 权限处理 (曲目信息) | 低 | ⏸️ 暂不处理 | 2025-12-30 |
| 3.1 | 硬编码 FPS (deltaTime) | 低 | ❌ 未修复 | 2025-12-30 |

## 验证说明

- **1.1**: `AudioCaptureService.swift` Line 73 仍使用 `Task { @MainActor in ... }` 派发处理。
- **1.2**: `EqualizerView.swift` 仍使用 `ForEach` + `RoundedRectangle` 构建 60 个 View。
- **1.3**: `ParticlePulseView.swift` Line 25 仍为 `particleCount = 220`。
- **2.1**: `FeatureExtractor.swift` Line 73 仍每帧创建新数组。
- **2.2**: `AudioCaptureService.swift` Line 60-64 仍配置 2x2 视频流。
- **2.3**: `MenuBarController.swift` 曲目信息功能仍被注释。
- **3.1**: `ParticlePulseView` / `WaveView` 仍使用固定 FPS 计算 deltaTime。
