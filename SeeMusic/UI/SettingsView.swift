import SwiftUI

// 设置视图
struct SettingsView: View {
    @ObservedObject var config = Config.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
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
            
            Spacer()
            
            // 关闭按钮
            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 350, height: 400)
    }
}

#Preview {
    SettingsView()
}
