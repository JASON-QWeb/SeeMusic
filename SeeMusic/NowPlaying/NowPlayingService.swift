import Foundation
import AppKit

// Now Playing 服务 - 获取系统当前播放的曲目信息
@MainActor
class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()
    
    @Published var trackInfo: TrackInfo?
    @Published var isAvailable = false
    
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 1.0  // 1秒轮询
    
    private init() {}
    
    // 开始轮询
    func startPolling() {
        stopPolling()
        
        // 立即获取一次
        fetchNowPlaying()
        
        // 设置轮询定时器
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchNowPlaying()
            }
        }
    }
    
    // 停止轮询
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // 获取当前播放信息
    private func fetchNowPlaying() {
        // 使用 MediaRemote 私有框架获取 Now Playing 信息
        // 通过动态加载避免直接依赖
        
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, 
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else {
            isAvailable = false
            return
        }
        
        // 获取 MRMediaRemoteGetNowPlayingInfo 函数
        guard let getInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
            isAvailable = false
            return
        }
        
        typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (
            DispatchQueue,
            @escaping ([String: Any]?) -> Void
        ) -> Void
        
        let getInfo = unsafeBitCast(getInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        
        getInfo(DispatchQueue.main) { [weak self] info in
            Task { @MainActor in
                guard let self = self else { return }
                
                guard let info = info, !info.isEmpty else {
                    self.trackInfo = nil
                    self.isAvailable = false
                    return
                }
                
                // 提取信息
                let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
                let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
                let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
                let playbackRate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double
                
                self.trackInfo = TrackInfo(
                    title: title,
                    artist: artist,
                    artworkData: artworkData,
                    isPlaying: playbackRate.map { $0 > 0 }
                )
                
                self.isAvailable = title != nil || artist != nil
            }
        }
    }
}
