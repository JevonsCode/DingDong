import Foundation

enum AppLanguage: String, CaseIterable, Codable, Equatable {
    case english = "en"
    case chinese = "zh"

    var shortTitle: String {
        switch self {
        case .english:
            "EN"
        case .chinese:
            "中"
        }
    }

    var displayTitle: String {
        switch self {
        case .english:
            "English"
        case .chinese:
            "中文"
        }
    }

    func text(_ key: AppText) -> String {
        switch (self, key) {
        case (.english, .subtitle): "AI companion hub"
        case (.chinese, .subtitle): "AI 伴侣中心"
        case (.english, .refresh): "Refresh"
        case (.chinese, .refresh): "刷新"
        case (.english, .quit): "Quit DingDong"
        case (.chinese, .quit): "退出 DingDong"
        case (.english, .settings): "Settings"
        case (.chinese, .settings): "设置"
        case (.english, .general): "General"
        case (.chinese, .general): "通用"
        case (.english, .appearance): "Appearance"
        case (.chinese, .appearance): "外观"
        case (.english, .panelOpacity): "Background"
        case (.chinese, .panelOpacity): "背景透明度"
        case (.english, .defaultTab): "Default tab"
        case (.chinese, .defaultTab): "默认页面"
        case (.english, .listDensity): "List density"
        case (.chinese, .listDensity): "列表密度"
        case (.english, .loading): "Loading"
        case (.chinese, .loading): "加载中"
        case (.english, .today): "Today"
        case (.chinese, .today): "今日"
        case (.english, .library): "Library"
        case (.chinese, .library): "资源库"
        case (.english, .clipboard): "Clipboard"
        case (.chinese, .clipboard): "剪贴板"
        case (.english, .clipboardRetention): "Retention"
        case (.chinese, .clipboardRetention): "保留"
        case (.english, .clipboardRetentionDays): "Days"
        case (.chinese, .clipboardRetentionDays): "保存天数"
        case (.english, .clipboardRetentionLimit): "Limit"
        case (.chinese, .clipboardRetentionLimit): "条数上限"
        case (.english, .resources): "Resources"
        case (.chinese, .resources): "资源"
        case (.english, .prompts): "Prompts"
        case (.chinese, .prompts): "提示词"
        case (.english, .skills): "Skills"
        case (.chinese, .skills): "技能"
        case (.english, .api): "API"
        case (.chinese, .api): "API"
        case (.english, .recentAgents): "Recent agents"
        case (.chinese, .recentAgents): "最近 Agent"
        case (.english, .activeAgents): "Active agents"
        case (.chinese, .activeAgents): "活跃 Agent"
        case (.english, .noActiveAgents): "No active agents"
        case (.chinese, .noActiveAgents): "暂无活跃 Agent"
        case (.english, .agentLaunchpad): "Agent Launchpad"
        case (.chinese, .agentLaunchpad): "Agent 启动台"
        case (.english, .agentTask): "Task"
        case (.chinese, .agentTask): "任务"
        case (.english, .agentTaskPlaceholder): "Code review, release, research..."
        case (.chinese, .agentTaskPlaceholder): "代码审查、发布、研究..."
        case (.english, .copyPrepare): "Prepare"
        case (.chinese, .copyPrepare): "准备"
        case (.english, .copyPresence): "Presence"
        case (.chinese, .copyPresence): "状态"
        case (.english, .agentPrepareCommand): "Agent Prepare"
        case (.chinese, .agentPrepareCommand): "Agent 准备命令"
        case (.english, .agentPresenceCommand): "Agent Presence"
        case (.chinese, .agentPresenceCommand): "Agent 状态命令"
        case (.english, .agentMemoryCommand): "Agent Memory"
        case (.chinese, .agentMemoryCommand): "Agent 记忆命令"
        case (.english, .agentStartupCommand): "Agent Startup"
        case (.chinese, .agentStartupCommand): "Agent 启动命令"
        case (.english, .agentToolkitCommand): "Agent Toolkit"
        case (.chinese, .agentToolkitCommand): "Agent 工具包命令"
        case (.english, .agentWorkbench): "Agent Workbench"
        case (.chinese, .agentWorkbench): "Agent 工作台"
        case (.english, .agentWorkbenchCommand): "Agent Workbench"
        case (.chinese, .agentWorkbenchCommand): "Agent 工作台命令"
        case (.english, .activeSessions): "Active sessions"
        case (.chinese, .activeSessions): "活跃会话"
        case (.english, .noActiveSessions): "No active sessions"
        case (.chinese, .noActiveSessions): "暂无活跃会话"
        case (.english, .openSessionLibrary): "Open session library"
        case (.chinese, .openSessionLibrary): "打开会话库"
        case (.english, .copyWorkbench): "Workbench"
        case (.chinese, .copyWorkbench): "工作台"
        case (.english, .companionReadiness): "Companion readiness"
        case (.chinese, .companionReadiness): "伴侣就绪度"
        case (.english, .readyForAgents): "Ready for agents"
        case (.chinese, .readyForAgents): "已准备好服务 Agent"
        case (.english, .warmingUp): "Warming up"
        case (.chinese, .warmingUp): "正在准备"
        case (.english, .needsSetup): "Needs setup"
        case (.chinese, .needsSetup): "需要配置"
        case (.english, .startup): "Startup"
        case (.chinese, .startup): "启动"
        case (.english, .toolkit): "Toolkit"
        case (.chinese, .toolkit): "工具包"
        case (.english, .handoffInbox): "Handoff inbox"
        case (.chinese, .handoffInbox): "交接收件箱"
        case (.english, .agentMemory): "Agent memory"
        case (.chinese, .agentMemory): "Agent 记忆"
        case (.english, .noMemories): "No saved memories"
        case (.chinese, .noMemories): "暂无保存的记忆"
        case (.english, .copyMemory): "Copy memory command"
        case (.chinese, .copyMemory): "复制记忆命令"
        case (.english, .openMemoryLibrary): "Open memory library"
        case (.chinese, .openMemoryLibrary): "打开记忆库"
        case (.english, .noHandoffs): "No open handoffs"
        case (.chinese, .noHandoffs): "暂无待处理交接"
        case (.english, .openLibrary): "Open library"
        case (.chinese, .openLibrary): "打开资源库"
        case (.english, .pinned): "Pinned"
        case (.chinese, .pinned): "置顶"
        case (.english, .noPinnedResources): "No pinned resources"
        case (.chinese, .noPinnedResources): "暂无置顶资源"
        case (.english, .sharedAgentLibrary): "Shared agent library"
        case (.chinese, .sharedAgentLibrary): "共享 Agent 资源库"
        case (.english, .librarySubtitle): "Prompts, skills, MCP servers, local knowledge"
        case (.chinese, .librarySubtitle): "提示词、Skills、MCP、本地知识"
        case (.english, .importAction): "Import"
        case (.chinese, .importAction): "导入"
        case (.english, .close): "Close"
        case (.chinese, .close): "关闭"
        case (.english, .add): "Add"
        case (.chinese, .add): "新增"
        case (.english, .addResource): "Add resource"
        case (.chinese, .addResource): "新增资源"
        case (.english, .editResource): "Edit resource"
        case (.chinese, .editResource): "编辑资源"
        case (.english, .title): "Title"
        case (.chinese, .title): "标题"
        case (.english, .group): "Group"
        case (.chinese, .group): "分组"
        case (.english, .tagsPlaceholder): "Tags, comma separated"
        case (.chinese, .tagsPlaceholder): "标签，用逗号分隔"
        case (.english, .pin): "Pin"
        case (.chinese, .pin): "置顶"
        case (.english, .save): "Save"
        case (.chinese, .save): "保存"
        case (.english, .update): "Update"
        case (.chinese, .update): "更新"
        case (.english, .importFolder): "Import folder"
        case (.chinese, .importFolder): "导入文件夹"
        case (.english, .folderPath): "Folder path"
        case (.chinese, .folderPath): "文件夹路径"
        case (.english, .knowledge): "Knowledge"
        case (.chinese, .knowledge): "知识库"
        case (.english, .noIndexableFiles): "No indexable files found"
        case (.chinese, .noIndexableFiles): "没有可索引文件"
        case (.english, .copyFilePath): "Copy file path"
        case (.chinese, .copyFilePath): "复制文件路径"
        case (.english, .clipboardMonitor): "Clipboard monitor"
        case (.chinese, .clipboardMonitor): "剪贴板监控"
        case (.english, .clipboardWatching): "Watching text changes every 1.5s"
        case (.chinese, .clipboardWatching): "每 1.5 秒监听文本变化"
        case (.english, .clipboardManual): "Manual capture only"
        case (.chinese, .clipboardManual): "仅手动捕获"
        case (.english, .on): "On"
        case (.chinese, .on): "开"
        case (.english, .off): "Off"
        case (.chinese, .off): "关"
        case (.english, .capture): "Capture"
        case (.chinese, .capture): "捕获"
        case (.english, .openGroup): "Open Group"
        case (.chinese, .openGroup): "打开分组"
        case (.english, .clipboardEmpty): "Clipboard records will appear here"
        case (.chinese, .clipboardEmpty): "剪贴板记录会显示在这里"
        case (.english, .clipboardSnippets): "Snippets"
        case (.chinese, .clipboardSnippets): "片段"
        case (.english, .clipboardCopilot): "Clipboard Copilot"
        case (.chinese, .clipboardCopilot): "剪贴板 Copilot"
        case (.english, .clipboardCopilotReady): "Metadata-only context for local agents"
        case (.chinese, .clipboardCopilotReady): "给本地 Agent 使用的元数据上下文"
        case (.english, .clipboardCopilotEmpty): "Capture clipboard records to unlock agent actions"
        case (.chinese, .clipboardCopilotEmpty): "记录剪贴板后可生成 Agent 动作"
        case (.english, .useful): "Useful"
        case (.chinese, .useful): "可用"
        case (.english, .hiddenSensitive): "Hidden sensitive"
        case (.chinese, .hiddenSensitive): "隐藏敏感"
        case (.english, .copyInsights): "Insights"
        case (.chinese, .copyInsights): "洞察"
        case (.english, .copyDigest): "Digest"
        case (.chinese, .copyDigest): "摘要"
        case (.english, .focusCandidates): "Focus"
        case (.chinese, .focusCandidates): "聚焦"
        case (.english, .clipboardInsightsCommand): "Clipboard Insights"
        case (.chinese, .clipboardInsightsCommand): "剪贴板洞察命令"
        case (.english, .clipboardDigestCommand): "Clipboard Digest"
        case (.chinese, .clipboardDigestCommand): "剪贴板摘要命令"
        case (.english, .agentTemplates): "Agent templates"
        case (.chinese, .agentTemplates): "Agent 模板"
        case (.english, .endpoints): "Endpoints"
        case (.chinese, .endpoints): "接口"
        case (.english, .copyDingCurl): "Copy Ding Curl"
        case (.chinese, .copyDingCurl): "复制提醒命令"
        case (.english, .soundLab): "Alert sound"
        case (.chinese, .soundLab): "提醒声音"
        case (.english, .customSound): "Custom"
        case (.chinese, .customSound): "自定义"
        case (.english, .clearSound): "Clear"
        case (.chinese, .clearSound): "清除"
        case (.english, .copyTemplate): "Copy template"
        case (.chinese, .copyTemplate): "复制模板"
        case (.english, .test): "Test"
        case (.chinese, .test): "测试"
        case (.english, .ringing): "Ringing"
        case (.chinese, .ringing): "提醒中"
        case (.english, .ready): "Ready"
        case (.chinese, .ready): "就绪"
        case (.english, .searchPlaceholder): "Search prompts, skills, MCP, knowledge"
        case (.chinese, .searchPlaceholder): "搜索提示词、Skills、MCP、知识库"
        case (.english, .all): "All"
        case (.chinese, .all): "全部"
        case (.english, .noResources): "No resources"
        case (.chinese, .noResources): "暂无资源"
        case (.english, .noAgentEvents): "No agent events yet"
        case (.chinese, .noAgentEvents): "暂无 Agent 事件"
        case (.english, .scanKnowledge): "Scan knowledge"
        case (.chinese, .scanKnowledge): "扫描知识库"
        case (.english, .saveAsPrompt): "Save as prompt"
        case (.chinese, .saveAsPrompt): "保存为提示词"
        case (.english, .unpin): "Unpin"
        case (.chinese, .unpin): "取消置顶"
        case (.english, .copyContent): "Copy content"
        case (.chinese, .copyContent): "复制内容"
        case (.english, .copyResourceID): "Copy ID"
        case (.chinese, .copyResourceID): "复制 ID"
        case (.english, .restoreClipboard): "Restore clipboard"
        case (.chinese, .restoreClipboard): "恢复剪贴板"
        case (.english, .edit): "Edit"
        case (.chinese, .edit): "编辑"
        case (.english, .delete): "Delete"
        case (.chinese, .delete): "删除"
        case (.english, .apiLive): "Live"
        case (.chinese, .apiLive): "在线"
        case (.english, .apiDown): "Down"
        case (.chinese, .apiDown): "离线"
        case (.english, .waitingForAgent): "Waiting for an agent signal"
        case (.chinese, .waitingForAgent): "等待 Agent 信号"
        case (.english, .noTriggers): "No triggers yet"
        case (.chinese, .noTriggers): "暂无触发"
        case (.english, .language): "Language"
        case (.chinese, .language): "语言"
        case (.english, .total): "Total"
        case (.chinese, .total): "总数"
        case (.english, .command): "Command"
        case (.chinese, .command): "命令"
        case (.english, .code): "Code"
        case (.chinese, .code): "代码"
        case (.english, .path): "Path"
        case (.chinese, .path): "路径"
        case (.english, .email): "Email"
        case (.chinese, .email): "邮箱"
        case (.english, .sensitive): "Sensitive"
        case (.chinese, .sensitive): "敏感"
        case (.english, .handoffs): "Handoffs"
        case (.chinese, .handoffs): "交接"
        case (.english, .monitor): "Monitor"
        case (.chinese, .monitor): "监听"
        case (.english, .chime): "Chime"
        case (.chinese, .chime): "提示音"
        case (.english, .manualTest): "Manual test"
        case (.chinese, .manualTest): "手动测试"
        case (.english, .apiDing): "Ding"
        case (.chinese, .apiDing): "提醒"
        case (.english, .apiLibrary): "Library"
        case (.chinese, .apiLibrary): "资源库"
        case (.english, .apiGroups): "Groups"
        case (.chinese, .apiGroups): "分组"
        case (.english, .apiAdd): "Add"
        case (.chinese, .apiAdd): "新增"
        case (.english, .apiImport): "Import"
        case (.chinese, .apiImport): "导入"
        case (.english, .apiExport): "Export"
        case (.chinese, .apiExport): "导出"
        case (.english, .apiTemplates): "Templates"
        case (.chinese, .apiTemplates): "模板"
        case (.english, .apiCaps): "Caps"
        case (.chinese, .apiCaps): "能力"
        case (.english, .apiStatus): "Status"
        case (.chinese, .apiStatus): "状态"
        case (.english, .apiBrief): "Brief"
        case (.chinese, .apiBrief): "简报"
        case (.english, .apiPrepare): "Prepare"
        case (.chinese, .apiPrepare): "准备"
        case (.english, .apiRecommend): "Recommend"
        case (.chinese, .apiRecommend): "推荐"
        case (.english, .apiHandoff): "Handoff"
        case (.chinese, .apiHandoff): "交接"
        case (.english, .apiContext): "Context"
        case (.chinese, .apiContext): "上下文"
        case (.english, .apiPromote): "Promote"
        case (.chinese, .apiPromote): "提升"
        case (.english, .apiRestore): "Restore"
        case (.chinese, .apiRestore): "恢复"
        case (.english, .apiHistory): "History"
        case (.chinese, .apiHistory): "历史"
        case (.english, .apiInsights): "Insights"
        case (.chinese, .apiInsights): "洞察"
        case (.english, .apiSnippets): "Snippets"
        case (.chinese, .apiSnippets): "片段"
        case (.english, .apiEdit): "Edit"
        case (.chinese, .apiEdit): "编辑"
        case (.english, .soundDing): "Ding"
        case (.chinese, .soundDing): "叮咚"
        case (.english, .soundJoy): "Joy"
        case (.chinese, .soundJoy): "愉快"
        case (.english, .soundLevelUp): "Level Up"
        case (.chinese, .soundLevelUp): "升级"
        case (.english, .soundTaDa): "Ta-da"
        case (.chinese, .soundTaDa): "登场"
        case (.english, .soundBubble): "Bubble"
        case (.chinese, .soundBubble): "泡泡"
        case (.english, .soundCoin): "Coin"
        case (.chinese, .soundCoin): "金币"
        case (.english, .soundFanfare): "Fanfare"
        case (.chinese, .soundFanfare): "号角"
        case (.english, .soundArcade): "Arcade"
        case (.chinese, .soundArcade): "街机"
        case (.english, .soundBloom): "Bloom"
        case (.chinese, .soundBloom): "绽放"
        case (.english, .soundSunrise): "Sunrise"
        case (.chinese, .soundSunrise): "日出"
        case (.english, .soundPopcorn): "Popcorn"
        case (.chinese, .soundPopcorn): "爆米花"
        case (.english, .soundGlimmer): "Glimmer"
        case (.chinese, .soundGlimmer): "微光"
        case (.english, .soundRocket): "Rocket"
        case (.chinese, .soundRocket): "火箭"
        case (.english, .soundConfetti): "Confetti"
        case (.chinese, .soundConfetti): "彩纸"
        case (.english, .soundMarimba): "Marimba"
        case (.chinese, .soundMarimba): "木琴"
        case (.english, .soundCandy): "Candy"
        case (.chinese, .soundCandy): "糖果"
        case (.english, .soundSparkle): "Sparkle"
        case (.chinese, .soundSparkle): "闪光"
        case (.english, .soundSuccess): "Success"
        case (.chinese, .soundSuccess): "成功"
        case (.english, .soundCelebrate): "Celebrate"
        case (.chinese, .soundCelebrate): "庆祝"
        case (.english, .soundRandom): "Random"
        case (.chinese, .soundRandom): "随机"
        case (.english, .soundSystem): "System"
        case (.chinese, .soundSystem): "系统"
        case (.english, .soundMuted): "Muted"
        case (.chinese, .soundMuted): "静音"
        case (.english, .hotKeyInactive): "⌘⇧V inactive"
        case (.chinese, .hotKeyInactive): "⌘⇧V 未启用"
        case (.english, .hotKeyReady): "⌘⇧V ready"
        case (.chinese, .hotKeyReady): "⌘⇧V 就绪"
        case (.english, .hotKeyUnavailable): "⌘⇧V unavailable"
        case (.chinese, .hotKeyUnavailable): "⌘⇧V 被占用"
        }
    }

