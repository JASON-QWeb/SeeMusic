import AppKit
import SwiftUI

// 悬浮窗面板 - 透明、无边框、置顶、可拖拽、可调整大小
class FloatingPanel: NSPanel {
    
    // 调整大小的边缘检测区域
    private let resizeEdgeSize: CGFloat = 8
    private var isResizing = false
    private var resizeEdge: ResizeEdge = .none
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero
    
    enum ResizeEdge {
        case none
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow, .resizable],
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
    
    // 状态
    private var isDragging = false
    private var initialWindowOrigin: NSPoint = .zero
    
    // 检测鼠标位置对应的调整边缘
    private func detectResizeEdge(at point: NSPoint) -> ResizeEdge {
        let frame = self.frame
        let localPoint = NSPoint(x: point.x - frame.origin.x, y: point.y - frame.origin.y)
        
        // 增加边缘检测范围，让操作更容易
        let edgeSize: CGFloat = 12 
        
        let nearLeft = localPoint.x < edgeSize
        let nearRight = localPoint.x > frame.width - edgeSize
        let nearBottom = localPoint.y < edgeSize
        let nearTop = localPoint.y > frame.height - edgeSize
        
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearBottom { return .bottom }
        if nearTop { return .top }
        
        return .none
    }
    
    // 根据边缘设置光标
    private func setCursor(for edge: ResizeEdge) {
        switch edge {
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .topLeft, .bottomRight:
            NSCursor._windowResizeNorthWestSouthEastCursor.set()
        case .topRight, .bottomLeft:
            NSCursor._windowResizeNorthEastSouthWestCursor.set()
        case .none:
            NSCursor.arrow.set()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        let edge = detectResizeEdge(at: mouseLocation)
        setCursor(for: edge)
        
        // 我们不需要调用 super.mouseMoved，因为我们接管了
        // super.mouseMoved(with: event) 
    }
    
    override func mouseDown(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        resizeEdge = detectResizeEdge(at: mouseLocation)
        
        if resizeEdge != .none {
            // 模式 A：调整大小
            isResizing = true
            isDragging = false
            initialMouseLocation = mouseLocation
            initialFrame = self.frame
        } else {
            // 模式 B：移动窗口
            isResizing = false
            isDragging = true
            initialMouseLocation = mouseLocation
            initialWindowOrigin = self.frame.origin
            NSCursor.closedHand.set() // 设置抓手光标
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        if isResizing {
            // --- 调整大小逻辑 ---
            let deltaX = mouseLocation.x - initialMouseLocation.x
            let deltaY = mouseLocation.y - initialMouseLocation.y
            
            var newFrame = initialFrame
            
            // 根据边缘调整 frame
            switch resizeEdge {
            case .right:
                newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
            case .left:
                let newWidth = max(minSize.width, initialFrame.width - deltaX)
                newFrame.origin.x = initialFrame.maxX - newWidth
                newFrame.size.width = newWidth
            case .top:
                newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
            case .bottom:
                let newHeight = max(minSize.height, initialFrame.height - deltaY)
                newFrame.origin.y = initialFrame.maxY - newHeight
                newFrame.size.height = newHeight
            case .topRight:
                newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
                newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
            case .topLeft:
                let newWidth = max(minSize.width, initialFrame.width - deltaX)
                newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
                newFrame.origin.x = initialFrame.maxX - newWidth
                newFrame.size.width = newWidth
            case .bottomRight:
                newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
                let newHeight = max(minSize.height, initialFrame.height - deltaY)
                newFrame.origin.y = initialFrame.maxY - newHeight
                newFrame.size.height = newHeight
            case .bottomLeft:
                let newWidth = max(minSize.width, initialFrame.width - deltaX)
                let newHeight = max(minSize.height, initialFrame.height - deltaY)
                newFrame.origin.x = initialFrame.maxX - newWidth
                newFrame.origin.y = initialFrame.maxY - newHeight
                newFrame.size.width = newWidth
                newFrame.size.height = newHeight
            case .none:
                break
            }
            
            // 限制最大尺寸
            newFrame.size.width = min(maxSize.width, newFrame.size.width)
            newFrame.size.height = min(maxSize.height, newFrame.size.height)
            
            // 处理正方形约束 (Proportional Resizing)
            if Config.shared.theme.isSquare {
                var sideLength = max(newFrame.width, newFrame.height)
                sideLength = max(sideLength, minSize.width)
                sideLength = min(sideLength, maxSize.height)
                
                // 修正 Origin (如果是左侧或底部调整)
                if resizeEdge == .left || resizeEdge == .topLeft || resizeEdge == .bottomLeft {
                     newFrame.origin.x = newFrame.maxX - sideLength
                }
                if resizeEdge == .bottom || resizeEdge == .bottomLeft || resizeEdge == .bottomRight {
                     newFrame.origin.y = newFrame.maxY - sideLength
                }
                
                newFrame.size.width = sideLength
                newFrame.size.height = sideLength
            }
            
            self.setFrame(newFrame, display: true)
            
            // 更新 Config
            Config.shared.windowWidth = newFrame.width
            Config.shared.windowHeight = newFrame.height
            
        } else if isDragging {
            // --- 移动窗口逻辑 ---
            let deltaX = mouseLocation.x - initialMouseLocation.x
            let deltaY = mouseLocation.y - initialMouseLocation.y
            
            let newOrigin = NSPoint(
                x: initialWindowOrigin.x + deltaX,
                y: initialWindowOrigin.y + deltaY
            )
            self.setFrameOrigin(newOrigin)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isResizing = false
        isDragging = false
        resizeEdge = .none
        
        // 恢复光标检测
        let mouseLocation = NSEvent.mouseLocation
        let edge = detectResizeEdge(at: mouseLocation)
        setCursor(for: edge)
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
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
