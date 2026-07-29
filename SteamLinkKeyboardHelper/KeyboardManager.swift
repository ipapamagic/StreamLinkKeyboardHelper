import Carbon
import Foundation

final class KeyboardManager {
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
