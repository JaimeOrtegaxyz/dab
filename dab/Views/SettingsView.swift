import SwiftUI
import Carbon
import AppKit
import UniformTypeIdentifiers

// MARK: - Themed dropdowns

/// The settings dropdowns whose option lists are drawn by dab (case-yellow
/// plate) instead of a system `NSMenu`, whose popup can't be themed.
private enum DropdownID: Hashable {
    case filterMode
    case presets
}

/// Each open chip publishes its on-screen frame up to the window root, where
/// the floating option plate is positioned — so it escapes the scroll clip and
/// sits above every sibling.
private struct DropdownAnchorKey: PreferenceKey {
    static let defaultValue: [DropdownID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [DropdownID: Anchor<CGRect>],
                       nextValue: () -> [DropdownID: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// One option in a themed dropdown list. Selected = live value → lcd-green fill
/// + check (the app's "green is the live value" grammar); hover = a lighter
/// green wash so the interaction colour stays consistent.
private struct DropdownRowView: View {
    let label: String
    let isSelected: Bool
    /// When set, a hover-revealed ✕ deletes this row (used for saved palettes).
    var onDelete: (() -> Void)? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label.lowercased())
                    .font(WatchFont.body(13, weight: .semibold))
                    .foregroundStyle(isSelected ? WatchTheme.lcdInk : WatchTheme.caseInk)
                Spacer(minLength: 8)
                if let onDelete, hovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(isSelected ? WatchTheme.lcdInk : WatchTheme.caseInk.opacity(0.7))
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverCursor(.pointingHand)
                    .help("delete this saved palette")
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(WatchTheme.lcdInk)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5).fill(fill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
        .onHover { hovering = $0 }
    }

    private var fill: Color {
        if isSelected { return WatchTheme.lcdGreen }
        if hovering { return WatchTheme.lcdGreen.opacity(0.3) }
        return .clear
    }
}

// MARK: - Palette reorder

/// Live reordering for the palette tile grid. `LazyVGrid` has no `onMove`, so we
/// drive the move from each tile's `dropEntered`: as the dragged swatch passes
/// over a target tile, it's spliced into that target's slot. The order is
/// persisted on drop (here for tile drops; the grid-level `onDrop` covers drops
/// that land in the gaps).
private struct PaletteReorderDropDelegate: DropDelegate {
    let target: PaletteSwatch
    @Binding var palette: [PaletteSwatch]
    @Binding var dragging: PaletteSwatch?
    let persist: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let dragging,
              dragging.id != target.id,
              let from = palette.firstIndex(where: { $0.id == dragging.id }),
              let to = palette.firstIndex(where: { $0.id == target.id })
        else { return }

        // remove-then-insert reproduces SwiftUI's move(fromOffsets:toOffset:)
        // result for both drag directions, with no index-shift bookkeeping.
        withAnimation(.easeInOut(duration: 0.18)) {
            let moved = palette.remove(at: from)
            palette.insert(moved, at: to)
        }
        // Persist per splice: .onDrag has no cancel callback, so a drag
        // released outside every drop target must never leave the visible
        // order diverged from AppSettings.
        persist()
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        persist()
        return true
    }
}

/// A single palette swatch card: the color, its order badge, the "bg" tag on
/// position 1, and a pencil affordance on hover so it's obvious that a click
/// opens the editor (drag reorders).
private struct PaletteTileView: View {
    let swatch: PaletteSwatch
    let position: Int          // 0-based
    let isSelected: Bool
    let height: CGFloat
    let onSelect: () -> Void
    /// Reported upward so the preview can wash out the cells this swatch
    /// does not own while it's hovered.
    var onHoverChange: (Bool) -> Void = { _ in }

