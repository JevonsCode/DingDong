import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

enum PanelMetrics {
    static let width: CGFloat = 390
    static let height: CGFloat = 760
    static let minHeight: CGFloat = 540
    static let maxHeight: CGFloat = 940
    static let detailWidth: CGFloat = 304
    static let detailHeight: CGFloat = 420
    static let detailGap: CGFloat = 10
}

enum PanelTheme {
    static let panelRadius: CGFloat = 18
    static let background = Color(red: 0.934, green: 0.944, blue: 0.946)
    static let surface = Color(red: 0.988, green: 0.989, blue: 0.986)
    static let surfaceSoft = Color(red: 0.955, green: 0.962, blue: 0.962)
    static let field = Color(red: 0.924, green: 0.929, blue: 0.925)
    static let border = Color(red: 0.40, green: 0.42, blue: 0.40).opacity(0.15)
    static let textPrimary = Color(red: 0.16, green: 0.17, blue: 0.18)
    static let textSecondary = Color(red: 0.40, green: 0.40, blue: 0.39)
    static let textTertiary = Color(red: 0.58, green: 0.57, blue: 0.54)
    static let textOnAccent = Color.white
    static let textOnWarm = Color(red: 0.33, green: 0.28, blue: 0.20)
    static let accent = Color(red: 0.31, green: 0.41, blue: 0.58)
    static let accentSoft = Color(red: 0.890, green: 0.915, blue: 0.955)
    static let success = Color(red: 0.38, green: 0.50, blue: 0.38)
    static let successSoft = Color(red: 0.900, green: 0.935, blue: 0.890)
    static let warning = Color(red: 0.58, green: 0.43, blue: 0.24)
    static let warningSoft = Color(red: 0.910, green: 0.875, blue: 0.795)
    static let danger = Color(red: 0.63, green: 0.34, blue: 0.30)
    static let dangerSoft = Color(red: 0.955, green: 0.885, blue: 0.865)

    static func panelBackground(opacity: Double) -> some View {
        let materialOpacity = min(0.80, max(0.52, opacity - 0.16))
        let colorOpacity = min(0.86, max(0.62, opacity * 0.82))

        return ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(materialOpacity)
            background.opacity(colorOpacity)
        }
    }
}

enum PanelFocusField: Hashable {
    case librarySearch
    case clipboardSearch
}

enum PanelPageDirection {
    case up
    case down
}

enum ClipboardSelectionDirection {
    case up
    case down
}

let clipboardListCoordinateSpaceName = "dingdong.clipboard-list.viewport"

struct ClipboardVisibleRow: Equatable {
    var id: UUID
    var minY: CGFloat
    var maxY: CGFloat
}

struct ClipboardVisibleRowsPreferenceKey: PreferenceKey {
    static let defaultValue: [ClipboardVisibleRow] = []

    static func reduce(value: inout [ClipboardVisibleRow], nextValue: () -> [ClipboardVisibleRow]) {
        value.append(contentsOf: nextValue())
    }
}

struct ThinScrollMetrics: Equatable {
    var minY: CGFloat = 0
    var height: CGFloat = 0
}

struct ThinScrollMetricsPreferenceKey: PreferenceKey {
    static let defaultValue = ThinScrollMetrics()

    static func reduce(value: inout ThinScrollMetrics, nextValue: () -> ThinScrollMetrics) {
        value = nextValue()
    }
}

struct ThinScrollableView<Content: View>: View {
    var coordinateSpaceName: String
    @ViewBuilder var content: () -> Content
    @State private var metrics = ThinScrollMetrics()

    var body: some View {
        GeometryReader { viewport in
            let viewportHeight = viewport.size.height

            ScrollView(showsIndicators: false) {
                content()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(metricsReader())
            }
            .coordinateSpace(name: coordinateSpaceName)
            .overlay(alignment: .trailing) {
                scrollIndicator(viewportHeight: viewportHeight)
            }
            .onPreferenceChange(ThinScrollMetricsPreferenceKey.self) { metrics in
                self.metrics = metrics
            }
        }
    }

