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

    @Published var rmsGain: Double {
        didSet { UserDefaults.standard.set(rmsGain, forKey: "rmsGain") }
    }

    @Published var lowGain: Double {
        didSet { UserDefaults.standard.set(lowGain, forKey: "lowGain") }
    }

    @Published var beatBoost: Double {
        didSet { UserDefaults.standard.set(beatBoost, forKey: "beatBoost") }
    }

    @Published var rmsAttackMs: Double {
        didSet { UserDefaults.standard.set(rmsAttackMs, forKey: "rmsAttackMs") }
    }

    @Published var rmsReleaseMs: Double {
        didSet { UserDefaults.standard.set(rmsReleaseMs, forKey: "rmsReleaseMs") }
    }

    @Published var lowAttackMs: Double {
        didSet { UserDefaults.standard.set(lowAttackMs, forKey: "lowAttackMs") }
    }

    @Published var lowReleaseMs: Double {
        didSet { UserDefaults.standard.set(lowReleaseMs, forKey: "lowReleaseMs") }
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

    @Published var showDebugOverlay: Bool {
        didSet { UserDefaults.standard.set(showDebugOverlay, forKey: "showDebugOverlay") }
    }
    
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    
    // MARK: - 枚举定义
    enum Theme: String, CaseIterable {
        case classic = "蓝白"
        case minimal = "简约"
        case neon = "霓虹"
        case equalizer = "音响"
        case particle = "脉冲"
        
        // 是否是正方形主题
        var isSquare: Bool {
            switch self {
            case .equalizer, .particle:
                return true
            default:
                return false
            }
        }
        
        // 推荐的窗口尺寸
        var recommendedSize: (width: CGFloat, height: CGFloat) {
            if isSquare {
                return (200, 200)
            } else {
                return (480, 140)
            }
        }
    }
    
    enum FrameRateMode: String, CaseIterable {
        case performance = "节能"   // 30 FPS
        case balanced = "标准"      // 60 FPS（默认）
        case smooth = "丝滑"        // 120 FPS
        
        var fps: Double {
            switch self {
            case .performance: return 30
            case .balanced: return 60
            case .smooth: return 120
            }
        }
    }
    
    // MARK: - 初始化
    private init() {
        self.sensitivity = UserDefaults.standard.object(forKey: "sensitivity") as? Double ?? 1.0
        self.lowEnergyBoost = UserDefaults.standard.object(forKey: "lowEnergyBoost") as? Double ?? 1.5
        self.rmsGain = UserDefaults.standard.object(forKey: "rmsGain") as? Double ?? 3.0
        self.lowGain = UserDefaults.standard.object(forKey: "lowGain") as? Double ?? 2.2
        self.beatBoost = UserDefaults.standard.object(forKey: "beatBoost") as? Double ?? 2.4
        self.rmsAttackMs = UserDefaults.standard.object(forKey: "rmsAttackMs") as? Double ?? 40
        self.rmsReleaseMs = UserDefaults.standard.object(forKey: "rmsReleaseMs") as? Double ?? 180
        self.lowAttackMs = UserDefaults.standard.object(forKey: "lowAttackMs") as? Double ?? 30
        self.lowReleaseMs = UserDefaults.standard.object(forKey: "lowReleaseMs") as? Double ?? 150
        self.theme = Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .classic
        self.frameRateMode = FrameRateMode(rawValue: UserDefaults.standard.string(forKey: "frameRateMode") ?? "") ?? .balanced
        self.windowWidth = UserDefaults.standard.object(forKey: "windowWidth") as? CGFloat ?? 480
        self.windowHeight = UserDefaults.standard.object(forKey: "windowHeight") as? CGFloat ?? 140
        self.showTrackInfo = UserDefaults.standard.object(forKey: "showTrackInfo") as? Bool ?? true
        self.showDebugOverlay = UserDefaults.standard.object(forKey: "showDebugOverlay") as? Bool ?? false
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
    }
}
