import AppKit

enum SteamLinkDetector {
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
