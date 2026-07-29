import AppKit
import Carbon

final class F4EventInterceptor {
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
