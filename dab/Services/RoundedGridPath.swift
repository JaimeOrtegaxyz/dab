import CoreGraphics
import Foundation

enum RoundedGridPath {
    private struct GridPoint: Hashable {
        let x: Int
        let y: Int
    }

    private struct Edge {
        let start: GridPoint
        let end: GridPoint

        var direction: Direction {
            Direction(dx: end.x - start.x, dy: end.y - start.y)
        }
    }

    private struct RoundedCorner {
        let entry: CGPoint
        let corner: CGPoint
        let exit: CGPoint
    }

    private enum Direction {
        case up
        case right
        case down
        case left

        init(dx: Int, dy: Int) {
            switch (dx, dy) {
            case (0, -1):
                self = .up
            case (1, 0):
                self = .right
            case (0, 1):
                self = .down
            case (-1, 0):
                self = .left
            default:
                fatalError("Unsupported edge direction (\(dx), \(dy))")
            }
        }

        var turnPriority: [Direction] {
            [turnedRight, self, turnedLeft, opposite]
        }

        private var turnedRight: Direction {
            switch self {
            case .up: return .right
            case .right: return .down
            case .down: return .left
            case .left: return .up
            }
        }

        private var turnedLeft: Direction {
            switch self {
            case .up: return .left
            case .left: return .down
            case .down: return .right
            case .right: return .up
            }
        }

        private var opposite: Direction {
            switch self {
            case .up: return .down
            case .down: return .up
            case .left: return .right
            case .right: return .left
            }
        }
    }

    static func cgPath(for grid: GridState, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let loops = simplifiedBoundaryLoops(for: grid)
        let bridgeCenters = diagonalBridgeCenters(for: grid)
        guard !loops.isEmpty || !bridgeCenters.isEmpty else { return path }

        let cellWidth = rect.width / CGFloat(grid.size)
        let cellHeight = rect.height / CGFloat(grid.size)
        let radius = min(cellWidth, cellHeight) / 2

        for loop in loops {
            let points = loop.map {
                CGPoint(
                    x: rect.minX + CGFloat($0.x) * cellWidth,
                    y: rect.minY + CGFloat($0.y) * cellHeight
                )
            }
            appendRoundedLoop(points, radius: radius, to: path)
        }

        for center in bridgeCenters {
            appendDiagonalBridge(
                at: CGPoint(
                    x: rect.minX + CGFloat(center.x) * cellWidth,
                    y: rect.minY + CGFloat(center.y) * cellHeight
                ),
                radius: radius,
                to: path
            )
        }

        return path
    }

    static func svgBoundaryPathData(for grid: GridState) -> String {
        simplifiedBoundaryLoops(for: grid)
            .map { loop in
                let points = loop.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
                return svgPath(for: points, radius: 0.5)
            }
            .joined(separator: " ")
    }

