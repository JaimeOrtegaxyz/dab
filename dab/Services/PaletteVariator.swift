import Foundation

enum PaletteVariator {
    /// Returns a deterministic variation of `palette` for the given seed.
    /// Seed 0 returns the input unchanged. Non-zero seeds permute the
    /// non-transparent swatches into a different positional order while
    /// keeping the exact same set of colors (no new hues are invented).
    /// Transparent swatches keep their original positions so transparent
    /// assignment in the filters continues to work.
    ///
    /// The mapping from seed to permutation is the lexicographic order of
    /// permutations, decoded via factorial-base decomposition of the seed.
    /// For N non-transparent swatches there are N! distinct permutations;
    /// seeds outside `0..<N!` wrap around, including negative seeds.
    static func variation(of palette: [PaletteSwatch], seed: Int) -> [PaletteSwatch] {
        guard seed != 0 else { return palette }

        // Collect non-transparent swatches with their original positions.
        var slots: [Int] = []
        var swatches: [PaletteSwatch] = []
        for (index, swatch) in palette.enumerated() where !swatch.isTransparent {
            slots.append(index)
            swatches.append(swatch)
        }

        guard swatches.count > 1 else { return palette }

        let permuted = permutation(of: swatches, seed: seed)

        // Rebuild the palette: transparent positions are untouched,
        // non-transparent positions get filled in the permuted order.
        var result = palette
        for (slot, position) in slots.enumerated() {
            result[position] = permuted[slot]
        }
        return result
    }

    private static func permutation<T>(of items: [T], seed: Int) -> [T] {
        let n = items.count
        guard n > 1 else { return items }

        // Precompute factorials up to n!.
        var factorials = [Int](repeating: 1, count: n + 1)
        for i in 1...n {
            factorials[i] = factorials[i - 1] * i
        }

        // Reduce the seed into [0, n!). Swift's % can return negatives, so
        // normalize by adding n! once.
        let total = factorials[n]
        var remaining = ((seed % total) + total) % total

        var available = items
        var result: [T] = []
        result.reserveCapacity(n)

        for k in stride(from: n, through: 1, by: -1) {
            let bucket = factorials[k - 1]
            let pickIndex = remaining / bucket
            result.append(available.remove(at: pickIndex))
            remaining %= bucket
        }

        return result
    }
}
