import SwiftUI

// 曲目信息视图
struct TrackInfoView: View {
    @ObservedObject var nowPlayingService = NowPlayingService.shared
    @ObservedObject var config = Config.shared
    
    var body: some View {
        Group {
            if config.showTrackInfo, let trackInfo = nowPlayingService.trackInfo, trackInfo.hasInfo {
                HStack(spacing: 12) {
                    // 封面图
                    if let artworkData = trackInfo.artworkData,
                       let nsImage = NSImage(data: artworkData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        // 默认封面
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.8))
                            )
                    }
                    
                    // 歌曲信息
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = trackInfo.title {
                            Text(title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        if let artist = trackInfo.artist {
                            Text(artist)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // 播放状态指示
                    if let isPlaying = trackInfo.isPlaying {
                        Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: nowPlayingService.trackInfo?.title)
        .onAppear {
            nowPlayingService.startPolling()
        }
        .onDisappear {
            nowPlayingService.stopPolling()
        }
    }
}

#Preview {
    TrackInfoView()
        .padding()
        .background(Color.black)
}
