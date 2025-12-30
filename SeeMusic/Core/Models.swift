import Foundation

// AudioFeatures: 音频特征数据
struct AudioFeatures {
    let timestamp: Double
    let rms: Float           // 0..1 整体能量
    let lowEnergy: Float     // 0..1 低频能量
    let beat: Float          // 0..1 鼓点瞬态
    let climaxLevel: Float   // 0..1 段落增强
    let isClimax: Bool
    let sampleRate: Double
    
    static let zero = AudioFeatures(
        timestamp: 0,
        rms: 0,
        lowEnergy: 0,
        beat: 0,
        climaxLevel: 0,
        isClimax: false,
        sampleRate: 44100
    )
}

// TrackInfo: 当前播放曲目信息
struct TrackInfo {
    var title: String?
    var artist: String?
    var artworkData: Data?
    var isPlaying: Bool?
    
    init(title: String? = nil, artist: String? = nil, artworkData: Data? = nil, isPlaying: Bool? = nil) {
        self.title = title
        self.artist = artist
        self.artworkData = artworkData
        self.isPlaying = isPlaying
    }
    
    var hasInfo: Bool {
        title != nil || artist != nil
    }
}
