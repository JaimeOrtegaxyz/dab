import SwiftUI
import AppKit

// The shared Timex-watch design system for dab's settings UI.
//
// State grammar (used consistently across every control):
//   dashed ink ring [3,3]  = the watch is listening (recording / focused input)
//   lcdGreen               = live value (chips, slider fill, selected key)
//   yellow ring            = selected (palette tile)
//   white 0.25 wash        = hover
//   ink 0.18 wash          = pressed

// MARK: - Watch Theme

enum WatchTheme {
    // FEC700 — bright Timex plastic.
    static let caseYellow = Color(red: 254.0 / 255.0, green: 199.0 / 255.0, blue: 0.0 / 255.0)
    static let caseInk    = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let lcdGreen   = Color(red: 0.66, green: 0.78, blue: 0.62)
    static let lcdInk     = Color(red: 0.06, green: 0.10, blue: 0.06)
    static let badgeGreen = Color(red: 0.66, green: 0.78, blue: 0.62).opacity(0.55)
}

enum WatchFont {
    static func body(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .custom("Inconsolata", size: size).weight(weight)
    }
}

enum WatchMetrics {
    static let valueChipWidth: CGFloat = 60
    static let titleBarHeight: CGFloat = 28
}

extension Color {
    init(pixelColor: PixelColor) {
        self.init(
            red: Double(pixelColor.red),
            green: Double(pixelColor.green),
            blue: Double(pixelColor.blue)
        )
    }
}

extension PixelColor {
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

struct BundleImage: View {
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
struct HoverCursor: ViewModifier {
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

struct HoverScale: ViewModifier {
    var scale: CGFloat = 1.05
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverCursor(_ cursor: NSCursor) -> some View { modifier(HoverCursor(cursor: cursor)) }
    func hoverScale(_ scale: CGFloat = 1.05) -> some View { modifier(HoverScale(scale: scale)) }
}

// MARK: - Reusable components

/// Chip color language: lcd-green = interactive (click/type/pick), ink with
/// white text (`readout: true`) = display-only, matching the HUD bar and the
/// shortcut keycaps.
struct LCDChip<Content: View>: View {
    var width: CGFloat? = nil
    var maxWidth: CGFloat? = nil
    var readout: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(WatchFont.body(13, weight: .semibold))
            .foregroundStyle(readout ? .white : WatchTheme.lcdInk)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(width: width, alignment: .center)
            .frame(maxWidth: maxWidth, alignment: .trailing)
            .background(readout ? WatchTheme.caseInk : WatchTheme.lcdGreen)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WatchTheme.caseInk, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }
}

/// A side-pusher key on the watch case: yellow at rest, lcd-green when it's
/// the active option. Shared by the render-mode keys and the mirror keys.
struct WatchKeyStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, isSelected: isSelected)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(WatchFont.body(11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(isSelected ? WatchTheme.lcdInk : WatchTheme.caseInk)
                .background(isSelected ? WatchTheme.lcdGreen : WatchTheme.caseYellow)
                .overlay(stateWash)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(isSelected ? 0.18 : 0), radius: 1, y: 1)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

struct SilkscreenLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.lowercased())
            .font(WatchFont.body(11, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(WatchTheme.caseInk)
    }
}

struct SilkscreenRule: View {
    var body: some View {
        Rectangle()
            // Soft hairline: enough to structure the rows without the heavy
            // full-bleed ledger lines crowding every list.
            .fill(WatchTheme.caseInk.opacity(0.4))
            .frame(height: 1)
    }
}

struct WatchButtonStyle: ButtonStyle {
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
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

// MARK: - Watch-style toggle

/// A small sliding switch in the watch palette: ink track, lcd-green when on,
/// case-ink knob. Used for on/off settings so they read like the rest of the
/// Timex-styled controls rather than a stock SwiftUI `Toggle`.
struct WatchToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? WatchTheme.lcdGreen : WatchTheme.caseInk.opacity(0.22))
                .frame(width: 42, height: 22)
                .overlay(
                    Circle()
                        .fill(WatchTheme.caseInk)
                        .padding(2)
                        .frame(width: 22, height: 22)
                        .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                )
                .overlay(
                    Capsule().stroke(WatchTheme.caseInk, lineWidth: 1)
                )
                .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .hoverCursor(.pointingHand)
    }
}

// MARK: - Checkerboard (see-through indicator)

struct CheckerboardFill: View {
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

// MARK: - LCD boot transition

struct LCDBootModifier: ViewModifier, Animatable {
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

// MARK: - LCD picker

/// Renders a `Menu` (via `.menuStyle(.button)`) as a green LCD chip so the
/// filter-mode / mirror pickers match the numeric value chips. The previous
/// `.menuStyle(.borderlessButton)` silently dropped the label's background.
struct LCDPickerButtonStyle: ButtonStyle {
    let width: CGFloat
    var isOpen: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, width: width, isOpen: isOpen)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let width: CGFloat
        let isOpen: Bool
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 4) {
                configuration.label
                    .font(WatchFont.body(13, weight: .semibold))
                    .foregroundStyle(WatchTheme.lcdInk)
                    .lineLimit(1)
                Spacer(minLength: 4)
                // Flips to point up while its themed list is open.
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(WatchTheme.lcdInk)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .animation(.easeOut(duration: 0.15), value: isOpen)
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

/// A compact lcd-green action chip: same visual language as the closed
/// `LCDPickerButtonStyle` picker (green = interactive), but it hugs its label
/// with no chevron/fixed width. Used for one-shot actions like "save".
struct LCDActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyleBody(configuration: configuration) }

    private struct StyleBody: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(WatchFont.body(12, weight: .semibold))
                .foregroundStyle(WatchTheme.lcdInk)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(WatchTheme.lcdGreen)
                .overlay(stateWash)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

// `lcdPicker` (a system `Menu`) was retired: the popup it produced couldn't be
// themed, so settings now uses `LCDDropdown` — see SettingsView — which renders
// its option list as a case-yellow plate anchored at the window root.
