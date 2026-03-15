import Foundation

struct GridState {
    let size: Int
    var cells: [Bool]  // true = black cell
    var isInverted: Bool = false
    var mirrorHorizontal: Bool = false
    var mirrorVertical: Bool = false

    init(size: Int) {
        self.size = size
        self.cells = Array(repeating: false, count: size * size)
    }

    /// Returns the effective cell value accounting for inversion and mirroring
    func effectiveCell(row: Int, col: Int) -> Bool {
        guard row >= 0, row < size, col >= 0, col < size else { return false }
        let r = mirrorVertical ? (size - 1 - row) : row
        let c = mirrorHorizontal ? (size - 1 - col) : col
        let index = r * size + c
        guard index >= 0, index < cells.count else { return false }
        let value = cells[index]
        return isInverted ? !value : value
    }

    /// Creates grid from brightness values and threshold
    static func from(brightness: [Float], gridSize: Int, threshold: Float) -> GridState {
        var state = GridState(size: gridSize)
        for i in 0..<min(brightness.count, gridSize * gridSize) {
            state.cells[i] = brightness[i] < threshold  // darker than threshold = black
        }
        return state
    }
}
