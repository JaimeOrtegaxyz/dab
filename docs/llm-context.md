# dab LLM Context

This document is meant to be given to another language model so it can quickly understand what dab is, what it does, what kind of product it wants to be, and how to reason about future ideas, copy, positioning, or visual direction.

It is intentionally more interpretive than a technical spec. Some parts below are hard facts from the current app. Some parts are inferred product intent based on the implementation and the existing tone of the project. That distinction is called out where it matters.

## One-Paragraph Summary

dab is a macOS menu bar utility that lets a user sample a live area of their screen around the cursor, reduce it to a small palette-mapped pixel grid, preview the result in real time, and export that result as an SVG made of exact square cells. It was built first as the icon-making tool for a separate project, Surface & Logic, and second as something that can be open-sourced for others who want to explore a similar visual language. The app is not trying to be a full image editor. It is a fast reduction tool: summon it, hover over something interesting, tune the simplification, and save a crisp color SVG interpretation of that moment.

## Stable Product Facts

These are true of the current app as implemented.

- dab is a macOS app.
- It lives in the menu bar and can also be triggered via a configurable global hotkey.
- When activated, it opens a floating preview window near the cursor and samples the screen area around that cursor position.
- The preview updates live as the mouse moves.
- The sampled image is reduced to a square grid.
- Each cell maps to one swatch from an editable palette, or to a transparent swatch when the palette includes one.
- The default palette is black, green, red, yellow, and blue.
- The user can change grid size, viewport size, resize step, brightness threshold, filter mode, palette colors, horizontal flip, vertical flip, save location, filename format, and activation hotkey.
- The user can invert the preview into a negative mode while the overlay is active.
- The user can enter a "randomizer" mode while the overlay is active. Pressing Z toggles it on; while on, `]` and `[` step through deterministically hue-rotated variations of the current palette. The user's stored palette is never modified — randomization is a view layer on top. Saving a frame while randomizing exports whatever variation is currently displayed. The last-used variation index persists across sessions, but the randomizer itself always starts off when the overlay is summoned.
- The user can save the current result as an SVG.
- The current square-cell SVG export is deliberately literal: each non-transparent pixel becomes its own 1x1 square in the SVG grid, with no geometry merging.
- The export background is transparent.
- The app exists first as an internal tool for generating iconography for Surface & Logic, and then as a tool that can be shared publicly.
- The app currently offers four filters:
  - Color Match
  - Threshold
  - Halftone
  - Outline

## Origin Story And Why It Matters

dab is not just a utility that happened to be built in the abstract. It exists because the author wants to create the icon language for a separate project called Surface & Logic.

That matters because it gives the app a real center of gravity. The project is not trying to answer a vague market prompt like "what if there were a pixel tool." It is solving a specific creative need inside a larger brand and studio worldview.

The plan is:

- build the tool for a real internal use case
- use it to generate the pixelated icons that populate Surface & Logic branding
- then open-source it as a kind of honest process artifact
- meaning: "this is the actual tool behind that visual language, feel free to use it if it speaks to you"

That origin gives dab a more interesting story than a generic utility. It is both a tool and evidence of a process.

## Relationship To Surface & Logic

Surface & Logic is built around a core tension: the visible encounter on one side, and the structural system underneath it on the other. In that framing:

- surface means the thing a person perceives immediately: the visual style, the composition, the expressiveness, the personality
- logic means the system that makes the result hold together: constraints, structure, documentation, reproducibility, and ownership

dab fits that philosophy unusually well.

The surface side of dab is obvious:

- bold pixel forms
- strong reduction
- graphic palette-constrained output
- a playful, stylized result

The logic side is equally important:

- exact square cells
- exact palette decisions
- repeatable filters
- strict grid structure
- predictable SVG output
- no hidden smoothing or fake vectorization

That is not incidental. dab is a concrete expression of the same ideology behind Surface & Logic: playful outcomes made trustworthy by constraints.

In Surface & Logic terms, dab says something like this:

"We can let the surface be bold because the logic underneath is disciplined."

## What dab Is Trying To Do

This section is partly interpretive, but it is the most important section for downstream LLM use.

dab is best understood as a reduction instrument.

Its job is not to preserve a screenshot faithfully. Its job is to take high-density, full-color, high-detail screen content and crush it into something simpler, sharper, stranger, and more symbolic. The output should feel intentional rather than merely degraded. A good result looks like a tiny emblem, icon, mark, glyph, diagram fragment, or lo-fi visual sample.

