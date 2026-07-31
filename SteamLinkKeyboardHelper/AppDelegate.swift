import AppKit
import Foundation

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let keyboardManager = KeyboardManager()
    private let eventInterceptor = F4EventInterceptor()
    private var timer: Timer?
    private var steamLinkWasForeground = false
    private var lastABCSelect = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = NSImage(named: "AppIcon")
        configureStatusItem()
        startF4EventInterceptor()
        startMonitoring()
        evaluateSteamLinkForegroundState(force: true)
        Notifier.requestAuthorization()
        Notifier.show(
            title: NSLocalizedString("notification.running.title", comment: "Notification title shown right after the app launches"),
            body: NSLocalizedString("notification.running.body", comment: "Notification body shown right after the app launches")
        )
    }

    private func configureStatusItem() {
        statusItem.button?.title = NSLocalizedString("status.icon.normal", comment: "Menu bar icon text when F4 is not blocked")
        statusItem.button?.toolTip = AppConstants.appName
        rebuildMenu(steamLinkForeground: false)
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateSteamLinkForegroundState(force: false)
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func startF4EventInterceptor() {
        if eventInterceptor.start() {
            return
        }

        Notifier.show(
            title: NSLocalizedString("notification.accessibilityNeeded.title", comment: "Notification title when Accessibility permission is missing"),
            body: NSLocalizedString("notification.accessibilityNeeded.body", comment: "Notification body when Accessibility permission is missing")
        )
    }

    private func evaluateSteamLinkForegroundState(force: Bool) {
        let steamLinkForeground = SteamLinkDetector.isForeground()
        let changed = force || steamLinkForeground != steamLinkWasForeground

        if changed {
            if steamLinkForeground {
                keyboardManager.disableSpotlightF4()
                selectABCIfNeeded()
                Notifier.show(
                    title: NSLocalizedString("notification.foreground.title", comment: "Notification title when Steam Link becomes foreground"),
                    body: NSLocalizedString("notification.foreground.body", comment: "Notification body when Steam Link becomes foreground")
                )
            } else if steamLinkWasForeground {
                keyboardManager.restoreSpotlightF4()
                Notifier.show(
                    title: NSLocalizedString("notification.leftForeground.title", comment: "Notification title when Steam Link leaves foreground"),
                    body: NSLocalizedString("notification.leftForeground.body", comment: "Notification body when Steam Link leaves foreground")
                )
            }
            steamLinkWasForeground = steamLinkForeground
            rebuildMenu(steamLinkForeground: steamLinkForeground)
        }

        if steamLinkForeground {
            selectABCIfNeeded()
        }
    }

    private func selectABCIfNeeded() {
        guard Date().timeIntervalSince(lastABCSelect) > 5 else { return }
        keyboardManager.selectABCInputSource()
        lastABCSelect = Date()
    }

    private func rebuildMenu(steamLinkForeground: Bool) {
        let menu = NSMenu()
        let steamStatus = steamLinkForeground
            ? NSLocalizedString("menu.steamLink.foreground", comment: "Menu status line when Steam Link is foreground")
            : NSLocalizedString("menu.steamLink.background", comment: "Menu status line when Steam Link is not foreground")
        let f4Status = keyboardManager.spotlightF4IsDisabled
            ? NSLocalizedString("menu.f4.disabled", comment: "Menu status line when F4 Spotlight is disabled")
            : NSLocalizedString("menu.f4.enabled", comment: "Menu status line when F4 Spotlight is enabled")

        menu.addItem(infoItem(steamStatus))
        menu.addItem(infoItem(f4Status))
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("menu.action.quit", comment: "Menu item to quit the app"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = steamLinkForeground
            ? NSLocalizedString("status.icon.blocked", comment: "Menu bar icon text when F4 is blocked")
            : NSLocalizedString("status.icon.normal", comment: "Menu bar icon text when F4 is not blocked")
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(noop), keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func noop() {}

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
