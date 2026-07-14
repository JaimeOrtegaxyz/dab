import SwiftUI
import AppKit

/// The dab dropdown, rebuilt as a themed panel because macOS gives no public
/// hook to restyle an `NSMenu`'s own window (its blur, corners, shadow, and
/// padding are all system-drawn). Losing the menu means rebuilding what it gave
/// for free — dismissal, keyboard nav, ⌘-equivalents, the button highlight —
/// which lives here and in `StatusBarController`.
///
/// A borderless panel can't take key focus by default, so we override
/// `canBecomeKey`; the controller activates the app on open so keystrokes
/// actually reach us (a background app's window can't be key otherwise).
final class StatusMenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// One row of the dropdown. `key` is both the functional ⌘-equivalent and the
/// source of the hint glyph, so the two can't drift apart.
struct StatusMenuCommand: Identifiable {
    let id = UUID()
    let title: String
    let key: KeyEquivalent?
    let dividerAfter: Bool
    let action: () -> Void

    init(_ title: String,
         key: KeyEquivalent? = nil,
         dividerAfter: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.key = key
        self.dividerAfter = dividerAfter
        self.action = action
    }

    /// `⌘,` / `⌘Q` — command char uppercased so letters read like a menu.
    var shortcutLabel: String? {
        key.map { "⌘\(String($0.character).uppercased())" }
    }
}

/// The yellow-cased dropdown that mirrors the settings window's bezel: a
/// rounded caseYellow plate with an ink stroke, Inconsolata rows, and an
/// lcd-green "selected" wash reusing the render-key grammar (green fill = the
/// active choice). Highlight is shared by hover and arrow keys.
struct StatusMenuView: View {
    let commands: [StatusMenuCommand]
    let onDismiss: () -> Void

    @State private var selection: Int? = nil
    @FocusState private var focused: Bool

    private let plateWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                row(index: index, command: command)
                if command.dividerAfter {
                    Rectangle()
                        .fill(WatchTheme.caseInk.opacity(0.22))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(6)
        .frame(width: plateWidth)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(WatchTheme.caseYellow)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(WatchTheme.caseInk, lineWidth: 1)
                )
        )
        // Take focus so arrow keys / Return / Esc route here rather than to a
        // stray Button; the ⌘-equivalents fire window-wide regardless.
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onExitCommand { onDismiss() }
        .onKeyPress { handleKey($0) }
    }

    private func row(index: Int, command: StatusMenuCommand) -> some View {
        let isActive = selection == index
        return Button {
            perform(command)
        } label: {
            HStack(spacing: 8) {
                Text(command.title)
                    .font(WatchFont.body(13, weight: .semibold))
                    .tracking(0.5)
                Spacer(minLength: 12)
                if let shortcut = command.shortcutLabel {
                    Text(shortcut)
                        .font(WatchFont.body(12, weight: .medium))
                        .foregroundStyle(WatchTheme.caseInk.opacity(isActive ? 0.7 : 0.45))
                }
            }
            .foregroundStyle(WatchTheme.caseInk)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? WatchTheme.lcdGreen : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(command.key.map { KeyboardShortcut($0, modifiers: .command) })
        .hoverCursor(.pointingHand)
        .onHover { hovering in
            if hovering { selection = index }
            else if selection == index { selection = nil }
        }
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            move(1); return .handled
        case .upArrow:
            move(-1); return .handled
        case .return, KeyEquivalent(" "):
            if let index = selection { perform(commands[index]) }
            return .handled
        default:
            return .ignored
        }
    }

    private func move(_ delta: Int) {
        let count = commands.count
        guard count > 0 else { return }
        let current = selection ?? (delta > 0 ? -1 : 0)
        selection = ((current + delta) % count + count) % count
    }

    private func perform(_ command: StatusMenuCommand) {
        onDismiss()
        command.action()
    }
}
