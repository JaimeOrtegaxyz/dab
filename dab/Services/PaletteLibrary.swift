import Foundation

/// One entry on the palette shelf.
///
/// The overlay's `c` key walks these in order and the settings dropdown lists
/// them in the same order, so "what cycling does" and "what the list shows" are
/// the same sequence by construction rather than by two copies staying in sync.
struct PaletteEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        /// A `PaletteSwatch.presets` entry the user hasn't deleted.
        case builtIn
        /// One of the user's named palettes.
        case saved(UUID)
        /// The single working slot — see `PaletteLibrary.syncUnsavedSlot`.
        case unsaved
    }

    var kind: Kind
    var name: String
    var swatches: [PaletteSwatch]

    var id: String {
        switch kind {
        case .builtIn: return "builtin:\(name)"
        case .saved(let uuid): return "saved:\(uuid.uuidString)"
        case .unsaved: return "unsaved"
        }
    }

    var isUnsaved: Bool { kind == .unsaved }
}

/// The palette shelf: built-in presets, the user's saved palettes, and one
/// working slot for an edit that hasn't been named yet. Shared by the capture
/// overlay and the settings window so both agree on what exists and in what
/// order.
enum PaletteLibrary {
    /// Label for the working slot, in the dropdown and the overlay flash.
    static let unsavedName = "unsaved"

    // MARK: - Sources

    /// Built-ins the user has deleted. Stored as names rather than indices so
    /// shipping or reordering a preset doesn't silently hide a different one.
    private static var hiddenBuiltInNames: Set<String> {
        get { Set(AppSettings.shared.hiddenPresetNames) }
        set { AppSettings.shared.hiddenPresetNames = Array(newValue).sorted() }
    }

    static var builtIns: [PaletteEntry] {
        let hidden = hiddenBuiltInNames
        return PaletteSwatch.presets
            .filter { !hidden.contains($0.name) }
            .map { PaletteEntry(kind: .builtIn, name: $0.name, swatches: $0.swatches) }
    }

    static var saved: [PaletteEntry] {
        AppSettings.shared.savedPalettes.map {
            PaletteEntry(kind: .saved($0.id), name: $0.name, swatches: $0.swatches)
        }
    }

    /// The working slot, when the user has an unnamed edit parked in it.
    static var unsaved: PaletteEntry? {
        guard let swatches = AppSettings.shared.stashedPalette else { return nil }
        return PaletteEntry(kind: .unsaved, name: unsavedName, swatches: swatches)
    }

    /// Everything, in cycle order: built-ins, then yours, then the working slot.
    static var entries: [PaletteEntry] {
        builtIns + saved + (unsaved.map { [$0] } ?? [])
    }

    // MARK: - Matching

