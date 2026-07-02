import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var floatingPanel: FloatingPanel?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()

        // 全局快捷键：Cmd+Q 退出 + Cmd+C/V/X/A 编辑操作（直接通过响应链发送）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command) else { return event }
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return event }

            if chars == "q" {
                self?.quitApp()
                return nil
            }

            // Cmd+C/V/X/A/Z — 直接发送给第一响应者
            if let keyWindow = NSApp.keyWindow {
                switch chars {
                case "c": keyWindow.firstResponder?.tryToPerform(#selector(NSText.copy(_:)), with: nil)
                case "v": keyWindow.firstResponder?.tryToPerform(#selector(NSText.paste(_:)), with: nil)
                case "x": keyWindow.firstResponder?.tryToPerform(#selector(NSText.cut(_:)), with: nil)
                case "a": keyWindow.firstResponder?.tryToPerform(#selector(NSText.selectAll(_:)), with: nil)
                case "z": keyWindow.firstResponder?.tryToPerform(Selector(("undo:")), with: nil)
                default: break
                }
                if ["c", "v", "x", "a", "z"].contains(chars) { return nil }
            }

            return event
        }

        setupStatusBar()
        setupPopover()
        setupFloatingPanel()
        listenForNotifications()

        BalanceService.shared.startAutoRefresh()

        BalanceService.shared.$balanceModel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in self?.updateStatusBarText(model: model) }
            .store(in: &cancellables)

        if !SettingsManager.shared.hasAPIKey {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showSettings() }
        }
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let qi = NSMenuItem(title: "退出 DeepSeek Balance", action: #selector(quitApp), keyEquivalent: "q")
        qi.target = self
        appMenu.addItem(qi)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @MainActor @objc func quitApp() {
        BalanceService.shared.stopAutoRefresh()
        NSApp.terminate(nil)
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        if let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "DeepSeek") {
            img.isTemplate = true; button.image = img
        }
        button.action = #selector(togglePopover)
        button.target = self
        button.toolTip = "DeepSeek 余额监控"
    }

    private func updateStatusBarText(model: BalanceDisplayModel?) {
        guard let button = statusItem?.button else { return }
        button.title = model != nil ? " \(model!.balanceText)" : ""
        statusItem?.length = NSStatusItem.variableLength
    }

    private func setupPopover() {
        let contentView = BalancePopoverView()
        let hostingCtrl = NSHostingController(rootView: contentView)
        popover = NSPopover()
        popover.contentViewController = hostingCtrl
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 250, height: 220)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); popover.contentViewController?.view.window?.makeKey() }
    }

    private func setupFloatingPanel() {
        let view = FloatingPanelView()
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: SettingsManager.panelWidth, height: SettingsManager.panelHeight)

        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: SettingsManager.panelWidth, height: SettingsManager.panelHeight),
                                  hostingView: hosting)
        let sx = SettingsManager.panelX; let sy = SettingsManager.panelY
        if sx > 0 || sy > 0 { panel.setFrameOrigin(NSPoint(x: sx, y: sy)) }
        self.floatingPanel = panel
        if SettingsManager.panelVisible { panel.show() }
    }

    func showFloatingPanel() { floatingPanel?.show(); SettingsManager.panelVisible = true }
    func hideFloatingPanel() { floatingPanel?.orderOut(nil); SettingsManager.panelVisible = false }
    func toggleFloatingPanel() {
        guard let panel = floatingPanel else { return }
        panel.isVisible ? hideFloatingPanel() : showFloatingPanel()
    }

    @objc func showSettings() {
        if let window = settingsWindow { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let hostingCtrl = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "DeepSeek 余额监控"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: 560))
        window.center(); window.isReleasedWhenClosed = false; window.delegate = self
        settingsWindow = window; window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if popover.isShown { popover.performClose(nil) }
    }

    func listenForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(showSettings), name: .openSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleFloat), name: .toggleFloatingPanel, object: nil)
    }

    @objc private func handleToggleFloat() { toggleFloatingPanel() }
    @MainActor @objc func refreshNow() { BalanceService.shared.refreshNow() }
}

class FloatingPanel: NSPanel {
    init(contentRect: NSRect, hostingView: NSView) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        self.isOpaque = false; self.backgroundColor = NSColor.clear
        self.hasShadow = false; self.level = .floating
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false; self.contentView = hostingView
        NotificationCenter.default.addObserver(self, selector: #selector(savePosition),
                                               name: NSWindow.didMoveNotification, object: self)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    func show() { orderFrontRegardless() }

    @objc func savePosition() {
        SettingsManager.panelX = Double(frame.origin.x)
        SettingsManager.panelY = Double(frame.origin.y)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow { settingsWindow = nil }
    }
}
