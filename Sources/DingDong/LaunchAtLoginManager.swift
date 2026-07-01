import ServiceManagement

@MainActor
protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
struct ServiceManagementLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard SMAppService.mainApp.status != .enabled else {
                return
            }

            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status == .enabled else {
                return
            }

            try SMAppService.mainApp.unregister()
        }
    }
}
