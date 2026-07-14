import SwiftUI
import AppKit

/// The watch-cased fader that replaces both the +/- steppers and the stock
/// `Slider`: a recessed ink slot with an lcd-green fill, detent ticks, and a
/// 12×22 ink cap whose center tick glows green while dragging.
///
/// Interactions: click anywhere jumps to the nearest detent (animated), drag is
/// absolute and snapped (unanimated; grabbing the knob tracks the grab point),
/// double-click resets to `defaultValue`. Focusable: ←/→ step, Shift steps
/// coarse (mirrors the overlay's shift grammar), Home/End hit the bounds.
struct WatchSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double
    /// Detent marks every `tickStride` units; bounds are always marked. `nil`
    /// draws only the bounds.
    var tickStride: Double? = nil
    /// Taller mark at the range midpoint (the threshold slider's neutral).
    var centerTick: Bool = false
    /// Shift-arrow step; defaults to 5 × `step`.
    var coarseStep: Double? = nil
    var chipWidth: CGFloat = WatchMetrics.valueChipWidth
    let format: (Double) -> String

    init(label: String,
         value: Binding<Double>,
         in range: ClosedRange<Double>,
         step: Double,
         defaultValue: Double,
         tickStride: Double? = nil,
         centerTick: Bool = false,
         coarseStep: Double? = nil,
         chipWidth: CGFloat = WatchMetrics.valueChipWidth,
         format: @escaping (Double) -> String) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.tickStride = tickStride
        self.centerTick = centerTick
        self.coarseStep = coarseStep
        self.chipWidth = chipWidth
        self.format = format
    }

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool
    @State private var dragging = false
    @State private var dragBegan = false
    @State private var knobHovering = false
    @State private var resetPending = false
    @State private var grabOffset: CGFloat = 0

    private let knobSize = CGSize(width: 12, height: 22)
    private let trackHeight: CGFloat = 8
    private let zoneHeight: CGFloat = 26   // knob + tick marks below the slot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label.lowercased())
                    .font(WatchFont.body(11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(WatchTheme.caseInk)
                Spacer()
                LCDChip(width: chipWidth, readout: true) {
                    Text(format(value))
                }
            }
            trackZone
        }
        .opacity(isEnabled ? 1 : 0.4)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(phases: [.down, .repeat]) { press in
            handleKey(press)
        }
        // "The watch is listening": dashed silkscreen ring while focused.
        .padding(4)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(WatchTheme.caseInk,
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .opacity(focused ? 1 : 0)
        )
        .padding(-4)
    }

    // MARK: - Track

    private var trackZone: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let t = fraction(of: value)
            let travel = max(1, width - knobSize.width)

            ZStack(alignment: .leading) {
                // Recessed slot in the case plastic.
                RoundedRectangle(cornerRadius: 2)
                    .fill(WatchTheme.caseInk.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(WatchTheme.caseInk, lineWidth: 1)
                    )
                    .frame(height: trackHeight)

                // lcdGreen = live value: fill up to the knob center, inset 1pt.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(WatchTheme.lcdGreen)
                    .frame(width: max(0, knobSize.width / 2 + t * travel - 2),
                           height: trackHeight - 4)
                    .padding(.leading, 2)

                knob
                    .offset(x: t * travel)
            }
            .frame(height: zoneHeight - 4)
            .overlay(alignment: .bottom) {
                tickMarks(width: width)
            }
            .contentShape(Rectangle())
            .hoverCursor(.pointingHand)
            .gesture(dragGesture(width: width))
        }
        .frame(height: zoneHeight)
    }

    private var knob: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(WatchTheme.caseInk)
            .frame(width: knobSize.width, height: knobSize.height)
            .overlay(
                // Center tick: yellow at rest, green while the fader is engaged.
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(dragging ? WatchTheme.lcdGreen : WatchTheme.caseYellow)
                    .frame(width: 2, height: 10)
            )
            .overlay(knobHovering && !dragging ? Color.white.opacity(0.25) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .scaleEffect(knobHovering && !dragging ? 1.05 : 1)
            .animation(.easeOut(duration: 0.12), value: knobHovering)
            .onHover { knobHovering = $0 }
            .help("drag to adjust · double-click to reset")
    }

    private func tickMarks(width: CGFloat) -> some View {
        Canvas { ctx, size in
            let travel = max(1, width - knobSize.width)
            var marks: [(Double, CGFloat)] = [(range.lowerBound, 3), (range.upperBound, 3)]
            if let strideBy = tickStride, strideBy > 0 {
                var v = range.lowerBound + strideBy
                while v < range.upperBound - 0.0001 {
                    marks.append((v, 3))
                    v += strideBy
                }
            }
            if centerTick {
                marks.append(((range.lowerBound + range.upperBound) / 2, 5))
            }
            for (v, height) in marks {
                let x = knobSize.width / 2 + fraction(of: v) * travel
                let rect = CGRect(x: x - 0.5, y: size.height - height, width: 1, height: height)
                ctx.fill(Path(rect), with: .color(WatchTheme.caseInk.opacity(0.4)))
            }
        }
        .frame(height: 5)
        .allowsHitTesting(false)
    }

    // MARK: - Value math

    private func fraction(of v: Double) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(min(1, max(0, (v - range.lowerBound) / span)))
    }

    private func snapped(_ raw: Double) -> Double {
        let stepped = (raw / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, stepped))
    }

    private func value(atX x: CGFloat, width: CGFloat) -> Double {
        let travel = max(1, width - knobSize.width)
        let t = min(1, max(0, (x - knobSize.width / 2) / travel))
        return snapped(range.lowerBound + Double(t) * (range.upperBound - range.lowerBound))
    }

    private func apply(_ newValue: Double, animated: Bool = false) {
        guard newValue != value else { return }
        if dragging {
            // Every snapped step ticks — the dense tactility is the point.
            // Drawn detents (ticks and bounds) knock harder: .levelChange is
            // a noticeably heavier pulse than .alignment on the trackpad.
            let pattern: NSHapticFeedbackManager.FeedbackPattern =
                crossesDetent(from: value, to: newValue) ? .levelChange : .alignment
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.12)) { value = newValue }
        } else {
            value = newValue
        }
    }

    /// Whether a value change lands on or passes a drawn detent (tick or
    /// bound) — those get the heavier haptic accent.
    private func crossesDetent(from old: Double, to new: Double) -> Bool {
        let lo = min(old, new)
        let hi = max(old, new)
        if hi >= range.upperBound || lo <= range.lowerBound { return true }
        guard let strideBy = tickStride, strideBy > 0 else { return false }
        return floor((lo - range.lowerBound) / strideBy) != floor((hi - range.lowerBound) / strideBy)
    }

    // MARK: - Gestures

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if !dragBegan {
                    dragBegan = true
                    // AppKit knows the click count; a TapGesture(count: 2)
                    // would delay every drag that starts on the knob.
                    if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
                        resetPending = true
                        withAnimation(.easeOut(duration: 0.12)) { value = defaultValue }
                        return
                    }
                    dragging = true
                    let travel = max(1, width - knobSize.width)
                    let knobCenterX = knobSize.width / 2 + fraction(of: value) * travel
                    if abs(g.location.x - knobCenterX) <= knobSize.width / 2 + 4 {
                        // Grabbed the knob: keep the current value and track
                        // relative to the grab point, so an off-center press
                        // doesn't nudge fine-step sliders.
                        grabOffset = g.location.x - knobCenterX
                    } else {
                        // First contact on the track is a jump: animate the
                        // knob to the click.
                        grabOffset = 0
                        apply(value(atX: g.location.x, width: width), animated: true)
                    }
                } else if !resetPending {
                    apply(value(atX: g.location.x - grabOffset, width: width))
                }
            }
            .onEnded { _ in
                dragging = false
                dragBegan = false
                resetPending = false
                grabOffset = 0
            }
    }

    // No scroll-wheel adjustment: every monitor/gesture approach either
    // hijacks page scrolling over the full-width tracks or leaks a local
    // monitor when the knob moves out from under a stationary cursor.
    // Drag, click-jump, keyboard, and double-click reset cover the need.

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let coarse = coarseStep ?? (step * 5)
        let delta = press.modifiers.contains(.shift) ? coarse : step
        switch press.key {
        case .leftArrow:
            apply(snapped(value - delta))
            return .handled
        case .rightArrow:
            apply(snapped(value + delta))
            return .handled
        case .home:
            apply(range.lowerBound)
            return .handled
        case .end:
            apply(range.upperBound)
            return .handled
        default:
            return .ignored
        }
    }
}

extension WatchSlider {
    /// Integer-range convenience (grid size and friends).
    init(label: String,
         value: Binding<Int>,
         in range: ClosedRange<Int>,
         step: Int = 1,
         defaultValue: Int,
         tickStride: Int? = nil,
         chipWidth: CGFloat = WatchMetrics.valueChipWidth,
         format: @escaping (Int) -> String) {
        self.init(
            label: label,
            value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ),
            in: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            defaultValue: Double(defaultValue),
            tickStride: tickStride.map(Double.init),
            chipWidth: chipWidth,
            format: { format(Int($0.rounded())) }
        )
    }
}
