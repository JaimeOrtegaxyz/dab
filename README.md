# dab

A macOS menu-bar app that turns any patch of your screen into pixel art, live.

Press the hotkey and a capture viewport follows your cursor, quantizing
whatever is under it into a small grid of palette colors in real time. Click
to save the result as an SVG. That's the whole loop: point, tune, dab.

## How it works

- **Capture** — a global hotkey (default `⌘⇧P`) opens a borderless overlay
  that tracks the mouse and re-renders ~30×/s from a ScreenCaptureKit stream.
- **Quantize** — each grid cell is matched against your palette through one of
  four filters: **Color Match** (nearest color, per-pixel voting), **Threshold**
  (brightness bands), **Halftone** (Bayer-dithered bands), or **Outline**
  (Sobel edges).
- **Render** — three arrangements: **squares** (classic pixels), **dots**
  (rounded blobs on a dominant-color ground), **blobs** (rounded regions with
  palette-order grout).
- **Save** — click captures the current frame to SVG. Vector output, so the
  result scales to print size.

## Overlay controls

| Key | Action |
|---|---|
| `← / →` | resize viewport |
| `↑ / ↓` | grid size (4–64) |
| `+ / -` | the current filter's dial (spread, threshold, or edge sensitivity) |
| `shift` + any of the above | larger jumps |
| `f` | cycle filter mode |
| `r` | cycle squares / dots / blobs |
| `c` | cycle palettes |
| `z` | palette randomizer |
| `h` / `v` | mirror horizontally / vertically |
| `space` | invert |
| `esc` | close |
| click | save SVG and close |

Palettes are editable in Settings (up to 8 swatches, one of them optionally
see-through), with built-in presets and room to save your own.

## Install

Download the latest `.dmg` from
[Releases](https://github.com/JaimeOrtegaxyz/dab/releases), mount it, and drag
dab to `/Applications`. The app is notarized and updates itself via Sparkle.

Requires **macOS 14+** on **Apple silicon**. dab needs two permissions to
function — **Screen Recording** (to sample pixels) and **Accessibility** (for
the overlay's keyboard controls); it prompts for both on first run.

## Build from source

```
git clone https://github.com/JaimeOrtegaxyz/dab.git
cd dab
./build.sh
open dab.app
```

`build.sh` produces a locally-signed development bundle. Plain `swift build`
works too if you only want the binary compiled.

## License

[MIT](LICENSE)
