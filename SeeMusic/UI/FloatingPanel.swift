import AppKit
import SwiftUI

// 悬浮窗面板 - 透明、无边框、置顶、可拖拽、可调整大小
class FloatingPanel: NSPanel {
    
    private var isDragging = false
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero
    
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
        self.hasShadow = false
        
        // 可移动设置 - 禁用系统背景移动，改为手动控制以解决冲突
        self.isMovableByWindowBackground = false
        
        // 隐藏标题栏但保持功能
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // 允许在非激活状态下接收事件
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        
        // 设置最小尺寸
        self.minSize = NSSize(width: 100, height: 80)
        self.maxSize = NSSize(width: 800, height: 600)
    }
    
    // 允许成为 key window 以接收事件
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if shouldBeginDrag(with: event) {
                let mouseLocation = NSEvent.mouseLocation
                isDragging = true
                initialMouseLocation = mouseLocation
                initialWindowOrigin = self.frame.origin
                NSCursor.closedHand.set()
                return
            }
        case .leftMouseDragged:
            if isDragging {
                let mouseLocation = NSEvent.mouseLocation
                let deltaX = mouseLocation.x - initialMouseLocation.x
                let deltaY = mouseLocation.y - initialMouseLocation.y
                let newOrigin = NSPoint(
                    x: initialWindowOrigin.x + deltaX,
                    y: initialWindowOrigin.y + deltaY
                )
                self.setFrameOrigin(newOrigin)
                return
            }
        case .leftMouseUp:
            if isDragging {
                isDragging = false
                NSCursor.arrow.set()
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }
    
    private func shouldBeginDrag(with event: NSEvent) -> Bool {
        guard let contentView = contentView else { return true }
        let localPoint = contentView.convert(event.locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(localPoint) else { return true }
        return !(hitView is NSControl)
    }

}

// 窗口控制器
class FloatingWindowController: NSWindowController {
    
    private var themeObserver: NSObjectProtocol?
    
    convenience init(contentView: NSView) {
        let theme = Config.shared.theme
        let size = theme.recommendedSize
        
        let panel = FloatingPanel(contentRect: NSRect(
            x: 100, y: 100,
            width: size.width,
            height: size.height
        ))
        panel.contentView = contentView
        
        self.init(window: panel)
        
        // 设置追踪区域以接收 mouseMoved 事件
        setupTrackingArea()
        
        // 恢复窗口位置
        if let savedFrame = UserDefaults.standard.string(forKey: "windowFrame") {
            panel.setFrame(from: savedFrame)
            
            // 确保尺寸与 Config 同步 (或重置为推荐尺寸)
            // 这里我们优先信任 Config 的值，如果它存在且合理
            let configWidth = Config.shared.windowWidth
            let configHeight = Config.shared.windowHeight
            
            // 如果是正方形主题，强制正方形
            if theme.isSquare {
                 panel.setContentSize(NSSize(width: configWidth, height: configWidth))
            } else {
                 panel.setContentSize(NSSize(width: configWidth, height: configHeight))
            }

        } else {
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.maxX - panel.frame.width - 20
                let y = screenRect.minY + 20
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        setupThemeObserver()
    }
    
    private func setupTrackingArea() {
        guard let contentView = window?.contentView else { return }
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: window,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
    }
    
    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupThemeObserver() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThemeChange()
        }
    }
    
    private func handleThemeChange() {
        let size = Config.shared.theme.recommendedSize
        resizeWindow(to: size)
        
        // 关键：同步更新 Config，确保 ContentView 响应
        Config.shared.windowWidth = size.width
        Config.shared.windowHeight = size.height
    }
    
    private func resizeWindow(to size: (width: CGFloat, height: CGFloat)) {
        guard let window = window else { return }
        
        let currentCenter = NSPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )
        
        let newOrigin = NSPoint(
            x: currentCenter.x - size.width / 2,
            y: currentCenter.y - size.height / 2
        )
        
        let newFrame = NSRect(
            origin: newOrigin,
            size: NSSize(width: size.width, height: size.height)
        )
        
        window.setFrame(newFrame, display: true, animate: true)
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
