import Foundation

enum AppConstants {
    static let appName = "Steam Link Keyboard Helper"
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
