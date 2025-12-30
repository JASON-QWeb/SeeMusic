# 问题追踪列表

| ID | 问题 | 严重程度 | 状态 | 日期 |
|---|---|---|---|---|
| 1.1 | 音频处理运行在主线程 | 高 | ✅ 已修复 | 2025-12-30 |
| 1.2 | EqualizerView 渲染效率较低 | 中 | ✅ 已修复 | 2025-12-30 |
| 1.3 | 粒子系统主线程计算负载 | 中 | ✅ 已修复 | 2025-12-30 |
| 2.1 | 内存分配优化 | 低 | ✅ 已修复 | 2025-12-30 |
| 2.2 | 屏幕录制流配置 (视频流) | 低 | ⏸️ 设计限制 | 2025-12-30 |
| 2.3 | 权限处理 (曲目信息) | 低 | ⏸️ 暂不处理 | 2025-12-30 |
| 3.1 | 硬编码 FPS (deltaTime) | 低 | ✅ 已修复 | 2025-12-30 |

## 修复说明

- **1.1**: `AudioCaptureService.swift` - 音频处理已移至后台队列 `processingQueue`。
- **1.2**: `EqualizerView.swift` - 已使用 `Canvas` 替代 60 个 SwiftUI View。
- **1.3**: `ParticlePulseView.swift` - 粒子数量从 220 降至 120。
- **2.1**: `FeatureExtractor.swift` - `samples` 缓冲区已预分配为类成员。
- **2.2**: ScreenCaptureKit 要求必须配置视频流，2x2 已是最小化配置。
- **3.1**: `WaveView`, `ParticlePulseView` - 使用 `CACurrentMediaTime()` 计算真实 deltaTime。
