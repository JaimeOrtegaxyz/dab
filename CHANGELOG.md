# Changelog

All notable changes to dab are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Branded the DMG install window with a custom background and an app volume
  icon.

## [0.5.1] - 2026-07-25

### Changed

- Built-in presets and saved palettes now live in one unified shelf; presets
  seed in on first run and behave like ordinary palettes.
- Default activation hotkey is now `` ⌃⇧` `` (Control-Shift-backtick), changed
  from `⌘⇧P`.
- Updated Sparkle to 2.9.4.

## [0.5.0] - 2026-07-25

First public release.

### Added

- Real-time screen pixelation: a global hotkey opens a borderless overlay that
  tracks the cursor and re-renders ~30×/s from a ScreenCaptureKit stream.
- Three render modes — **squares**, **dots**, and **blobs** — cycled with `r`.
- Four filters — **Color Match**, **Threshold**, **Halftone**, and
  **Outline** — each with a spread / threshold / edge-sensitivity dial.
- Grids from 4×4 up to 64×64.
- Editable palettes of up to 8 swatches (one optionally see-through), with
  built-in presets and room to save your own.
- SVG export: click to capture the current frame as scalable vector output.
- Self-updating via Sparkle, with notarized builds.

[Unreleased]: https://github.com/JaimeOrtegaxyz/dab/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/JaimeOrtegaxyz/dab/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/JaimeOrtegaxyz/dab/releases/tag/v0.5.0
