import SwiftUI

// 主内容视图 - 整合波浪和曲目信息
struct ContentView: View {
    @ObservedObject var config = Config.shared
    
    var body: some View {
        ZStack {
            // 波浪视图（透明背景）
            WaveView()
            
            // TODO: 曲目信息功能暂时禁用，等待权限方案解决后恢复
            // VStack {
            //     if config.showTrackInfo {
            //         TrackInfoView()
            //             .padding(.horizontal, 8)
            //             .padding(.top, 8)
            //     }
            //     Spacer()
            // }
        }
        .frame(
            width: config.windowWidth,
            height: config.windowHeight
        )
    }
}

#Preview {
    ContentView()
}
