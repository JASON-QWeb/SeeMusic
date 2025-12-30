import SwiftUI
import AppKit

@main
struct SeeMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 使用 Settings 场景来避免显示空窗口
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为菜单栏应用（不在 Dock 显示图标）
        NSApp.setActivationPolicy(.accessory)
        
        // 创建主视图
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(
            x: 0, y: 0,
            width: Config.shared.windowWidth,
            height: Config.shared.windowHeight
        )
        
        // 创建悬浮窗
        windowController = FloatingWindowController(contentView: hostingView)
        windowController?.show()
        
        // 创建菜单栏控制器
        if let wc = windowController {
            menuBarController = MenuBarController(windowController: wc)
        }
        
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 保存窗口位置
        windowController?.savePosition()
        
        // 停止音频捕获
        Task {
            await AudioCaptureService.shared.stop()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击 Dock 图标时显示窗口
        windowController?.show()
        return true
    }
}
