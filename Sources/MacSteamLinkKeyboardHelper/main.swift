import AppKit
import Carbon
import Foundation
import UserNotifications

private enum AppConstants {
    static let appName = "Steam Link Keyboard Helper"
    static let bundleID = "tw.ipa.MacSteamLinkKeyboardHelper"
    static let pollInterval: TimeInterval = 2
    static let abcInputSourceID = "com.apple.keylayout.ABC"
    static let spotlightHotkeyIDs = ["64", "65"]
    static let hidSearchKeySource = 51_539_608_097 // 0x0C00000221, Consumer/Search key used by the F4 Spotlight key.
    static let hidNoEventDestination = 30_064_771_072 // 0x700000000, HID no-event/reserved destination.
    static let f4VirtualKeyCode: Int64 = 118
    static let cgEventSystemDefinedRawValue: UInt32 = 14
    static let nxSystemDefinedSpecialKeySubtype = 8
    static let nxKeyTypeLaunchPanel = 13
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let keyboardManager = KeyboardManager()
    private let eventInterceptor = F4EventInterceptor()
    private var timer: Timer?
    private var steamLinkWasForeground = false
    private var lastABCSelect = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Notifier.requestAuthorization()
        configureStatusItem()
        startF4EventInterceptor()
        startMonitoring()
        evaluateSteamLinkForegroundState(force: true)
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

        let launchAgentTitle = LaunchAgentInstaller.isInstalled ? "Remove launch at login" : "Install launch at login"
        let launchAgentItem = NSMenuItem(title: launchAgentTitle, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAgentItem.target = self
        menu.addItem(launchAgentItem)

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

    @objc private func toggleLaunchAtLogin() {
        if LaunchAgentInstaller.isInstalled {
            LaunchAgentInstaller.uninstall()
        } else {
            LaunchAgentInstaller.install()
        }
        rebuildMenu(steamLinkForeground: SteamLinkDetector.isForeground())
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func show(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

private enum SteamLinkDetector {
    static func isForeground() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let candidates = [
            app.localizedName,
            app.bundleIdentifier,
            app.executableURL?.lastPathComponent
        ].compactMap { $0?.lowercased() }

        return candidates.contains { value in
            value.contains("steam link") || value.contains("steamlink") || value.contains("valve.steamlink")
        }
    }
}

private final class F4EventInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            return false
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << AppConstants.cgEventSystemDefinedRawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: Self.callback,
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private static let callback: CGEventTapCallBack = { proxy, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            return Unmanaged.passUnretained(event)
        }

        guard SteamLinkDetector.isForeground(), isF4Event(type: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }

        return nil
    }

    private static func isF4Event(type: CGEventType, event: CGEvent) -> Bool {
        if type == .keyDown {
            return event.getIntegerValueField(.keyboardEventKeycode) == AppConstants.f4VirtualKeyCode
        }

        guard type.rawValue == AppConstants.cgEventSystemDefinedRawValue,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == AppConstants.nxSystemDefinedSpecialKeySubtype else {
            return false
        }

        let keyType = (nsEvent.data1 & 0xFFFF0000) >> 16
        let keyState = (nsEvent.data1 & 0x0000FF00) >> 8
        let keyDown = keyState == 0x0A

        return keyDown && keyType == AppConstants.nxKeyTypeLaunchPanel
    }
}

private final class KeyboardManager {
    private let settingsDefaults = UserDefaults.standard
    private let symbolicHotkeysDefaults = UserDefaults(suiteName: "com.apple.symbolichotkeys")
    private let backupKey = "spotlightHotkeysBackup"
    private let f4DisabledKey = "spotlightF4IsDisabled"

    var spotlightF4IsDisabled: Bool {
        settingsDefaults.bool(forKey: f4DisabledKey)
    }

    func disableSpotlightF4() {
        backupSpotlightHotkeysIfNeeded()
        setSpotlightHotkeys(enabled: false)
        applyF4SearchKeyRemap(disabled: true)
        settingsDefaults.set(true, forKey: f4DisabledKey)
    }

    func restoreSpotlightF4() {
        restoreSpotlightHotkeyBackup()
        applyF4SearchKeyRemap(disabled: false)
        settingsDefaults.set(false, forKey: f4DisabledKey)
    }

    func selectABCInputSource() {
        let criteria: [String: Any] = [
            kTISPropertyInputSourceID as String: AppConstants.abcInputSourceID
        ]

        guard let list = TISCreateInputSourceList(criteria as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              let abc = list.first else {
            return
        }

        TISSelectInputSource(abc)
    }

    private func backupSpotlightHotkeysIfNeeded() {
        guard settingsDefaults.object(forKey: backupKey) == nil,
              let hotkeys = symbolicHotkeysDefaults?.dictionary(forKey: "AppleSymbolicHotKeys") else {
            return
        }

        var backup: [String: Any] = [:]
        for id in AppConstants.spotlightHotkeyIDs {
            if let value = hotkeys[id] {
                backup[id] = value
            }
        }
        settingsDefaults.set(backup, forKey: backupKey)
    }

    private func setSpotlightHotkeys(enabled: Bool) {
        guard let defaults = symbolicHotkeysDefaults else { return }
        var hotkeys = defaults.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]

        for id in AppConstants.spotlightHotkeyIDs {
            var item = (hotkeys[id] as? [String: Any]) ?? [:]
            item["enabled"] = enabled
            hotkeys[id] = item
        }

        defaults.set(hotkeys, forKey: "AppleSymbolicHotKeys")
        defaults.synchronize()
        refreshSystemShortcutPreferences()
    }

    private func restoreSpotlightHotkeyBackup() {
        guard let defaults = symbolicHotkeysDefaults else { return }
        var hotkeys = defaults.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]

        if let backup = settingsDefaults.dictionary(forKey: backupKey) {
            for (id, value) in backup {
                hotkeys[id] = value
            }
        } else {
            for id in AppConstants.spotlightHotkeyIDs {
                var item = (hotkeys[id] as? [String: Any]) ?? [:]
                item["enabled"] = true
                hotkeys[id] = item
            }
        }

        defaults.set(hotkeys, forKey: "AppleSymbolicHotKeys")
        defaults.synchronize()
        settingsDefaults.removeObject(forKey: backupKey)
        refreshSystemShortcutPreferences()
    }

    private func refreshSystemShortcutPreferences() {
        _ = Shell.run("/usr/bin/killall", arguments: ["cfprefsd"])
        _ = Shell.run("/usr/bin/killall", arguments: ["SystemUIServer"])
    }

    private func applyF4SearchKeyRemap(disabled: Bool) {
        let json: String
        if disabled {
            json = """
            {"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\(AppConstants.hidSearchKeySource),"HIDKeyboardModifierMappingDst":\(AppConstants.hidNoEventDestination)}]}
            """
        } else {
            json = #"{"UserKeyMapping":[]}"#
        }

        _ = Shell.run("/usr/bin/hidutil", arguments: ["property", "--set", json])
    }
}

private enum LaunchAgentInstaller {
    private static var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private static var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(AppConstants.bundleID).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func install() {
        guard let executable = Bundle.main.executableURL else { return }
        try? FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(AppConstants.bundleID)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executable.path)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        try? plist.write(to: plistURL, atomically: true, encoding: .utf8)
        _ = Shell.run("/bin/launchctl", arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func uninstall() {
        _ = Shell.run("/bin/launchctl", arguments: ["bootout", "gui/\(getuid())", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
    }
}

private enum Shell {
    @discardableResult
    static func run(_ path: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
