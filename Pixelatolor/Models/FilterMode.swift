import Foundation

enum FilterMode: String, CaseIterable {
    case threshold
    case otsu
    case adaptive
    case contrastBoost
    case cleanThreshold
    case edgeDetect
    case floydSteinberg
    case bayerDither

    var displayName: String {
        switch self {
        case .threshold: return "Threshold"
        case .otsu: return "Otsu"
        case .adaptive: return "Adaptive"
        case .contrastBoost: return "Contrast"
        case .cleanThreshold: return "Clean"
        case .edgeDetect: return "Outline"
        case .floydSteinberg: return "Floyd-Steinberg"
        case .bayerDither: return "Ordered Dither"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .threshold, .otsu, .adaptive, .contrastBoost, .cleanThreshold:
            return displayName
        case .edgeDetect:
            return "Outline"
        case .floydSteinberg:
            return "Floyd"
        case .bayerDither:
            return "Ordered"
        }
    }
}
