import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct UsageGuidePanelView: View {
    var language: AppLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                guideSection(title: localized("首次设置", "First Run"), icon: "checklist") {
                    guideRow(
                        title: localized("1. 打开设置", "1. Open Settings"),
                        detail: localized(
                            "确认 API 在线，按需要打开开机启动和剪贴板监听。",
                            "Confirm the API is online, then enable launch at login and clipboard monitoring if needed."
                        )
                    )
                    guideRow(
                        title: localized("2. 添加资源", "2. Add Resource"),
                        detail: localized(
                            "在资源管理里添加第一个 Prompt、Skill 或 MCP 引用。",
                            "Add the first prompt, skill, or MCP reference in Resource Manager."
                        )
                    )
                    guideRow(
                        title: localized("3. 接入 Agent", "3. Connect Agent"),
                        detail: localized(
                            "只安装 DingDong MCP，让 Agent 从 DingDong 读取摘要并按需加载全文。",
                            "Install only the DingDong MCP so agents read summaries from DingDong and load full content only when needed."
                        )
                    )
                    guideRow(
                        title: localized("4. 测试提醒", "4. Test Notify"),
                        detail: localized(
                            "让 Agent 在整项任务结束、阻塞或等待你决策时调用一次 dingdong_notify。",
                            "Have the agent call dingdong_notify once when the whole task completes, blocks, or waits for your decision."
                        )
                    )
                }

                guideSection(title: localized("入口", "Entry"), icon: "menubar.rectangle") {
                    guideRow(
                        title: localized("左键图标", "Left-click icon"),
                        detail: localized("打开或关闭主面板。", "Open or close the main panel.")
                    )
                    guideRow(
                        title: localized("右键图标", "Right-click icon"),
                        detail: localized(
                            "打开面板、打开剪贴板、开关监听、查看使用说明、设置和退出。",
                            "Open the panel, clipboard, monitoring toggle, guide, settings, and quit."
                        )
                    )
                }

                guideSection(title: localized("主面板", "Panel"), icon: "rectangle.3.group") {
                    guideRow(
                        title: localized("今日", "Today"),
                        detail: localized("查看当前状态、最近事件、会话和交接提醒。", "View status, recent events, sessions, and handoffs.")
                    )
                    guideRow(
                        title: localized("资源库", "Library"),
                        detail: localized(
                            "保存常用 Prompt、Skill、MCP、知识路径，供本机 Agent 复用。",
                            "Store prompts, skills, MCP references, and knowledge paths for local agents."
                        )
                    )
                    guideRow(
                        title: localized("剪贴板", "Clipboard"),
                        detail: localized(
                            "记录文本、链接、命令、代码、文件和图片文件。单击预览，双击粘贴。",
                            "Record text, links, commands, code, files, and image files. Click to preview, double-click to paste."
                        )
                    )
                }

                guideSection(title: localized("剪贴板快捷键", "Clipboard Shortcuts"), icon: "keyboard") {
                    guideRow(title: "⌘⇧V", detail: localized("打开或关闭剪贴板面板。", "Open or close the clipboard panel."))
                    guideRow(
                        title: "⌘1 - ⌘9",
                        detail: localized("粘贴当前可见列表里的第 1 到第 9 条。", "Paste item 1-9 from the currently visible list.")
                    )
                    guideRow(
                        title: "⌘F / ⌘Q / ⌘W / ⌘E",
                        detail: localized(
                            "搜索，或切换今日、资源库、剪贴板。输入框聚焦时保留系统输入行为。",
                            "Search, or switch Today, Library, Clipboard. Text fields keep normal input behavior."
                        )
                    )
                    guideRow(title: "⌘A / ⌘D", detail: localized("剪贴板列表上翻、下翻。", "Page up or down in the clipboard list."))
                }

                guideSection(title: localized("权限", "Permissions"), icon: "hand.raised") {
                    guideRow(
                        title: localized("辅助功能", "Accessibility"),
                        detail: localized(
                            "只用于把选中的剪贴板内容粘回原来的输入框。授权后请重启 DingDong。",
                            "Only used to paste the selected item back to the previous input field. Restart DingDong after granting access."
                        )
                    )
                }

                guideSection(title: localized("资源库", "Library"), icon: "square.stack.3d.up") {
                    guideRow(
                        title: localized("保存内容", "Saved Content"),
                        detail: localized(
                            "用于沉淀常用 Prompt、Skill、MCP 配置和项目知识，不会默认替你创建一堆分组。",
                            "Use it for prompts, skills, MCP config, and project knowledge. DingDong does not create default groups for you."
                        )
                    )
                    guideRow(
                        title: localized("剪贴板归档", "Clipboard Archive"),
                        detail: localized(
                            "右键剪贴板条目可以归档到已有组或新建组；只有你归档过的组会出现在菜单里。",
                            "Right-click a clipboard item to archive it to an existing or new group. Only groups you used for archive appear in the menu."
                        )
                    )
                }

                guideSection(title: localized("Agent 接口", "Agent API"), icon: "point.3.connected.trianglepath.dotted") {
                    guideRow(
                        title: "127.0.0.1:8765+",
                        detail: localized(
                            "本地 loopback API。默认 8765；如果被占用，会自动使用下一个可用端口。",
                            "Local loopback API. Defaults to 8765; if occupied, DingDong uses the next available port."
                        )
                    )
                    guideRow(
                        title: "/agent/startup / /agent/context",
                        detail: localized(
                            "让 Agent 获取任务相关资源和上下文。剪贴板内容默认不暴露。",
                            "Let agents fetch task-scoped resources and context. Clipboard content is hidden by default."
                        )
                    )
                    guideRow(
                        title: "/ding",
                        detail: localized(
                            "Agent 只在整项用户任务最终完成、阻塞或等待你决策时调用一次，不用于阶段结束。",
                            "Agents call this once only when the whole user-visible task is final, blocked, or waiting for your decision, not after intermediate steps."
                        )
                    )
                }

                guideSection(title: localized("MCP 接入", "MCP Setup"), icon: "terminal") {
                    guideRow(
                        title: localized("接入方式", "How it works"),
                        detail: localized(
                            "Codex、Claude Code 等 Agent 只注册 DingDong MCP；Prompt、Skill、MCP 引用仍由 DingDong 统一管理。",
                            "Codex, Claude Code, and other agents only register the DingDong MCP. Prompts, skills, and MCP references stay managed in DingDong."
                        )
                    )
                    guideRow(
                        title: localized("内置 MCP", "Bridge binary"),
                        detail: "/Applications/DingDong.app/Contents/MacOS/dingdong-mcp"
                    )
                    guideRow(
                        title: localized("Codex 配置", "Codex config"),
                        detail: "[mcp_servers.dingdong] command = \"/Applications/DingDong.app/Contents/MacOS/dingdong-mcp\""
                    )
                    guideRow(
                        title: localized("Claude Code 配置", "Claude Code config"),
                        detail: "{\"mcpServers\":{\"dingdong\":{\"command\":\"/Applications/DingDong.app/Contents/MacOS/dingdong-mcp\"}}}"
                    )
                    guideRow(
                        title: localized("任务开始", "Task start"),
                        detail: localized(
                            "调用 dingdong_bridge(task) 获取摘要；只有需要时再按 id 加载全文。",
                            "Call dingdong_bridge(task) for summaries; load full content by id only when needed."
                        )
                    )
                    guideRow(
                        title: localized("资源读取", "Asset loading"),
                        detail: "dingdong_search_assets / dingdong_get_asset / dingdong_load_skill"
                    )
                    guideRow(
                        title: localized("MCP 推荐", "MCP recommendation"),
                        detail: "dingdong_recommend_mcp / dingdong_install_native_mcp"
                    )
                    guideRow(
                        title: localized("任务结束", "Task end"),
                        detail: "dingdong_notify(message)"
                    )
                    guideRow(
                        title: localized("隐私", "Privacy"),
                        detail: localized(
                            "默认不读取剪贴板正文；只有你明确要求剪贴板相关任务时才取内容。",
                            "Clipboard body is hidden by default and only fetched when you explicitly ask for clipboard-aware work."
                        )
                    )
                }
            }
            .padding(18)
        }
        .frame(minWidth: 600, minHeight: 640)
        .foregroundStyle(PanelTheme.textPrimary)
        .background(PanelTheme.background)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(localized("使用说明", "User Guide"))
                    .font(.system(size: 22, weight: .semibold))
                Text(localized("DingDong 的入口、剪贴板、资源库和 Agent 接口说明。", "Entry points, clipboard, library, and agent API."))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.bottom, 2)
    }

    private func guideSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PanelTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .padding(14)
        .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(PanelTheme.border, lineWidth: 1))
    }

    private func guideRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.textPrimary)
                .frame(width: 118, alignment: .leading)
                .lineLimit(2)

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PanelTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}
