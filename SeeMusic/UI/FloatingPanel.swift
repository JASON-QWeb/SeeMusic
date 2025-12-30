import AppKit

// 悬浮窗面板 - 透明、无边框、置顶、可拖拽
class FloatingPanel: NSPanel {
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        // 基础设置
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        
        // 可移动设置
        self.isMovableByWindowBackground = true
        
        // 隐藏标题栏但保持功能
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // 允许在非激活状态下接收事件
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
    }
    
    // 允许成为 key window 以接收事件
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// 窗口控制器
class FloatingWindowController: NSWindowController {
    
    convenience init(contentView: NSView) {
        let panel = FloatingPanel(contentRect: NSRect(
            x: 100, y: 100,
            width: Config.shared.windowWidth,
            height: Config.shared.windowHeight
        ))
        panel.contentView = contentView
        
        self.init(window: panel)
        
        // 恢复窗口位置
        if let savedFrame = UserDefaults.standard.string(forKey: "windowFrame") {
            panel.setFrame(from: savedFrame)
        } else {
            // 默认位置：屏幕右下角
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.maxX - panel.frame.width - 20
                let y = screenRect.minY + 20
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
    
    var isVisible: Bool {
        window?.isVisible ?? false
    }
    
    func savePosition() {
        if let frame = window?.frameDescriptor {
            UserDefaults.standard.set(frame, forKey: "windowFrame")
        }
    }
}
