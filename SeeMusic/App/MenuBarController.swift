import AppKit

// 菜单栏控制器
class MenuBarController {
    private var statusItem: NSStatusItem?
    private var windowController: FloatingWindowController?
    
    init(windowController: FloatingWindowController) {
        self.windowController = windowController
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 使用 SF Symbol 作为图标
            if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "SeeMusic") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "♪"
            }
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // 显示/隐藏窗口
        let toggleItem = NSMenuItem(
            title: "显示/隐藏波浪",
            action: #selector(toggleWindow),
            keyEquivalent: "w"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 灵敏度子菜单
        let sensitivityMenu = NSMenu()
        for value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
            let item = NSMenuItem(
                title: String(format: "%.0f%%", value * 100),
                action: #selector(setSensitivity(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(value * 100)
            if Config.shared.sensitivity == value {
                item.state = .on
            }
            sensitivityMenu.addItem(item)
        }
        let sensitivityItem = NSMenuItem(title: "灵敏度", action: nil, keyEquivalent: "")
        sensitivityItem.submenu = sensitivityMenu
        menu.addItem(sensitivityItem)
        
        // 主题子菜单
        let themeMenu = NSMenu()
        for theme in Config.Theme.allCases {
            let item = NSMenuItem(
                title: theme.rawValue,
                action: #selector(setTheme(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = theme
            if Config.shared.theme == theme {
                item.state = .on
            }
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)
        
        // 帧率子菜单
        let fpsMenu = NSMenu()
        for mode in Config.FrameRateMode.allCases {
            let item = NSMenuItem(
                title: "\(mode.rawValue) (\(Int(mode.fps)) FPS)",
                action: #selector(setFrameRate(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode
            if Config.shared.frameRateMode == mode {
                item.state = .on
            }
            fpsMenu.addItem(item)
        }
        let fpsItem = NSMenuItem(title: "帧率", action: nil, keyEquivalent: "")
        fpsItem.submenu = fpsMenu
        menu.addItem(fpsItem)
        
        // 显示曲目信息
        let showTrackItem = NSMenuItem(
            title: "显示曲目信息",
            action: #selector(toggleTrackInfo),
            keyEquivalent: ""
        )
        showTrackItem.target = self
        showTrackItem.state = Config.shared.showTrackInfo ? .on : .off
        menu.addItem(showTrackItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(
            title: "退出 SeeMusic",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleWindow() {
        windowController?.toggle()
    }
    
    @objc private func setSensitivity(_ sender: NSMenuItem) {
        Config.shared.sensitivity = Double(sender.tag) / 100.0
        setupMenu() // 刷新菜单状态
    }
    
    @objc private func setTheme(_ sender: NSMenuItem) {
        if let theme = sender.representedObject as? Config.Theme {
            Config.shared.theme = theme
            setupMenu()
        }
    }
    
    @objc private func setFrameRate(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? Config.FrameRateMode {
            Config.shared.frameRateMode = mode
            setupMenu()
        }
    }
    
    @objc private func toggleTrackInfo() {
        Config.shared.showTrackInfo.toggle()
        setupMenu()
    }
    
    @objc private func quitApp() {
        windowController?.savePosition()
        NSApplication.shared.terminate(nil)
    }
}
