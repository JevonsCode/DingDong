import Foundation

@MainActor
final class ClipboardMonitoringService {
    private let reader: ClipboardReading
    private let interval: TimeInterval
    private let onChange: @MainActor () -> Void
    private var timer: Timer?
    private var lastChangeCount = -1

    private(set) var isRunning = false

    init(
        reader: ClipboardReading,
        interval: TimeInterval = 1.5,
        onChange: @escaping @MainActor () -> Void
    ) {
        self.reader = reader
        self.interval = interval
        self.onChange = onChange
    }

    func start() {
        timer?.invalidate()
        isRunning = true
        lastChangeCount = reader.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollForChanges()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func pollForChanges() {
        let currentChangeCount = reader.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lastChangeCount = currentChangeCount
        onChange()
    }
}
