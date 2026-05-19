import Foundation

enum FilterMode: String, CaseIterable {
    case colorMatch
    case threshold
    case edgeDetect

    var displayName: String {
        switch self {
        case .colorMatch: return "Color Match"
        case .threshold: return "Threshold"
        case .edgeDetect: return "Outline"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .colorMatch:
            return "Color"
        case .threshold:
            return displayName
        case .edgeDetect:
            return "Outline"
        }
    }
}