    func message(_ key: AppMessage, value: String = "", count: Int = 0, maxCharacters: Int = 0) -> String {
        switch (self, key) {
        case (.english, .apiListening): "API listening on 127.0.0.1:\(value)"
        case (.chinese, .apiListening): "API 正在监听 127.0.0.1:\(value)"
        case (.english, .apiFailed): "API failed: \(value)"
        case (.chinese, .apiFailed): "API 失败：\(value)"
        case (.english, .resourceLibraryUnavailable): "Resource library unavailable"
        case (.chinese, .resourceLibraryUnavailable): "资源库不可用"
        case (.english, .titleAndContentRequired): "Title and content are required"
        case (.chinese, .titleAndContentRequired): "标题和内容必填"
        case (.english, .savedResource): "Saved \(value)"
        case (.chinese, .savedResource): "已保存 \(value)"
        case (.english, .couldNotSaveResource): "Could not save resource"
        case (.chinese, .couldNotSaveResource): "无法保存资源"
        case (.english, .resourceNotFound): "Resource not found"
        case (.chinese, .resourceNotFound): "未找到资源"
        case (.english, .updatedResource): "Updated \(value)"
        case (.chinese, .updatedResource): "已更新 \(value)"
        case (.english, .couldNotUpdateResource): "Could not update resource"
        case (.chinese, .couldNotUpdateResource): "无法更新资源"
        case (.english, .clipboardHasNoText): "Clipboard has no text"
        case (.chinese, .clipboardHasNoText): "剪贴板没有文本"
        case (.english, .clipboardAlreadyCaptured): "Clipboard already captured"
        case (.chinese, .clipboardAlreadyCaptured): "剪贴板已记录"
        case (.english, .capturedClipboard): "Captured clipboard"
        case (.chinese, .capturedClipboard): "已捕获剪贴板"
        case (.english, .couldNotSaveClipboard): "Could not save clipboard"
        case (.chinese, .couldNotSaveClipboard): "无法保存剪贴板"
        case (.english, .contentTooLarge): "Content exceeds \(maxCharacters) characters"
        case (.chinese, .contentTooLarge): "内容超过 \(maxCharacters) 个字符"
        case (.english, .couldNotValidateContent): "Could not validate content"
        case (.chinese, .couldNotValidateContent): "内容校验失败"
        case (.english, .copied): "Copied \(value)"
        case (.chinese, .copied): "已复制 \(value)"
        case (.english, .restoredClipboard): "Restored \(value) to clipboard"
        case (.chinese, .restoredClipboard): "已恢复 \(value) 到剪贴板"
        case (.english, .savedAsPrompt): "Saved as prompt"
        case (.chinese, .savedAsPrompt): "已保存为提示词"
        case (.english, .couldNotSavePrompt): "Could not save prompt"
        case (.chinese, .couldNotSavePrompt): "无法保存提示词"
        case (.english, .pinnedResource): "Pinned \(value)"
        case (.chinese, .pinnedResource): "已置顶 \(value)"
        case (.english, .unpinnedResource): "Unpinned \(value)"
        case (.chinese, .unpinnedResource): "已取消置顶 \(value)"
        case (.english, .deletedResource): "Deleted \(value)"
        case (.chinese, .deletedResource): "已删除 \(value)"
        case (.english, .couldNotDeleteResource): "Could not delete resource"
        case (.chinese, .couldNotDeleteResource): "无法删除资源"
        case (.english, .clipboardImportUnsupported): "Clipboard import is not supported"
        case (.chinese, .clipboardImportUnsupported): "不支持导入剪贴板"
        case (.english, .importedResources): "Imported \(count) resources"
        case (.chinese, .importedResources): "已导入 \(count) 个资源"
        case (.english, .importPathNotDirectory): "Import path is not a directory"
        case (.chinese, .importPathNotDirectory): "导入路径不是文件夹"
        case (.english, .couldNotImportResources): "Could not import resources"
        case (.chinese, .couldNotImportResources): "无法导入资源"
        case (.english, .onlyKnowledgeScannable): "Only knowledge resources can be scanned"
        case (.chinese, .onlyKnowledgeScannable): "只有知识库资源可以扫描"
        case (.english, .scannedResource): "Scanned \(value)"
        case (.chinese, .scannedResource): "已扫描 \(value)"
        case (.english, .filesCount): "\(count) files"
        case (.chinese, .filesCount): "\(count) 个文件"
        case (.english, .filesShownMoreAvailable): "\(count) files shown, more available"
        case (.chinese, .filesShownMoreAvailable): "已显示 \(count) 个文件，还有更多"
        case (.english, .pathNotDirectory): "Path is not a directory"
        case (.chinese, .pathNotDirectory): "路径不是文件夹"
        case (.english, .knowledgePathUnavailable): "Knowledge path unavailable"
        case (.chinese, .knowledgePathUnavailable): "知识库路径不可用"
        case (.english, .couldNotScan): "Could not scan"
        case (.chinese, .couldNotScan): "无法扫描"
        case (.english, .knowledgeScanFailed): "Knowledge scan failed"
        case (.chinese, .knowledgeScanFailed): "知识库扫描失败"
        }
    }
}

