import SwiftUI
import Carbon
import AppKit

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
    static let valueChipWidth: CGFloat = 72
    static let titleBarHeight: CGFloat = 28
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
            .frame(width: width, alignment: .trailing)
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
            .fill(WatchTheme.caseInk.opacity(0.85))
            .frame(height: 1)
    }
}

private struct WatchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchFont.body(11, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(WatchTheme.caseInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                configuration.isPressed
                    ? WatchTheme.caseYellow.opacity(0.55)
                    : WatchTheme.caseYellow
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Custom case-yellow stepper (black arrows, on the left)

private struct CaseStepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(WatchTheme.caseInk)
            .frame(width: 20, height: 18)
            .background(
                configuration.isPressed
                    ? WatchTheme.caseYellow.opacity(0.5)
                    : WatchTheme.caseYellow
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
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

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("gridSize") private var gridSize: Int = 16
    @AppStorage("viewportSize") private var viewportSize: Double = 200.0
    @AppStorage("resizeStep") private var resizeStep: Double = 10.0
    @AppStorage("brightnessThreshold") private var brightnessThreshold: Double = 0.5
    @AppStorage("filterMode") private var filterModeRaw: String = FilterMode.threshold.rawValue
    @AppStorage("horizontalMirrorMode") private var horizontalMirrorModeRaw: String = AppSettings.shared.horizontalMirrorMode.rawValue
    @AppStorage("verticalMirrorMode") private var verticalMirrorModeRaw: String = AppSettings.shared.verticalMirrorMode.rawValue
    @AppStorage("filenameFormat") private var filenameFormat: String = "dab_{date}_{time}"
    @State private var savePathDisplay: String = ""
    @State private var isRecordingHotkey: Bool = false
    @State private var hotkeyKeyCode: UInt32 = AppSettings.shared.hotkeyKeyCode
    @State private var hotkeyModifiers: UInt32 = AppSettings.shared.hotkeyModifiers
    @State private var hotkeyDisplayString: String = AppSettings.shared.hotkeyDisplayString
    @State private var filenamePreview: String = ""
    @State private var keyMonitor: Any?
    @FocusState private var isFilenameFieldFocused: Bool

    var onHotkeyChanged: ((UInt32, UInt32) -> Void)?

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
            updateFilenamePreview()
        }
        .onChange(of: filenameFormat) { _, _ in
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
            SilkscreenRule()
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
            shortcutRow("r", "toggle round mode")
            SilkscreenRule()
            shortcutRow("h", "cycle horizontal mirror")
            SilkscreenRule()
            shortcutRow("v", "cycle vertical mirror")
            SilkscreenRule()
            shortcutRow("1-8", "select filter mode")
            SilkscreenRule()
            shortcutRow("f", "cycle filter mode")
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
        Menu {
            ForEach(options, id: \.0) { (value, label) in
                Button(label) { selection.wrappedValue = value }
            }
        } label: {
            HStack(spacing: 4) {
                let currentLabel = options.first { $0.0 == selection.wrappedValue }?.1 ?? "—"
                Text(currentLabel.lowercased())
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
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
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
            // Require at least one modifier key
            guard mods != 0 else { return nil }

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
        settings.hotkeyKeyCode = hotkeyKeyCode
        settings.hotkeyModifiers = hotkeyModifiers
        hotkeyDisplayString = settings.hotkeyDisplayString
        onHotkeyChanged?(hotkeyKeyCode, hotkeyModifiers)
    }

    private func updateFilenamePreview() {
        filenamePreview = SVGExporter.buildFilename(from: filenameFormat, gridSize: gridSize)
    }
}