    private func metricsReader() -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(coordinateSpaceName))
            Color.clear.preference(
                key: ThinScrollMetricsPreferenceKey.self,
                value: ThinScrollMetrics(minY: frame.minY, height: frame.height)
            )
        }
    }

    @ViewBuilder
    private func scrollIndicator(viewportHeight: CGFloat) -> some View {
        let contentHeight = metrics.height
        if viewportHeight > 0, contentHeight > viewportHeight + 1 {
            let trackInset: CGFloat = 12
            let trackHeight = max(1, viewportHeight - trackInset * 2)
            let thumbHeight = max(34, trackHeight * viewportHeight / contentHeight)
            let maxOffset = max(1, contentHeight - viewportHeight)
            let scrollOffset = min(max(0, -metrics.minY), maxOffset)
            let thumbY = trackInset + (trackHeight - thumbHeight) * scrollOffset / maxOffset

            Capsule()
                .fill(PanelTheme.textSecondary.opacity(0.50))
                .frame(width: 2, height: thumbHeight)
                .offset(y: thumbY)
                .frame(width: 2, height: viewportHeight, alignment: .top)
                .padding(.trailing, 3)
                .allowsHitTesting(false)
        }
    }
}

struct DingDongLoadingSpinner: View {
    var color: Color
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.18, to: 0.82)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
            )
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: 0.72).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

enum ClipboardContextAction {
    case details
    case copy
    case addTitle
    case editText
    case saveTo
    case archive
    case archiveTo
    case defaultArchive
    case newArchiveGroup
    case share
}

struct ClipboardFilterDropDelegate: DropDelegate {
    let target: ClipboardSmartFilter
    @Binding var draggingFilter: ClipboardSmartFilter?
    @Binding var hoverTarget: ClipboardSmartFilter?
    let move: (ClipboardSmartFilter, ClipboardSmartFilter) -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggingFilter, source != target, hoverTarget != target else {
            return
        }

        hoverTarget = target
        move(source, target)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingFilter = nil
        hoverTarget = nil
        return true
    }

    func dropExited(info: DropInfo) {
        if !info.hasItemsConforming(to: [UTType.text]) {
            draggingFilter = nil
            hoverTarget = nil
        }
    }
}

struct ClipboardGroupDropDelegate: DropDelegate {
    let target: String
    @Binding var draggingGroup: String?
    @Binding var hoverTarget: String?
    let move: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggingGroup, source != target, hoverTarget != target else {
            return
        }

        hoverTarget = target
        move(source, target)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingGroup = nil
        hoverTarget = nil
        return true
    }

    func dropExited(info: DropInfo) {
        if !info.hasItemsConforming(to: [UTType.text]) {
            draggingGroup = nil
            hoverTarget = nil
        }
    }
}

enum CompanionTab: CaseIterable {
    case today
    case library
    case clipboard
    case api

    static let mainPanelTabs: [CompanionTab] = [.today, .library, .clipboard]

    init?(apiValue: String) {
        switch apiValue.lowercased() {
        case "today", "home":
            self = .today
        case "library", "resources":
            self = .library
        case "clipboard":
            self = .clipboard
        case "api":
            self = .api
        default:
            return nil
        }
    }

    var apiValue: String {
        switch self {
        case .today:
            "today"
        case .library:
            "library"
        case .clipboard:
            "clipboard"
        case .api:
            "api"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .today:
            language.text(.today)
        case .library:
            language.text(.library)
        case .clipboard:
            language.text(.clipboard)
        case .api:
            language.text(.api)
        }
    }

    var icon: String {
        switch self {
        case .today:
            "sparkles"
        case .library:
            "square.stack.3d.up"
        case .clipboard:
            "doc.on.clipboard"
        case .api:
            "point.3.connected.trianglepath.dotted"
        }
    }
}

extension ResourceType {
    func displayTitle(language: AppLanguage) -> String {
        switch self {
        case .prompt:
            language.text(.prompts)
        case .skill:
            language.text(.skills)
        case .mcp:
            "MCP"
        case .knowledge:
            language.text(.knowledge)
        case .clipboard:
            language.text(.clipboard)
        }
    }
}

extension DingSound {
    static var primaryChoices: [DingSound] {
        [.default, .success, .system, .muted]
    }