    /// Exact compare is right here: palettes are applied verbatim, never
    /// interpolated, so a swatch either is the preset's colour or isn't.
    static func matches(_ lhs: [PaletteSwatch], _ rhs: [PaletteSwatch]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
            $0.color == $1.color && $0.isTransparent == $1.isTransparent
        }
    }

    /// The shelf entry `palette` currently *is*, or nil if it matches nothing.
    static func entry(matching palette: [PaletteSwatch]) -> PaletteEntry? {
        entries.first { matches($0.swatches, palette) }
    }

    // MARK: - Cycling

    /// The next entry after whatever `palette` currently is, wrapping around.
    /// A palette that matches nothing on the shelf starts the walk at the top.
    static func next(after palette: [PaletteSwatch]) -> PaletteEntry? {
        let all = entries
        guard !all.isEmpty else { return nil }
        guard let index = all.firstIndex(where: { matches($0.swatches, palette) }) else {
            return all[0]
        }
        return all[(index + 1) % all.count]
    }

    // MARK: - The working slot

    /// Parks `palette` in the working slot when it matches no named palette, and
    /// empties the slot once it does (there's nothing left to lose, so nothing
    /// to show).
    ///
    /// Call this on *edits* only — never when switching palettes. Switching to
    /// "lite brite" must leave the slot alone, or stepping past a preset with
    /// `c` would throw away the very edit the slot exists to protect.
    static func syncUnsavedSlot(with palette: [PaletteSwatch]) {
        let isNamed = (builtIns + saved).contains { matches($0.swatches, palette) }
        AppSettings.shared.stashedPalette = isNamed ? nil : palette
    }

    /// Empties the working slot — used once its contents have been saved under
    /// a real name.
    static func clearUnsavedSlot() {
        AppSettings.shared.stashedPalette = nil
    }

    /// Throws the working slot away without saving it — the escape hatch for a
    /// parked edit the user has decided against, so it stops being a permanent
    /// stop in the cycle and the dropdown.
    ///
    /// Returns a palette to switch the live selection onto when the slot being
    /// discarded *was* the live one (there'd otherwise be nothing selected);
    /// `nil` when it wasn't, so the caller leaves the live palette untouched.
    /// The fallback is the first named shelf entry — `canDelete` guarantees at
    /// least one always exists, so the default is just belt-and-suspenders.
    static func discardUnsaved(livePalette: [PaletteSwatch]) -> [PaletteSwatch]? {
        let wasLive = unsaved.map { matches($0.swatches, livePalette) } ?? false
        clearUnsavedSlot()
        guard wasLive else { return nil }
        return (builtIns + saved).first?.swatches ?? PaletteSwatch.defaultPalette
    }

    /// Parks `palette` if it's on the shelf nowhere at all — a custom palette
    /// carried over from before the working slot existed, which no edit has
    /// passed through since.
    ///
    /// Call before *switching away*. Unlike `syncUnsavedSlot` this leaves a
    /// named palette's slot alone, so stepping onto "lite brite" can't clear an
    /// unrelated parked edit.
    static func parkIfUnknown(_ palette: [PaletteSwatch]) {
        guard entry(matching: palette) == nil else { return }
        AppSettings.shared.stashedPalette = palette
    }

    // MARK: - Deleting

    /// Whether `entry` can be removed. The shelf must always keep at least one
    /// named palette, or the dropdown and the `c` cycle would have nothing to
    /// offer. The working slot isn't deletable: it empties itself when saved or
    /// when the palette is edited back onto a named one.
    static func canDelete(_ entry: PaletteEntry) -> Bool {
        guard !entry.isUnsaved else { return false }
        return builtIns.count + saved.count > 1
    }

    /// Removes `entry` from the shelf. A deleted palette that's still the live
    /// one lands in the working slot rather than vanishing out from under the
    /// user mid-edit.
    static func delete(_ entry: PaletteEntry, livePalette: [PaletteSwatch]) {
        guard canDelete(entry) else { return }

        switch entry.kind {
        case .builtIn:
            hiddenBuiltInNames.insert(entry.name)
        case .saved(let id):
            AppSettings.shared.savedPalettes.removeAll { $0.id == id }
        case .unsaved:
            return
        }

        // Only when the deleted palette was the live one: it just lost its
        // name, so park it instead of letting it vanish mid-use. Deleting any
        // *other* palette must leave the slot alone — it may be holding an
        // unrelated edit, and syncing against a named live palette would wipe
        // it.
        if matches(entry.swatches, livePalette) {
            syncUnsavedSlot(with: livePalette)
        }
    }

    /// Whether any built-in has been deleted, so the settings dropdown knows to
    /// offer the way back.
    static var hasHiddenBuiltIns: Bool {
        !hiddenBuiltInNames.isEmpty
    }

    /// Brings every deleted built-in back. There's no per-preset undo: the
    /// hidden set is small and unordered, so one restore is the whole story.
    static func restoreBuiltIns() {
        hiddenBuiltInNames = []
    }
}

extension Notification.Name {
    /// Posted when the live palette or the shelf changes outside the settings
    /// window — today that's `c` in the capture overlay.
    ///
    /// The settings window is built once and reused across openings, so its
    /// `onAppear` won't fire again to re-read `AppSettings`. Without this its
    /// `@State` palette would go stale and the next edit would write the stale
    /// copy back over whatever `c` selected.
    static let dabPaletteDidChange = Notification.Name("dabPaletteDidChange")
}