enum AppText {
    case subtitle
    case refresh
    case quit
    case settings
    case general
    case appearance
    case panelOpacity
    case defaultTab
    case listDensity
    case loading
    case today
    case library
    case clipboard
    case clipboardRetention
    case clipboardRetentionDays
    case clipboardRetentionLimit
    case resources
    case prompts
    case skills
    case api
    case recentAgents
    case activeAgents
    case noActiveAgents
    case agentLaunchpad
    case agentTask
    case agentTaskPlaceholder
    case copyPrepare
    case copyPresence
    case agentPrepareCommand
    case agentPresenceCommand
    case agentMemoryCommand
    case agentStartupCommand
    case agentToolkitCommand
    case agentWorkbench
    case agentWorkbenchCommand
    case activeSessions
    case noActiveSessions
    case openSessionLibrary
    case copyWorkbench
    case companionReadiness
    case readyForAgents
    case warmingUp
    case needsSetup
    case startup
    case toolkit
    case handoffInbox
    case agentMemory
    case noMemories
    case copyMemory
    case openMemoryLibrary
    case noHandoffs
    case openLibrary
    case pinned
    case noPinnedResources
    case sharedAgentLibrary
    case librarySubtitle
    case importAction
    case close
    case add
    case addResource
    case editResource
    case title
    case group
    case tagsPlaceholder
    case pin
    case save
    case update
    case importFolder
    case folderPath
    case knowledge
    case noIndexableFiles
    case copyFilePath
    case clipboardMonitor
    case clipboardWatching
    case clipboardManual
    case on
    case off
    case capture
    case openGroup
    case clipboardEmpty
    case clipboardSnippets
    case clipboardCopilot
    case clipboardCopilotReady
    case clipboardCopilotEmpty
    case useful
    case hiddenSensitive
    case copyInsights
    case copyDigest
    case focusCandidates
    case clipboardInsightsCommand
    case clipboardDigestCommand
    case agentTemplates
    case endpoints
    case copyDingCurl
    case soundLab
    case customSound
    case clearSound
    case copyTemplate
    case test
    case ringing
    case ready
    case searchPlaceholder
    case all
    case noResources
    case noAgentEvents
    case scanKnowledge
    case saveAsPrompt
    case unpin
    case copyContent
    case copyResourceID
    case restoreClipboard
    case edit
    case delete
    case apiLive
    case apiDown
    case waitingForAgent
    case noTriggers
    case language
    case total
    case command
    case code
    case path
    case email
    case sensitive
    case handoffs
    case monitor
    case chime
    case manualTest
    case apiDing
    case apiLibrary
    case apiGroups
    case apiAdd
    case apiImport
    case apiExport
    case apiTemplates
    case apiCaps
    case apiStatus
    case apiBrief
    case apiPrepare
    case apiRecommend
    case apiHandoff
    case apiContext
    case apiPromote
    case apiRestore
    case apiHistory
    case apiInsights
    case apiSnippets
    case apiEdit
    case soundDing
    case soundJoy
    case soundLevelUp
    case soundTaDa
    case soundBubble
    case soundCoin
    case soundFanfare
    case soundArcade
    case soundBloom
    case soundSunrise
    case soundPopcorn
    case soundGlimmer
    case soundRocket
    case soundConfetti
    case soundMarimba
    case soundCandy
    case soundSparkle
    case soundSuccess
    case soundCelebrate
    case soundRandom
    case soundSystem
    case soundMuted
    case hotKeyInactive
    case hotKeyReady
    case hotKeyUnavailable
}

enum AppMessage {
    case apiListening
    case apiFailed
    case resourceLibraryUnavailable
    case titleAndContentRequired
    case savedResource
    case couldNotSaveResource
    case resourceNotFound
    case updatedResource
    case couldNotUpdateResource
    case clipboardHasNoText
    case clipboardAlreadyCaptured
    case capturedClipboard
    case couldNotSaveClipboard
    case contentTooLarge
    case couldNotValidateContent
    case copied
    case restoredClipboard
    case savedAsPrompt
    case couldNotSavePrompt
    case pinnedResource
    case unpinnedResource
    case deletedResource
    case couldNotDeleteResource
    case clipboardImportUnsupported
    case importedResources
    case importPathNotDirectory
    case couldNotImportResources
    case onlyKnowledgeScannable
    case scannedResource
    case filesCount
    case filesShownMoreAvailable
    case pathNotDirectory
    case knowledgePathUnavailable
    case couldNotScan
    case knowledgeScanFailed
}
