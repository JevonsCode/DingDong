import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct ControlPanelView: View {
    @ObservedObject var controller: StatusController
    @ObservedObject var soundPlayer: SoundPlayer
    @State private var isImportingResources = false
    @State private var importResourceType: ResourceType = .knowledge
    @State private var importPath = ""
    @State private var importGroup = ""
    @State private var importTags = ""
    @State private var launchpadTask = ""
    @State private var isClipboardDetailsExpanded = false
    @State private var isCommandQuickSelectActive = false
    @State private var selectedClipboardDetailID: UUID?
    @State private var clipboardScrollTargetID: UUID?
    @State private var visibleClipboardShortcutIDs: [UUID] = []
    @State private var deferredSearchRefreshWorkItem: DispatchWorkItem?
    @State private var suppressNextSearchRefresh = false
    @State private var draggingClipboardFilter: ClipboardSmartFilter?
    @State private var hoveringClipboardFilterDropTarget: ClipboardSmartFilter?
    @State private var draggingClipboardGroup: String?
    @State private var hoveringClipboardGroupDropTarget: String?
    @FocusState private var focusedPanelField: PanelFocusField?

    var body: some View {
        ZStack {
            companionBackground

            VStack(spacing: 0) {
                header
                tabBar
                Divider().overlay(PanelTheme.border)
                content
                footer
            }
        }
        .frame(
            minWidth: PanelMetrics.width,
            idealWidth: PanelMetrics.width,
            maxWidth: PanelMetrics.width,
            minHeight: PanelMetrics.minHeight,
            idealHeight: PanelMetrics.height,
            maxHeight: .infinity
        )
        .foregroundStyle(PanelTheme.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: PanelTheme.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PanelTheme.panelRadius, style: .continuous)
                .stroke(PanelTheme.border, lineWidth: 1)
        }
        .background {
            ClipboardQuickSelectMonitor(
                isEnabled: true,
                isQuickSelectEnabled: controller.activeTab == .clipboard,
                focusedPanelField: focusedPanelField,
                onCommandStateChange: { isActive in
                    isCommandQuickSelectActive = isActive
                },
                onNumber: { number in
                    restoreVisibleClipboardItem(at: number)
                },
                onSearch: {
                    focusSearchFromShortcut()
                },
                onToggleFilters: {
                    toggleClipboardFiltersFromShortcut()
                },
                onTab: { tab in
                    controller.setActiveTab(tab)
                },
                onPage: { direction in
                    moveClipboardPage(direction)
                },
                onMoveSelection: { direction in
                    moveClipboardSelection(direction)
                },
                onPreviewSelection: {
                    previewSelectedClipboardItem()
                },
                onUseSelection: {
                    useSelectedClipboardItem()
                }
            )
            .frame(width: 0, height: 0)
        }
        .onAppear {
            controller.refreshResources()
        }
        .onChange(of: controller.searchText) { _, _ in
            if suppressNextSearchRefresh {
                suppressNextSearchRefresh = false
                return
            }

            scheduleSearchRefresh()
        }
        .onChange(of: controller.activeTab) { _, tab in
            if tab != .clipboard {
                isCommandQuickSelectActive = false
                selectedClipboardDetailID = nil
                controller.hideClipboardDetail()
            } else {
                isClipboardDetailsExpanded = false
            }
        }
        .onChange(of: controller.clipboardItems.map(\.id)) { _, ids in
            guard let selectedClipboardDetailID,
                  !ids.contains(selectedClipboardDetailID)
            else {
                return
            }

            self.selectedClipboardDetailID = nil
        }
    }

    private var companionBackground: some View {
        PanelTheme.panelBackground(opacity: controller.panelBackgroundOpacity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: StatusController.makePanelLogoImage())
                .resizable()
                .frame(width: 34, height: 34)
                .shadow(color: PanelTheme.warning.opacity(0.18), radius: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text("DingDong")
                    .font(.system(size: 20, weight: .semibold))
            }

            Spacer()

            Button {
                controller.refreshResources()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(text(.refresh))
            .buttonStyle(IconButtonStyle(size: 32))

            Button {
                controller.showSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
            }
            .help(text(.settings))
            .buttonStyle(IconButtonStyle(size: 32))

            Button {
                controller.hideCurrentPanel()
            } label: {
                Image(systemName: "chevron.up")
            }
            .help(controller.language == .chinese ? "收起面板" : "Hide Panel")
            .buttonStyle(IconButtonStyle(size: 32))
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(WindowDragSurface())
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(CompanionTab.mainPanelTabs, id: \.self) { tab in
                let shortcut = commandShortcut(for: tab)
                let showsShortcut = shortcut != nil && isCommandQuickSelectActive

                Button {
                    controller.setActiveTab(tab)
                } label: {
                    ZStack {
                        HStack(spacing: 5) {
                            tabIcon(for: tab)

                            Text(tab.title(language: controller.language))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.leading, showsShortcut ? 2 : 0)
                        .padding(.trailing, showsShortcut ? 46 : 0)

                        if let shortcut, showsShortcut {
                            HStack {
                                Spacer()
                                Text(shortcut)
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(controller.activeTab == tab ? PanelTheme.textOnAccent.opacity(0.86) : PanelTheme.textTertiary)
                                    .frame(width: 34, height: 18)
                            }
                            .padding(.trailing, 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TabButtonStyle(isSelected: controller.activeTab == tab))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func tabIcon(for tab: CompanionTab) -> some View {
        let isLoading = controller.isContentLoading && controller.activeTab == tab
        let color = controller.activeTab == tab ? PanelTheme.textOnAccent : PanelTheme.textSecondary

        ZStack {
            if isLoading {
                DingDongLoadingSpinner(color: .white)
                    .transition(.opacity)
            } else {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .transition(.opacity)
            }
        }
        .frame(width: 16, height: 16)
        .animation(.easeInOut(duration: 0.16), value: isLoading)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.activeTab {
        case .today:
            todayView
        case .library:
            libraryView
        case .clipboard:
            clipboardView
        case .api:
            SettingsPanelView(controller: controller, soundPlayer: soundPlayer)
        }
    }

    private var todayView: some View {
        ThinScrollableView(coordinateSpaceName: "dingdong.today-list.viewport") {
            VStack(alignment: .leading, spacing: 14) {
                statusCard
                HStack(spacing: 10) {
                    metricCard(text(.resources), "\(controller.resourceOverview.total)", "square.stack.3d.up")
                    metricCard(text(.clipboard), "\(controller.resourceOverview.clipboard)", "doc.on.clipboard")
                    metricCard(text(.api), apiStatusShort, "point.3.connected.trianglepath.dotted")
                }

                if !controller.activeAgentPresences.isEmpty {
                    sectionHeader(text(.activeAgents))
                    agentPresenceList(controller.activeAgentPresences)
                }

                sectionHeader(text(.recentAgents))
                eventList(controller.agentEvents.prefix(4).map { $0 })

                sectionHeader(text(.pinned))
                resourceList(controller.resources.filter(\.pinned).prefix(4).map { $0 }, emptyText: text(.noPinnedResources))
            }
            .padding(16)
        }
    }

    private var handoffInboxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PanelTheme.accent)

                Text(text(.handoffInbox))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PanelTheme.textSecondary)

                statusCountPill("open", controller.handoffInboxStatusCounts["open"] ?? 0, PanelTheme.accent)
                statusCountPill("blocked", controller.handoffInboxStatusCounts["blocked"] ?? 0, PanelTheme.warning)

                Spacer()

                Button {
                    controller.openHandoffLibrary()
                } label: {
                    Image(systemName: "tray.full")
                }
                .instantHoverHelp(text(.openLibrary))
                .buttonStyle(.bordered)
            }

            if controller.handoffInboxItems.isEmpty {
                Text(text(.noHandoffs))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            } else {
                VStack(spacing: 7) {
                    ForEach(controller.handoffInboxItems.prefix(3)) { item in
                        handoffInboxRow(item)
                    }
                }
            }
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.accent.opacity(0.12), lineWidth: 1))
    }

    private var companionReadinessCard: some View {
        let readiness = controller.companionReadiness
        let accent = readinessAccent(readiness.state)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: readinessIcon(readiness.state))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(text(.companionReadiness))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelTheme.textSecondary)
                    Text(readinessTitle(readiness.state))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                }

                Spacer()

                Text("\(readiness.score)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent.opacity(0.9))
                    .frame(width: 36, alignment: .trailing)

                Button {
                    controller.copyAgentStartupCommand(task: launchpadTask)
                } label: {
                    Label(text(.startup), systemImage: "play.circle")
                        .labelStyle(.iconOnly)
                }
                .instantHoverHelp(text(.agentStartupCommand))
                .buttonStyle(.borderedProminent)

                Button {
                    controller.copyAgentToolkitCommand()
                } label: {
                    Label(text(.toolkit), systemImage: "wrench.and.screwdriver")
                        .labelStyle(.iconOnly)
                }
                .instantHoverHelp(text(.agentToolkitCommand))
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                readinessMetric(text(.resources), "\(readiness.resourceCount)", "square.stack.3d.up", PanelTheme.accent)
                readinessMetric(text(.agentMemory), "\(readiness.memoryCount)", "book.closed", PanelTheme.warning)
                readinessMetric(text(.clipboard), "\(readiness.clipboardCount)", "doc.on.clipboard", PanelTheme.success)
                readinessMetric(text(.activeAgents), "\(readiness.activeAgentCount)", "cpu", PanelTheme.danger)
            }
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.14), lineWidth: 1))
    }

    private func readinessMetric(_ title: String, _ value: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent.opacity(0.86))
                .frame(width: 13)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 7)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
    }

    private var agentMemoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PanelTheme.warning)

                Text(text(.agentMemory))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PanelTheme.textSecondary)

                statusCountPill(text(.total), controller.resourceOverview.memories, PanelTheme.warning)

                Spacer()

                Button {
                    controller.copyAgentMemoryCommand(task: launchpadTask)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .instantHoverHelp(text(.copyMemory))
                .buttonStyle(.bordered)

                Button {
                    controller.openMemoryLibrary()
                } label: {
                    Image(systemName: "tray.full")
                }
                .instantHoverHelp(text(.openMemoryLibrary))
                .buttonStyle(.bordered)
            }

            if controller.memoryItems.isEmpty {
                Text(text(.noMemories))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            } else {
                VStack(spacing: 7) {
                    ForEach(controller.memoryItems.prefix(3)) { item in
                        agentMemoryRow(item)
                    }
                }
            }
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.warning.opacity(0.13), lineWidth: 1))
    }

    private var agentWorkbenchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PanelTheme.accent)

                Text(text(.agentWorkbench))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PanelTheme.textSecondary)

                statusCountPill(text(.activeSessions), controller.activeSessionItems.count, PanelTheme.accent)
                statusCountPill(text(.handoffs), controller.companionReadiness.openHandoffCount, PanelTheme.warning)

                Spacer()

                Button {
                    controller.copyAgentWorkbenchCommand(task: launchpadTask)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .instantHoverHelp(text(.agentWorkbenchCommand))
                .buttonStyle(.borderedProminent)

                Button {
                    controller.openSessionLibrary()
                } label: {
                    Image(systemName: "tray.full")
                }
                .instantHoverHelp(text(.openSessionLibrary))
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                readinessMetric(text(.activeAgents), "\(controller.activeAgentPresences.count)", "cpu", PanelTheme.danger)
                readinessMetric(text(.activeSessions), "\(controller.activeSessionItems.count)", "checklist", PanelTheme.accent)
                readinessMetric(text(.agentMemory), "\(controller.memoryItems.count)", "book.closed", PanelTheme.warning)
            }

            if controller.activeSessionItems.isEmpty {
                Text(text(.noActiveSessions))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            } else {
                VStack(spacing: 7) {
                    ForEach(controller.activeSessionItems.prefix(3)) { item in
                        agentSessionRow(item)
                    }
                }
            }
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.accent.opacity(0.14), lineWidth: 1))
    }

    private func agentSessionRow(_ item: ResourceItem) -> some View {
        let status = controller.sessionStatus(for: item)

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: item.pinned ? "pin.fill" : "checklist")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(item.pinned ? PanelTheme.warning : PanelTheme.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(status)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PanelTheme.accent.opacity(0.82), in: RoundedRectangle(cornerRadius: 5))
                }

                Text(sessionExcerpt(item.content))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)

                if let source = item.source {
                    Text(source)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 5) {
                Button {
                    controller.copyResourceID(item)
                } label: {
                    Image(systemName: "number")
                }
                .instantHoverHelp(text(.copyResourceID))

                Button {
                    controller.openSessionLibrary()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .instantHoverHelp(text(.openSessionLibrary))
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
    }

    private func agentMemoryRow(_ item: ResourceItem) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: item.pinned ? "pin.fill" : "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(item.pinned ? PanelTheme.warning : PanelTheme.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(AgentMemoryRequest.kind(from: item))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PanelTheme.warning.opacity(0.82), in: RoundedRectangle(cornerRadius: 5))
                }

                Text(memoryExcerpt(item.content))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)

                if let source = item.source {
                    Text(source)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 5) {
                Button {
                    controller.copyResourceContent(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .instantHoverHelp(text(.copyContent))

                Button {
                    controller.openMemoryLibrary()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .instantHoverHelp(text(.openMemoryLibrary))
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
    }

    private func handoffInboxRow(_ item: ResourceItem) -> some View {
        let status = controller.handoffStatus(for: item)
        let accent = handoffStatusColor(status)

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: status == "blocked" ? "exclamationmark.triangle.fill" : "arrow.turn.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent.opacity(0.86))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(status)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.82), in: RoundedRectangle(cornerRadius: 5))
                }

                Text(handoffSummaryExcerpt(item.content))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)

                if let source = item.source {
                    Text(source)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 5) {
                Button {
                    controller.copyResourceID(item)
                } label: {
                    Image(systemName: "number")
                }
                .instantHoverHelp(text(.copyResourceID))

                Button {
                    controller.openHandoffLibrary()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .instantHoverHelp(text(.openLibrary))
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
    }

    private func statusCountPill(_ title: String, _ count: Int, _ accent: Color) -> some View {
        Text("\(title) \(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(count > 0 ? PanelTheme.textOnAccent : PanelTheme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(count > 0 ? accent.opacity(0.86) : PanelTheme.field, in: RoundedRectangle(cornerRadius: 5))
    }

    private func handoffStatusColor(_ status: String) -> Color {
        switch status {
        case "blocked":
            PanelTheme.warning
        case "open":
            PanelTheme.accent
        default:
            PanelTheme.textTertiary
        }
    }

    private func handoffSummaryExcerpt(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let summaryIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "## Summary" }) {
            for line in lines.dropFirst(summaryIndex + 1) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                    return trimmed
                }
            }
        }

        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") } ?? content
    }

    private func memoryExcerpt(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let memoryIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "## Memory" }) {
            for line in lines.dropFirst(memoryIndex + 1) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                    return trimmed
                }
            }
        }

        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("-") } ?? content
    }

    private func sessionExcerpt(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let stepIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "## Current Step" }) {
            for line in lines.dropFirst(stepIndex + 1) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                    return trimmed
                }
            }
        }

        if let summaryIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "## Summary" }) {
            for line in lines.dropFirst(summaryIndex + 1) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                    return trimmed
                }
            }
        }

        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("-") } ?? content
    }

    private var agentLaunchpadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PanelTheme.warning)

                Text(text(.agentLaunchpad))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PanelTheme.textSecondary)

                Spacer()

                Button {
                    controller.setActiveTab(.api)
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                }
                .instantHoverHelp(text(.api))
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Label(text(.agentTask), systemImage: "target")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(width: 74, alignment: .leading)

                TextField(text(.agentTaskPlaceholder), text: $launchpadTask)
                    .textFieldStyle(.plain)
                    .padding(9)
                    .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
            }

            HStack(spacing: 8) {
                Button {
                    controller.copyAgentPrepareCommand(task: launchpadTask)
                } label: {
                    Label(text(.copyPrepare), systemImage: "wand.and.sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    controller.copyAgentPresenceCommand(task: launchpadTask)
                } label: {
                    Label(text(.copyPresence), systemImage: "cpu")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.warning.opacity(0.14), lineWidth: 1))
    }

    private var libraryView: some View {
        VStack(spacing: 12) {
            libraryToolbar
            if isImportingResources {
                importResourcePanel
                    .padding(.horizontal, 16)
            }
            searchAndFilters
            if controller.knowledgeIndexTitle != nil {
                knowledgeIndexPanel
                    .padding(.horizontal, 16)
            }
            ThinScrollableView(coordinateSpaceName: "dingdong.library-list.viewport") {
                lazyResourceList(controller.resources, emptyText: text(.noResources))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .padding(.top, 14)
    }

    private var libraryToolbar: some View {
        HStack(spacing: 10) {
            Text(text(.library))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                isImportingResources = false
                controller.showResourceManagerWindow()
            } label: {
                Label(controller.language == .chinese ? "资源管理" : "Manage", systemImage: "rectangle.stack")
            }
            .buttonStyle(ControlButtonStyle(isProminent: true))
        }
        .padding(.horizontal, 16)
    }

    private var importResourcePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text(.importFolder))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PanelTheme.textSecondary)

            HStack(spacing: 6) {
                ForEach([ResourceType.prompt, .skill, .mcp, .knowledge], id: \.self) { type in
                    Button {
                        importResourceType = type
                        if importGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            importGroup = type.defaultGroup
                        }
                    } label: {
                        Label(type.displayTitle(language: controller.language), systemImage: icon(for: type))
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .buttonStyle(FilterButtonStyle(isSelected: importResourceType == type))
                }
            }

            HStack(spacing: 8) {
                TextField(text(.folderPath), text: $importPath)
                    .textFieldStyle(.plain)
                    .foregroundStyle(PanelTheme.textPrimary)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))

                TextField(text(.group), text: $importGroup)
                    .textFieldStyle(.plain)
                    .foregroundStyle(PanelTheme.textPrimary)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 126)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
            }

            HStack(spacing: 8) {
                TextField(text(.tagsPlaceholder), text: $importTags)
                    .textFieldStyle(.plain)
                    .foregroundStyle(PanelTheme.textPrimary)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))

                Button {
                    if controller.importResources(
                        type: importResourceType,
                        path: importPath,
                        group: importGroup,
                        tagsText: importTags
                    ) {
                        resetImportDraft()
                        isImportingResources = false
                    }
                } label: {
                    Label(text(.importAction), systemImage: "square.and.arrow.down.fill")
                }
                .buttonStyle(ControlButtonStyle(isProminent: true))
            }
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
        .onAppear {
            if importGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                importGroup = importResourceType.defaultGroup
            }
        }
    }

    private var knowledgeIndexPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundStyle(PanelTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.knowledgeIndexTitle ?? text(.knowledge))
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    Text(controller.knowledgeIndexStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    controller.closeKnowledgeIndex()
                } label: {
                    Image(systemName: "xmark")
                }
                .instantHoverHelp(text(.close))
                .buttonStyle(RowIconButtonStyle())
            }

            if let root = controller.knowledgeIndexRoot {
                Text(root)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if controller.knowledgeIndexEntries.isEmpty {
                Text(text(.noIndexableFiles))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(controller.knowledgeIndexEntries.prefix(5), id: \.path) { entry in
                        knowledgeIndexRow(entry)
                    }
                }
            }
        }
        .padding(11)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.accent.opacity(0.16), lineWidth: 1))
    }

    private func knowledgeIndexRow(_ entry: KnowledgeIndexEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.relativePath)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                controller.copyKnowledgeEntryPath(entry)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .instantHoverHelp(text(.copyFilePath))
            .buttonStyle(RowIconButtonStyle())
        }
        .padding(8)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
    }

    private var clipboardView: some View {
        VStack(spacing: 10) {
            clipboardToolbar

            if isClipboardDetailsExpanded {
                clipboardDetailsPanel
            }

            clipboardContentArea
        }
    }

    private var clipboardContentArea: some View {
        ScrollViewReader { proxy in
            GeometryReader { viewport in
                let viewportHeight = viewport.size.height

                ThinScrollableView(coordinateSpaceName: clipboardListCoordinateSpaceName) {
                    clipboardList
                        .padding(.leading, 16)
                        .padding(.trailing, 14)
                        .padding(.bottom, 16)
                }
                .onPreferenceChange(ClipboardVisibleRowsPreferenceKey.self) { rows in
                    updateVisibleClipboardShortcutRows(rows, viewportHeight: viewportHeight)
                }
                .onChange(of: clipboardScrollTargetID) { _, id in
                    guard let id else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.16)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var clipboardToolbar: some View {
        HStack(spacing: 8) {
            Toggle(isOn: clipboardMonitoringBinding) {
                EmptyView()
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .frame(width: 48, height: 34)
            .padding(.horizontal, 6)
            .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .help(controller.isClipboardMonitoring ? text(.off) : text(.on))

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)

                TextField("", text: $controller.searchText, prompt: Text(clipboardSearchPlaceholder).foregroundStyle(PanelTheme.textTertiary))
                    .textFieldStyle(.plain)
                    .foregroundStyle(PanelTheme.textPrimary)
                    .font(.system(size: 12, weight: .medium))
                    .focused($focusedPanelField, equals: .clipboardSearch)

                Button {
                    clearSearchText()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .opacity(controller.searchText.isEmpty ? 0 : 1)
                }
                .foregroundStyle(PanelTheme.textSecondary)
                .buttonStyle(.plain)
                .disabled(controller.searchText.isEmpty)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

            Button {
                isClipboardDetailsExpanded.toggle()
            } label: {
                ZStack {
                    Image(systemName: isClipboardDetailsExpanded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .opacity(isCommandQuickSelectActive ? 0 : 1)

                    Text("R")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .opacity(isCommandQuickSelectActive ? 1 : 0)
                }
                .frame(width: 18, height: 18)
            }
            .instantHoverHelp(clipboardDetailsTitle)
            .buttonStyle(IconButtonStyle(isProminent: isClipboardDetailsExpanded || hasActiveClipboardScope, size: 34))
        }
        .padding(10)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(PanelTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var clipboardDetailsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(clipboardDetailsTitle, systemImage: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)

                Spacer()

                Button {
                    controller.selectResourceType(.clipboard)
                    controller.setActiveTab(.library)
                } label: {
                    Image(systemName: "tray.full")
                }
                .instantHoverHelp(text(.openGroup))
                .buttonStyle(IconButtonStyle(size: 30))
            }

            HStack(spacing: 7) {
                clipboardOverviewBadge(icon: "tray.full", value: controller.clipboardOverview.total, helpText: text(.total), accent: PanelTheme.accent)
                clipboardOverviewBadge(icon: "link", value: controller.clipboardOverview.urls, helpText: "URL", accent: PanelTheme.accent)
                clipboardOverviewBadge(icon: "terminal", value: controller.clipboardOverview.commands, helpText: text(.command), accent: PanelTheme.success)
                clipboardOverviewBadge(icon: "lock.shield", value: controller.clipboardOverview.sensitive, helpText: text(.sensitive), accent: PanelTheme.warning)
            }

            clipboardSmartFilters
            clipboardGroupFilters
        }
        .padding(12)
        .background(PanelTheme.surfaceSoft, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(PanelTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func clipboardOverviewBadge(icon: String, value: Int, helpText: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            Text("\(value)")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)
        }
        .frame(height: 26)
        .padding(.horizontal, 8)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(PanelTheme.border, lineWidth: 1))
        .help(helpText)
    }

    private var clipboardList: some View {
        LazyVStack(alignment: .leading, spacing: resourceListSpacing) {
            if controller.clipboardItems.isEmpty {
                Text(text(.clipboardEmpty))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(controller.clipboardItems) { item in
                    clipboardRow(
                        item,
                        shortcutNumber: clipboardShortcutNumber(for: item),
                        isSelected: selectedClipboardDetailID == item.id
                    )
                    .id(item.id)
                    .background(clipboardRowVisibilityReader(id: item.id))
                }
            }
        }
    }

    private var clipboardOverviewStrip: some View {
        HStack(spacing: 8) {
            summaryPill(
                title: text(.total),
                value: "\(controller.clipboardOverview.total)",
                icon: "tray.full",
                accent: PanelTheme.accent
            )
            summaryPill(
                title: "URL",
                value: "\(controller.clipboardOverview.urls)",
                icon: "link",
                accent: PanelTheme.accent
            )
            summaryPill(
                title: text(.command),
                value: "\(controller.clipboardOverview.commands)",
                icon: "terminal",
                accent: PanelTheme.success
            )
            summaryPill(
                title: text(.sensitive),
                value: "\(controller.clipboardOverview.sensitive)",
                icon: "lock.shield",
                accent: PanelTheme.warning
            )
        }
        .padding(.horizontal, 16)
    }

    private var clipboardCopilotCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PanelTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(text(.clipboardCopilot))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PanelTheme.textSecondary)
                    Text(controller.clipboardCopilot.total == 0 ? text(.clipboardCopilotEmpty) : text(.clipboardCopilotReady))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    controller.copyClipboardInsightsCommand()
                } label: {
                    Label(text(.copyInsights), systemImage: "sparkle.magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .instantHoverHelp(text(.copyInsights))
                .buttonStyle(.bordered)

                Button {
                    controller.copyClipboardDigestCommand(task: controller.searchText)
                } label: {
                    Label(text(.copyDigest), systemImage: "doc.text.magnifyingglass")
                        .labelStyle(.iconOnly)
                }
                .instantHoverHelp(text(.copyDigest))
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                copilotMetric(text(.useful), "\(controller.clipboardCopilot.usefulCandidates)", "wand.and.stars", PanelTheme.warning)
                copilotMetric(text(.clipboardSnippets), "\(controller.clipboardCopilot.snippetCandidates)", "bolt.fill", PanelTheme.success)
                copilotMetric(text(.hiddenSensitive), "\(controller.clipboardCopilot.hiddenSensitive)", "lock.shield", PanelTheme.danger)

                Button {
                    controller.focusClipboardCopilotCandidates()
                } label: {
                    Label(text(.focusCandidates), systemImage: controller.clipboardCopilot.preferredFilter.icon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .buttonStyle(.bordered)
                .disabled(!controller.clipboardCopilot.hasSuggestions)
            }
        }
        .padding(11)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.accent.opacity(0.13), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func copilotMetric(_ title: String, _ value: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent.opacity(0.86))
                .frame(width: 13)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 7)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
    }

    private var clipboardSmartFilters: some View {
        VStack(alignment: .leading, spacing: 6) {
            clipboardFilterSectionTitle(controller.language == .chinese ? "分类" : "Category")

            LazyVGrid(columns: clipboardFilterGridColumns, alignment: .leading, spacing: 7) {
                ForEach(controller.clipboardFilterOrder, id: \.self) { filter in
                    Button {
                        controller.setClipboardFilter(filter)
                    } label: {
                        Label(filter.title(language: controller.language), systemImage: filter.icon)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompactFilterButtonStyle(isSelected: controller.selectedClipboardFilter == filter))
                    .help(filter.title(language: controller.language))
                    .onDrag {
                        draggingClipboardFilter = filter
                        hoveringClipboardFilterDropTarget = nil
                        return NSItemProvider(object: filter.rawValue as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: ClipboardFilterDropDelegate(
                            target: filter,
                            draggingFilter: $draggingClipboardFilter,
                            hoverTarget: $hoveringClipboardFilterDropTarget,
                            move: controller.moveClipboardFilter
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var clipboardSnippetStrip: some View {
        if !controller.clipboardSnippets.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Label(text(.clipboardSnippets), systemImage: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PanelTheme.warning)

                    Text("\(controller.clipboardSnippets.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PanelTheme.textOnAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(PanelTheme.warning.opacity(0.82), in: RoundedRectangle(cornerRadius: 5))

                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(controller.clipboardSnippets) { shortcut in
                            clipboardSnippetButton(shortcut)
                        }
                    }
                }
            }
            .padding(10)
            .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.warning.opacity(0.14), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private func clipboardSnippetButton(_ shortcut: ClipboardSnippetShortcut) -> some View {
        Button {
            controller.restoreClipboardItem(shortcut.item)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: shortcut.item.isSensitiveClipboard ? "lock.shield" : "arrowshape.turn.up.left.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(shortcut.item.isSensitiveClipboard ? PanelTheme.danger : PanelTheme.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text("@\(shortcut.alias)")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Text(shortcut.item.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 118, alignment: .leading)
        }
        .buttonStyle(SnippetButtonStyle())
        .instantHoverHelp(text(.restoreClipboard))
    }

    @ViewBuilder
    private var clipboardGroupFilters: some View {
        if !controller.clipboardOverview.groups.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                clipboardFilterSectionTitle(controller.language == .chinese ? "分组" : "Groups")

                LazyVGrid(columns: clipboardGroupGridColumns, alignment: .leading, spacing: 7) {
                    ForEach(controller.clipboardOverview.groups, id: \.name) { bucket in
                        clipboardGroupFilterControl(bucket)
                    }

                    clipboardGroupFilterButton(
                        title: text(.all),
                        group: nil,
                        count: controller.clipboardOverview.total
                    )
                }
            }
        }
    }

    private var clipboardFilterGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 76), spacing: 7)]
    }

    private var clipboardGroupGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 92), spacing: 7)]
    }

    @ViewBuilder
    private func clipboardGroupFilterControl(_ bucket: ClipboardBucket) -> some View {
        let button = clipboardGroupFilterButton(
            title: bucket.name,
            group: bucket.name,
            count: bucket.count
        )

        if isDefaultClipboardGroup(bucket.name) {
            button
        } else {
            button
                .onDrag {
                    draggingClipboardGroup = bucket.name
                    hoveringClipboardGroupDropTarget = nil
                    return NSItemProvider(object: bucket.name as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ClipboardGroupDropDelegate(
                        target: bucket.name,
                        draggingGroup: $draggingClipboardGroup,
                        hoverTarget: $hoveringClipboardGroupDropTarget,
                        move: controller.moveClipboardGroup
                    )
                )
        }
    }

    private func isDefaultClipboardGroup(_ group: String) -> Bool {
        group.localizedCaseInsensitiveCompare(ResourceType.clipboard.defaultGroup) == .orderedSame
    }

    private func clipboardGroupFilterButton(title: String, group: String?, count: Int) -> some View {
        Button {
            controller.setClipboardGroup(group)
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: 118, alignment: .leading)

                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PanelTheme.textOnAccent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(PanelTheme.accent.opacity(0.78), in: RoundedRectangle(cornerRadius: 5))
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(CompactFilterButtonStyle(isSelected: controller.selectedClipboardGroup == group))
        .help(title)
    }

    private func clipboardFilterSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(PanelTheme.textTertiary)
            .lineLimit(1)
    }

    private func clipboardRow(_ item: ResourceItem, shortcutNumber: Int?, isSelected: Bool) -> some View {
        let isCompact = controller.panelDensity == .compact

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: clipboardRowIcon(for: item))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(clipboardRowAccent(for: item))
                .frame(width: 30, height: 30)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
                .help(clipboardRowIconHelp(for: item))

            VStack(alignment: .leading, spacing: isCompact ? 3 : 5) {
                HStack(spacing: 5) {
                    Text(clipboardRowTitle(for: item))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PanelTheme.textPrimary)
                        .lineLimit(1)

                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PanelTheme.warning)
                    }
                }

                Text(clipboardRowPreview(for: item))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(isCompact ? 1 : 2)
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcutNumber {
                Text("⌘ \(shortcutNumber)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(PanelTheme.textOnAccent)
                    .frame(width: 38, height: 24)
                    .background(PanelTheme.accent, in: RoundedRectangle(cornerRadius: 7))
            } else {
                Text(clipboardRowTime(for: item))
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(PanelTheme.textTertiary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .frame(minHeight: isCompact ? 54 : 64, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, isCompact ? 7 : 9)
        .background(isSelected ? PanelTheme.accentSoft : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? PanelTheme.accent.opacity(0.34) : PanelTheme.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(count: 2) {
            selectClipboardItem(item, opensDetail: false)
            controller.restoreClipboardItemFromQuickAction(item)
        }
        .onTapGesture {
            selectClipboardItem(item, opensDetail: true)
        }
        .help(clipboardRowHelp)
        .contextMenu {
            Button {
                selectClipboardItem(item, opensDetail: true)
            } label: {
                Label(clipboardMenuText(.details), systemImage: "sidebar.right")
            }

            Button {
                controller.restoreClipboardItem(item)
            } label: {
                Label(clipboardMenuText(.copy), systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                promptClipboardTitle(item)
            } label: {
                Label(clipboardMenuText(.addTitle), systemImage: "textformat")
            }

            Button {
                promptClipboardContent(item)
            } label: {
                Label(clipboardMenuText(.editText), systemImage: "pencil")
            }

            Menu {
                Button {
                    controller.saveClipboardItem(item, as: .prompt)
                } label: {
                    Label(ResourceType.prompt.displayTitle(language: controller.language), systemImage: icon(for: .prompt))
                }

                Button {
                    controller.saveClipboardItem(item, as: .knowledge)
                } label: {
                    Label(ResourceType.knowledge.displayTitle(language: controller.language), systemImage: icon(for: .knowledge))
                }
            } label: {
                Label(clipboardMenuText(.saveTo), systemImage: "tray.and.arrow.down")
            }

            clipboardArchiveMenu(for: item)

            Button {
                controller.shareResourceContent(item)
            } label: {
                Label(clipboardMenuText(.share), systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                controller.deleteResource(item)
                if selectedClipboardDetailID == item.id {
                    selectedClipboardDetailID = nil
                    controller.hideClipboardDetail()
                }
            } label: {
                Label(text(.delete), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func clipboardArchiveMenu(for item: ResourceItem) -> some View {
        Menu {
            Button {
                controller.archiveClipboardItem(item)
            } label: {
                Label(clipboardMenuText(.defaultArchive), systemImage: "archivebox")
            }

            let groups = clipboardArchiveGroups(excluding: "Archive")
            if !groups.isEmpty {
                Divider()

                ForEach(groups, id: \.self) { group in
                    Button {
                        controller.archiveClipboardItem(item, group: group)
                    } label: {
                        Label(group, systemImage: "folder")
                    }
                }
            }

            Divider()

            Button {
                promptClipboardArchiveGroup(item)
            } label: {
                Label(clipboardMenuText(.newArchiveGroup), systemImage: "folder.badge.plus")
            }
        } label: {
            Label(clipboardMenuText(.archiveTo), systemImage: "archivebox")
        }
    }

    private func clipboardRowIcon(for item: ResourceItem) -> String {
        if item.isSensitiveClipboard {
            return "lock.shield"
        }
        if item.tags.contains("image") {
            return "photo"
        }
        if item.tags.contains("file") {
            return "doc"
        }
        if item.tags.contains("command") {
            return "terminal"
        }
        if item.tags.contains("url") {
            return "link"
        }
        if item.tags.contains("code") || item.tags.contains("json") {
            return "chevron.left.forwardslash.chevron.right"
        }
        if item.tags.contains("path") {
            return "folder"
        }
        return "doc.on.clipboard"
    }

    private func clipboardRowAccent(for item: ResourceItem) -> Color {
        if item.isSensitiveClipboard {
            return PanelTheme.danger
        }
        if item.tags.contains("image") {
            return PanelTheme.warning
        }
        if item.tags.contains("file") {
            return PanelTheme.accent
        }
        if item.tags.contains("command") {
            return PanelTheme.success
        }
        if item.tags.contains("url") {
            return PanelTheme.accent
        }
        return PanelTheme.textSecondary
    }

    private func clipboardRowIconHelp(for item: ResourceItem) -> String {
        if item.isSensitiveClipboard {
            return text(.sensitive)
        }
        if item.tags.contains("image") {
            return controller.language == .chinese ? "图片文件" : "Image File"
        }
        if item.tags.contains("file") {
            return controller.language == .chinese ? "文件" : "File"
        }
        if item.tags.contains("command") {
            return text(.command)
        }
        if item.tags.contains("url") {
            return "URL"
        }
        if item.tags.contains("code") || item.tags.contains("json") {
            return text(.code)
        }
        if item.tags.contains("path") {
            return text(.path)
        }
        return text(.clipboard)
    }

    private func clipboardRowTitle(for item: ResourceItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        return clipboardRowPreview(for: item)
    }

    private func clipboardRowPreview(for item: ResourceItem) -> String {
        let preview = item.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !preview.isEmpty {
            return preview
        }

        return item.source ?? item.group
    }

    private func clipboardRowTime(for item: ResourceItem) -> String {
        item.updatedAt.formatted(date: .omitted, time: .shortened)
    }

    private var apiView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(text(.agentTemplates))
                ForEach(AgentCommandTemplate.defaults) { template in
                    agentTemplateRow(template)
                }

                sectionHeader(text(.endpoints))
                apiLine(text(.apiDing), "POST /ding")
                apiLine(text(.apiLibrary), "GET /library?type=prompt&q=review&limit=20")
                apiLine(text(.apiGroups), "GET /library/groups?type=prompt")
                apiLine(text(.apiAdd), "POST /library")
                apiLine(text(.apiExport), "GET /library/export?limit=200")
                apiLine(text(.knowledge), "GET /knowledge/index?path=/docs&limit=20")
                apiLine(text(.apiTemplates), "GET /agent/templates")
                apiLine(text(.apiCaps), "GET /agent/capabilities")
                apiLine(text(.apiCaps), "GET /agent/manifest")
                apiLine(text(.apiStatus), "GET /system/status")
                apiLine(text(.apiBrief), "GET /agent/brief")
                apiLine(text(.apiPrepare), "GET /agent/prepare?task=review&limit=8")
                apiLine(text(.apiPrepare), "GET /agent/workbench?task=review&limit=8")
                apiLine(text(.apiPrepare), "GET /agent/instructions?task=review&limit=6")
                apiLine(text(.apiContext), "POST /agent/session")
                apiLine(text(.apiContext), "GET /agent/sessions?status=active&limit=10")
                apiLine(text(.apiContext), "PATCH /agent/session/{id}")
                apiLine(text(.apiContext), "POST /agent/memory")
                apiLine(text(.apiContext), "GET /agent/memories?q=review&limit=10")
                apiLine(text(.apiRecommend), "GET /agent/recommend?q=review&type=prompt")
                apiLine(text(.apiRecommend), "GET /agent/resolve?q=review&type=prompt")
                apiLine(text(.apiContext), "GET /agent/resource/{id}")
                apiLine(text(.apiHandoff), "POST /agent/handoff")
                apiLine(text(.handoffs), "GET /agent/handoffs?status=open&limit=10")
                apiLine(text(.apiContext), "GET /agent/context?q=review&limit=20")
                apiLine(text(.clipboard), "POST /clipboard/capture")
                apiLine(text(.apiInsights), "GET /clipboard/insights?limit=8")
                apiLine(text(.apiInsights), "GET /clipboard/digest?task=review&limit=8")
                apiLine(text(.apiInsights), "POST /clipboard/collect")
                apiLine(text(.apiHistory), "GET /clipboard/history?filter=command&limit=10")
                apiLine(text(.apiSnippets), "GET /clipboard/snippets?alias=deploy")
                apiLine(text(.apiGroups), "GET /clipboard/groups")
                apiLine(text(.apiEdit), "PATCH /clipboard/{id}")
                apiLine(text(.apiPromote), "POST /clipboard/promote/{id}")
                apiLine(text(.apiRestore), "POST /clipboard/restore/{id}")
                apiLine(text(.apiSnippets), "POST /clipboard/snippet/{alias}/restore")

                sectionHeader(text(.soundLab))
                soundLab

                Button {
                    controller.copyCurlExample()
                } label: {
                    Label(text(.copyDingCurl), systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    private var soundLab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(DingSound.primaryChoices, id: \.self) { sound in
                    soundButton(sound)
                }
            }

            HStack(spacing: 6) {
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
            }
        }
        .padding(11)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.warning.opacity(0.14), lineWidth: 1))
    }

    private func soundButton(_ sound: DingSound) -> some View {
        Button {
            controller.trigger(DingRequest(
                message: sound.displayTitle(language: controller.language),
                source: "DingDong",
                sound: sound,
                flashCount: 6
            ))
        } label: {
            Label(sound.displayTitle(language: controller.language), systemImage: sound.icon)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .buttonStyle(.bordered)
    }

    private func agentTemplateRow(_ template: AgentCommandTemplate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelTheme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(template.summary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)
                Text(template.command)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                controller.copyAgentTemplate(template)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .instantHoverHelp(text(.copyTemplate))
            .buttonStyle(RowIconButtonStyle())
        }
        .padding(10)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(controller.serverState.displayText(language: controller.language))
                .lineLimit(1)
                .truncationMode(.middle)

            Text("·")
                .foregroundStyle(PanelTheme.textSecondary)

            Text(controller.clipboardHotKeyState.displayText(language: controller.language))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(PanelTheme.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PanelTheme.surfaceSoft)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(controller.lastMessage)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(2)

            HStack {
                Label(controller.lastTriggerText, systemImage: "clock")
                Spacer()
                Label(controller.isFlashing ? text(.ringing) : text(.ready), systemImage: controller.isFlashing ? "waveform" : "checkmark.seal")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(PanelTheme.textSecondary)
        }
        .padding(14)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private var companionSummaryStrip: some View {
        HStack(spacing: 8) {
            summaryPill(
                title: text(.handoffs),
                value: "\(controller.resourceOverview.handoffs)",
                icon: "arrow.triangle.branch",
                accent: PanelTheme.accent
            )
            summaryPill(
                title: text(.agentMemory),
                value: "\(controller.resourceOverview.memories)",
                icon: "book.closed",
                accent: PanelTheme.warning
            )
            summaryPill(
                title: text(.monitor),
                value: controller.isClipboardMonitoring ? text(.on) : text(.off),
                icon: controller.isClipboardMonitoring ? "record.circle.fill" : "circle",
                accent: controller.isClipboardMonitoring ? PanelTheme.success : PanelTheme.textTertiary
            )
            summaryPill(
                title: text(.chime),
                value: DingSound.joy.displayTitle(language: controller.language),
                icon: "sun.max",
                accent: PanelTheme.warning
            )
        }
    }

    private func summaryPill(title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent.opacity(0.86))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 10)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.13), lineWidth: 1))
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PanelTheme.textSecondary)
                TextField("", text: $controller.searchText, prompt: Text(text(.searchPlaceholder)).foregroundStyle(PanelTheme.textTertiary))
                    .textFieldStyle(.plain)
                    .foregroundStyle(PanelTheme.textPrimary)
                    .font(.system(size: 12, weight: .medium))
                    .focused($focusedPanelField, equals: .librarySearch)
                Button {
                    clearSearchText()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .opacity(controller.searchText.isEmpty ? 0 : 1)
                }
                .foregroundStyle(PanelTheme.textSecondary)
                .buttonStyle(.plain)
                .disabled(controller.searchText.isEmpty)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 6) {
                filterButton(text(.all), nil)
                ForEach(ResourceType.allCases, id: \.self) { type in
                    filterButton(type.displayTitle(language: controller.language), type)
                }
            }

            libraryGroupFilters
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var libraryGroupFilters: some View {
        if !controller.libraryGroupSummaries.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    libraryGroupFilterButton(
                        title: text(.all),
                        group: nil,
                        count: controller.libraryGroupSummaries.reduce(0) { $0 + $1.count }
                    )

                    ForEach(controller.libraryGroupSummaries, id: \.filterID) { summary in
                        libraryGroupFilterButton(
                            title: summary.group,
                            group: summary.group,
                            count: summary.count
                        )
                    }
                }
            }
        }
    }

    private func filterButton(_ title: String, _ type: ResourceType?) -> some View {
        Button {
            controller.selectResourceType(type)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .buttonStyle(FilterButtonStyle(isSelected: controller.selectedResourceType == type))
    }

    private func libraryGroupFilterButton(title: String, group: String?, count: Int) -> some View {
        Button {
            controller.selectResourceGroup(group)
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PanelTheme.textOnAccent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(PanelTheme.accent.opacity(0.78), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .buttonStyle(CompactFilterButtonStyle(isSelected: controller.selectedResourceGroup == group))
    }

    private func metricCard(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PanelTheme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72)
        .padding(.horizontal, 12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func resourceList(_ items: [ResourceItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: resourceListSpacing) {
            if items.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(items) { item in
                    resourceRow(item)
                }
            }
        }
    }

    private func lazyResourceList(_ items: [ResourceItem], emptyText: String) -> some View {
        LazyVStack(alignment: .leading, spacing: resourceListSpacing) {
            if items.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(items) { item in
                    resourceRow(item)
                }
            }
        }
    }

    private var resourceListSpacing: CGFloat {
        controller.panelDensity == .compact ? 6 : 8
    }

    private func eventList(_ items: [AgentEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty {
                Text(text(.noAgentEvents))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            } else {
                ForEach(items) { event in
                    agentEventRow(event)
                }
            }
        }
    }

    private func agentPresenceList(_ items: [AgentPresenceRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty {
                Text(text(.noActiveAgents))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            } else {
                ForEach(items) { item in
                    agentPresenceRow(item)
                }
            }
        }
    }

    private func agentPresenceRow(_ item: AgentPresenceRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PanelTheme.success)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(item.status)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PanelTheme.textOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PanelTheme.success.opacity(0.86), in: Capsule())
                    Text(item.updatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                }

                if let task = item.task {
                    Text(task)
                        .font(.system(size: 11))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .frame(minHeight: 64, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func agentEventRow(_ event: AgentEvent) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PanelTheme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.source)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(event.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PanelTheme.textOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PanelTheme.accent.opacity(0.86), in: Capsule())
                }

                Text(event.message)
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .frame(minHeight: 64, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func resourceRow(_ item: ResourceItem) -> some View {
        let isCompact = controller.panelDensity == .compact
        let actionColumns = Array(repeating: GridItem(.fixed(28), spacing: 4), count: 3)
        let tags = displayResourceTags(for: item)

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon(for: item.type))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.pinned ? PanelTheme.warning : PanelTheme.accent)
                .frame(width: 24, height: 26)
                .help(item.type.displayTitle(language: controller.language))

            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Text(item.content)
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(isCompact ? 1 : 2)

                resourceMetadataRow(for: item, tags: tags, isCompact: isCompact)
            }
            .layoutPriority(1)

            Spacer()

            LazyVGrid(columns: actionColumns, alignment: .trailing, spacing: 5) {
                if item.type == .knowledge {
                    Button {
                        controller.scanKnowledge(item)
                        controller.setActiveTab(.library)
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                    .instantHoverHelp(text(.scanKnowledge))
                }

                if item.type == .clipboard {
                    Button {
                        controller.promoteClipboardToPrompt(item)
                    } label: {
                        Image(systemName: "wand.and.sparkles")
                    }
                    .instantHoverHelp(text(.saveAsPrompt))
                }

                Button {
                    controller.togglePinned(item)
                } label: {
                    Image(systemName: item.pinned ? "pin.fill" : "pin")
                }
                .instantHoverHelp(item.pinned ? text(.unpin) : text(.pin))

                Button {
                    controller.copyResourceContent(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .instantHoverHelp(text(.copyContent))

                Button {
                    controller.showResourceManagerWindow(editing: item)
                } label: {
                    Image(systemName: "pencil")
                }
                .instantHoverHelp(text(.edit))

                Button {
                    controller.deleteResource(item)
                } label: {
                    Image(systemName: "trash")
                }
                .instantHoverHelp(text(.delete))
            }
            .frame(width: 88, alignment: .trailing)
            .buttonStyle(RowIconButtonStyle())
        }
        .frame(minHeight: isCompact ? 70 : 86, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, isCompact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func resourceGroupBadgeTitle(_ group: String) -> String {
        let trimmedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroup.isEmpty else {
            return "General"
        }

        return trimmedGroup
    }

    private func displayResourceTags(for item: ResourceItem) -> [String] {
        var seen: Set<String> = []
        return item.tags.compactMap { rawTag in
            guard let tag = resourceTagTitle(rawTag) else {
                return nil
            }

            let key = tag.lowercased()
            guard !seen.contains(key) else {
                return nil
            }

            seen.insert(key)
            return tag
        }
        .prefix(4)
        .map { $0 }
    }

    private func resourceTagTitle(_ rawTag: String) -> String? {
        let trimmed = rawTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let lowercased = trimmed.lowercased()
        let hiddenTags: Set<String> = [
            "clipboard", "file", "file-url", "text", "from-clipboard", "default"
        ]

        guard trimmed.count > 1,
              trimmed != "...",
              trimmed != "…",
              !hiddenTags.contains(lowercased),
              !lowercased.hasPrefix("ext:"),
              !lowercased.hasPrefix("source:")
        else {
            return nil
        }

        if lowercased.hasPrefix("alias:") {
            let alias = String(trimmed.dropFirst("alias:".count))
            return alias.isEmpty ? nil : "@\(alias)"
        }

        if lowercased.hasPrefix("domain:") {
            let domain = String(trimmed.dropFirst("domain:".count))
            return domain.isEmpty ? nil : domain
        }

        return trimmed
    }

    @ViewBuilder
    private func resourceMetadataRow(for item: ResourceItem, tags: [String], isCompact: Bool) -> some View {
        let group = resourceGroupBadgeTitle(item.group)
        let visibleTags = isCompact ? Array(tags.prefix(2)) : tags

        WrappingHStack(spacing: 4, rowSpacing: 4) {
            resourceGroupChip(group)

            ForEach(visibleTags, id: \.self) { tag in
                resourceTagChip(tag)
            }
        }
        .help(([group] + visibleTags.map { "#\($0)" }).joined(separator: " · "))
    }

    private func resourceGroupChip(_ group: String) -> some View {
        Text(group)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(PanelTheme.textOnWarm)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(PanelTheme.warningSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(PanelTheme.warning.opacity(0.14), lineWidth: 1))
    }

    private func resourceTagChip(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(PanelTheme.accent)
            .lineLimit(1)
            .truncationMode(.middle)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(PanelTheme.accentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(PanelTheme.accent.opacity(0.12), lineWidth: 1))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(PanelTheme.textSecondary)
            .padding(.top, 4)
    }

    private func apiLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Spacer()
        }
        .padding(11)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var apiStatusShort: String {
        switch controller.serverState {
        case .running:
            text(.apiLive)
        case .failed:
            text(.apiDown)
        }
    }

    private func readinessTitle(_ state: CompanionReadinessState) -> String {
        switch state {
        case .ready:
            text(.readyForAgents)
        case .warming:
            text(.warmingUp)
        case .needsSetup:
            text(.needsSetup)
        }
    }

    private func readinessAccent(_ state: CompanionReadinessState) -> Color {
        switch state {
        case .ready:
            PanelTheme.success
        case .warming:
            PanelTheme.warning
        case .needsSetup:
            PanelTheme.danger
        }
    }

    private func readinessIcon(_ state: CompanionReadinessState) -> String {
        switch state {
        case .ready:
            "checkmark.seal.fill"
        case .warming:
            "sparkles"
        case .needsSetup:
            "wrench.and.screwdriver"
        }
    }

    private func text(_ key: AppText) -> String {
        controller.text(key)
    }

    private var clipboardMonitoringBinding: Binding<Bool> {
        Binding(
            get: { controller.isClipboardMonitoring },
            set: { nextValue in
                guard nextValue != controller.isClipboardMonitoring else {
                    return
                }
                controller.toggleClipboardMonitoring()
            }
        )
    }

    private var clipboardDetailsTitle: String {
        switch controller.language {
        case .chinese:
            "筛选"
        case .english:
            "Filters"
        }
    }

    private var clipboardSearchPlaceholder: String {
        switch controller.language {
        case .chinese:
            "搜索剪贴板"
        case .english:
            "Search clipboard"
        }
    }

    private var clipboardRowHelp: String {
        switch controller.language {
        case .chinese:
            "单击预览，双击粘贴"
        case .english:
            "Click to preview, double-click to paste"
        }
    }

    private var hasActiveClipboardScope: Bool {
        controller.selectedClipboardFilter != .all || controller.selectedClipboardGroup != nil
    }

    private var selectedClipboardDetailItem: ResourceItem? {
        guard let selectedClipboardDetailID else {
            return nil
        }

        return controller.clipboardItems.first { $0.id == selectedClipboardDetailID }
    }

    private func clipboardMenuText(_ action: ClipboardContextAction) -> String {
        switch (controller.language, action) {
        case (.chinese, .details):
            "查看详情"
        case (.english, .details):
            "Details"
        case (.chinese, .copy):
            "复制"
        case (.english, .copy):
            "Copy"
        case (.chinese, .addTitle):
            "添加标题"
        case (.english, .addTitle):
            "Add Title"
        case (.chinese, .editText):
            "编辑文本"
        case (.english, .editText):
            "Edit Text"
        case (.chinese, .saveTo):
            "保存至"
        case (.english, .saveTo):
            "Save To"
        case (.chinese, .archive):
            "归档"
        case (.english, .archive):
            "Archive"
        case (.chinese, .archiveTo):
            "归档到"
        case (.english, .archiveTo):
            "Archive To"
        case (.chinese, .defaultArchive):
            "默认归档"
        case (.english, .defaultArchive):
            "Default Archive"
        case (.chinese, .newArchiveGroup):
            "新建归档组..."
        case (.english, .newArchiveGroup):
            "New Archive Group..."
        case (.chinese, .share):
            "分享"
        case (.english, .share):
            "Share"
        }
    }

    private func commandShortcut(for tab: CompanionTab) -> String? {
        switch tab {
        case .today:
            "⌘ Q"
        case .library:
            "⌘ W"
        case .clipboard:
            "⌘ E"
        case .api:
            nil
        }
    }

    private func restoreVisibleClipboardItem(at shortcutNumber: Int) {
        guard let item = visibleClipboardShortcutItem(at: shortcutNumber) else {
            _ = controller.restoreVisibleClipboardItemFromShortcut(at: shortcutNumber)
            return
        }

        selectClipboardItem(item, opensDetail: false)
        controller.restoreClipboardItemFromQuickAction(item)
    }

    private func clipboardShortcutNumber(for item: ResourceItem) -> Int? {
        guard isCommandQuickSelectActive,
              controller.activeTab == .clipboard,
              let index = visibleClipboardShortcutIDs.firstIndex(of: item.id),
              index < 9
        else {
            return nil
        }

        return index + 1
    }

    private func visibleClipboardShortcutItem(at shortcutNumber: Int) -> ResourceItem? {
        let index = shortcutNumber - 1
        guard visibleClipboardShortcutIDs.indices.contains(index) else {
            return nil
        }

        let id = visibleClipboardShortcutIDs[index]
        return controller.clipboardItems.first { $0.id == id }
    }

    private func updateVisibleClipboardShortcutRows(_ rows: [ClipboardVisibleRow], viewportHeight: CGFloat) {
        guard viewportHeight > 0 else {
            return
        }

        let visibleIDs = rows
            .filter { $0.maxY > 0 && $0.minY < viewportHeight }
            .sorted { lhs, rhs in
                if abs(lhs.minY - rhs.minY) > 0.5 {
                    return lhs.minY < rhs.minY
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .reduce(into: [UUID]()) { result, row in
                if !result.contains(row.id) {
                    result.append(row.id)
                }
            }

        let shortcutIDs = Array(visibleIDs.prefix(9))
        guard shortcutIDs != visibleClipboardShortcutIDs else {
            return
        }

        visibleClipboardShortcutIDs = shortcutIDs
        let shortcutItems = shortcutIDs.compactMap { id in
            controller.clipboardItems.first { $0.id == id }
        }
        controller.updateVisibleClipboardShortcutItems(shortcutItems)
    }

    private func clipboardRowVisibilityReader(id: UUID) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(clipboardListCoordinateSpaceName))
            Color.clear.preference(
                key: ClipboardVisibleRowsPreferenceKey.self,
                value: [
                    ClipboardVisibleRow(
                        id: id,
                        minY: frame.minY,
                        maxY: frame.maxY
                    )
                ]
            )
        }
    }

    private func selectClipboardItem(_ item: ResourceItem, opensDetail: Bool) {
        selectedClipboardDetailID = item.id
        clipboardScrollTargetID = item.id

        if opensDetail {
            controller.showClipboardDetail(item)
        }
    }

    private func promptClipboardTitle(_ item: ResourceItem) {
        let alert = NSAlert()
        alert.messageText = controller.language == .chinese ? "添加标题" : "Add Title"
        alert.informativeText = controller.language == .chinese ? "为这条剪贴板内容设置一个更容易识别的标题。" : "Set a clearer title for this clipboard item."
        alert.addButton(withTitle: controller.language == .chinese ? "保存" : "Save")
        alert.addButton(withTitle: controller.language == .chinese ? "取消" : "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 28))
        field.stringValue = item.title
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        controller.updateClipboardTitle(item, title: field.stringValue)
    }

    private func promptClipboardContent(_ item: ResourceItem) {
        let alert = NSAlert()
        alert.messageText = controller.language == .chinese ? "编辑文本" : "Edit Text"
        alert.informativeText = controller.language == .chinese ? "修改会直接更新这条剪贴板记录。" : "Changes update this clipboard item directly."
        alert.addButton(withTitle: controller.language == .chinese ? "保存" : "Save")
        alert.addButton(withTitle: controller.language == .chinese ? "取消" : "Cancel")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 340, height: 180))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 340, height: 180))
        textView.string = item.content
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        scrollView.documentView = textView
        alert.accessoryView = scrollView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        controller.updateClipboardContent(item, content: textView.string)
    }

    private func promptClipboardArchiveGroup(_ item: ResourceItem) {
        let alert = NSAlert()
        alert.messageText = controller.language == .chinese ? "新建归档组" : "New Archive Group"
        alert.informativeText = controller.language == .chinese
            ? "输入一个简短的组名，这条剪贴板会被标记为归档并移动到该组。"
            : "Enter a short group name. This clipboard item will be marked archived and moved there."
        alert.addButton(withTitle: controller.language == .chinese ? "归档" : "Archive")
        alert.addButton(withTitle: controller.language == .chinese ? "取消" : "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 28))
        field.stringValue = item.group == "Archive" ? "" : item.group
        field.placeholderString = controller.language == .chinese ? "例如：项目草稿" : "e.g. Project Drafts"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        controller.archiveClipboardItem(item, group: field.stringValue)
    }

    private func clipboardArchiveGroups(excluding excludedGroup: String) -> [String] {
        controller.clipboardArchiveGroups(excluding: excludedGroup)
    }

    private func moveClipboardPage(_ direction: PanelPageDirection) {
        guard controller.activeTab == .clipboard,
              !controller.clipboardItems.isEmpty
        else {
            return
        }

        let currentIndex = selectedClipboardDetailID.flatMap { selectedID in
            controller.clipboardItems.firstIndex { $0.id == selectedID }
        } ?? (direction == .down ? -1 : controller.clipboardItems.count)
        let step = controller.panelDensity == .compact ? 6 : 5
        let nextIndex: Int

        switch direction {
        case .up:
            nextIndex = max(0, currentIndex - step)
        case .down:
            nextIndex = min(controller.clipboardItems.count - 1, currentIndex + step)
        }

        let item = controller.clipboardItems[nextIndex]
        selectedClipboardDetailID = item.id
        clipboardScrollTargetID = item.id
    }

    private func moveClipboardSelection(_ direction: ClipboardSelectionDirection) {
        guard controller.activeTab == .clipboard,
              !controller.clipboardItems.isEmpty
        else {
            return
        }

        let currentIndex = selectedClipboardDetailID.flatMap { selectedID in
            controller.clipboardItems.firstIndex { $0.id == selectedID }
        }
        let nextIndex: Int

        switch direction {
        case .up:
            nextIndex = max(0, (currentIndex ?? controller.clipboardItems.count) - 1)
        case .down:
            nextIndex = min(controller.clipboardItems.count - 1, (currentIndex ?? -1) + 1)
        }

        let item = controller.clipboardItems[nextIndex]
        selectedClipboardDetailID = item.id
        clipboardScrollTargetID = item.id
    }

    private func previewSelectedClipboardItem() {
        guard controller.activeTab == .clipboard,
              let item = currentOrFirstClipboardItem()
        else {
            return
        }

        selectClipboardItem(item, opensDetail: true)
    }

    private func useSelectedClipboardItem() {
        guard controller.activeTab == .clipboard,
              let item = currentOrFirstClipboardItem()
        else {
            return
        }

        selectClipboardItem(item, opensDetail: false)
        controller.restoreClipboardItemFromQuickAction(item)
    }

    private func currentOrFirstClipboardItem() -> ResourceItem? {
        if let selectedClipboardDetailID,
           let selectedItem = controller.clipboardItems.first(where: { $0.id == selectedClipboardDetailID }) {
            return selectedItem
        }

        return controller.clipboardItems.first
    }

    private func toggleClipboardFiltersFromShortcut() {
        guard controller.activeTab == .clipboard else {
            return
        }

        isClipboardDetailsExpanded.toggle()
    }

    private func scheduleSearchRefresh() {
        deferredSearchRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            controller.refreshResources()
        }
        deferredSearchRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: workItem)
    }

    private func clearSearchText() {
        deferredSearchRefreshWorkItem?.cancel()
        deferredSearchRefreshWorkItem = nil
        guard !controller.searchText.isEmpty else {
            return
        }

        suppressNextSearchRefresh = true
        controller.searchText = ""
        controller.refreshResources()
    }

    private func focusSearchFromShortcut() {
        switch controller.activeTab {
        case .library:
            focusPanelSearch(.librarySearch)
        case .clipboard:
            focusPanelSearch(.clipboardSearch)
        case .today, .api:
            controller.setActiveTab(.clipboard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                focusPanelSearch(.clipboardSearch)
            }
        }
    }

    private func focusPanelSearch(_ field: PanelFocusField) {
        focusedPanelField = field
        DispatchQueue.main.async {
            focusedPanelField = field
        }
    }

    private func icon(for type: ResourceType) -> String {
        switch type {
        case .prompt:
            "text.quote"
        case .skill:
            "wand.and.sparkles"
        case .mcp:
            "server.rack"
        case .knowledge:
            "books.vertical"
        case .clipboard:
            "doc.on.clipboard"
        }
    }

    private func resetImportDraft() {
        importResourceType = .knowledge
        importPath = ""
        importGroup = ResourceType.knowledge.defaultGroup
        importTags = ""
    }
}

