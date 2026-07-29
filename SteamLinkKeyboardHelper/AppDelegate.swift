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
        configureStatusItem()
        startF4EventInterceptor()
        startMonitoring()
        evaluateSteamLinkForegroundState(force: true)
        Notifier.requestAuthorization()
        Notifier.show(title: "Steam Link Keyboard Helper is running", body: "Look for F4 in the menu bar. Steam Link foreground will switch to ABC and block F4.")
    }

    private func configureStatusItem() {
        statusItem.button?.title = "F4"
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
            title: "Accessibility permission needed",
            body: "Allow Steam Link Keyboard Helper in System Settings > Privacy & Security > Accessibility to block F4 directly."
        )
    }

    private func evaluateSteamLinkForegroundState(force: Bool) {
        let steamLinkForeground = SteamLinkDetector.isForeground()
        let changed = force || steamLinkForeground != steamLinkWasForeground

        if changed {
            if steamLinkForeground {
                keyboardManager.disableSpotlightF4()
                selectABCIfNeeded()
                Notifier.show(title: "Steam Link foreground", body: "F4 Spotlight disabled. Input source switched to ABC.")
            } else if steamLinkWasForeground {
                keyboardManager.restoreSpotlightF4()
                Notifier.show(title: "Steam Link left foreground", body: "F4 Spotlight restored.")
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
        let steamStatus = steamLinkForeground ? "Steam Link: foreground" : "Steam Link: background / not running"
        let f4Status = keyboardManager.spotlightF4IsDisabled ? "F4 Spotlight: disabled" : "F4 Spotlight: enabled"

        menu.addItem(disabledItem(steamStatus))
        menu.addItem(disabledItem(f4Status))
        menu.addItem(NSMenuItem.separator())

        let disableItem = NSMenuItem(title: "Disable F4 Spotlight now", action: #selector(disableF4Now), keyEquivalent: "")
        disableItem.target = self
        menu.addItem(disableItem)

        let restoreItem = NSMenuItem(title: "Restore F4 Spotlight now", action: #selector(restoreF4Now), keyEquivalent: "")
        restoreItem.target = self
        menu.addItem(restoreItem)

        let abcItem = NSMenuItem(title: "Switch to ABC now", action: #selector(switchABCNow), keyEquivalent: "")
        abcItem.target = self
        menu.addItem(abcItem)

        let notifyItem = NSMenuItem(title: "Show status notification", action: #selector(showStatusNotification), keyEquivalent: "")
        notifyItem.target = self
        menu.addItem(notifyItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = steamLinkForeground ? "F4 off" : "F4"
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func disableF4Now() {
        keyboardManager.disableSpotlightF4()
        rebuildMenu(steamLinkForeground: SteamLinkDetector.isForeground())
    }

    @objc private func restoreF4Now() {
        keyboardManager.restoreSpotlightF4()
        rebuildMenu(steamLinkForeground: SteamLinkDetector.isForeground())
    }

    @objc private func switchABCNow() {
        keyboardManager.selectABCInputSource()
    }

    @objc private func showStatusNotification() {
        let foreground = SteamLinkDetector.isForeground()
        let body = foreground ? "Steam Link is foreground. F4 should be blocked." : "Steam Link is not foreground. F4 should behave normally."
        Notifier.show(title: "Steam Link Keyboard Helper", body: body)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