    func displayTitle(language: AppLanguage) -> String {
        switch self {
        case .default:
            language.text(.soundDing)
        case .joy:
            language.text(.soundJoy)
        case .levelUp:
            language.text(.soundLevelUp)
        case .taDa:
            language.text(.soundTaDa)
        case .bubble:
            language.text(.soundBubble)
        case .coin:
            language.text(.soundCoin)
        case .fanfare:
            language.text(.soundFanfare)
        case .arcade:
            language.text(.soundArcade)
        case .bloom:
            language.text(.soundBloom)
        case .sunrise:
            language.text(.soundSunrise)
        case .popcorn:
            language.text(.soundPopcorn)
        case .glimmer:
            language.text(.soundGlimmer)
        case .rocket:
            language.text(.soundRocket)
        case .confetti:
            language.text(.soundConfetti)
        case .marimba:
            language.text(.soundMarimba)
        case .candy:
            language.text(.soundCandy)
        case .sparkle:
            language.text(.soundSparkle)
        case .success:
            language.text(.soundSuccess)
        case .celebrate:
            language.text(.soundCelebrate)
        case .random:
            language.text(.soundRandom)
        case .custom:
            language.text(.customSound)
        case .system:
            language.text(.soundSystem)
        case .muted:
            language.text(.soundMuted)
        }
    }

    var icon: String {
        switch self {
        case .joy:
            "sun.max"
        case .levelUp:
            "arrow.up.forward.circle"
        case .taDa:
            "party.popper"
        case .bubble:
            "circle.grid.2x2"
        case .coin:
            "centsign.circle"
        case .fanfare:
            "music.quarternote.3"
        case .arcade:
            "gamecontroller"
        case .bloom:
            "camera.macro"
        case .sunrise:
            "sunrise"
        case .popcorn:
            "popcorn"
        case .glimmer:
            "sparkle.magnifyingglass"
        case .rocket:
            "paperplane"
        case .confetti:
            "sparkles"
        case .marimba:
            "music.note.list"
        case .candy:
            "heart"
        case .sparkle:
            "sparkles"
        case .success:
            "checkmark.seal"
        case .celebrate:
            "party.popper"
        case .random:
            "shuffle"
        case .default:
            "bell"
        case .custom:
            "music.note"
        case .system:
            "speaker.wave.2"
        case .muted:
            "speaker.slash"
        }
    }
}

struct TabButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .frame(height: 34)
            .background(isSelected ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct FilterButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isSelected ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(isSelected ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(PanelTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct CompactFilterButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isSelected ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(isSelected ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(PanelTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SettingsChoiceButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(isSelected ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct ControlButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(isProminent ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isProminent ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

struct RowIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PanelTheme.textSecondary)
            .frame(width: 30, height: 30)
            .background(configuration.isPressed ? PanelTheme.field.opacity(0.72) : PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(PanelTheme.border, lineWidth: 1))
    }
}

struct InstantHoverHelpModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .background(HoverTooltipAnchor(title: title))
            .onDisappear {
                HoverTooltipWindow.shared.hide(title: title)
            }
    }
}

struct HoverTooltipAnchor: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> HoverTooltipTrackingView {
        let view = HoverTooltipTrackingView()
        view.title = title
        return view
    }

    func updateNSView(_ nsView: HoverTooltipTrackingView, context: Context) {
        nsView.title = title
    }
}

final class HoverTooltipTrackingView: NSView {
    var title = ""

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        guard let window else {
            HoverTooltipWindow.shared.show(title: title, anchorRect: nil)
            return
        }

        let localFrame = convert(bounds, to: nil)
        let screenFrame = window.convertToScreen(localFrame)
        HoverTooltipWindow.shared.show(title: title, anchorRect: screenFrame)
    }

    override func mouseExited(with event: NSEvent) {
        HoverTooltipWindow.shared.hide(title: title)
    }
}

@MainActor
final class HoverTooltipWindow {
    static let shared = HoverTooltipWindow()

    private var panel: NSPanel?
    private var currentTitle: String?

