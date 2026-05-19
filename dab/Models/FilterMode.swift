import Foundation

enum FilterMode: String, CaseIterable {
    case colorMatch
    case threshold
    case halftone
    case edgeDetect

    var displayName: String {
        switch self {
        case .colorMatch: return "Color Match"
        case .threshold: return "Threshold"
        case .halftone: return "Halftone"
        case .edgeDetect: return "Outline"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .colorMatch:
            return "Color"
        case .threshold, .halftone:
            return displayName
        case .edgeDetect:
            return "Outline"
        }
    }
}
