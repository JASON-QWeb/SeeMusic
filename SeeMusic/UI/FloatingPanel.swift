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
        
        // 可移动设置
        self.isMovableByWindowBackground = true
        
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
    
    // 检测鼠标位置对应的调整边缘
    private func detectResizeEdge(at point: NSPoint) -> ResizeEdge {
        let frame = self.frame
        let localPoint = NSPoint(x: point.x - frame.origin.x, y: point.y - frame.origin.y)
        
        let nearLeft = localPoint.x < resizeEdgeSize
        let nearRight = localPoint.x > frame.width - resizeEdgeSize
        let nearBottom = localPoint.y < resizeEdgeSize
        let nearTop = localPoint.y > frame.height - resizeEdgeSize
        
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
            NSCursor.crosshair.set()
        case .topRight, .bottomLeft:
            NSCursor.crosshair.set()
        case .none:
            NSCursor.arrow.set()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        let edge = detectResizeEdge(at: mouseLocation)
        setCursor(for: edge)
        super.mouseMoved(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        resizeEdge = detectResizeEdge(at: mouseLocation)
        
        if resizeEdge != .none {
            isResizing = true
            initialMouseLocation = mouseLocation
            initialFrame = self.frame
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isResizing {
            let mouseLocation = NSEvent.mouseLocation
            let deltaX = mouseLocation.x - initialMouseLocation.x
            let deltaY = mouseLocation.y - initialMouseLocation.y
            
            var newFrame = initialFrame
            
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
                newFrame.origin.x = initialFrame.maxX - newWidth
                newFrame.size.width = newWidth
                newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
            case .bottomRight:
                newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
                let newHeight = max(minSize.height, initialFrame.height - deltaY)
                newFrame.origin.y = initialFrame.maxY - newHeight
                newFrame.size.height = newHeight
            case .bottomLeft:
                let newWidth = max(minSize.width, initialFrame.width - deltaX)
                newFrame.origin.x = initialFrame.maxX - newWidth
                newFrame.size.width = newWidth
                let newHeight = max(minSize.height, initialFrame.height - deltaY)
                newFrame.origin.y = initialFrame.maxY - newHeight
                newFrame.size.height = newHeight
            case .none:
                break
            }
            
            // 限制最大尺寸
            newFrame.size.width = min(maxSize.width, newFrame.size.width)
            newFrame.size.height = min(maxSize.height, newFrame.size.height)
            
            // 处理正方形约束 (Proportional Resizing)
            if Config.shared.theme.isSquare {
                // 取最大边长作为正方形边长
                // 或者根据拖动方向决定：
                // 简单的策略：均取最大值，或者根据主拖动轴
                
                var sideLength = max(newFrame.width, newFrame.height)
                
                // 再次检查约束
                sideLength = max(sideLength, minSize.width)
                sideLength = min(sideLength, maxSize.height)
                
                // 调整 Frame
                // 如果是左边或上边拖动，需要修正 origin
                if resizeEdge == .left || resizeEdge == .topLeft || resizeEdge == .bottomLeft {
                     // 修正 x: 保持右边缘不变 -> newX = right - newWidth
                     let right = newFrame.maxX
                     newFrame.origin.x = right - sideLength
                }
                
                if resizeEdge == .top || resizeEdge == .topLeft || resizeEdge == .topRight {
                    // 修正 y: 由于 Cocoa 坐标系 bottom-left 0,0，top 变化通常改变 height
                    // 但 window frame y 是底部位置。
                    // 拖动 top 改变 height，bottom (y) 不变。
                    // 所以不需要修正 y?
                    // 等等，如果拖动 Top，height 变大，y 不变，top 变高。Correct.
                }
                
                if resizeEdge == .bottom || resizeEdge == .bottomLeft || resizeEdge == .bottomRight {
                     // 拖动 Bottom，height 变大，y 需要减小 (向下延伸) -> newY = top - newHeight
                     let top = newFrame.maxY
                     newFrame.origin.y = top - sideLength
                }
                
                newFrame.size.width = sideLength
                newFrame.size.height = sideLength
            }
            
            self.setFrame(newFrame, display: true)
            
            // 更新 Config 中的窗口尺寸
            Config.shared.windowWidth = newFrame.width
            Config.shared.windowHeight = newFrame.height
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            resizeEdge = .none
            NSCursor.arrow.set()
        } else {
            super.mouseUp(with: event)
        }
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