    /// Loaded once; tinted at draw time as a template image.
    private static let pencilIcon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "pencil", withExtension: "svg"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        return img
    }()

    @State private var hovering = false

    private var isBackground: Bool { position == 0 }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                if swatch.isTransparent {
                    CheckerboardFill()
                } else {
                    Color(pixelColor: swatch.color)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .overlay(editHint)
            .overlay(alignment: .topLeading) {
                positionBadge.padding(4)
            }
            .overlay(alignment: .bottomTrailing) {
                if isBackground { backgroundTag.padding(4) }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(WatchTheme.caseYellow, lineWidth: isSelected ? 2 : 0)
                    .padding(-2)
            )
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        // No hover-scale: the swatches sit in a grid, and a growing tile reads
        // as jitter against the inked, static watch aesthetic. The dim + pencil
        // overlay carries the hover affordance instead.
        .onHover { inside in
            hovering = inside
            onHoverChange(inside)
        }
        .hoverCursor(.pointingHand)
        .help(isBackground
              ? "click to edit · drag to reorder · #1 paints the gaps in blobs mode"
              : "click to edit · drag to reorder")
    }

    /// Dim + centered pencil on hover. The yellow ring keeps the glyph legible
    /// on any swatch color, including a near-black ink swatch. Hidden while the
    /// editor is already open for this swatch.
    private var editHint: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.16))
            Circle()
                .fill(WatchTheme.caseInk)
                .frame(width: 26, height: 26)
                .overlay(pencilGlyph)
                .overlay(Circle().stroke(WatchTheme.caseYellow.opacity(0.9), lineWidth: 1))
        }
        .opacity(hovering && !isSelected ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .allowsHitTesting(false)
    }

    /// The bundled (heavier) pencil, tinted yellow; falls back to the SF Symbol
    /// if the resource is missing from the bundle.
    @ViewBuilder
    private var pencilGlyph: some View {
        if let icon = Self.pencilIcon {
            Image(nsImage: icon)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(WatchTheme.caseYellow)
        } else {
            Image(systemName: "pencil")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WatchTheme.caseYellow)
        }
    }

    /// 1-based order marker. Position 1 is inverted (yellow on ink) to pair with
    /// the "bg" tag and flag it as the Blobs-mode background grout.
    private var positionBadge: some View {
        Text("\(position + 1)")
            .font(WatchFont.body(9, weight: .heavy))
            .foregroundStyle(isBackground ? WatchTheme.caseInk : WatchTheme.caseYellow)
            .frame(width: 15, height: 15)
            .background(isBackground ? WatchTheme.caseYellow : WatchTheme.caseInk)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(WatchTheme.caseInk, lineWidth: isBackground ? 1 : 0)
            )
    }

    private var backgroundTag: some View {
        Text("bg")
            .font(WatchFont.body(8.5, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(WatchTheme.caseInk)
            .padding(.horizontal, 4)
            .frame(height: 14)
            .background(WatchTheme.caseYellow)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
    }
}

// MARK: - Mirror glyph

/// The mirror keys' pictogram: filled square = source half, hairline = the
/// mirror axis, hollow square = the reflected copy. Inherits its color from
/// the key's foreground style.
private struct MirrorGlyph: View {
    enum Kind { case off, forward, backward }
    let kind: Kind
    let vertical: Bool

    var body: some View {
        if vertical {
            VStack(spacing: 2) { elements }
        } else {
            HStack(spacing: 2) { elements }
        }
    }

    @ViewBuilder
    private var elements: some View {
        switch kind {
        case .off:
            filled
        case .forward:
            filled
            mirrorLine
            hollow
        case .backward:
            hollow
            mirrorLine
            filled
        }
    }

    private var filled: some View {
        RoundedRectangle(cornerRadius: 1)
            .frame(width: 6, height: 6)
    }

    private var hollow: some View {
        RoundedRectangle(cornerRadius: 1)
            .stroke(lineWidth: 1)
            .frame(width: 5, height: 5)
            .padding(0.5)
    }

    private var mirrorLine: some View {
        Rectangle()
            .frame(width: vertical ? 10 : 1, height: vertical ? 1 : 10)
            .opacity(0.55)
    }
}

// MARK: - Editable hex field

/// LCD-chip-styled hex input. Commits on Return via `PixelColor(hex:)`;
/// invalid input beeps and reverts. Re-syncs whenever the bound hex changes
/// (e.g. the color well moved).
private struct HexField: View {
    let hex: String
    /// Returns whether the submitted string parsed and was applied.
    let onCommit: (String) -> Bool

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(WatchFont.body(13, weight: .semibold))
            .foregroundStyle(WatchTheme.lcdInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(WatchTheme.lcdGreen)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            // Dashed ring = the watch is listening.
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(WatchTheme.caseInk,
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .padding(-2)
                    .opacity(focused ? 1 : 0)
            )
            .frame(width: 84)
            .focused($focused)
            .onAppear { text = hex.lowercased() }
            .onChange(of: hex) { _, newValue in
                text = newValue.lowercased()
            }
            .onSubmit {
                if onCommit(text) {
                    focused = false
                } else {
                    NSSound.beep()
                    text = hex.lowercased()
                }
            }
            .help("hex color — return to apply")
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("gridSize") private var gridSize: Int = 16
    @AppStorage("viewportSize") private var viewportSize: Double = 200.0
    @AppStorage("resizeStep") private var resizeStep: Double = 10.0
    @AppStorage("brightnessThreshold") private var brightnessThreshold: Double = 0.5
    @AppStorage("filterMode") private var filterModeRaw: String = FilterMode.colorMatch.rawValue
    @AppStorage("horizontalMirrorMode") private var horizontalMirrorModeRaw: String = AppSettings.shared.horizontalMirrorMode.rawValue
    @AppStorage("verticalMirrorMode") private var verticalMirrorModeRaw: String = AppSettings.shared.verticalMirrorMode.rawValue
    @AppStorage("defaultRenderMode") private var defaultRenderModeRaw: Int = RenderMode.squares.rawValue
    @AppStorage("filenameFormat") private var filenameFormat: String = "dab_{date}_{time}"
    @State private var savePathDisplay: String = ""
    @State private var isRecordingHotkey: Bool = false
    @State private var hotkeyKeyCode: UInt32 = AppSettings.shared.hotkeyKeyCode
    @State private var hotkeyModifiers: UInt32 = AppSettings.shared.hotkeyModifiers
    @State private var hotkeyDisplayString: String = AppSettings.shared.hotkeyDisplayString
    @State private var filenamePreview: String = ""
    @State private var palette: [PaletteSwatch] = PaletteSwatch.defaultPalette
    @State private var openAtLogin: Bool = LoginItemService.isEnabled
    @State private var selectedSwatchID: UUID? = nil
    @State private var draggingSwatch: PaletteSwatch? = nil
    @State private var hoveredSwatchIndex: Int? = nil
    @State private var keyMonitor: Any?
    @State private var openDropdown: DropdownID? = nil
    @State private var savedPalettes: [SavedPalette] = AppSettings.shared.savedPalettes
    @State private var isNamingPalette: Bool = false
    @State private var newPaletteName: String = ""
    @FocusState private var isFilenameFieldFocused: Bool
    @FocusState private var isPaletteNameFocused: Bool

    /// Scroll positions live outside @State so per-pixel scroll updates don't
    /// re-render the body; only the seam Bool flip does.
    private final class SeamTracker {
        var headerBottom: CGFloat = 0
        var sectionTop: CGFloat = 0
    }
    @State private var seamTracker = SeamTracker()
    @State private var showHeaderSeam = false

    /// Returns whether the new hotkey was successfully registered, so the
    /// recorder can revert to the previous binding on failure.
    var onHotkeyChanged: ((UInt32, UInt32) -> Bool)?

    private var filterMode: FilterMode {
        FilterMode(rawValue: filterModeRaw) ?? .colorMatch
    }

    private var defaultRenderModeBinding: Binding<RenderMode> {
        Binding(
            get: { RenderMode(rawValue: defaultRenderModeRaw) ?? .squares },
            set: { defaultRenderModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            // The preview pins to the top only while the sections that feed it
            // (picture controls + palette) are in view; the viewport section
            // pushes it away naturally.
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    VStack(alignment: .leading, spacing: 24) {
                        pictureControls
                        paletteSection
                    }
                    .padding(.horizontal, 24)
                    // 4pt of visual breathing room + 6pt hidden under the
                    // header's plate lip.
                    .padding(.top, 10)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.onChange(
                                of: proxy.frame(in: .named("settingsScroll")).minY,
                                initial: true
                            ) { _, y in
                                seamTracker.sectionTop = y
                                refreshHeaderSeam()
                            }
                        }
                    )
                } header: {
                    stickyPreviewHeader
                }

                VStack(alignment: .leading, spacing: 24) {
                    viewportSection
                    outputSection
                    systemSection
                    shortcutsSection
                    watchFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Tap empty space to dismiss the open color editor. Interactive
            // controls (tiles, sliders, the tray itself) consume their own taps,
            // so this only fires on the surrounding non-interactive area.
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedSwatchID != nil {
                    withAnimation(.easeOut(duration: 0.22)) { selectedSwatchID = nil }
                }
            }
        }
        .coordinateSpace(name: "settingsScroll")
        .background(WatchTheme.caseYellow)
        .tint(WatchTheme.caseInk)
        // Root-level fallback: a palette drag released over the pinned
        // preview, the presets row, or any other non-grid area still commits
        // and clears the drag state (the grid-level onDrop can't see those).
        .onDrop(of: [.text], isTargeted: nil) { _ in
            guard draggingSwatch != nil else { return false }
            draggingSwatch = nil
            savePalette()
            return true
        }
        .contentMargins(.bottom, 12, for: .scrollIndicators)
        .overlay(alignment: .top) {
            WatchTheme.caseYellow
                .frame(height: WatchMetrics.titleBarHeight)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
        }
        // Floating dropdown lists, drawn at the window root so they clear the
        // scroll clip and every sibling. The open chip reports its frame via
        // the anchor preference; a near-invisible backdrop catches outside taps.
        .overlayPreferenceValue(DropdownAnchorKey.self) { anchors in
            // Nothing layered over the scroll view unless a dropdown is open, so
            // the closed state can't intercept scrolling or taps.
            if openDropdown != nil {
                dropdownOverlay(anchors)
            }
        }
        .onAppear {
            savePathDisplay = AppSettings.shared.saveDirectory.path
            hotkeyKeyCode = AppSettings.shared.hotkeyKeyCode
            hotkeyModifiers = AppSettings.shared.hotkeyModifiers
            hotkeyDisplayString = AppSettings.shared.hotkeyDisplayString
            if FilterMode(rawValue: filterModeRaw) == nil {
                filterModeRaw = FilterMode.colorMatch.rawValue
            }
            palette = AppSettings.shared.palette
            savedPalettes = AppSettings.shared.savedPalettes
            openAtLogin = LoginItemService.isEnabled
            updateFilenamePreview()
        }
        .onChange(of: filenameFormat) { _, _ in
            updateFilenamePreview()
        }
        .onChange(of: gridSize) { _, _ in
            updateFilenamePreview()
        }
        .onDisappear {
            stopRecording()
        }
        .onTapGesture {
            isFilenameFieldFocused = false
        }
    }

    // MARK: - Header / Footer

    /// The pinned preview: opaque case plastic so scrolled content disappears
    /// beneath it cleanly.
    private var stickyPreviewHeader: some View {
        SettingsPreview(
            gridSize: gridSize,
            filterMode: filterMode,
            brightnessThreshold: Float(brightnessThreshold),
            palette: palette,
            horizontalMirrorMode: HorizontalMirrorMode(rawValue: horizontalMirrorModeRaw) ?? .none,
            verticalMirrorMode: VerticalMirrorMode(rawValue: verticalMirrorModeRaw) ?? .none,
            renderMode: defaultRenderModeBinding,
            highlightedPaletteIndex: hoveredSwatchIndex
        )
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchTheme.caseYellow)
        // Plate lip: an opaque overhang below the header that swallows the
        // top strokes and drop shadows of rows sliding underneath (clipping
        // exactly at the edge left them peeking). The seam line sits on the
        // lip's lower edge and fades in only while content is slid under.
        // The section's top padding accounts for the lip, so the resting
        // layout is unchanged.
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                WatchTheme.caseYellow
                Rectangle()
                    .fill(WatchTheme.caseInk.opacity(0.4))
                    .frame(height: 1)
                    .opacity(showHeaderSeam ? 1 : 0)
            }
            .frame(height: 6)
            .offset(y: 6)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onChange(
                    of: proxy.frame(in: .named("settingsScroll")).maxY,
                    initial: true
                ) { _, y in
                    seamTracker.headerBottom = y
                    refreshHeaderSeam()
                }
            }
        )
    }

    private func refreshHeaderSeam() {
        let slid = seamTracker.sectionTop < seamTracker.headerBottom - 0.5
        guard slid != showHeaderSeam else { return }
        withAnimation(.easeOut(duration: 0.15)) { showHeaderSeam = slid }
    }

    private var watchFooter: some View {
        VStack(spacing: 12) {
            BundleImage(name: "dab-face-regular", ext: "svg")
                .frame(width: 56, height: 56)
                .accessibilityLabel("dab face")
            VStack(spacing: 6) {
                Text("turning retina displays into potato displays")
                    .font(WatchFont.body(11, weight: .medium))
                    .foregroundStyle(WatchTheme.caseInk)
                    .multilineTextAlignment(.center)
                Text(authorAttribution)
                    .font(WatchFont.body(11, weight: .medium))
                    .foregroundStyle(WatchTheme.caseInk)
                    .multilineTextAlignment(.center)
                // build.sh stamps the real version into Info.plist; a literal
                // here would contradict every stamped build.
                Text("v" + ((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"))
                    .font(WatchFont.body(11, weight: .bold))
                    .foregroundStyle(WatchTheme.caseInk.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }

    private var authorAttribution: AttributedString {
        var attr = AttributedString("hocus-pocused into reality by Jaime Ortega")
        if let range = attr.range(of: "Jaime Ortega") {
            attr[range].link = URL(string: "https://www.twitter.com/JaimeOrtega")
            attr[range].underlineStyle = .single
            attr[range].font = .custom("Inconsolata", size: 11).weight(.bold)
            attr[range].foregroundColor = WatchTheme.caseInk
        }
        return attr
    }

    // MARK: - Picture controls (everything the pinned preview reacts to)

    @ViewBuilder
    private var pictureControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            WatchSlider(
                label: "grid size",
                value: $gridSize,
                in: 4...32,
                defaultValue: 16,
                tickStride: 4,
                format: { "\($0)x\($0)" }
            )

            settingsRow("filter mode") {
                // 128 is snug on the widest label ("color match") — 160 left a
                // dead gap before the chevron.
                dropdownChip(id: .filterMode, label: filterMode.displayName, width: 128)
            }

            VStack(alignment: .leading, spacing: 4) {
                WatchSlider(
                    label: "brightness threshold",
                    value: $brightnessThreshold,
                    in: 0...1,
                    step: 0.01,
                    defaultValue: 0.5,
                    tickStride: 0.25,
                    centerTick: true,
                    coarseStep: 0.10,
                    format: { String(format: "%.2f", $0) }
                )
                // Actually inert, not just dimmed: when the current filter
                // ignores the threshold, block drag/keys too. WatchSlider dims
                // itself to 0.4 when disabled.
                .disabled(thresholdIsInert)

                Text(thresholdCaption)
                    .font(WatchFont.body(9, weight: .medium))
                    .foregroundStyle(WatchTheme.caseInk.opacity(0.6))
            }

            settingsRow("mirror") {
                // Pictographic keys instead of dropdowns: filled square =
                // source half, line = the mirror, hollow square = the copy.
                // The pinned preview demonstrates the rest on click.
                HStack(spacing: 12) {
                    HStack(spacing: 2) {
                        ForEach(HorizontalMirrorMode.allCases, id: \.self) { mode in
                            mirrorKey(
                                isSelected: horizontalMirrorModeRaw == mode.rawValue,
                                glyph: MirrorGlyph(kind: Self.glyphKind(horizontal: mode), vertical: false),
                                help: Self.mirrorHelp(horizontal: mode)
                            ) { horizontalMirrorModeRaw = mode.rawValue }
                        }
                    }
                    .animation(.easeOut(duration: 0.15), value: horizontalMirrorModeRaw)

                    HStack(spacing: 2) {
                        ForEach(VerticalMirrorMode.allCases, id: \.self) { mode in
                            mirrorKey(
                                isSelected: verticalMirrorModeRaw == mode.rawValue,
                                glyph: MirrorGlyph(kind: Self.glyphKind(vertical: mode), vertical: true),
                                help: Self.mirrorHelp(vertical: mode)
                            ) { verticalMirrorModeRaw = mode.rawValue }
                        }
                    }
                    .animation(.easeOut(duration: 0.15), value: verticalMirrorModeRaw)
                }
            }
        }
    }

    private func mirrorKey<G: View>(isSelected: Bool,
                                    glyph: G,
                                    help: String,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glyph.frame(width: 30, height: 22)
        }
        .buttonStyle(WatchKeyStyle(isSelected: isSelected))
        .help(help)
    }

    private static func glyphKind(horizontal mode: HorizontalMirrorMode) -> MirrorGlyph.Kind {
        switch mode {
        case .none: return .off
        case .leftToRight: return .forward
        case .rightToLeft: return .backward
        }
    }

    private static func glyphKind(vertical mode: VerticalMirrorMode) -> MirrorGlyph.Kind {
        switch mode {
        case .none: return .off
        case .topToBottom: return .forward
        case .bottomToTop: return .backward
        }
    }

    private static func mirrorHelp(horizontal mode: HorizontalMirrorMode) -> String {
        switch mode {
        case .none: return "no horizontal mirror"
        case .leftToRight: return "left half mirrors onto the right"
        case .rightToLeft: return "right half mirrors onto the left"
        }
    }

    private static func mirrorHelp(vertical mode: VerticalMirrorMode) -> String {
        switch mode {
        case .none: return "no vertical mirror"
        case .topToBottom: return "top half mirrors onto the bottom"
        case .bottomToTop: return "bottom half mirrors onto the top"
        }
    }

    private var thresholdIsInert: Bool {
        filterMode == .colorMatch && !palette.contains(where: \.isTransparent)
    }

    private var thresholdCaption: String {
        switch filterMode {
        case .colorMatch:
            return thresholdIsInert
                ? "no effect — no see-through swatch"
                : "shifts which brightness band goes see-through"
        case .threshold, .halftone:
            return "biases cells toward darker or brighter swatches"
        case .edgeDetect:
            return "edge sensitivity — higher catches more edges"
        }
    }

    // MARK: - Palette

    @ViewBuilder
    private var paletteSection: some View {
        sectionShell("palette") {
            HStack(spacing: 8) {
                if isNamingPalette {
                    paletteNameField
                } else {
                    presetsMenu
                    // Offer "save" only when the live palette is something the
                    // user built (matches no preset, built-in or saved yet).
                    if currentPresetName == nil {
                        saveChip
                    }
                }
                Spacer()
                LCDChip(width: 48, readout: true) {
                    Text("\(palette.count)/8")
                }
            }

            paletteOrderHint

            paletteTileGrid

            if let id = selectedSwatchID,
               let idx = palette.firstIndex(where: { $0.id == id }) {
                SilkscreenRule()
                paletteEditor(index: idx)
                    .transition(.lcdBoot)
            }
        }
        .animation(.easeOut(duration: 0.22), value: selectedSwatchID)
        .animation(.easeOut(duration: 0.22), value: palette.count)
        .animation(.easeOut(duration: 0.18), value: isNamingPalette)
    }

    /// Presets as a themed dropdown. The chip shows the active preset's name
    /// (falling back to the prompt once the palette is edited away from any
    /// preset), so a pick is legible, not just a colour change.
    private var presetsMenu: some View {
        dropdownChip(id: .presets, label: currentPresetName ?? "presets…", width: 150)
    }

    /// Bookmarks the live palette. Appears only for a custom palette; tapping it
    /// swaps the header into an inline name field (see `paletteNameField`).
    private var saveChip: some View {
        Button { beginSavePalette() } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .heavy))
                Text("save")
            }
        }
        .buttonStyle(LCDActionButtonStyle())
        .fixedSize()
        .help("save this palette to your presets")
    }

    /// The inline naming field the save chip expands into: an LCD-green input
    /// with the dashed "listening" ring, a commit ✓, Return to save, Esc to
    /// cancel. Replaces the presets chip while naming.
    private var paletteNameField: some View {
        HStack(spacing: 6) {
            TextField("name it…", text: $newPaletteName)
                .textFieldStyle(.plain)
                .font(WatchFont.body(13, weight: .semibold))
                .foregroundStyle(WatchTheme.lcdInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(width: 150)
                .background(WatchTheme.lcdGreen)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                // Dashed ring = the watch is listening.
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(WatchTheme.caseInk,
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .padding(-2)
                        .opacity(isPaletteNameFocused ? 1 : 0)
                )
                .focused($isPaletteNameFocused)
                .onSubmit { commitSavePalette() }
                .onExitCommand { cancelSavePalette() }

            Button { commitSavePalette() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(WatchTheme.caseInk)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverCursor(.pointingHand)
            .disabled(trimmedPaletteName.isEmpty)
            .opacity(trimmedPaletteName.isEmpty ? 0.35 : 1)
            .help("save")
        }
    }

    private var trimmedPaletteName: String {
        newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginSavePalette() {
        newPaletteName = ""
        withAnimation(.easeOut(duration: 0.18)) { isNamingPalette = true }
        // Focus after the field exists.
        DispatchQueue.main.async { isPaletteNameFocused = true }
    }

    private func cancelSavePalette() {
        isPaletteNameFocused = false
        withAnimation(.easeOut(duration: 0.18)) { isNamingPalette = false }
    }

    private func commitSavePalette() {
        let name = trimmedPaletteName
        guard !name.isEmpty else { NSSound.beep(); return }

        // Re-saving under an existing name overwrites that bookmark's colours
        // rather than making a confusing duplicate.
        if let idx = savedPalettes.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            savedPalettes[idx].swatches = palette
        } else {
            savedPalettes.append(SavedPalette(name: name, swatches: palette))
        }
        AppSettings.shared.savedPalettes = savedPalettes
        cancelSavePalette()
    }

    private func deleteSavedPalette(_ saved: SavedPalette) {
        savedPalettes.removeAll { $0.id == saved.id }
        AppSettings.shared.savedPalettes = savedPalettes
    }

    /// The preset whose colours (and see-through flags, in order) the current
    /// palette exactly matches — checks built-in presets first, then the user's
    /// saved palettes; `nil` once the palette is edited into something custom.
    /// Exact float compare is fine: palettes are applied verbatim.
    private var currentPresetName: String? {
        if let preset = PaletteSwatch.presets.first(where: { paletteMatches($0.swatches) }) {
            return preset.name
        }
        if let saved = savedPalettes.first(where: { paletteMatches($0.swatches) }) {
            return saved.name
        }
        return nil
    }

    private func paletteMatches(_ swatches: [PaletteSwatch]) -> Bool {
        swatches.count == palette.count &&
        zip(swatches, palette).allSatisfy {
            $0.color == $1.color && $0.isTransparent == $1.isTransparent
        }
    }

    // MARK: - Themed dropdown plumbing

    /// The closed chip — looks exactly like the old `lcdPicker` label, but taps
    /// toggle our own list instead of opening a system menu, and it reports its
    /// frame so the root can place that list beneath it.
    private func dropdownChip(id: DropdownID, label: String, width: CGFloat) -> some View {
        Button {
            toggleDropdown(id)
        } label: {
            Text(label.lowercased())
        }
        .buttonStyle(LCDPickerButtonStyle(width: width, isOpen: openDropdown == id))
        .fixedSize()
        .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) { [id: $0] }
    }

    private func toggleDropdown(_ id: DropdownID) {
        withAnimation(.easeOut(duration: 0.12)) {
            openDropdown = (openDropdown == id) ? nil : id
        }
    }

    private func closeDropdown() {
        withAnimation(.easeOut(duration: 0.12)) { openDropdown = nil }
    }

    /// Backdrop (outside-tap dismiss) + the option plate, positioned under the
    /// open chip via its reported anchor.
    private func dropdownOverlay(_ anchors: [DropdownID: Anchor<CGRect>]) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if openDropdown != nil {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { closeDropdown() }
                }
                if let id = openDropdown, let anchor = anchors[id] {
                    let rect = geo[anchor]
                    dropdownPanel(for: id)
                        .frame(width: rect.width)
                        .offset(x: rect.minX, y: rect.maxY + 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private func dropdownPanel(for id: DropdownID) -> some View {
        VStack(spacing: 0) {
            switch id {
            case .filterMode:
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    DropdownRowView(label: mode.displayName,
                                    isSelected: filterModeRaw == mode.rawValue) {
                        filterModeRaw = mode.rawValue
                        closeDropdown()
                    }
                }
            case .presets:
                ForEach(PaletteSwatch.presets) { preset in
                    DropdownRowView(label: preset.name,
                                    isSelected: preset.name == currentPresetName) {
                        setPalette(preset.swatches)
                        closeDropdown()
                    }
                }
                if !savedPalettes.isEmpty {
                    dropdownGroupLabel("yours")
                    ForEach(savedPalettes) { saved in
                        DropdownRowView(label: saved.name,
                                        isSelected: saved.name == currentPresetName,
                                        onDelete: { deleteSavedPalette(saved) }) {
                            setPalette(saved.swatches)
                            closeDropdown()
                        }
                    }
                }
            }
        }
        .padding(4)
        // Flat, defined by its ink border alone — no drop shadow, to match the
        // rest of the inked UI.
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(WatchTheme.caseYellow)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
        )
    }

    /// A silkscreen divider inside a dropdown list — separates the built-in
    /// presets from the user's saved palettes ("yours").
    private func dropdownGroupLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(WatchFont.body(8, weight: .heavy))
                .tracking(1)
                .foregroundStyle(WatchTheme.caseInk.opacity(0.5))
            Rectangle()
                .fill(WatchTheme.caseInk.opacity(0.18))
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 3)
    }

    /// One-line reminder that palette order is a creative lever: the lowest
    /// index (position 1) is the grout that fills the gaps in Blobs render mode.
    private var paletteOrderHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 8, weight: .heavy))
            Text("drag to reorder · #1 paints the gaps in blobs")
                .font(WatchFont.body(9, weight: .medium))
        }
        .foregroundStyle(WatchTheme.caseInk.opacity(0.6))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paletteTileGrid: some View {
        // Flexible columns so the tiles fill the full content width instead of
        // leaving a dead gap on the right.
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        let tileHeight: CGFloat = 46
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(palette.enumerated()), id: \.element.id) { index, swatch in
                PaletteTileView(
                    swatch: swatch,
                    position: index,
                    isSelected: selectedSwatchID == swatch.id,
                    height: tileHeight,
                    onSelect: {
                        selectedSwatchID = (selectedSwatchID == swatch.id ? nil : swatch.id)
                    },
                    onHoverChange: { hovering in
                        if hovering {
                            hoveredSwatchIndex = index
                        } else if hoveredSwatchIndex == index {
                            hoveredSwatchIndex = nil
                        }
                    }
                )
                .opacity(draggingSwatch?.id == swatch.id ? 0.35 : 1)
                .onDrag {
                    draggingSwatch = swatch
                    // Edit and reorder never coexist: dragging closes the tray.
                    selectedSwatchID = nil
                    hoveredSwatchIndex = nil
                    return NSItemProvider(object: swatch.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: PaletteReorderDropDelegate(
                        target: swatch,
                        palette: $palette,
                        dragging: $draggingSwatch,
                        persist: savePalette
                    )
                )
            }
            if palette.count < 8 {
                addTile(height: tileHeight)
            }
        }
        // Catches drops that land in the grid gaps or on the add tile, so an
        // in-progress reorder is always committed and the drag state cleared.
        .onDrop(of: [.text], isTargeted: nil) { _ in
            guard draggingSwatch != nil else { return false }
            draggingSwatch = nil
            savePalette()
            return true
        }
    }

    private func addTile(height: CGFloat) -> some View {
        Button {
            addPaletteColorAndSelect()
        } label: {
            ZStack {
                WatchTheme.caseYellow.opacity(0.25)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(WatchTheme.caseInk.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        WatchTheme.caseInk.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                    )
            )
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
        .help("add a swatch — watch the preview re-quantize")
    }

    /// The editor tray: two calm lines below the grid. Line A is identity +
    /// color, line B is behavior. It never occludes the preview.
    @ViewBuilder
    private func paletteEditor(index: Int) -> some View {
        let swatch = palette[index]
        VStack(spacing: 8) {
            // Line A — identity + color.
            HStack(spacing: 8) {
                miniSwatch(swatch)
                Text("swatch \(index + 1)")
                    .font(WatchFont.body(11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(WatchTheme.caseInk)
                if index == 0 {
                    Text("bg")
                        .font(WatchFont.body(8.5, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(WatchTheme.caseYellow)
                        .padding(.horizontal, 4)
                        .frame(height: 14)
                        .background(WatchTheme.caseInk)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Spacer()

                // Both states share one footprint (a ZStack sized to the taller
                // branch — they're both 122pt wide) so toggling see-through never
                // nudges the row height. Only the shown branch is hit-testable.
                ZStack(alignment: .trailing) {
                    HStack(spacing: 8) {
                        ColorPicker(
                            "",
                            selection: paletteColorBinding(for: index),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 30)

                        HexField(hex: swatch.color.hexString) { text in
                            guard let pixelColor = PixelColor(hex: text) else { return false }
                            guard palette.indices.contains(index) else { return false }
                            palette[index].color = pixelColor
                            palette[index].isTransparent = false
                            savePalette()
                            return true
                        }
                        // Re-key per swatch: without this, switching selection
                        // between same-hex swatches keeps a stale typed draft.
                        .id(swatch.id)
                    }
                    .opacity(swatch.isTransparent ? 0 : 1)
                    .allowsHitTesting(!swatch.isTransparent)

                    LCDChip(width: 122, readout: true) {
                        HStack(spacing: 5) {
                            CheckerboardFill(cell: 3)
                                .frame(width: 12, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text("see-through")
                        }
                    }
                    .opacity(swatch.isTransparent ? 1 : 0)
                    .allowsHitTesting(swatch.isTransparent)
                }
            }

            // Line B — behavior.
            HStack(spacing: 8) {
                WatchToggle(isOn: Binding(
                    get: { palette.indices.contains(index) && palette[index].isTransparent },
                    set: { setSeeThrough($0, at: index) }
                ))
                .help("only one swatch can be see-through")

                VStack(alignment: .leading, spacing: 1) {
                    Text("see-through")
                        .font(WatchFont.body(11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(WatchTheme.caseInk)
                    Text("shows the desktop behind")
                        .font(WatchFont.body(9, weight: .medium))
                        .foregroundStyle(WatchTheme.caseInk.opacity(0.6))
                }

                Spacer()

                if palette.count > 1 {
                    Button("remove") {
                        removeSelectedSwatch(at: index)
                    }
                    .buttonStyle(WatchButtonStyle())
                }
            }
        }
        // Swallow taps that land on the tray's own non-interactive areas (labels,
        // gaps) so the outside-tap-to-dismiss above doesn't close it from within.
        .contentShape(Rectangle())
        .onTapGesture { }
    }

    /// 14×14 sample of the edited color; tethers the tray to its tile.
    @ViewBuilder
    private func miniSwatch(_ swatch: PaletteSwatch) -> some View {
        ZStack {
            if swatch.isTransparent {
                CheckerboardFill(cell: 3.5)
            } else {
                Color(pixelColor: swatch.color)
            }
        }
        .frame(width: 14, height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(WatchTheme.caseInk, lineWidth: 1)
        )
    }

    // MARK: - Viewport

    @ViewBuilder
    private var viewportSection: some View {
        sectionShell("viewport") {
            WatchSlider(
                label: "viewport size",
                value: $viewportSize,
                in: 60...600,
                step: 10,
                defaultValue: 200,
                tickStride: 60,
                format: { "\(Int($0))px" }
            )

            WatchSlider(
                label: "resize step",
                value: $resizeStep,
                in: 5...50,
                step: 5,
                defaultValue: 10,
                tickStride: 5,
                format: { "\(Int($0))px" }
            )

            Text("size of the on-screen loupe — doesn't change the picture")
                .font(WatchFont.body(9, weight: .medium))
                .foregroundStyle(WatchTheme.caseInk.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Output

    @ViewBuilder
    private var outputSection: some View {
        sectionShell("output") {
            settingsRow("filename format") {
                TextField("", text: $filenameFormat)
                    .textFieldStyle(.plain)
                    .font(WatchFont.body(13, weight: .semibold))
                    .foregroundStyle(WatchTheme.lcdInk)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WatchTheme.lcdGreen)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(WatchTheme.caseInk, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    // Dashed ring = the watch is listening.
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(WatchTheme.caseInk,
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .padding(-2)
                            .opacity(isFilenameFieldFocused ? 1 : 0)
                    )
                    .frame(width: 220)
                    .focused($isFilenameFieldFocused)
                    .onSubmit {
                        isFilenameFieldFocused = false
                    }
            }
            HStack {
                Spacer()
                Text("tokens: {date} {time} {grid} {timestamp}")
                    .font(WatchFont.body(9, weight: .medium))
                    .foregroundStyle(WatchTheme.caseInk.opacity(0.6))
            }
            SilkscreenRule()
            settingsRow("preview") {
                LCDChip(maxWidth: 220, readout: true) {
                    Text(filenamePreview)
                        .truncationMode(.tail)
                }
            }
            SilkscreenRule()
            settingsRow("save location") {
                HStack(spacing: 8) {
                    LCDChip(maxWidth: 150, readout: true) {
                        Text(savePathDisplay)
                            .truncationMode(.head)
                    }
                    Button("choose…") {
                        isFilenameFieldFocused = false
                        chooseSaveDirectory()
                    }
                    .buttonStyle(WatchButtonStyle())
                }
            }
        }
    }

    // MARK: - System

    @ViewBuilder
    private var systemSection: some View {
        sectionShell("system") {
            settingsRow("activation hotkey") {
                hotkeyControl
            }
            SilkscreenRule()
            settingsRow("open at login") {
                WatchToggle(isOn: Binding(
                    get: { openAtLogin },
                    set: { newValue in
                        openAtLogin = newValue
                        LoginItemService.setEnabled(newValue)
                        // Re-read the real status: macOS can leave the request in
                        // a pending/approval state, so reflect what actually stuck.
                        openAtLogin = LoginItemService.isEnabled
                    }
                ))
            }
        }
    }

    // MARK: - Shortcuts reference

    @ViewBuilder
    private var shortcutsSection: some View {
        sectionShell("overlay shortcuts") {
            shortcutRow("left / right", "resize viewport")
            SilkscreenRule()
            shortcutRow("up / down", "change grid size")
            SilkscreenRule()
            shortcutRow("+ / -", "adjust threshold")
            SilkscreenRule()
            shortcutRow("shift + arrows / +/-", "larger jumps")
            SilkscreenRule()
            shortcutRow("space", "toggle negative")
            SilkscreenRule()
            shortcutRow("r", "cycle squares / dots / blobs (starts at your default)")
            SilkscreenRule()
            shortcutRow("h", "cycle horizontal mirror")
            SilkscreenRule()
            shortcutRow("v", "cycle vertical mirror")
            SilkscreenRule()
            shortcutRow("1-4", "select filter mode")
            SilkscreenRule()
            shortcutRow("f", "cycle filter mode")
            SilkscreenRule()
            shortcutRow("z", "toggle randomizer")
            SilkscreenRule()
            shortcutRow("[ / ]", "prev / next variation")
            SilkscreenRule()
            shortcutRow("click", "save svg")
            SilkscreenRule()
            shortcutRow("esc", "dismiss overlay")
        }
    }

    // MARK: - Hotkey control (tap-to-record)

    private var hotkeyControl: some View {
        Button {
            if isRecordingHotkey {
                stopRecording()
            } else {
                isFilenameFieldFocused = false
                startRecording()
            }
        } label: {
            if isRecordingHotkey {
                HStack(spacing: 6) {
                    Text("press shortcut…")
                        .font(WatchFont.body(13, weight: .semibold))
                        .foregroundStyle(WatchTheme.caseInk)
                    Text("esc to cancel")
                        .font(WatchFont.body(9, weight: .medium))
                        .foregroundStyle(WatchTheme.caseInk.opacity(0.55))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(WatchTheme.caseInk,
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
            } else {
                LCDChip { Text(hotkeyDisplayString.lowercased()) }
            }
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
        .help(isRecordingHotkey ? "click or press esc to cancel" : "click to record a new shortcut")
    }

    // MARK: - Section Helpers

    @ViewBuilder
    private func sectionShell<Content: View>(_ title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SilkscreenLabel(title)
            VStack(spacing: 8) {
                content()
            }
        }
    }

    // MARK: - Palette mutations

    private func paletteColorBinding(for index: Int) -> Binding<Color> {
        Binding {
            guard palette.indices.contains(index) else {
                return Color.black
            }

            return Color(pixelColor: palette[index].color)
        } set: { newColor in
            guard palette.indices.contains(index), let pixelColor = PixelColor(color: newColor) else {
                return
            }

            palette[index].color = pixelColor
            palette[index].isTransparent = false
            savePalette()
        }
    }

    private func setPalette(_ swatches: [PaletteSwatch]) {
        palette = Array(swatches.prefix(8))
        if palette.isEmpty {
            palette = PaletteSwatch.defaultPalette
        }
        if let id = selectedSwatchID, !palette.contains(where: { $0.id == id }) {
            selectedSwatchID = nil
        }
        savePalette()
    }

    private func addPaletteColorAndSelect() {
        guard palette.count < 8 else { return }
        let newSwatch = PaletteSwatch(color: PixelColor(hex: "#FFFFFF")!)
        palette.append(newSwatch)
        selectedSwatchID = newSwatch.id
        savePalette()
    }

    private func removeSelectedSwatch(at index: Int) {
        guard palette.count > 1, palette.indices.contains(index) else { return }
        palette.remove(at: index)
        selectedSwatchID = nil
        savePalette()
    }

    /// See-through is exclusive: enabling it on one swatch strips it from the
    /// rest, animated so the losing tile visibly flips checker→color.
    private func setSeeThrough(_ on: Bool, at index: Int) {
        guard palette.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            if on {
                for i in palette.indices where i != index {
                    palette[i].isTransparent = false
                }
            }
            palette[index].isTransparent = on
        }
        savePalette()
    }

    private func savePalette() {
        AppSettings.shared.palette = palette
    }

    // MARK: - Hotkey Recording

    private func startRecording() {
        isRecordingHotkey = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            let mods = AppSettings.carbonModifiers(from: event.modifierFlags)
            // Require at least one modifier key, and a real (mappable) key —
            // reject pure-modifier keycodes that can't be bound meaningfully.
            guard mods != 0, AppSettings.isKnownKeyCode(UInt32(event.keyCode)) else {
                NSSound.beep()
                return nil
            }

            hotkeyKeyCode = UInt32(event.keyCode)
            hotkeyModifiers = mods
            applyHotkey()
            stopRecording()
            return nil // consume the event
        }
    }

    private func stopRecording() {
        isRecordingHotkey = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Row Helpers

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label.lowercased())
                .font(WatchFont.body(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(WatchTheme.caseInk)
            Spacer()
            content()
        }
    }

    private func shortcutRow(_ key: String, _ action: String) -> some View {
        HStack {
            Text(key.lowercased())
                .font(WatchFont.body(11, weight: .regular))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(WatchTheme.caseInk)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Spacer()
            Text(action.lowercased())
                .font(WatchFont.body(10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(WatchTheme.caseInk.opacity(0.85))
        }
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose where to save SVG files"

        if panel.runModal() == .OK, let url = panel.url {
            AppSettings.shared.saveDirectory = url
            savePathDisplay = url.path
        }
    }

    private func applyHotkey() {
        let settings = AppSettings.shared
        // Remember the previous binding so we can revert if registration fails
        // (e.g. the chosen combo is already claimed system-wide).
        let previousKeyCode = settings.hotkeyKeyCode
        let previousModifiers = settings.hotkeyModifiers

        settings.hotkeyKeyCode = hotkeyKeyCode
        settings.hotkeyModifiers = hotkeyModifiers

        let registered = onHotkeyChanged?(hotkeyKeyCode, hotkeyModifiers) ?? true
        if !registered {
            // Roll back to the last working binding and notify the user.
            settings.hotkeyKeyCode = previousKeyCode
            settings.hotkeyModifiers = previousModifiers
            hotkeyKeyCode = previousKeyCode
            hotkeyModifiers = previousModifiers
            _ = onHotkeyChanged?(previousKeyCode, previousModifiers)
            NSSound.beep()
        }

        hotkeyDisplayString = settings.hotkeyDisplayString
    }

    private func updateFilenamePreview() {
        filenamePreview = SVGExporter.buildFilename(from: filenameFormat, gridSize: gridSize)
    }
}
