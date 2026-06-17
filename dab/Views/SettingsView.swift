import SwiftUI
import Carbon
import AppKit
import UniformTypeIdentifiers

// MARK: - Watch Theme

private enum WatchTheme {
    // FEC700 — bright Timex plastic.
    static let caseYellow = Color(red: 254.0 / 255.0, green: 199.0 / 255.0, blue: 0.0 / 255.0)
    static let caseInk    = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let lcdGreen   = Color(red: 0.66, green: 0.78, blue: 0.62)
    static let lcdInk     = Color(red: 0.06, green: 0.10, blue: 0.06)
    static let badgeGreen = Color(red: 0.66, green: 0.78, blue: 0.62).opacity(0.55)
}

private enum WatchFont {
    static func body(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .custom("Inconsolata", size: size).weight(weight)
    }
}

private enum WatchMetrics {
    static let valueChipWidth: CGFloat = 60
    static let titleBarHeight: CGFloat = 28
}

private extension Color {
    init(pixelColor: PixelColor) {
        self.init(
            red: Double(pixelColor.red),
            green: Double(pixelColor.green),
            blue: Double(pixelColor.blue)
        )
    }
}

private extension PixelColor {
    init?(color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else {
            return nil
        }

        self.init(
            red: Float(rgb.redComponent),
            green: Float(rgb.greenComponent),
            blue: Float(rgb.blueComponent)
        )
    }
}

// MARK: - Bundled image renderer (SVG / PNG)

private struct BundleImage: View {
    let name: String
    let ext: String
    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: ext),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Hover affordances

/// Pushes a cursor while the pointer is inside and pops it on exit (and on
/// disappear, so a view removed mid-hover doesn't leave the cursor stuck).
/// Gives SwiftUI controls the clickable/draggable cursor macOS users expect.
private struct HoverCursor: ViewModifier {
    let cursor: NSCursor
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    if !pushed { cursor.push(); pushed = true }
                } else if pushed {
                    NSCursor.pop(); pushed = false
                }
            }
            .onDisappear { if pushed { NSCursor.pop(); pushed = false } }
    }
}

private struct HoverScale: ViewModifier {
    var scale: CGFloat = 1.05
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

private extension View {
    func hoverCursor(_ cursor: NSCursor) -> some View { modifier(HoverCursor(cursor: cursor)) }
    func hoverScale(_ scale: CGFloat = 1.05) -> some View { modifier(HoverScale(scale: scale)) }
}

// MARK: - Reusable components

private struct LCDChip<Content: View>: View {
    var width: CGFloat? = nil
    var maxWidth: CGFloat? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(WatchFont.body(13, weight: .semibold))
            .foregroundStyle(WatchTheme.lcdInk)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(width: width, alignment: .center)
            .frame(maxWidth: maxWidth, alignment: .trailing)
            .background(WatchTheme.lcdGreen)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }
}

private struct SilkscreenLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.lowercased())
            .font(WatchFont.body(11, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(WatchTheme.caseInk)
    }
}

private struct SilkscreenRule: View {
    var body: some View {
        Rectangle()
            // Soft hairline: enough to structure the rows without the heavy
            // full-bleed ledger lines crowding every list.
            .fill(WatchTheme.caseInk.opacity(0.4))
            .frame(height: 1)
    }
}

private struct WatchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyleBody(configuration: configuration) }

    private struct StyleBody: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(WatchFont.body(11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(WatchTheme.caseInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(WatchTheme.caseYellow)
                // The button fill matches the case, so hover/press feedback has
                // to come from a wash on top: lighten on hover, darken on press.
                .overlay(stateWash)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onHover { hovering = $0 }
                .hoverCursor(.pointingHand)
        }

        private var stateWash: Color {
            if configuration.isPressed { return WatchTheme.caseInk.opacity(0.18) }
            if hovering { return .white.opacity(0.25) }
            return .clear
        }
    }
}

// MARK: - Palette tile helpers

