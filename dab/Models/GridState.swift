import Foundation

enum GridCell: Hashable {
    case palette(Int)
    case transparent
}

/// How the grid is drawn. Cycled with the `r` key: squares → dots → blobs.
enum RenderMode: Int, CaseIterable {
    /// Crisp pixels.
    case squares
    /// Rounded blobs over a single dominant-color background grout.
    case dots
    /// Rounded blobs over a palette-order grout (lowest palette index wins gaps).
    case blobs

    var next: RenderMode {
        let all = RenderMode.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var displayName: String {
        switch self {
        case .squares: return "Squares"
        case .dots: return "Dots"
        case .blobs: return "Blobs"
        }
    }
}

struct GridState {
    let size: Int
    var palette: [PaletteSwatch]
    var cells: [GridCell]
    var isInverted: Bool = false
    var horizontalMirrorMode: HorizontalMirrorMode = .none
    var verticalMirrorMode: VerticalMirrorMode = .none
    var renderMode: RenderMode = .squares

    init(size: Int, palette: [PaletteSwatch] = PaletteSwatch.defaultPalette) {
        self.size = size
        self.palette = Array(palette.prefix(8))
        self.cells = Array(repeating: .transparent, count: size * size)
    }

    func effectiveCell(row: Int, col: Int) -> GridCell {
        guard row >= 0, row < size, col >= 0, col < size else { return .transparent }

        let r: Int
        switch verticalMirrorMode {
        case .none:
            r = row
        case .topToBottom:
            r = row < size / 2 ? row : size - 1 - row
        case .bottomToTop:
            r = row < size / 2 ? size - 1 - row : row
        }

        let c: Int
        switch horizontalMirrorMode {
        case .none:
            c = col
        case .leftToRight:
            c = col < size / 2 ? col : size - 1 - col
        case .rightToLeft:
            c = col < size / 2 ? size - 1 - col : col
        }

        let index = r * size + c
        guard index >= 0, index < cells.count else { return .transparent }
        return inverted(cells[index])
    }

    func effectivePaletteIndex(row: Int, col: Int) -> Int? {
        guard !palette.isEmpty else { return nil }

        switch effectiveCell(row: row, col: col) {
        case .transparent:
            return nil
        case .palette(let index):
            let clampedIndex = min(max(index, 0), palette.count - 1)
            guard !palette[clampedIndex].isTransparent else { return nil }
            return clampedIndex
        }
    }

    func effectiveSwatch(row: Int, col: Int) -> PaletteSwatch? {
        guard let index = effectivePaletteIndex(row: row, col: col) else {
            return nil
        }

        return palette[index]
    }

    func usedEffectivePaletteIndices() -> [Int] {
        var indices = Set<Int>()
        for row in 0..<size {
            for col in 0..<size {
                if let index = effectivePaletteIndex(row: row, col: col) {
                    indices.insert(index)
                }
            }
        }
        return indices.sorted()
    }

    /// The most-used effective palette index — the "background" color for Dots
    /// mode. Ties break toward the lowest index for determinism.
    func dominantPaletteIndex() -> Int? {
        var counts: [Int: Int] = [:]
        for row in 0..<size {
            for col in 0..<size {
                if let index = effectivePaletteIndex(row: row, col: col) {
                    counts[index, default: 0] += 1
                }
            }
        }
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }?.key
    }

    private func inverted(_ cell: GridCell) -> GridCell {
        guard isInverted, !palette.isEmpty else {
            return cell
        }

        switch cell {
        case .transparent:
            return .transparent
        case .palette(let index):
            let clampedIndex = min(max(index, 0), palette.count - 1)
            return .palette(palette.count - 1 - clampedIndex)
        }
    }
}