For the original use case, those outputs are meant to become part of the iconography of Surface & Logic itself. So the app should not be understood as merely making "pixel art." It is helping generate a brand language through a constrained system.

The app is not primarily about nostalgia, even though pixel aesthetics are part of the surface appeal. It is more about transformation through constraint:

- too much detail becomes just enough detail
- smooth images become block structure
- gradients become judgment calls
- complex UI becomes pattern
- a screen moment becomes a reusable visual asset

The existing voice inside the app, "Turning retina displays into potato displays," is playful and self-aware. That suggests the project is comfortable being a little irreverent, but the actual product behavior is fairly precise. The tone should not drift into pure joke software. The joke opens the door; the usefulness keeps the product interesting.

## Core User Experience

The intended experience is fast, direct, and tactile.

The user flow is roughly:

1. Trigger dab from the menu bar or hotkey.
2. Move the cursor over some part of the screen they want to sample.
3. Watch a live simplified preview follow the cursor.
4. Adjust the interpretation on the fly:
   - grid size
   - viewport size
   - threshold
   - filter mode
   - negative mode
   - horizontal or vertical flip
5. Click once to save the current result as SVG.
6. Return immediately to whatever they were doing.

That interaction model matters. dab should feel closer to a capture tool, scanner, loupe, or live sampler than to a document-centric editor. It should not feel heavy. It should not ask the user to import, manage layers, or build a composition from scratch. It is opportunistic: the user steals shapes from what is already on screen.

## What Makes The Output Special

The output is not just "an SVG export of a screenshot." It is a very particular kind of SVG:

- square grid
- uniform cell size
- palette-colored active cells
- optional transparent cells
- no anti-aliased geometry
- no soft edges
- no shape-merging logic
- no hidden vector smoothing

This matters conceptually. The export should feel like a clean, literal pixel matrix that just happens to be encoded in SVG. It is not pretending to be curved vector art. It is preserving the logic of pixels while gaining the portability and composability of vector output.

That means downstream uses can include:

- icons
- visual marks
- textures
- logos or logo sketches
- print motifs
- generative design inputs
- zine graphics
- stickers
- motion design source material
- references for manual tracing or refinement

## The Role Of Filters

The filters are not just "effects." They are alternate decision systems for how to reduce a captured area into a palette grid.

The filters are:

- Color Match: maps each source pixel to the nearest non-transparent palette color and picks the majority winner per cell. Transparent assignment is handled separately by an ordered brightness band when the palette includes a transparent swatch. This is the default and the most color-faithful option.
- Threshold: collapses each cell's average brightness into ordered palette bands. The palette is internally sorted by brightness for band assignment so the threshold slider behaves predictably regardless of how the user has arranged the palette in the editor. The slider biases the whole image toward darker or brighter swatches.
- Halftone: same brightness-to-band reduction as Threshold, but ordered dithering (an 8x8 Bayer matrix) decides whether each cell rounds up or down at band boundaries. Pixels near a band center keep their nearest band; pixels near a boundary form a regular stipple pattern between the two adjacent swatches. Produces a print-process feel.
- Outline: edge detection. Edge cells take the nearest palette color of their underlying source; non-edge cells take the background (the first transparent swatch if present, otherwise the brightest non-transparent swatch). The slider controls edge sensitivity.

If another LLM is asked to propose future filters, the guiding question should be:

"Does this produce more usable, legible, intentionally reduced outputs at small grid sizes?"

That question is more important than whether a filter sounds mathematically interesting.

## Who This Is For

The primary user, in the most literal sense, is the author of the app using it to make visual assets for Surface & Logic.

The secondary audience is broader. dab is likely most relevant to people who already think visually and work quickly:

- designers
- creative coders
- motion designers
- artists
- UI designers
- identity designers
- people collecting visual fragments
- people who enjoy reduction, constraints, and lo-fi reinterpretation

It may also appeal to people who like niche utilities and playful tools. The important nuance is that it is playful and genuinely useful at the same time.

## What It Is Not

This is equally important for positioning and copy.

dab is not:

- a full image editor
- a batch image converter
- an AI image generator
- a screenshot annotation app
- a vector tracing tool in the Illustrator sense
- a polished photo-to-logo automation system
- a retro game asset editor
- a raster painting app

It borrows from some of those categories, but it should not be described in a way that creates the wrong expectation.

## Product Personality

The product has a distinct personality, and downstream copy or visual exploration should preserve it.

Good traits:

- clever
- compact
- slightly weird
- toolish
- visual
- fast
- precise
- playful without being disposable