private struct CheckerboardFill: View {
    var cell: CGFloat = 5
    var light: Color = Color(white: 0.92)
    var dark: Color = Color(white: 0.55)

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))
            let cols = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for r in 0..<rows {
                for c in 0..<cols {
                    guard (r + c) % 2 == 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(c) * cell,
                        y: CGFloat(r) * cell,
                        width: cell,
                        height: cell
                    )
                    ctx.fill(Path(rect), with: .color(dark))
                }
            }
        }
    }
}

private struct LCDBootModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = max(0, min(1, progress))
        content
            .scaleEffect(x: 1, y: max(0.001, p), anchor: .top)
            .opacity(Double(p))
            .overlay(
                GeometryReader { proxy in
                    Rectangle()
                        .fill(WatchTheme.lcdGreen)
                        .frame(height: 1.5)
                        .opacity(p < 0.98 ? 0.9 : 0)
                        .offset(y: proxy.size.height * p)
                        .allowsHitTesting(false)
                }
            )
    }
}

extension AnyTransition {
    static var lcdBoot: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: LCDBootModifier(progress: 0),
                identity: LCDBootModifier(progress: 1)
            ),
            removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
        )
    }
}

// MARK: - Custom case-yellow stepper (black arrows, on the left)

private struct CaseStepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyleBody(configuration: configuration) }

    private struct StyleBody: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(WatchTheme.caseInk)
                .frame(width: 20, height: 18)
                .background(WatchTheme.caseYellow)
                .overlay(stateWash)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .onHover { hovering = $0 }
                .hoverCursor(.pointingHand)
        }

        private var stateWash: Color {
            if configuration.isPressed { return WatchTheme.caseInk.opacity(0.18) }
            if hovering { return .white.opacity(0.25) }
            return .clear
        }
    }
}

/// Renders a `Menu` (via `.menuStyle(.button)`) as a green LCD chip so the
/// filter-mode / mirror pickers match the numeric value chips. The previous
/// `.menuStyle(.borderlessButton)` silently dropped the label's background.
private struct LCDPickerButtonStyle: ButtonStyle {
    let width: CGFloat
    func makeBody(configuration: Configuration) -> some View { StyleBody(configuration: configuration, width: width) }

    private struct StyleBody: View {
        let configuration: Configuration
        let width: CGFloat
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 4) {
                configuration.label
                    .font(WatchFont.body(13, weight: .semibold))
                    .foregroundStyle(WatchTheme.lcdInk)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(WatchTheme.lcdInk)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(width: width)
            .background(WatchTheme.lcdGreen)
            .overlay(stateWash)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .onHover { hovering = $0 }
            .hoverCursor(.pointingHand)
        }

        private var stateWash: Color {
            if configuration.isPressed { return WatchTheme.lcdInk.opacity(0.12) }
            if hovering { return .white.opacity(0.18) }
            return .clear
        }
    }
}

private struct CaseStepper<V>: View where V: Strideable & Comparable, V.Stride: SignedNumeric {
    @Binding var value: V
    let range: ClosedRange<V>
    let step: V.Stride

