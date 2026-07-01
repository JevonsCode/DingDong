import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPanelView: View {
    @ObservedObject var controller: StatusController
    @ObservedObject var soundPlayer: SoundPlayer
    @State private var usageSnapshot = SystemUsageSnapshot.current()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsHeader
                generalSection
                updateSection
                systemUsageSection
                permissionsSection
                appearanceSection
                clipboardSection
                soundSection
                apiSection
            }
            .padding(18)
        }
        .frame(minWidth: 560, minHeight: 620)
        .foregroundStyle(PanelTheme.textPrimary)
        .background(PanelTheme.background)
        .onAppear {
            refreshUsageSnapshot()
            controller.refreshReleaseStatus()
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(text(.settings))
                    .font(.system(size: 22, weight: .semibold))
                Text("DingDong")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var generalSection: some View {
        settingsSection(title: text(.general), icon: "switch.2") {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text(text(.language))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelTheme.textSecondary)

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Button {
                                controller.setLanguage(language)
                            } label: {
                                Text(language.displayTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 76)
                            }
                            .buttonStyle(SettingsChoiceButtonStyle(isSelected: controller.language == language))
                        }
                    }
                }

                HStack(spacing: 10) {
                    Label(localized("开机启动", "Launch at login"), systemImage: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelTheme.textSecondary)

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { controller.launchAtLoginEnabled },
                            set: { controller.setLaunchAtLoginEnabled($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var updateSection: some View {
        settingsSection(title: updateTitle, icon: "sparkle.magnifyingglass") {
            VStack(alignment: .leading, spacing: 8) {
                settingValueRow(
                    title: controller.language == .chinese ? "当前版本" : "Current",
                    value: "\(controller.releaseStatus.currentVersion) (\(controller.releaseStatus.currentBuild))"
                )
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                settingValueRow(
                    title: controller.language == .chinese ? "最新版本" : "Latest",
                    value: latestVersionText
                )
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                if !releaseNotesText.isEmpty {
                    Text(releaseNotesText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 8) {
                    Text(updateStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)

                    Spacer()

                    Button {
                        controller.refreshReleaseStatus()
                    } label: {
                        Label(updateCheckButtonTitle, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        controller.openReleaseWebsite()
                    } label: {
                        Label(controller.language == .chinese ? "官网" : "Website", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        controller.openLatestReleasePage()
                    } label: {
                        Label(controller.language == .chinese ? "发布页" : "Release", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var permissionsSection: some View {
        settingsSection(title: permissionsTitle, icon: "hand.raised") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Label(
                        accessibilityStatusTitle,
                        systemImage: controller.isQuickPasteAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(controller.isQuickPasteAccessibilityTrusted ? PanelTheme.success : PanelTheme.warning)

                    Spacer()

                    if !controller.isQuickPasteAccessibilityTrusted {
                        Button {
                            controller.openAccessibilityPrivacySettings()
                        } label: {
                            Label(openSettingsTitle, systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(SettingsChoiceButtonStyle(isSelected: true))
                    }
                }

                Text(accessibilityDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var systemUsageSection: some View {
        settingsSection(title: usageTitle, icon: "gauge.with.dots.needle.50percent") {
            VStack(spacing: 8) {
                settingValueRow(
                    title: controller.language == .chinese ? "当前内存" : "Memory",
                    value: formattedBytes(usageSnapshot.residentMemoryBytes)
                )
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                settingValueRow(
                    title: controller.language == .chinese ? "本地存储" : "Storage",
                    value: formattedBytes(usageSnapshot.storageBytes)
                )
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    Text(usageDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Button {
                        refreshUsageSnapshot()
                    } label: {
                        Label(controller.language == .chinese ? "刷新" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var appearanceSection: some View {
        settingsSection(title: text(.appearance), icon: "slider.horizontal.3") {
            VStack(spacing: 8) {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text(text(.panelOpacity))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PanelTheme.textSecondary)

                        Spacer()

                        Text("\(Int((controller.panelBackgroundOpacity * 100).rounded()))%")
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .foregroundStyle(PanelTheme.textPrimary)
                    }

                    Slider(
                        value: Binding(
                            get: { controller.panelBackgroundOpacity },
                            set: { controller.setPanelBackgroundOpacity($0) }
                        ),
                        in: PanelPreferences.minBackgroundOpacity...PanelPreferences.maxBackgroundOpacity,
                        step: 0.01
                    )
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                settingChoiceRow(title: text(.defaultTab)) {
                    ForEach(CompanionTab.mainPanelTabs, id: \.self) { tab in
                        Button {
                            controller.setDefaultPanelTab(tab)
                        } label: {
                            Label(tab.title(language: controller.language), systemImage: tab.icon)
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 90)
                        }
                        .buttonStyle(SettingsChoiceButtonStyle(isSelected: controller.defaultPanelTab == tab))
                    }
                }

                settingChoiceRow(title: text(.listDensity)) {
                    ForEach(PanelDensity.allCases, id: \.self) { density in
                        Button {
                            controller.setPanelDensity(density)
                        } label: {
                            Text(density.title(language: controller.language))
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 78)
                        }
                        .buttonStyle(SettingsChoiceButtonStyle(isSelected: controller.panelDensity == density))
                    }
                }
            }
        }
    }

    private var clipboardSection: some View {
        settingsSection(title: text(.clipboard), icon: "doc.on.clipboard") {
            VStack(spacing: 8) {
                Stepper(
                    value: Binding(
                        get: { controller.clipboardMaxAgeDays },
                        set: { controller.setClipboardMaxAgeDays($0) }
                    ),
                    in: ClipboardRetentionPolicy.minMaxAgeDays...ClipboardRetentionPolicy.maxMaxAgeDays,
                    step: 1
                ) {
                    settingValueRow(
                        title: text(.clipboardRetentionDays),
                        value: controller.language == .chinese ? "\(controller.clipboardMaxAgeDays) 天" : "\(controller.clipboardMaxAgeDays)d"
                    )
                }
                .controlSize(.small)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                Stepper(
                    value: Binding(
                        get: { controller.clipboardMaxItems },
                        set: { controller.setClipboardMaxItems($0) }
                    ),
                    in: ClipboardRetentionPolicy.minMaxItems...ClipboardRetentionPolicy.maxMaxItems,
                    step: 20
                ) {
                    settingValueRow(
                        title: text(.clipboardRetentionLimit),
                        value: controller.language == .chinese ? "\(controller.clipboardMaxItems) 条" : "\(controller.clipboardMaxItems)"
                    )
                }
                .controlSize(.small)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var soundSection: some View {
        settingsSection(title: text(.soundLab), icon: "speaker.wave.2") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(DingSound.primaryChoices, id: \.self) { sound in
                    soundButton(sound)
                }
            }

            HStack(spacing: 8) {
                Button {
                    controller.chooseCustomSound()
                } label: {
                    Label(text(.customSound), systemImage: "music.note")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    controller.clearCustomSound()
                } label: {
                    Label(text(.clearSound), systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)

                if let customSoundPath = soundPlayer.customSoundPath {
                    Text(customSoundPath)
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
        }
    }

    private var apiSection: some View {
        settingsSection(title: text(.endpoints), icon: "point.3.connected.trianglepath.dotted") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(localized(
                        "安装 DingDong MCP 后，Agent 从这里读取资源摘要、按需加载 Skill，并在任务最终结束时通知你。",
                        "Install the DingDong MCP once. Agents read resource summaries here, load skills only when needed, and notify you when the whole task is final."
                    ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Button {
                        controller.showUsageGuideWindow()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(SettingsChoiceButtonStyle(isSelected: false))
                    .frame(width: 34, height: 34)
                    .help(localized("查看 MCP 安装说明", "View MCP setup guide"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                ForEach(apiLines, id: \.value) { line in
                    apiLine(line.title, line.value)
                }

                HStack(spacing: 8) {
                    Button {
                        controller.copyCurlExample()
                    } label: {
                        Label(text(.copyDingCurl), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        controller.testDing()
                    } label: {
                        Label(text(.test), systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
    }

    private var permissionsTitle: String {
        controller.language == .chinese ? "权限" : "Permissions"
    }

    private var usageTitle: String {
        controller.language == .chinese ? "占用" : "Usage"
    }

    private var updateTitle: String {
        controller.language == .chinese ? "版本" : "Version"
    }

    private var latestVersionText: String {
        if controller.releaseStatus.isChecking {
            return controller.language == .chinese ? "检查中..." : "Checking..."
        }

        return controller.releaseStatus.latestVersion ?? (controller.language == .chinese ? "未知" : "Unknown")
    }

    private var updateStatusText: String {
        if controller.releaseStatus.isChecking {
            return controller.language == .chinese ? "正在检查 GitHub Pages 更新信息" : "Checking GitHub Pages for updates"
        }

        if let error = controller.releaseStatus.errorMessage {
            return controller.language == .chinese ? "检查失败：\(error)" : "Update check failed: \(error)"
        }

        switch controller.releaseStatus.isLatest {
        case .some(true):
            return controller.language == .chinese ? "已是最新版本" : "You're up to date"
        case .some(false):
            return controller.language == .chinese ? "有新版本可用" : "A new version is available"
        case .none:
            return controller.language == .chinese ? "尚未获取更新信息" : "No update metadata yet"
        }
    }

    private var updateCheckButtonTitle: String {
        controller.language == .chinese ? "检查" : "Check"
    }

    private var releaseNotesText: String {
        guard let notes = controller.releaseStatus.metadata?.notes,
              !notes.isEmpty
        else {
            return ""
        }

        return notes.map { "• \($0)" }.joined(separator: "\n")
    }

    private var usageDescription: String {
        controller.language == .chinese
            ? "内存为当前 DingDong 进程占用；存储为 DingDong 本地数据目录大小。"
            : "Memory is the current DingDong process footprint. Storage is the local DingDong data folder."
    }

    private var accessibilityStatusTitle: String {
        if controller.isQuickPasteAccessibilityTrusted {
            return controller.language == .chinese ? "已授权" : "Permission granted"
        }

        return controller.language == .chinese ? "需要辅助功能权限" : "Accessibility required"
    }

    private var accessibilityDescription: String {
        if controller.isQuickPasteAccessibilityTrusted {
            return controller.language == .chinese
                ? "macOS 辅助功能权限已开启。自动粘贴和快捷键流程可以正常使用。"
                : "Accessibility is enabled. Quick paste and shortcut handling are available."
        }

        return controller.language == .chinese
            ? "用于在你选择剪贴板内容后，把文本粘回刚才的输入框。授权后请重启 DingDong。"
            : "Used to paste the selected clipboard item back into the field you were typing in. Restart DingDong after granting access."
    }

    private var openSettingsTitle: String {
        controller.language == .chinese ? "打开" : "Open"
    }

    private func refreshUsageSnapshot() {
        usageSnapshot = controller.systemUsageSnapshot
    }

    private func formattedBytes(_ bytes: UInt64?) -> String {
        guard let bytes else {
            return controller.language == .chinese ? "不可用" : "Unavailable"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)

            content()
        }
        .padding(14)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func settingValueRow(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(PanelTheme.textPrimary)
        }
    }

    private func settingChoiceRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)

            Spacer()

            HStack(spacing: 6) {
                content()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
    }

    private func soundButton(_ sound: DingSound) -> some View {
        Button {
            controller.trigger(DingRequest(
                message: sound.displayTitle(language: controller.language),
                source: "DingDong",
                sound: sound,
                flashCount: 4
            ))
        } label: {
            Label(sound.displayTitle(language: controller.language), systemImage: sound.icon)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(SettingsChoiceButtonStyle(isSelected: false))
    }

    private func apiLine(_ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
    }

    private var apiLines: [(title: String, value: String)] {
        [
            (text(.apiDing), "POST /ding"),
            (text(.apiLibrary), "GET /library?type=prompt&q=review&limit=20"),
            (text(.apiGroups), "GET /library/groups?type=prompt"),
            (text(.apiAdd), "POST /library"),
            (text(.apiExport), "GET /library/export?limit=200"),
            (text(.knowledge), "GET /knowledge/index?path=/docs&limit=20"),
            (text(.apiTemplates), "GET /agent/templates"),
            (text(.apiCaps), "GET /agent/capabilities"),
            (text(.apiCaps), "GET /agent/manifest"),
            (text(.apiStatus), "GET /system/status"),
            (text(.apiBrief), "GET /agent/brief"),
            (text(.apiPrepare), "GET /agent/prepare?task=review&limit=8"),
            (text(.apiPrepare), "GET /agent/workbench?task=review&limit=8"),
            (text(.apiContext), "POST /agent/session"),
            (text(.apiContext), "GET /agent/sessions?status=active&limit=10"),
            (text(.apiContext), "POST /agent/memory"),
            (text(.apiRecommend), "GET /agent/recommend?q=review&type=prompt"),
            (text(.apiHandoff), "POST /agent/handoff"),
            (text(.clipboard), "POST /clipboard/capture"),
            (text(.apiInsights), "GET /clipboard/insights?limit=8"),
            (text(.apiHistory), "GET /clipboard/history?filter=command&limit=10")
        ]
    }

    private func text(_ key: AppText) -> String {
        controller.text(key)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        controller.language == .chinese ? chinese : english
    }
}
