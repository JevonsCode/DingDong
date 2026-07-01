import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class QuickPasteFocusCoordinator {
    private let workspaceActivationObserver = NotificationObserverBox(center: NSWorkspace.shared.notificationCenter)
    private var lastExternalApplication: NSRunningApplication?
    private(set) var targetApplication: NSRunningApplication?

    var isSessionActive: Bool {
        targetApplication != nil
    }

    init() {
        startTrackingExternalApplicationActivation()
    }

    func captureTargetApplication() {
        targetApplication = resolveTargetApplication()
    }

    func clearTarget() {
        targetApplication = nil
    }

    func restoreFocus(
        to targetApplication: NSRunningApplication?,
        completion: (() -> Void)? = nil
    ) {
        NSApp.deactivate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Self.activate(application: targetApplication)
            if let completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    completion()
                }
            }
        }
    }

    func requestAccessibilityIfNeeded(prompts: Bool, openSettings: () -> Void) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if prompts {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            openSettings()
        }

        return false
    }

    static func postPasteShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return
        }

        source.localEventsSuppressionInterval = 0
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let commandFlag = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = commandFlag
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = commandFlag
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func startTrackingExternalApplicationActivation() {
        if let application = Self.currentExternalFrontmostApplication() {
            lastExternalApplication = application
        }

        workspaceActivationObserver.observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor in
                self?.recordExternalApplication(application)
            }
        }
    }

    private func recordExternalApplication(_ application: NSRunningApplication) {
        guard Self.isExternalApplication(application) else {
            return
        }

        lastExternalApplication = application
    }

    private func resolveTargetApplication() -> NSRunningApplication? {
        if let application = Self.currentExternalFrontmostApplication() {
            lastExternalApplication = application
            return application
        }

        guard let application = lastExternalApplication,
              !application.isTerminated
        else {
            return nil
        }

        return application
    }

    private static func currentExternalFrontmostApplication() -> NSRunningApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        guard isExternalApplication(application) else {
            return nil
        }

        return application
    }

    private static func isExternalApplication(_ application: NSRunningApplication) -> Bool {
        guard !application.isTerminated,
              application.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            return false
        }

        if let bundleIdentifier = application.bundleIdentifier,
           bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        return true
    }

    private static func activate(application: NSRunningApplication?) {
        guard let application, !application.isTerminated else {
            return
        }

        if #available(macOS 14.0, *) {
            application.activate(options: [.activateAllWindows])
        } else {
            application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }
}
