import SwiftUI

// 设置视图
struct SettingsView: View {
    @ObservedObject var config = Config.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题
                Text("SeeMusic 设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Divider()
                
                // 灵敏度
                VStack(alignment: .leading, spacing: 8) {
                    Text("灵敏度")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: $config.sensitivity, in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.0f%%", config.sensitivity * 100))
                            .frame(width: 50)
                    }
                }
                
                // 低频增强
                VStack(alignment: .leading, spacing: 8) {
                    Text("低频增强")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: $config.lowEnergyBoost, in: 1.0...3.0, step: 0.1)
                        Text(String(format: "%.1fx", config.lowEnergyBoost))
                            .frame(width: 50)
                    }
                }
                
                Divider()
                
                // 鼓点调参
                VStack(alignment: .leading, spacing: 8) {
                    Text("鼓点调参")
                        .font(.headline)
                    
                    HStack {
                        Text("RMS 增益")
                        Slider(value: $config.rmsGain, in: 1.0...5.0, step: 0.1)
                        Text(String(format: "%.1f", config.rmsGain))
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("低频增益")
                        Slider(value: $config.lowGain, in: 1.0...4.0, step: 0.1)
                        Text(String(format: "%.1f", config.lowGain))
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("鼓点增益")
                        Slider(value: $config.beatBoost, in: 1.0...4.0, step: 0.1)
                        Text(String(format: "%.1f", config.beatBoost))
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("RMS Attack")
                        Slider(value: $config.rmsAttackMs, in: 20...150, step: 5)
                        Text(String(format: "%.0fms", config.rmsAttackMs))
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("RMS Release")
                        Slider(value: $config.rmsReleaseMs, in: 120...600, step: 10)
                        Text(String(format: "%.0fms", config.rmsReleaseMs))
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("低频 Attack")
                        Slider(value: $config.lowAttackMs, in: 15...120, step: 5)
                        Text(String(format: "%.0fms", config.lowAttackMs))
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("低频 Release")
                        Slider(value: $config.lowReleaseMs, in: 100...500, step: 10)
                        Text(String(format: "%.0fms", config.lowReleaseMs))
                            .frame(width: 60)
                    }
                }
                
                Divider()
                
                // 主题
                VStack(alignment: .leading, spacing: 8) {
                    Text("主题")
                        .font(.headline)
                    
                    Picker("", selection: $config.theme) {
                        ForEach(Config.Theme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 帧率
                VStack(alignment: .leading, spacing: 8) {
                    Text("帧率模式")
                        .font(.headline)
                    
                    Picker("", selection: $config.frameRateMode) {
                        ForEach(Config.FrameRateMode.allCases, id: \.self) { mode in
                            Text("\(mode.rawValue) (\(Int(mode.fps)) FPS)").tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // 显示选项
                Toggle("显示曲目信息", isOn: $config.showTrackInfo)
                Toggle("显示调试信息", isOn: $config.showDebugOverlay)
                
                Spacer()
                
                // 关闭按钮
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 380, height: 560)
    }
}

#Preview {
    SettingsView()
}
