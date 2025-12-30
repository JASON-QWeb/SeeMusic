import Foundation

// 应用配置管理
class Config: ObservableObject {
    static let shared = Config()
    
    // MARK: - 波浪设置
    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "sensitivity") }
    }
    
    @Published var lowEnergyBoost: Double {
        didSet { UserDefaults.standard.set(lowEnergyBoost, forKey: "lowEnergyBoost") }
    }
    
    // MARK: - 外观设置
    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    
    @Published var frameRateMode: FrameRateMode {
        didSet { UserDefaults.standard.set(frameRateMode.rawValue, forKey: "frameRateMode") }
    }
    
    // MARK: - 窗口设置
    @Published var windowWidth: CGFloat {
        didSet { UserDefaults.standard.set(windowWidth, forKey: "windowWidth") }
    }
    
    @Published var windowHeight: CGFloat {
        didSet { UserDefaults.standard.set(windowHeight, forKey: "windowHeight") }
    }
    
    @Published var showTrackInfo: Bool {
        didSet { UserDefaults.standard.set(showTrackInfo, forKey: "showTrackInfo") }
    }
    
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    
    // MARK: - 枚举定义
    enum Theme: String, CaseIterable {
        case classic = "经典"
        case minimal = "简约"
        case neon = "霓虹"
    }
    
    enum FrameRateMode: String, CaseIterable {
        case performance = "节能"   // 30 FPS
        case balanced = "平衡"      // 45 FPS
        case smooth = "丝滑"        // 60 FPS
        
        var fps: Double {
            switch self {
            case .performance: return 30
            case .balanced: return 45
            case .smooth: return 60
            }
        }
    }
    
    // MARK: - 初始化
    private init() {
        self.sensitivity = UserDefaults.standard.object(forKey: "sensitivity") as? Double ?? 1.0
        self.lowEnergyBoost = UserDefaults.standard.object(forKey: "lowEnergyBoost") as? Double ?? 1.5
        self.theme = Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .classic
        self.frameRateMode = FrameRateMode(rawValue: UserDefaults.standard.string(forKey: "frameRateMode") ?? "") ?? .smooth
        self.windowWidth = UserDefaults.standard.object(forKey: "windowWidth") as? CGFloat ?? 480
        self.windowHeight = UserDefaults.standard.object(forKey: "windowHeight") as? CGFloat ?? 140
        self.showTrackInfo = UserDefaults.standard.object(forKey: "showTrackInfo") as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
    }
}
