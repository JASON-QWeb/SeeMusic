import Foundation
import AppKit
import ScriptingBridge

// Now Playing 服务 - 使用 Scripting Bridge 获取播放信息（仅支持 Apple Music）
// 注意：这是公开 API，安全且符合 App Store 要求
@MainActor
class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()
    
    @Published var trackInfo: TrackInfo?
    @Published var isAvailable = false
    
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 2.0  // 2秒轮询
    
    private init() {}
    
    // 开始轮询
    func startPolling() {
        stopPolling()
        
        // 立即获取一次
        print("[NowPlaying] 🎵 开始轮询...")
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
        // 尝试从 Apple Music 获取
        print("[NowPlaying] 检查 Apple Music...")
        if let info = fetchFromAppleMusic() {
            print("[NowPlaying] ✅ Apple Music: \(info.title ?? "无标题") - \(info.artist ?? "无艺术家")")
            trackInfo = info
            isAvailable = info.hasInfo
            return
        }
        
        // 尝试从 Spotify 获取
        print("[NowPlaying] 检查 Spotify...")
        if let info = fetchFromSpotify() {
            print("[NowPlaying] ✅ Spotify: \(info.title ?? "无标题") - \(info.artist ?? "无艺术家")")
            trackInfo = info
            isAvailable = info.hasInfo
            return
        }
        
        // 尝试从 QQ音乐 获取
        print("[NowPlaying] 检查 QQ音乐...")
        if let info = fetchFromQQMusic() {
            print("[NowPlaying] ✅ QQ音乐: \(info.title ?? "无标题") - \(info.artist ?? "无艺术家")")
            trackInfo = info
            isAvailable = info.hasInfo
            return
        }
        
        // 尝试从 网易云音乐 获取
        print("[NowPlaying] 检查 网易云音乐...")
        if let info = fetchFromNetEaseMusic() {
            print("[NowPlaying] ✅ 网易云: \(info.title ?? "无标题") - \(info.artist ?? "无艺术家")")
            trackInfo = info
            isAvailable = info.hasInfo
            return
        }
        
        // 没有播放信息
        print("[NowPlaying] ❌ 未检测到任何播放器")
        trackInfo = nil
        isAvailable = false
    }
    
    // 从 Apple Music 获取（使用 AppleScript）
    private func fetchFromAppleMusic() -> TrackInfo? {
        // 检查 Music 应用是否在运行
        let runningApps = NSWorkspace.shared.runningApplications
        let musicApp = runningApps.first { $0.bundleIdentifier == "com.apple.Music" }
        
        guard let app = musicApp else {
            print("[NowPlaying]   → Apple Music 未运行")
            return nil
        }
        print("[NowPlaying]   → Apple Music 正在运行: \(app.localizedName ?? "unknown")")
        
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                return trackName & "|||" & artistName
            else
                return ""
            end if
        end tell
        """
        
        return executeAppleScript(script)
    }
    
    // 从 Spotify 获取（使用 AppleScript）
    private func fetchFromSpotify() -> TrackInfo? {
        let runningApps = NSWorkspace.shared.runningApplications
        let spotifyApp = runningApps.first { $0.bundleIdentifier == "com.spotify.client" }
        
        guard let app = spotifyApp else {
            print("[NowPlaying]   → Spotify 未运行")
            return nil
        }
        print("[NowPlaying]   → Spotify 正在运行: \(app.localizedName ?? "unknown")")
        
        let script = """
        tell application "Spotify"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                return trackName & "|||" & artistName
            else
                return ""
            end if
        end tell
        """
        
        return executeAppleScript(script)
    }
    
    // 执行 AppleScript 并解析结果
    private func executeAppleScript(_ source: String) -> TrackInfo? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        
        let result = script.executeAndReturnError(&error)
        
        if let err = error {
            print("[NowPlaying]   → AppleScript 错误: \(err)")
            return nil
        }
        
        guard let resultString = result.stringValue, !resultString.isEmpty else {
            return nil
        }
        
        let parts = resultString.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }
        
        let title = parts[0].isEmpty ? nil : parts[0]
        let artist = parts[1].isEmpty ? nil : parts[1]
        
        return TrackInfo(
            title: title,
            artist: artist,
            artworkData: nil,
            isPlaying: true
        )
    }
    
    // 从 QQ音乐 获取（通过窗口标题）
    // QQ音乐窗口标题格式通常为: "歌曲名 - 歌手名"
    private func fetchFromQQMusic() -> TrackInfo? {
        let bundleId = "com.tencent.QQMusicMac"
        return fetchFromWindowTitle(bundleId: bundleId, separator: " - ")
    }
    
    // 从 网易云音乐 获取（通过窗口标题）
    // 网易云音乐窗口标题格式通常为: "歌曲名 - 歌手名"
    private func fetchFromNetEaseMusic() -> TrackInfo? {
        let bundleId = "com.netease.163music"
        return fetchFromWindowTitle(bundleId: bundleId, separator: " - ")
    }
    
    // 通过窗口标题获取歌曲信息（适用于不支持 AppleScript 的应用）
    private func fetchFromWindowTitle(bundleId: String, separator: String) -> TrackInfo? {
        // 检查应用是否在运行
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) else {
            return nil
        }
        
        // 通过 Accessibility API 获取窗口标题
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            return nil
        }
        
        // 获取第一个窗口的标题
        var titleRef: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(windows[0], kAXTitleAttribute as CFString, &titleRef)
        
        guard titleResult == .success, let title = titleRef as? String, !title.isEmpty else {
            return nil
        }
        
        // 解析标题（格式: "歌曲名 - 歌手名" 或只有应用名）
        // 排除只包含应用名的情况
        let appName = app.localizedName ?? ""
        if title == appName || title == "QQ音乐" || title == "网易云音乐" {
            return nil
        }
        
        // 尝试解析 "歌曲名 - 歌手名" 格式
        if title.contains(separator) {
            let parts = title.components(separatedBy: separator)
            if parts.count >= 2 {
                let songTitle = parts[0].trimmingCharacters(in: .whitespaces)
                let artist = parts[1].trimmingCharacters(in: .whitespaces)
                
                if !songTitle.isEmpty {
                    return TrackInfo(
                        title: songTitle,
                        artist: artist.isEmpty ? nil : artist,
                        artworkData: nil,
                        isPlaying: true
                    )
                }
            }
        }
        
        // 如果格式不匹配，整个标题作为歌曲名
        return TrackInfo(
            title: title,
            artist: nil,
            artworkData: nil,
            isPlaying: true
        )
    }
}
