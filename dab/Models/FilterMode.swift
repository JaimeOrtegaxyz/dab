import Foundation

enum FilterMode: String, CaseIterable {
    case colorMatch
    case threshold
    case otsu
    case adaptive
    case contrastBoost
    case cleanThreshold
    case edgeDetect

    var displayName: String {
        switch self {
        case .colorMatch: return "Color Match"
        case .threshold: return "Threshold"
        case .otsu: return "Otsu"
        case .adaptive: return "Adaptive"
        case .contrastBoost: return "Contrast"
        case .cleanThreshold: return "Clean"
        case .edgeDetect: return "Outline"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .colorMatch:
            return "Color"
        case .threshold, .otsu, .adaptive, .contrastBoost, .cleanThreshold:
            return displayName
        case .edgeDetect:
            return "Outline"
        }
    }
}