Traits to avoid:

- corporate
- productivity-app blandness
- pseudo-magical AI language
- nostalgia cliches as the whole identity
- "for everyone" positioning
- overly technical academic framing

The brand voice can absolutely be witty, but it should still communicate that the tool is real and useful.

Another useful way to say this is:

- the tool is playful because the constraints are strong
- the output can be expressive because the system underneath is strict
- this is very aligned with the broader Surface & Logic worldview

## A Good Mental Model For Copy

When writing copy, it may help to think in terms of verbs. dab:

- samples
- reduces
- distills
- pixelates
- thresholds
- simplifies
- captures
- extracts
- converts
- freezes
- turns screen detail into graphic structure

Good copy probably treats the app as something that helps the user grab structure out of visual noise.

It can also be framed as a way of building a visual system from reduction, especially for iconography, marks, or modular brand assets.

Examples of the kind of framing that fits:

- a live pixel sampler
- a screen-to-grid reduction tool
- a way to turn on-screen detail into crisp palette SVGs
- a utility for stealing tiny visual systems from your screen
- a menu bar tool for reducing anything on screen into exportable pixel vectors

## A Good Mental Model For Visual Direction

If another LLM is asked to propose visual ideas for the project, it should understand that the visual identity should emerge from:

- grids
- squares
- palette and transparent-swatch logic
- high-density to low-density transformation
- sampling windows
- cropping
- cursor-centric capture
- palette decisions
- live reduction

Promising visual directions:

- strict modular grids
- magnified cell structures
- before/after density contrasts
- tiny viewports blown up big
- constrained color systems with one to eight swatches
- UI motifs based on loupe, cursor, crop, scan, or capture logic
- logos or marks built from modular cell clusters

Less aligned directions:

- generic neon cyberpunk pixel art
- retro arcade references as the default answer
- overcomplicated isometric worlds
- soft gradients with vague tech vibes
- AI-generated "pixel aesthetic" collage without a strong grid logic

## Important UX Principles

These principles are not formally declared in the codebase, but they are strongly implied by the app structure and should guide future ideas.

- The tool should feel immediate.
- The user should be able to stay in flow.
- The overlay should expose the result, not distract from it.
- Controls should support live tuning, not force setup upfront.
- Exports should be predictable.
- The reduced result should feel deliberate, not accidental.
- Small-grid legibility matters more than filter novelty.

## Important Implementation Constraints

These are useful for ideation because they define the real boundaries of the current product.

- It is macOS-only right now.
- It depends on Screen Recording permission.
- It captures around the cursor, not from a standalone canvas.
- The current output format is SVG.
- The output is palette-constrained, with up to eight swatches and optional transparency.
- The app is optimized around live preview and one-click save, not post-processing.
- The preview is fundamentally grid-based, so the right creative ideas are ones that respect the grid rather than trying to hide it.

## What Another LLM Should Assume By Default

If another LLM receives this file and is asked to generate ideas, it should assume the following unless told otherwise:

- The point is to make reduction feel intentional and artistically useful.
- The output should stay crisp, square, and palette-constrained.
- Simplicity beats feature bloat.
- Fast interaction beats deep configuration.
- The best ideas are those that strengthen the app as a small sharp utility, not as a sprawling editor.
- Creative direction should come from reduction, capture, and grid logic, not from generic "pixel art" tropes.

## Useful Short Description

If a downstream workflow needs a compact summary, this is a good default:

dab is a macOS menu bar tool that samples the screen under your cursor, reduces it into a live palette-mapped pixel grid, and exports the result as crisp square-cell SVG.

## Useful Expanded Description

If a downstream workflow needs a more expressive summary, this is a good default:

dab turns any part of your screen into a tiny palette-constrained pixel composition. You trigger it, hover over something interesting, watch a live reduced preview follow the cursor, tune the interpretation with different filters, palette swatches, and controls, and click once to save a crisp SVG made from exact square cells. It is less like a full editor and more like a fast visual reduction instrument for designers, artists, and anyone who wants to extract graphic structure from on-screen detail.

## Open Interpretive Space

This project still leaves room for multiple valid positioning choices. A future copy or branding pass could emphasize any of these angles:

- internal studio tool turned open-source
- playful utility
- creative sampling tool
- lo-fi reduction instrument
- icon and mark generator from live screen fragments
- visual research and extraction tool
- niche design companion app

The strongest direction will likely be the one that keeps all three of these ideas in balance:

- it is useful
- it is distinctive
- it is fun without becoming trivial
