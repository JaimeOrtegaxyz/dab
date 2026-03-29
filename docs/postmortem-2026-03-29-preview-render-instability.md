# Postmortem: Preview Render Instability

- Date: March 29, 2026
- Status: Resolved
- Branches involved: `codex-troubleshoot` -> `main`

## Summary

The live preview pipeline regressed after the screen-capture refactor. The overlay opened quickly, but rendered output was unstable and visually incorrect: noisy/staggered shapes, drifting pixels, and glitchy jumps even on simple high-contrast targets.

## User-visible symptoms

- Output looked weakly related to underlying content.
- Otsu and Outline appeared to "move on their own" while pointer was still.
- Straight UI elements (for example, white input bars) looked crooked/staggered.
- Motion felt glitchy (snaps/jumps) rather than continuous transition.

## Root causes

1. Frame ownership/lifetime handling was too weak:
- The service kept only `CVPixelBuffer` references from stream callbacks.
- This increased risk of reading unstable/reused frame data.

2. Frame quality gate was missing:
- Non-complete `ScreenCaptureKit` frames were not filtered out.

3. Stream lifecycle/configuration ordering:
- A live stream could be started during prewarm, before overlay session state was fully aligned.
- On activation, that stream could be reused instead of rebuilt, causing stale capture/exclusion behavior.

4. App-exclusion robustness:
- Capture relied on cached `SCShareableContent` app data.
- If current PID exclusion was missing in cached data, overlay self-capture/feedback risk increased.

## Fixes implemented

1. Strengthened frame snapshot model:
- Store `CMSampleBuffer` in snapshots, not only `CVPixelBuffer`.
- Resolve image buffer from sample at read time.

2. Added frame status validation:
- Only accept `.complete` frames from stream attachments.

3. Corrected overlay/capture session flow:
- Ensure overlay is established before active capture session is used.
- Force a fresh stream setup on capture start so exclusions/config are rebuilt for current session.

4. Hardened exclusion lookup:
- If current PID is absent from cached shareable content, force-refresh once before creating filter.
- Emit warning when exclusion still cannot be resolved.

5. Prewarm behavior reduced to metadata warmup:
- Prewarm no longer starts a long-lived stream that can be reused with stale context.

## Files changed

- `dab/Services/ScreenCaptureService.swift`
- `dab/App/AppDelegate.swift`
- `dab/ViewModels/CaptureViewModel.swift`

## Verification

- User re-tested on real UI targets (Google logo text, white input bar).
- Final result reported as fixed.

## Build/signing note

- For persistent TCC behavior across builds, app bundles must be signed consistently with the same Apple Development identity.
- This fix was built and signed with:
  - `B6263C6F33FB6C841AB4CE6026F1B2B24768B222`
  - `Apple Development: Jesus Jaime Ortega Cruz (PQSAA2QC4N)`

## Prevention checklist

- Always gate stream frames by `SCFrameStatus == .complete`.
- Keep owning frame references (`CMSampleBuffer`) while sampling.
- Avoid reusing prewarm-started streams for first interactive overlay session.
- On stream start, verify exclusion inputs are present; force-refresh once when missing.
- Keep a short "capture sanity" manual test:
  - straight horizontal/vertical bars
  - high-contrast text
  - still-cursor stability check
