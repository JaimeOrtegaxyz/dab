import Foundation

enum FilterMode: String, CaseIterable {
    case threshold
    case otsu
    case adaptive
    case edgeDetect
    case floydSteinberg
    case bayerDither

    var displayName: String {
        switch self {
        case .threshold: return "Threshold"
        case .otsu: return "Otsu"
        case .adaptive: return "Adaptive"
        case .edgeDetect: return "Edge Detect"
        case .floydSteinberg: return "Floyd-Steinberg"
        case .bayerDither: return "Bayer Dither"
        }
    }
}
