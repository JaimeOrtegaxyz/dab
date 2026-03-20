import SwiftUI
import Carbon

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("gridSize") private var gridSize: Int = 16
    @AppStorage("viewportSize") private var viewportSize: Double = 200.0
    @AppStorage("resizeStep") private var resizeStep: Double = 10.0
    @AppStorage("brightnessThreshold") private var brightnessThreshold: Double = 0.5
    @AppStorage("filterMode") private var filterModeRaw: String = FilterMode.threshold.rawValue
    @AppStorage("horizontalMirrorMode") private var horizontalMirrorModeRaw: String = AppSettings.shared.horizontalMirrorMode.rawValue
    @AppStorage("verticalMirrorMode") private var verticalMirrorModeRaw: String = AppSettings.shared.verticalMirrorMode.rawValue
    @AppStorage("filenameFormat") private var filenameFormat: String = "pixelatolor_{date}_{time}"
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
            VStack(spacing: 16) {
                Spacer().frame(height: 8)

                settingsContent

                Divider()
                    .padding(.horizontal, 4)

                aboutSection
            }
            .padding(20)
        }
        .background(.clear)
        .onAppear {
            savePathDisplay = AppSettings.shared.saveDirectory.path
            hotkeyKeyCode = AppSettings.shared.hotkeyKeyCode
            hotkeyModifiers = AppSettings.shared.hotkeyModifiers
            hotkeyDisplayString = AppSettings.shared.hotkeyDisplayString
            updateFilenamePreview()
        }
        .onChange(of: filenameFormat) { _ in
            updateFilenamePreview()
        }
        .onDisappear {
            stopRecording()
        }
        .onTapGesture {
            isFilenameFieldFocused = false
        }
    }

    // MARK: - Main Settings Content

    @ViewBuilder
    private var settingsContent: some View {
        // Defaults
        GroupBox {
            VStack(spacing: 10) {
                settingsRow("Grid Size") {
                    Stepper("\(gridSize)x\(gridSize)", value: $gridSize, in: 4...32)
                        .frame(width: 120)
                }
                Divider()
                settingsRow("Viewport Size") {
                    Stepper("\(Int(viewportSize))px", value: $viewportSize, in: 60...600, step: 10)
                        .frame(width: 120)
                }
                Divider()
                settingsRow("Resize Step") {
                    Stepper("\(Int(resizeStep))px", value: $resizeStep, in: 5...50, step: 5)
                        .frame(width: 120)
                }
                Divider()
                settingsRow("Brightness Threshold") {
                    HStack(spacing: 6) {
                        Slider(value: $brightnessThreshold, in: 0...1)
                            .frame(width: 120)
                        Text(String(format: "%.2f", brightnessThreshold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Divider()
                settingsRow("Filter Mode") {
                    Picker("", selection: $filterModeRaw) {
                        ForEach(FilterMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
            .padding(10)
        } label: {
            Label("Defaults", systemImage: "slider.horizontal.3")
                .font(.headline)
        }

        // Mirror
        GroupBox {
            VStack(spacing: 10) {
                settingsRow("Horizontal Mirror") {
                    Picker("", selection: $horizontalMirrorModeRaw) {
                        ForEach(HorizontalMirrorMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                Divider()
                settingsRow("Vertical Mirror") {
                    Picker("", selection: $verticalMirrorModeRaw) {
                        ForEach(VerticalMirrorMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
            .padding(10)
        } label: {
            Label("Mirror Output", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(.headline)
        }

        // Output
        GroupBox {
            VStack(spacing: 10) {
                settingsRow("Filename Format") {
                    TextField("", text: $filenameFormat)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .focused($isFilenameFieldFocused)
                        .onSubmit {
                            isFilenameFieldFocused = false
                        }
                }
                HStack {
                    Text("Tokens: {date} {time} {grid} {timestamp}")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("Preview: \(filenamePreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                settingsRow("Save Location") {
                    HStack(spacing: 6) {
                        Text(savePathDisplay)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 160, alignment: .trailing)
                        Button("Choose...") {
                            isFilenameFieldFocused = false
                            chooseSaveDirectory()
                        }
                        .controlSize(.small)
                    }
                }
            }
            .padding(10)
        } label: {
            Label("Output", systemImage: "square.and.arrow.down")
                .font(.headline)
        }

        // Hotkey
        GroupBox {
            VStack(spacing: 10) {
                settingsRow("Activation Hotkey") {
                    if isRecordingHotkey {
                        HStack(spacing: 6) {
                            Text("Press shortcut...")
                                .foregroundStyle(.orange)
                                .font(.system(.body, design: .rounded))
                            Button("Cancel") {
                                stopRecording()
                            }
                            .controlSize(.small)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(hotkeyDisplayString)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .font(.system(.body, design: .monospaced))
                            Button("Record") {
                                isFilenameFieldFocused = false
                                startRecording()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(10)
        } label: {
            Label("Hotkey", systemImage: "keyboard")
                .font(.headline)
        }

        // Keyboard Shortcuts Reference
        GroupBox {
            VStack(spacing: 6) {
                shortcutRow("Left / Right", "Resize viewport")
                Divider()
                shortcutRow("Up / Down", "Change grid size")
                Divider()
                shortcutRow("+ / -", "Adjust threshold")
                Divider()
                shortcutRow("Shift + arrows / +/-", "Larger jumps")
                Divider()
                shortcutRow("Space", "Toggle negative")
                Divider()
                shortcutRow("H", "Cycle horizontal mirror")
                Divider()
                shortcutRow("V", "Cycle vertical mirror")
                Divider()
                shortcutRow("1-8", "Select filter mode")
                Divider()
                shortcutRow("F", "Cycle filter mode")
                Divider()
                shortcutRow("Click", "Save SVG")
                Divider()
                shortcutRow("Esc", "Dismiss overlay")
            }
            .padding(10)
        } label: {
            Label("Overlay Shortcuts", systemImage: "command")
                .font(.headline)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.linearGradient(
                        colors: [Color.black, Color.gray.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                Canvas { context, size in
                    let cellSize = size.width / 4
                    let pattern: [(Int, Int)] = [(0,0),(0,2),(1,1),(1,3),(2,0),(2,2),(3,1),(3,3)]
                    for (r, c) in pattern {
                        let rect = CGRect(x: CGFloat(c) * cellSize + 3,
                                          y: CGFloat(r) * cellSize + 3,
                                          width: cellSize - 2,
                                          height: cellSize - 2)
                        context.fill(Path(rect), with: .color(.white))
                    }
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pixelatolor")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Version 1.0")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
                Text("Turning retina displays into potato displays")
                    .font(.system(.caption))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
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

    // MARK: - Helpers

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            content()
        }
    }

    private func shortcutRow(_ key: String, _ action: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Spacer()
            Text(action)
                .font(.caption)
                .foregroundStyle(.secondary)
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