    static func svgBridgePathData(for grid: GridState) -> String {
        diagonalBridgeCenters(for: grid)
            .map { svgDiagonalBridge(at: CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)), radius: 0.5) }
            .joined(separator: " ")
    }

    private static func simplifiedBoundaryLoops(for grid: GridState) -> [[GridPoint]] {
        boundaryLoops(for: grid).map(simplify)
    }

    private static func diagonalBridgeCenters(for grid: GridState) -> [GridPoint] {
        guard grid.size >= 2 else { return [] }

        var centers: [GridPoint] = []

        for row in 0..<(grid.size - 1) {
            for col in 0..<(grid.size - 1) {
                let topLeft = grid.effectiveCell(row: row, col: col)
                let topRight = grid.effectiveCell(row: row, col: col + 1)
                let bottomLeft = grid.effectiveCell(row: row + 1, col: col)
                let bottomRight = grid.effectiveCell(row: row + 1, col: col + 1)

                let forwardDiagonal = topLeft && bottomRight && !topRight && !bottomLeft
                let backwardDiagonal = topRight && bottomLeft && !topLeft && !bottomRight

                if forwardDiagonal || backwardDiagonal {
                    centers.append(GridPoint(x: col + 1, y: row + 1))
                }
            }
        }

        return centers
    }

    private static func boundaryLoops(for grid: GridState) -> [[GridPoint]] {
        let edges = boundaryEdges(for: grid)
        guard !edges.isEmpty else { return [] }

        var outgoing = [GridPoint: [Int]]()
        for (index, edge) in edges.enumerated() {
            outgoing[edge.start, default: []].append(index)
        }

        var unused = Set(edges.indices)
        var loops: [[GridPoint]] = []

        while let startIndex = unused.min() {
            let startEdge = edges[startIndex]
            var loop: [GridPoint] = [startEdge.start]
            var currentIndex = startIndex

            while true {
                unused.remove(currentIndex)
                let currentEdge = edges[currentIndex]
                let nextPoint = currentEdge.end

                if nextPoint == startEdge.start {
                    break
                }

                loop.append(nextPoint)

                guard let nextIndex = nextEdgeIndex(
                    after: currentEdge,
                    from: nextPoint,
                    edges: edges,
                    outgoing: outgoing,
                    unused: unused
                ) else {
                    break
                }

                currentIndex = nextIndex
            }

            if loop.count >= 3 {
                loops.append(loop)
            }
        }

        return loops
    }

    private static func boundaryEdges(for grid: GridState) -> [Edge] {
        var edges: [Edge] = []

        for row in 0..<grid.size {
            for col in 0..<grid.size where grid.effectiveCell(row: row, col: col) {
                if !grid.effectiveCell(row: row - 1, col: col) {
                    edges.append(Edge(start: GridPoint(x: col, y: row), end: GridPoint(x: col + 1, y: row)))
                }
                if !grid.effectiveCell(row: row, col: col + 1) {
                    edges.append(Edge(start: GridPoint(x: col + 1, y: row), end: GridPoint(x: col + 1, y: row + 1)))
                }
                if !grid.effectiveCell(row: row + 1, col: col) {
                    edges.append(Edge(start: GridPoint(x: col + 1, y: row + 1), end: GridPoint(x: col, y: row + 1)))
                }
                if !grid.effectiveCell(row: row, col: col - 1) {
                    edges.append(Edge(start: GridPoint(x: col, y: row + 1), end: GridPoint(x: col, y: row)))
                }
            }
        }

        return edges
    }

    private static func nextEdgeIndex(
        after edge: Edge,
        from point: GridPoint,
        edges: [Edge],
        outgoing: [GridPoint: [Int]],
        unused: Set<Int>
    ) -> Int? {
        guard let candidates = outgoing[point] else { return nil }

        for direction in edge.direction.turnPriority {
            if let match = candidates.first(where: { unused.contains($0) && edges[$0].direction == direction }) {
                return match
            }
        }

        return nil
    }

    private static func simplify(_ points: [GridPoint]) -> [GridPoint] {
        guard points.count >= 3 else { return points }

        var simplified = points
        var changed = true

        while changed, simplified.count >= 3 {
            changed = false

            for index in simplified.indices.reversed() {
                let prev = simplified[(index - 1 + simplified.count) % simplified.count]
                let current = simplified[index]
                let next = simplified[(index + 1) % simplified.count]

                if (prev.x == current.x && current.x == next.x) ||
                    (prev.y == current.y && current.y == next.y) {
                    simplified.remove(at: index)
                    changed = true
                }
            }
        }

        return simplified
    }

    private static func appendRoundedLoop(_ points: [CGPoint], radius: CGFloat, to path: CGMutablePath) {
        let corners = roundedCorners(for: points, radius: radius)
        guard !corners.isEmpty else { return }

        path.move(to: corners[0].entry)

        for (index, corner) in corners.enumerated() {
            if index > 0 {
                path.addLine(to: corner.entry)
            }
            path.addQuadCurve(to: corner.exit, control: corner.corner)
        }

        path.closeSubpath()
    }

    private static func svgPath(for points: [CGPoint], radius: CGFloat) -> String {
        let corners = roundedCorners(for: points, radius: radius)
        guard let first = corners.first else { return "" }

        var commands = ["M \(svg(first.entry))"]

        for (index, corner) in corners.enumerated() {
            if index > 0 {
                commands.append("L \(svg(corner.entry))")
            }
            commands.append("Q \(svg(corner.corner)) \(svg(corner.exit))")
        }

        commands.append("Z")
        return commands.joined(separator: " ")
    }

    private static func appendDiagonalBridge(at center: CGPoint, radius: CGFloat, to path: CGMutablePath) {
        let top = CGPoint(x: center.x, y: center.y - radius)
        let right = CGPoint(x: center.x + radius, y: center.y)
        let bottom = CGPoint(x: center.x, y: center.y + radius)
        let left = CGPoint(x: center.x - radius, y: center.y)

        path.move(to: top)
        path.addQuadCurve(to: right, control: center)
        path.addQuadCurve(to: bottom, control: center)
        path.addQuadCurve(to: left, control: center)
        path.addQuadCurve(to: top, control: center)
        path.closeSubpath()
    }

    private static func svgDiagonalBridge(at center: CGPoint, radius: CGFloat) -> String {
        let top = CGPoint(x: center.x, y: center.y - radius)
        let right = CGPoint(x: center.x + radius, y: center.y)
        let bottom = CGPoint(x: center.x, y: center.y + radius)
        let left = CGPoint(x: center.x - radius, y: center.y)

        return [
            "M \(svg(top))",
            "Q \(svg(center)) \(svg(right))",
            "Q \(svg(center)) \(svg(bottom))",
            "Q \(svg(center)) \(svg(left))",
            "Q \(svg(center)) \(svg(top))",
            "Z",
        ].joined(separator: " ")
    }

    private static func roundedCorners(for points: [CGPoint], radius: CGFloat) -> [RoundedCorner] {
        guard points.count >= 3 else { return [] }

        var corners: [RoundedCorner] = []

        for index in points.indices {
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]

            let incoming = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
            let outgoing = CGPoint(x: next.x - current.x, y: next.y - current.y)
            let incomingLength = hypot(incoming.x, incoming.y)
            let outgoingLength = hypot(outgoing.x, outgoing.y)
            guard incomingLength > 0, outgoingLength > 0 else { continue }

            let cornerRadius = min(radius, incomingLength / 2, outgoingLength / 2)
            let entry = CGPoint(
                x: current.x - incoming.x / incomingLength * cornerRadius,
                y: current.y - incoming.y / incomingLength * cornerRadius
            )
            let exit = CGPoint(
                x: current.x + outgoing.x / outgoingLength * cornerRadius,
                y: current.y + outgoing.y / outgoingLength * cornerRadius
            )

            corners.append(RoundedCorner(entry: entry, corner: current, exit: exit))
        }

        return corners
    }

    private static func svg(_ point: CGPoint) -> String {
        "\(svg(point.x)) \(svg(point.y))"
    }

    private static func svg(_ value: CGFloat) -> String {
        let formatted = String(format: "%.3f", value)
        let trimmedZeros = formatted.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        let trimmedDecimal = trimmedZeros.replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
        return trimmedDecimal.isEmpty ? "0" : trimmedDecimal
    }
}