    var body: some View {
        HStack(spacing: 4) {
            Button {
                let next = value.advanced(by: -step)
                if next >= range.lowerBound { value = next }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(CaseStepperButtonStyle())

            Button {
                let next = value.advanced(by: step)
                if next <= range.upperBound { value = next }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(CaseStepperButtonStyle())
        }
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
        .scaleEffect(hovering ? 1.04 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
        .hoverCursor(.pointingHand)
        .help(isBackground
              ? "click to edit · drag to reorder · #1 fills the gaps in blobs mode"
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

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("gridSize") private var gridSize: Int = 16
    @AppStorage("viewportSize") private var viewportSize: Double = 200.0
    @AppStorage("resizeStep") private var resizeStep: Double = 10.0
    @AppStorage("brightnessThreshold") private var brightnessThreshold: Double = 0.5
    @AppStorage("filterMode") private var filterModeRaw: String = FilterMode.colorMatch.rawValue
    @AppStorage("horizontalMirrorMode") private var horizontalMirrorModeRaw: String = AppSettings.shared.horizontalMirrorMode.rawValue
    @AppStorage("verticalMirrorMode") private var verticalMirrorModeRaw: String = AppSettings.shared.verticalMirrorMode.rawValue
    @AppStorage("filenameFormat") private var filenameFormat: String = "dab_{date}_{time}"
    @State private var savePathDisplay: String = ""
    @State private var isRecordingHotkey: Bool = false
    @State private var hotkeyKeyCode: UInt32 = AppSettings.shared.hotkeyKeyCode
    @State private var hotkeyModifiers: UInt32 = AppSettings.shared.hotkeyModifiers
    @State private var hotkeyDisplayString: String = AppSettings.shared.hotkeyDisplayString
    @State private var filenamePreview: String = ""
    @State private var palette: [PaletteSwatch] = PaletteSwatch.defaultPalette
    @State private var selectedSwatchID: UUID? = nil
    @State private var draggingSwatch: PaletteSwatch? = nil
    @State private var keyMonitor: Any?
    @FocusState private var isFilenameFieldFocused: Bool

    /// Returns whether the new hotkey was successfully registered, so the
    /// recorder can revert to the previous binding on failure.
    var onHotkeyChanged: ((UInt32, UInt32) -> Bool)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                watchHeader
                VStack(alignment: .leading, spacing: 24) {
                    settingsContent
                    watchFooter
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, WatchMetrics.titleBarHeight + 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(WatchTheme.caseYellow)
        .tint(WatchTheme.caseInk)
        .contentMargins(.bottom, 12, for: .scrollIndicators)
        .overlay(alignment: .top) {
            WatchTheme.caseYellow
                .frame(height: WatchMetrics.titleBarHeight)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
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

    private var watchHeader: some View {
        BundleImage(name: "dab-text", ext: "svg")
            .frame(maxWidth: .infinity)
            .accessibilityLabel("dab")
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
                Text("v0.4.1")
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

    // MARK: - Main Settings Content

    @ViewBuilder
    private var settingsContent: some View {
        sectionShell("defaults") {
            settingsRow("grid size") {
                HStack(spacing: 8) {
                    CaseStepper(value: $gridSize, range: 4...32, step: 1)
                    LCDChip(width: WatchMetrics.valueChipWidth) {
                        Text("\(gridSize)x\(gridSize)")
                    }
                }
            }
            SilkscreenRule()
            settingsRow("viewport size") {
                HStack(spacing: 8) {
                    CaseStepper(value: $viewportSize, range: 60...600, step: 10)
                    LCDChip(width: WatchMetrics.valueChipWidth) {
                        Text("\(Int(viewportSize))px")
                    }
                }
            }
            SilkscreenRule()
            settingsRow("resize step") {
                HStack(spacing: 8) {
                    CaseStepper(value: $resizeStep, range: 5...50, step: 5)
                    LCDChip(width: WatchMetrics.valueChipWidth) {
                        Text("\(Int(resizeStep))px")
                    }
                }
            }
            SilkscreenRule()
            settingsRow("brightness threshold") {
                HStack(spacing: 8) {
                    Slider(value: $brightnessThreshold, in: 0...1)
                        .tint(WatchTheme.caseInk)
                        .frame(width: 100)
                    LCDChip(width: WatchMetrics.valueChipWidth) {
                        Text(String(format: "%.2f", brightnessThreshold))
                    }
                }
            }
            SilkscreenRule()
            settingsRow("filter mode") {
                lcdPicker(
                    selection: $filterModeRaw,
                    options: FilterMode.allCases.map { ($0.rawValue, $0.displayName) },
                    width: 160
                )
            }
        }

        sectionShell("palette") {
            HStack(spacing: 8) {
                Button("default") {
                    setPalette(PaletteSwatch.defaultPalette)
                }
                .buttonStyle(WatchButtonStyle())

                Button("black / transparent") {
                    setPalette(PaletteSwatch.blackTransparentPalette)
                }
                .buttonStyle(WatchButtonStyle())

                Spacer()
                LCDChip(width: 48) {
                    Text("\(palette.count)/8")
                }
            }

            SilkscreenRule()

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

        sectionShell("mirror output") {
            settingsRow("horizontal") {
                lcdPicker(
                    selection: $horizontalMirrorModeRaw,
                    options: HorizontalMirrorMode.allCases.map { ($0.rawValue, $0.displayName) },
                    width: 160
                )
            }
            SilkscreenRule()
            settingsRow("vertical") {
                lcdPicker(
                    selection: $verticalMirrorModeRaw,
                    options: VerticalMirrorMode.allCases.map { ($0.rawValue, $0.displayName) },
                    width: 160
                )
            }
        }

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
                LCDChip(maxWidth: 220) {
                    Text(filenamePreview)
                        .truncationMode(.tail)
                }
            }
            SilkscreenRule()
            settingsRow("save location") {
                HStack(spacing: 8) {
                    LCDChip(maxWidth: 150) {
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

        sectionShell("hotkey") {
            settingsRow("activation") {
                hotkeyControl
            }
        }

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
            shortcutRow("r", "cycle squares / dots / blobs")
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
            SilkscreenRule()
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

    // MARK: - Section / Picker Helpers

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

    private func lcdPicker<T: Hashable>(selection: Binding<T>,
                                        options: [(T, String)],
                                        width: CGFloat) -> some View {
        let currentLabel = options.first { $0.0 == selection.wrappedValue }?.1 ?? "—"
        return Menu {
            ForEach(options, id: \.0) { (value, label) in
                Button(label) { selection.wrappedValue = value }
            }
        } label: {
            Text(currentLabel.lowercased())
        }
        .menuStyle(.button)
        .buttonStyle(LCDPickerButtonStyle(width: width))
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// One-line reminder that palette order is a creative lever: the lowest
    /// index (position 1) is the grout that fills the gaps in Blobs render mode.
    private var paletteOrderHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 8, weight: .heavy))
            Text("click to edit · drag to reorder · #1 fills the blobs gaps")
                .font(WatchFont.body(9, weight: .medium))
        }
        .foregroundStyle(WatchTheme.caseInk.opacity(0.6))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paletteTileGrid: some View {
        // Flexible columns so the tiles fill the full content width instead of
        // leaving a dead gap on the right.
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        let tileHeight: CGFloat = 58
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(palette.enumerated()), id: \.element.id) { index, swatch in
                PaletteTileView(
                    swatch: swatch,
                    position: index,
                    isSelected: selectedSwatchID == swatch.id,
                    height: tileHeight,
                    onSelect: {
                        selectedSwatchID = (selectedSwatchID == swatch.id ? nil : swatch.id)
                    }
                )
                .opacity(draggingSwatch?.id == swatch.id ? 0.35 : 1)
                .onDrag {
                    draggingSwatch = swatch
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
        .help("add a swatch")
    }

    @ViewBuilder
    private func paletteEditor(index: Int) -> some View {
        let swatch = palette[index]
        HStack(spacing: 8) {
            Text("swatch \(index + 1)")
                .font(WatchFont.body(11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(WatchTheme.caseInk)

            Spacer()

            if swatch.isTransparent {
                LCDChip(width: 122) {
                    Text("transparent")
                }
            } else {
                ColorPicker(
                    "",
                    selection: paletteColorBinding(for: index),
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 30)

                LCDChip(width: 84) {
                    Text(swatch.color.hexString.lowercased())
                }
            }

            Button(swatch.isTransparent ? "make color" : "transparent") {
                toggleTransparent(at: index)
            }
            .buttonStyle(WatchButtonStyle())

            if palette.count > 1 {
                Button("remove") {
                    removeSelectedSwatch(at: index)
                }
                .buttonStyle(WatchButtonStyle())
            }
        }
    }

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

    private func toggleTransparent(at index: Int) {
        guard palette.indices.contains(index) else { return }
        let newState = !palette[index].isTransparent
        if newState {
            for i in palette.indices where i != index && palette[i].isTransparent {
                palette[i].isTransparent = false
            }
        }
        palette[index].isTransparent = newState
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
