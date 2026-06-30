import AppKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?
    private var server: NotificationServer?
    private var hotKeyController: GlobalHotKeyController?
    private var instanceLockFileDescriptor: Int32 = -1
    private let preferredAPIPorts: [UInt16] = [8765, 8766, 8767, 8768, 8769]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard acquireSingleInstanceLock() else {
            NSApp.terminate(nil)
            return
        }
        disableAutomaticTermination()

        let soundPlayer = SoundPlayer()
        let resourceStore = ResourceStore()
        let clipboardRecorder = ClipboardRecorder()
        let agentEventStore = AgentEventStore()
        let agentPresenceStore = AgentPresenceStore()
        let statusController = StatusController(
            soundPlayer: soundPlayer,
            resourceStore: resourceStore,
            clipboardRecorder: clipboardRecorder,
            agentEventStore: agentEventStore,
            agentPresenceStore: agentPresenceStore
        )
        self.statusController = statusController
        let hotKeyController = GlobalHotKeyController { [weak statusController] in
            statusController?.handleClipboardHotKey()
        }
        statusController.setClipboardHotKeyState(hotKeyController.start())
        self.hotKeyController = hotKeyController

        var lastServerError: Error?
        for port in preferredAPIPorts {
            guard isAPIPortAvailable(port) else {
                continue
            }

            let server = NotificationServer(
                port: port,
                resourceStore: resourceStore,
                clipboardRecorder: clipboardRecorder,
                agentEventStore: agentEventStore,
                agentPresenceStore: agentPresenceStore,
                onShowPanel: { [weak statusController] tab in
                    statusController?.showWindow(tab: tab)
                },
                onClipboardMonitoring: { [weak statusController] enabled in
                    statusController?.setClipboardMonitoring(enabled)
                }
            ) { [weak statusController] request in
                statusController?.trigger(request, recordsEvent: false)
            }

            do {
                try server.start()
                statusController.setServerState(.running(port: port))
                writeActiveAPIPort(port)
                self.server = server
                break
            } catch {
                lastServerError = error
            }
        }

        if self.server == nil {
            clearActiveAPIPort()
            statusController.setServerState(.failed(lastServerError?.localizedDescription ?? "No available API port."))
        }

        statusController.pulseStatusIcon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.disableAutomaticTermination()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshGlobalHotKeyRegistration()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController?.stop()
        server?.stop()
        clearActiveAPIPort()
        releaseSingleInstanceLock()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func refreshGlobalHotKeyRegistration() {
        guard let statusController, let hotKeyController else {
            return
        }

        statusController.setClipboardHotKeyState(hotKeyController.start())
    }

    private func disableAutomaticTermination() {
        ProcessInfo.processInfo.disableAutomaticTermination("DingDong is a persistent menu bar utility.")
    }

    private func acquireSingleInstanceLock() -> Bool {
        guard instanceLockFileDescriptor < 0 else {
            return true
        }

        let lockDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DingDong", isDirectory: true)

        guard let lockDirectory else {
            return true
        }

        do {
            try FileManager.default.createDirectory(at: lockDirectory, withIntermediateDirectories: true)
        } catch {
            return true
        }

        let lockPath = lockDirectory.appendingPathComponent("DingDong.lock").path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            return true
        }

        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
            instanceLockFileDescriptor = descriptor
            return true
        }

        close(descriptor)
        return false
    }

    private func releaseSingleInstanceLock() {
        guard instanceLockFileDescriptor >= 0 else {
            return
        }

        flock(instanceLockFileDescriptor, LOCK_UN)
        close(instanceLockFileDescriptor)
        instanceLockFileDescriptor = -1
    }

    private func writeActiveAPIPort(_ port: UInt16) {
        guard let directory = applicationSupportDirectory() else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try "\(port)".write(to: directory.appendingPathComponent("api-port"), atomically: true, encoding: .utf8)
        } catch {
            // The app can still run; this file only helps local agent scripts discover a fallback port.
        }
    }

    private func clearActiveAPIPort() {
        guard let directory = applicationSupportDirectory() else {
            return
        }

        try? FileManager.default.removeItem(at: directory.appendingPathComponent("api-port"))
    }

    private func isAPIPortAvailable(_ port: UInt16) -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            return false
        }
        defer {
            close(descriptor)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }

    private func applicationSupportDirectory() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DingDong", isDirectory: true)
    }
}
