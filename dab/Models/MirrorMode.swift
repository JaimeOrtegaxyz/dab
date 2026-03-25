import Foundation

enum HorizontalMirrorMode: String, CaseIterable {
    case none
    case leftToRight
    case rightToLeft

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .leftToRight: return "Left -> Right"
        case .rightToLeft: return "Right -> Left"
        }
    }

    var statusLabel: String? {
        switch self {
        case .none: return nil
        case .leftToRight: return "H L->R"
        case .rightToLeft: return "H R->L"
        }
    }

    var next: HorizontalMirrorMode {
        switch self {
        case .none: return .leftToRight
        case .leftToRight: return .rightToLeft
        case .rightToLeft: return .none
        }
    }
}

enum VerticalMirrorMode: String, CaseIterable {
    case none
    case topToBottom
    case bottomToTop

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .topToBottom: return "Top -> Bottom"
        case .bottomToTop: return "Bottom -> Top"
        }
    }

    var statusLabel: String? {
        switch self {
        case .none: return nil
        case .topToBottom: return "V T->B"
        case .bottomToTop: return "V B->T"
        }
    }

    var next: VerticalMirrorMode {
        switch self {
        case .none: return .topToBottom
        case .topToBottom: return .bottomToTop
        case .bottomToTop: return .none
        }
    }
}