    func show(title: String, anchorRect: NSRect?) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        currentTitle = title
        let hostingView = NSHostingView(rootView: HoverTooltipContent(title: title))
        let fittingSize = hostingView.fittingSize
        let contentSize = NSSize(width: ceil(fittingSize.width), height: ceil(fittingSize.height))
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        let tooltipPanel = panel ?? makePanel(size: contentSize)
        panel = tooltipPanel
        tooltipPanel.contentView = hostingView
        tooltipPanel.setContentSize(contentSize)
        tooltipPanel.setFrameOrigin(origin(for: contentSize, anchorRect: anchorRect))

        if !tooltipPanel.isVisible {
            tooltipPanel.alphaValue = 0
            tooltipPanel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                tooltipPanel.animator().alphaValue = 1
            }
        } else {
            tooltipPanel.alphaValue = 1
        }
    }

    func hide(title: String? = nil) {
        guard title == nil || title == currentTitle else {
            return
        }

        currentTitle = nil
        panel?.orderOut(nil)
        panel?.alphaValue = 1
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        return panel
    }

    private func origin(for size: NSSize, anchorRect: NSRect?) -> NSPoint {
        let anchor = anchorRect ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let anchorCenterX = anchor.midX == 0 ? anchor.origin.x : anchor.midX
        let anchorBottomY = anchor.minY == 0 ? anchor.origin.y : anchor.minY
        let anchorTopY = anchor.maxY == 0 ? anchor.origin.y : anchor.maxY
        let screenFrame = NSScreen.screens
            .first { $0.frame.intersects(anchor) || $0.frame.contains(anchor.origin) }?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let gap: CGFloat = 0
        var x = anchorCenterX - size.width / 2
        var y = anchorBottomY - size.height - gap

        if y < screenFrame.minY + gap {
            y = anchorTopY + gap
        }

        x = min(max(x, screenFrame.minX + gap), screenFrame.maxX - size.width - gap)
        y = min(max(y, screenFrame.minY + gap), screenFrame.maxY - size.height - gap)
        return NSPoint(x: x, y: y)
    }
}

struct HoverTooltipContent: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(PanelTheme.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(PanelTheme.surface.opacity(0.98), in: Capsule())
            .overlay(Capsule().stroke(PanelTheme.border, lineWidth: 1))
            .padding(2)
    }
}

extension View {
    func instantHoverHelp(_ title: String) -> some View {
        modifier(InstantHoverHelpModifier(title: title))
    }
}

struct WrappingHStack: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(in: proposal.width ?? .greatestFiniteMagnitude, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangeSubviews(in: bounds.width, subviews: subviews)

        for item in arrangement.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private func arrangeSubviews(in availableWidth: CGFloat, subviews: Subviews) -> (items: [PlacedItem], size: CGSize) {
        let width = max(0, availableWidth.isFinite ? availableWidth : .greatestFiniteMagnitude)
        var items: [PlacedItem] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var originX = cursor.x == 0 ? 0 : cursor.x + spacing
            var nextX = originX + size.width

            if cursor.x > 0, nextX > width {
                maxWidth = max(maxWidth, cursor.x)
                cursor.x = 0
                cursor.y += rowHeight + rowSpacing
                rowHeight = 0
                originX = 0
                nextX = size.width
            }

            let origin = CGPoint(x: originX, y: cursor.y)
            items.append(PlacedItem(index: index, origin: origin, size: size))
            cursor.x = nextX
            rowHeight = max(rowHeight, size.height)
        }

        maxWidth = max(maxWidth, cursor.x)
        return (items, CGSize(width: min(maxWidth, width), height: cursor.y + rowHeight))
    }

    private struct PlacedItem {
        let index: Int
        let origin: CGPoint
        let size: CGSize
    }
}

struct SnippetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? PanelTheme.textPrimary : PanelTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(PanelTheme.border, lineWidth: 1))
    }
}

struct IconButtonStyle: ButtonStyle {
    var isProminent = false
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isProminent ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .frame(width: size, height: size)
            .background(isProminent ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelTheme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

struct LanguageButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? PanelTheme.textOnAccent : PanelTheme.textSecondary)
            .padding(.vertical, 6)
            .background(isSelected ? PanelTheme.accent : PanelTheme.surface, in: RoundedRectangle(cornerRadius: 7))
    }
}
