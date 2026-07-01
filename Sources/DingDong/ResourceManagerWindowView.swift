import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct ResourceManagerWindowView: View {
    @ObservedObject var controller: StatusController
    @State private var query = ""
    @State private var selectedType: ResourceType?
    @State private var selectedGroup: String?
    @State private var editingResourceID: UUID?
    @State private var draftType: ResourceType = .prompt
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var draftGroup = ResourceType.prompt.defaultGroup
    @State private var draftTags = ""
    @State private var draftPinned = false

    private var managedTypes: [ResourceType] {
        [.prompt, .skill, .mcp, .knowledge]
    }

    private var managedResources: [ResourceItem] {
        controller.resources.filter { managedTypes.contains($0.type) }
    }

    private var groups: [String] {
        var seen: Set<String> = []
        return managedResources.compactMap { item in
            let group = item.group.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !group.isEmpty else {
                return nil
            }

            let key = group.lowercased()
            guard !seen.contains(key) else {
                return nil
            }

            seen.insert(key)
            return group
        }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredResources: [ResourceItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return managedResources.filter { item in
            if let selectedType, item.type != selectedType {
                return false
            }

            if let selectedGroup, item.group.localizedCaseInsensitiveCompare(selectedGroup) != .orderedSame {
                return false
            }

            guard !needle.isEmpty else {
                return true
            }

            return item.title.localizedCaseInsensitiveContains(needle)
                || item.content.localizedCaseInsensitiveContains(needle)
                || item.group.localizedCaseInsensitiveContains(needle)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 960, minHeight: 640)
        .foregroundStyle(PanelTheme.textPrimary)
        .background(PanelTheme.background)
        .onAppear {
            controller.refreshResources()
            syncEditingTarget()
        }
        .onChange(of: controller.resourceManagerEditingResourceID) { _, _ in
            syncEditingTarget()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("资源管理", "Resources"))
                    .font(.system(size: 20, weight: .bold))
                Text(localized("Prompt、Skill、MCP 和知识路径", "Prompts, skills, MCP, and knowledge paths"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                sidebarButton(title: localized("全部", "All"), count: managedResources.count, isSelected: selectedType == nil && selectedGroup == nil) {
                    selectedType = nil
                    selectedGroup = nil
                }

                ForEach(managedTypes, id: \.self) { type in
                    sidebarButton(
                        title: type.displayTitle(language: controller.language),
                        count: managedResources.filter { $0.type == type }.count,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                        selectedGroup = nil
                    }
                }
            }

            if !groups.isEmpty {
                Text(localized("分组", "Groups"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PanelTheme.textTertiary)
                    .padding(.top, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(groups, id: \.self) { group in
                            sidebarButton(
                                title: group,
                                count: managedResources.filter { $0.group.localizedCaseInsensitiveCompare(group) == .orderedSame }.count,
                                isSelected: selectedGroup == group
                            ) {
                                selectedGroup = group
                                selectedType = nil
                            }
                        }
                    }
                }
            }

            Spacer()

            Button {
                startCreatingResource()
            } label: {
                Label(localized("新增资源", "New Resource"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SettingsChoiceButtonStyle(isSelected: true))
        }
        .padding(18)
        .frame(width: 236)
        .background(PanelTheme.surface.opacity(0.62))
    }

    private var content: some View {
        HStack(spacing: 0) {
            listPane

            Divider()

            editorPane
                .frame(width: 400)
        }
    }

    private var listPane: some View {
        VStack(spacing: 14) {
            searchField

            HStack(spacing: 8) {
                Text(localized("\(filteredResources.count) 个资源", "\(filteredResources.count) resources"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelTheme.textSecondary)
                Spacer()
                Button {
                    controller.refreshResources()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(localized("刷新", "Refresh"))
                .buttonStyle(ControlButtonStyle())
            }
            .padding(.horizontal, 18)

            ThinScrollableView(coordinateSpaceName: "dingdong.resource-manager.viewport") {
                LazyVStack(spacing: 8) {
                    if filteredResources.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredResources) { item in
                            managerRow(item)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PanelTheme.textSecondary)
            TextField("", text: $query, prompt: Text(localized("搜索资源", "Search resources")).foregroundStyle(PanelTheme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
            Button {
                query = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .opacity(query.isEmpty ? 0 : 1)
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(editingResourceID == nil ? localized("新增资源", "New Resource") : localized("编辑资源", "Edit Resource"))
                        .font(.system(size: 18, weight: .bold))
                    Text(localized("用于 Agent 复用的 Prompt、Skill、MCP 或知识路径", "Reusable prompts, skills, MCP references, or knowledge paths"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PanelTheme.textSecondary)
                }

                Spacer()

                Button {
                    clearDraft()
                } label: {
                    Image(systemName: "xmark")
                }
                .help(localized("清空", "Clear"))
                .buttonStyle(ControlButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("类型", "Type"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PanelTheme.textSecondary)

                HStack(spacing: 6) {
                    ForEach(managedTypes, id: \.self) { type in
                        Button {
                            draftType = type
                            if draftGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || managedTypes.map(\.defaultGroup).contains(draftGroup) {
                                draftGroup = type.defaultGroup
                            }
                        } label: {
                            Text(type.displayTitle(language: controller.language))
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: draftType == type))
                    }
                }
            }

            editorField(title: localized("标题", "Title")) {
                TextField("", text: $draftTitle, prompt: Text(localized("给资源一个清楚的名字", "Give this resource a clear name")).foregroundStyle(PanelTheme.textTertiary))
                    .textFieldStyle(.plain)
            }

            editorField(title: localized("分组", "Group")) {
                TextField("", text: $draftGroup, prompt: Text(draftType.defaultGroup).foregroundStyle(PanelTheme.textTertiary))
                    .textFieldStyle(.plain)
            }

            editorField(title: localized("标签", "Tags")) {
                TextField("", text: $draftTags, prompt: Text(localized("用逗号分隔", "Separate with commas")).foregroundStyle(PanelTheme.textTertiary))
                    .textFieldStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("内容", "Content"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PanelTheme.textSecondary)

                TextEditor(text: $draftContent)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 220)
                    .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
            }

            Toggle(isOn: $draftPinned) {
                Text(localized("置顶", "Pinned"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .toggleStyle(.switch)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    clearDraft()
                } label: {
                    Text(localized("取消", "Cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SettingsChoiceButtonStyle(isSelected: false))

                Button {
                    saveDraft()
                } label: {
                    Text(editingResourceID == nil ? localized("保存", "Save") : localized("更新", "Update"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SettingsChoiceButtonStyle(isSelected: true))
            }
        }
        .padding(18)
        .background(PanelTheme.surface.opacity(0.48))
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PanelTheme.textSecondary)

            content()
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PanelTheme.textTertiary)
            Text(localized("暂无资源", "No resources"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func managerRow(_ item: ResourceItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: item.type))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(item.pinned ? PanelTheme.warning : PanelTheme.accent)
                .frame(width: 28, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)

                Text(item.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .lineLimit(2)

                managerMetadataChips(for: item)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    controller.togglePinned(item)
                } label: {
                    Image(systemName: item.pinned ? "pin.fill" : "pin")
                }
                .instantHoverHelp(item.pinned ? localized("取消置顶", "Unpin") : localized("置顶", "Pin"))

                Button {
                    controller.copyResourceContent(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .instantHoverHelp(localized("复制内容", "Copy content"))

                Button {
                    populateDraft(with: item)
                } label: {
                    Image(systemName: "pencil")
                }
                .instantHoverHelp(localized("编辑", "Edit"))

                Button {
                    controller.deleteResource(item)
                } label: {
                    Image(systemName: "trash")
                }
                .instantHoverHelp(localized("删除", "Delete"))
            }
            .frame(width: 152, alignment: .trailing)
            .buttonStyle(ControlButtonStyle())
        }
        .padding(12)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func managerMetadataChips(for item: ResourceItem) -> some View {
        WrappingHStack(spacing: 6, rowSpacing: 6) {
            managerChip(
                item.type.displayTitle(language: controller.language),
                foreground: PanelTheme.textSecondary,
                background: PanelTheme.field
            )

            managerChip(
                item.group,
                foreground: PanelTheme.warning,
                background: PanelTheme.warning.opacity(0.12)
            )

            ForEach(cleanManagerTags(for: item).prefix(4), id: \.self) { tag in
                managerChip(
                    tag,
                    foreground: PanelTheme.accent,
                    background: PanelTheme.accent.opacity(0.10)
                )
            }
        }
    }

    private func managerChip(_ title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func cleanManagerTags(for item: ResourceItem) -> [String] {
        let hiddenTags: Set<String> = [
            "clipboard", "file", "file-url", "text", "from-clipboard", "default"
        ]
        var seen: Set<String> = []

        return item.tags.compactMap { rawTag in
            let tag = rawTag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            let key = tag.lowercased()

            guard tag.count > 1,
                  tag != "...",
                  tag != "…",
                  !hiddenTags.contains(key),
                  !key.hasPrefix("ext:"),
                  !key.hasPrefix("source:"),
                  !seen.contains(key)
            else {
                return nil
            }

            seen.insert(key)
            return tag
        }
    }

    private func sidebarButton(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isSelected ? PanelTheme.textOnAccent.opacity(0.18) : PanelTheme.field, in: Capsule())
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(SettingsChoiceButtonStyle(isSelected: isSelected))
    }

    private func icon(for type: ResourceType) -> String {
        switch type {
        case .prompt:
            "quote.bubble"
        case .skill:
            "wand.and.sparkles"
        case .mcp:
            "server.rack"
        case .knowledge:
            "folder"
        case .clipboard:
            "doc.on.clipboard"
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        controller.language == .chinese ? chinese : english
    }

    private func syncEditingTarget() {
        guard let id = controller.resourceManagerEditingResourceID,
              let item = managedResources.first(where: { $0.id == id })
        else {
            return
        }

        populateDraft(with: item)
    }

    private func startCreatingResource() {
        editingResourceID = nil
        draftType = selectedType ?? .prompt
        draftTitle = ""
        draftContent = ""
        draftGroup = selectedGroup ?? draftType.defaultGroup
        draftTags = ""
        draftPinned = false
    }

    private func populateDraft(with item: ResourceItem) {
        editingResourceID = item.id
        draftType = item.type
        draftTitle = item.title
        draftContent = item.content
        draftGroup = item.group
        draftTags = item.tags.joined(separator: ", ")
        draftPinned = item.pinned
    }

    private func clearDraft() {
        editingResourceID = nil
        draftType = selectedType ?? .prompt
        draftTitle = ""
        draftContent = ""
        draftGroup = selectedGroup ?? draftType.defaultGroup
        draftTags = ""
        draftPinned = false
    }

    private func saveDraft() {
        let didSave: Bool
        if let editingResourceID {
            didSave = controller.updateResource(
                id: editingResourceID,
                type: draftType,
                title: draftTitle,
                content: draftContent,
                group: draftGroup,
                tagsText: draftTags,
                pinned: draftPinned
            )
        } else {
            didSave = controller.addResource(
                type: draftType,
                title: draftTitle,
                content: draftContent,
                group: draftGroup,
                tagsText: draftTags,
                pinned: draftPinned
            )
        }

        if didSave {
            selectedType = draftType
            selectedGroup = nil
            query = draftTitle
            clearDraft()
        }
    }
}

