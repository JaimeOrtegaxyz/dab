# dab — original Seedance 2.0 promo concept bible

Four ~12s vertical gag videos (Seedance hard cap 15s per generation). Not product ads — absurdist jokes where "pixels" are a substance/condition in a mundane world. Tone: late-night 90s alt-cartoon block. Aesthetic lifted from `~/Downloads/ref-anim-frames` (the fly short).

This file remains the concept source for Videos 2–4 and the original visual/cast
bible for Video 1. **Do not submit the old Video 1 prompt below.** Coffee Shop
production has been superseded by the final modular specification in
`storyboards/v1-coffee-shop-production.md`. That document contains the approved
passes, 26-second edit, local repairs, sound mix, reusable outro, and the process
rules that should guide Videos 2–4.

---

## Job spec for the still-generation pass (Codex)

**Deliverables — 14 stills**, 9:16 vertical, into `promo/stills/`:

| File | What |
|---|---|
| `s0-pixels.png` | The pixel substance (shared asset, used in every video) |
| `v1-s1.png` `v1-s2.png` `v1-s3.png` | Coffee shop: first frame / punch shot / aftermath |
| `v2-s1.png` `v2-s2.png` `v2-s3.png` `v2-s4.png` | Optometrist: first frame / lens POV / blob doctor / pixel street |
| `v3-s1.png` `v3-s2.png` `v3-s3.png` | Vending machine: first frame / half-transformed / sprite form |
| `v4-s1.png` `v4-s2.png` `v4-s3.png` | Lake: first frame / fish two-shot / de-rezzing lake |

**Process:** write your own image-gen prompts (be as florid as you like), but every still must satisfy (a) the style bible, (b) the video's cast & set sheets, (c) its own REQUIRED list. If your image tool accepts reference images, attach these style anchors from `~/Downloads/ref-anim-frames`: `frame_006` (wide color-block set), `frame_012` (character on set), `frame_017` (extreme character close-up), plus `frame_020` (top-down perspective example).

**Acceptance checklist, every still:**
- [ ] 9:16, flat color-block set per the set sheet, palette only
- [ ] Thick wobbly black ink outlines, uneven weight; sketchy stray ticks on flat fields; paper grain + dust
- [ ] Characters match their cast sheet exactly (shape, colors, clothing, eye style)
- [ ] ZERO readable text anywhere (in-world signage = unreadable black squiggles)
- [ ] No logos, no watermarks, no UI
- [ ] Pixel substance (where present) matches `s0-pixels.png`: oversized chunky squares, wobbly ink outline each, palette colors

---

## Style bible (from the reference frames)

**Format:** vertical 9:16.

**Palette** (approx hex — sample from the ref frames if in doubt; eyes beat numbers):
- Mustard yellow `#F0A429` · olive green `#8A9A1F` · hot pink `#F2586E` · pale salmon `#F5C6AE` · teal `#4FB8C0` · tomato red `#E33226` · chocolate brown `#7B3F20` · ink black `#14100E`
- Flat, ultra-saturated fields, ZERO gradients. Backgrounds are 2–3 stacked color bands (wall/floor or sky/water).

**Perspective:** default staging is flat and frontal (color-block theater)… punctuated by occasional EXTREME perspective for dramatic effect — fisheye bulge, top-down bird's eye, worm's-eye with a tight vertical vanishing point. Rare, deliberate, always at the emotional turn. Each video has exactly one designated punch shot (marked in the shot lists).

**Line:** thick, wobbly hand-inked black outlines with uneven weight; stray sketchy hairline ticks and specks scattered across the flat color fields; scribbly hair/fuzz texture on characters.

**Surface:** paper grain, dust motes, faint scratches — worn-cel / risograph feel, slight frame jitter like hand-drawn animation on 2s.

**Characters:** bulbous grotesque-cute; eyes are enormous glossy orbs dominating the head; spindly limbs; tiny mouths; deadpan default expression. Specific limb/skin colors are locked per character in the cast sheets.

**The pixel substance (`s0-pixels.png`):** oversized chunky squares — each square roughly fist-sized relative to a character's head — in mustard, teal, hot pink, tomato red and olive; every square carries its own wobbly black ink outline; they pile, pour and cascade with soft physical weight (sand-avalanche, not confetti). This is what "pixels" look like in ALL four videos.

**Comedy grammar:** quiet deadpan build → sudden gross/surreal escalation → hold on the aftermath.

**Typography & logo — ALL LOCAL, NONE GENERATED:**
- No title cards, no logo, no readable text in any generation.
- Dialogue is delivered as CARDS: chunky 3D block letters, tomato red on hot pink, slight wobble (see `frame_029`). Cards are OVERLAYS composited on top of the running footage — they never pause or replace it, so they add zero runtime. Card text and timing are locked per video below.
- **Shared outro, built once, reused on all four (adds ~2.5s after the generation):** final held shot → pixelate away (use dab itself) → fade to flat mustard → dab logo. The 15s Seedance cap constrains the generation only, not the final cut.
- Every video ends on an **OUTRO HANDLE**: a stable, near-still, uncluttered final shot (~1s) that pixelates away cleanly.

---

## How to drive Seedance 2.0 (research summary)

- **Inputs:** up to 9 images, 3 videos (≤15s total), 3 audio files (≤15s total), 12 files max. Output 4–15s, selectable.
- **@ referencing:** tag each asset's role — `@Image1 as the first frame`, `@Image2 as reference for X`. Explicit roles; vague mentions underperform.
- **First frame vs reference:** "as the first frame" pins the opening exactly; "as reference" borrows look without forcing the frame. Drift grows with time from the first frame (12s > 15s).
- **Text-only vs image-anchored:** text-only drifts on character/style consistency; image-anchored is the production standard. Stills-first is our workflow.
- **Prompt weighting:** first 20–30 words matter most — lead with subject + core action.
- **Don't over-reference:** 3–4 images per generation max, not the full 9.
- **Multi-shot:** describe shots together, shared references. Fallback if the cut structure comes back mushy: split at the escalation point into 2 generations, stitch (pass 2 first frame = pass 1 last frame, or `Extend @Video1`).
- **Audio:** don't count on generated audio; SFX per shot list is added locally (keep Seedance's audio only as a base layer if it happens to be good).

**Per generation:** first frame pinned + 2–3 references (S0 counts as one when pixels appear), 9:16, duration as specified per video.

---

## Video 1 — "WITH PIXELS." (coffee shop) — 12.0s generation

**Logline:** A customer complains her coffee didn't come with pixels. The room laughs. The cup answers.

### Cast (locked)

- **MABEL** — the customer. Squat, pear-shaped, two heads tall. Salmon skin, spindly salmon arms. Enormous glossy white eyes, tiny black pupils, heavy upper lids. Tiny downturned mouth. Black scribble-hair in a tight bun. Boxy teal coat with two black buttons. Carries THE CUP.
- **CLERK** — the cashier. Tall and droopy, shoulders sagging. Olive-green skin. Enormous wet glossy eyes built for a sustained side-eye. A few mustache ticks. Hot-pink visor and hot-pink apron over a white tee.
- **THE LINE** (background, front-to-back): **NOODLE** — very tall, very thin man, mustard skin, head the size of a fist, chocolate turtleneck. **GRANNY TOAD** — round toad-like old lady, olive skin, chocolate coat, tiny round glasses. **EGG GUY** — egg-shaped sweaty man, salmon skin, teal polo, single hair. **WORM KID** — waist-high worm in a mustard hoodie, no arms.
- **THE CUP** — white paper cup, no lid, wobbly tomato-red squiggle for a logo, one steam wisp.

### Set (locked)

Mustard back wall (upper band) / olive floor (lower band). Hot-pink counter slab on the right third. Teal menu board hung top-right, covered in unreadable black squiggles. A grey wobbly box with one red light for an espresso machine behind the CLERK. Nothing else.

### Cards (local overlays; exact text, exact timing)

| # | Text | In–out |
|---|---|---|
| C1 | `HEY.` | 1.8–2.4s |
| C2 | `THIS AIN'T MY ORDER.` | 2.4–3.6s |
| C3 | `I ORDERED MINE WITH PIXELS.` | 5.0–6.4s |
| C4 (punchline) | `WITH PIXELS.` | 11.2s → through outro |

### Shot list (12.0s)

- **SH1 · 0.0–3.6 · wide, flat frontal (= `v1-s1` exactly).** Everyone frozen in place. At 0.8 MABEL thrusts THE CUP up toward CLERK and holds it there. THE LINE stares dead ahead; staggered single blinks. Steam wisp drifts. *SFX: room tone, fluorescent hum, tiny coffee slosh.*
- **SH2 · 3.6–6.4 · THE PUNCH SHOT.** Slow continuous push-in on CLERK's face, ending at extreme fisheye close-up (= `v1-s2`): eyes slid fully sideways in maximum side-eye, THE CUP reflected in both eyes, one eyelid twitch at 5.8. He never speaks. *SFX: thin rising sine drone; a single drip somewhere.*
- **SH3 · 6.4–8.2 · same wide as SH1.** At 6.5 every head in the room snaps back simultaneously; all mouths open huge (uvulas visible); bodies shake with laughter. MABEL doesn't laugh — she stares at her cup. *SFX: roaring ensemble laughter, one distinct wheeze.*
- **SH4 · 8.2–12.0 · same wide.** 8.2–8.8 THE CUP rumbles and rattles in MABEL's hand; 8.8 she peers INTO it; 9.2 it ERUPTS — a geyser of pixel substance (per `s0-pixels`) floods the room wall-to-wall as a heavy wave; characters flail; laughter turns to gargles. By 11.0 the surface settles into a still sea of pixels at mid-frame; ONE spindly arm in a teal sleeve (MABEL's) sticks out, motionless except one slow finger curl. **11.0–12.0 = OUTRO HANDLE.** *SFX: rumble → avalanche roar → abrupt silence at 11.0 → one bubble pop.*

### Stills (REQUIRED lists for Codex)

- **`v1-s1` (first frame — SH1 framing).** REQUIRED: full set per set sheet; CLERK behind the pink counter right; MABEL front-center, cup held aloft toward him; THE LINE receding to the left in order NOODLE → GRANNY TOAD → EGG GUY → WORM KID; menu board top-right; everyone deadpan, flat frontal staging.
- **`v1-s2` (reference — SH2 final frame).** REQUIRED: extreme fisheye close-up of CLERK's face filling the frame; both enormous wet eyes slid fully sideways; THE CUP visibly reflected inside each eye; hot-pink visor bulging with the wide-angle distortion; background just curved bands of mustard.
- **`v1-s3` (reference — SH4 final frame / outro handle).** REQUIRED: same wide framing as `v1-s1`; room flooded to mid-frame with settled pixel substance; mustard wall band + menu board still visible above the surface; one spindly teal-sleeved arm sticking straight out of the pixels; total calm.

### Seedance prompt

> A woman in a tiny cartoon coffee shop holds up a paper cup to complain, and the cup erupts, drowning the whole shop in an avalanche of giant square pixels. @Image1 as the first frame. @Image2 as reference for the cashier's fisheye close-up. @Image3 as reference for the flooded final shot. @Image4 as reference for what the pixels look like. Shot 1 (0–3.6s): static wide, the woman thrusts the cup up at the cashier and holds it, the queue of four odd customers stands dead still, deadpan. Shot 2 (3.6–6.4s): slow push-in to an extreme fisheye close-up of the cashier's enormous wet eyes in a sustained side-eye, the cup reflected in them, one eyelid twitch. Shot 3 (6.4–8.2s): back to the wide — every head snaps back at once and the whole room laughs hysterically with huge open mouths; the woman doesn't laugh. Shot 4 (8.2–12s): the cup rattles, she peers into it, it erupts like a volcano and floods the shop wall-to-wall with heavy chunky square pixels; everyone flails and sinks; the surface settles calm with one thin teal-sleeved arm sticking out; hold nearly still to the end. Hand-drawn 2D indie cartoon, flat saturated color fields, wobbly ink outlines, paper grain, subtle frame jitter, deadpan pacing, 12 seconds, vertical 9:16, no text.

---

## Video 2 — "BETTER OR WORSE" (optometrist) — 12.0s generation

**Logline:** An eye exam where every click re-renders the world — squares, dots, blobs. The patient chooses maximum blob. (Stealth nod to dab's three render modes; never stated.)

### Cast (locked)

- **PEARL** — the patient. Small and round. Mustard skin, spindly mustard limbs. Tall tomato-red beehive hairdo (scribble texture). Chocolate cardigan. Her eyes stay hidden behind the phoropter until SH4, where they're revealed: enormous glossy white orbs, tiny pupils.
- **DR. GLANZ** — the optometrist. Towering, three times Pearl's height. Completely bald tall dome head. Salmon skin. Enormous glossy heavy-lidded eyes, permanently calm. White lab coat over a teal turtleneck. Long spindly fingers, one always resting on the phoropter dial.

### Set (locked)

Exam room: olive wall band / teal floor band. Chocolate exam chair center. THE PHOROPTER: a hot-pink double-barreled lens machine hanging on a black wobbly arm, covering Pearl's face like giant insect eyes. One framed unreadable-squiggle diploma on the wall. Eye chart on a mustard wall section: white card, black glyphs that SUGGEST letters but are unreadable squiggles.
Final street (SH4): mustard building band / olive road band — every element re-rendered as pixel substance; only PEARL stays hand-drawn.

### Cards

| # | Text | In–out |
|---|---|---|
| C1 | `BETTER…` | 2.6–3.6s |
| C2 | `…OR WORSE?` | 4.8–5.8s |
| C3 (punchline) | `WORSE.` | 11.0s → through outro |

### Shot list (12.0s)

- **SH1 · 0.0–2.6 · wide, flat frontal (= `v2-s1`).** PEARL in the chair behind the phoropter, GLANZ looming beside, both motionless. At 1.8 his finger reaches the dial. CLICK at 2.4. *SFX: clinical hum; loud mechanical click.*
- **SH2 · 2.6–6.6 · POV through the phoropter's twin circles (= `v2-s2`).** Eye chart normal for a beat. CLICK 3.0 → glyphs snap into chunky squares. CLICK 4.2 → into round dots. CLICK 5.4 → into soft wobbling blobs that quiver gently. Slight zoom-in with each click. *SFX: three escalating clicks; wet squelch on the blob state.*
- **SH3 · 6.6–9.6 · THE PUNCH SHOT (= `v2-s3`).** Worm's-eye from the chair: GLANZ towers overhead, tight vertical vanishing point, ceiling far above. CLICK 7.0 → his legs re-render to squares. CLICK 7.9 → torso to dots. CLICK 8.8 → the entire doctor is a quivering blob-mosaic of himself, still calmly clicking. *SFX: clicks now boom with reverb; wet jiggle.*
- **SH4 · 9.6–12.0 · street exterior, flat frontal (= `v2-s4`).** Everything is pixel substance — buildings, lamppost, a passing bird as a drifting dot-cluster. PEARL (hand-drawn, huge eyes finally revealed) steps out, stops center, tiny serene smile at 10.8. **11.0–12.0 near-still = OUTRO HANDLE.** *SFX: muffled pixel-world ambience; one 8-bit bird chirp.*

### Stills (REQUIRED lists for Codex)

- **`v2-s1` (first frame).** REQUIRED: full exam room per set sheet; PEARL seated, face hidden by the hot-pink phoropter, beehive visible above it; GLANZ looming at her side, finger near the dial; flat frontal staging.
- **`v2-s2` (reference — SH2 squares state).** REQUIRED: view through two large round lens apertures (black vignette around them); white eye chart on mustard wall; its glyphs rendered as chunky unreadable square blocks; clinical, centered.
- **`v2-s3` (reference — SH3 final frame).** REQUIRED: extreme worm's-eye from the chair; GLANZ towering with strong vertical convergence; his entire body a mosaic of wobbling colored blobs (palette colors) while head/face silhouette stays readable; one long finger still on the dial; olive ceiling far above.
- **`v2-s4` (reference — SH4 / outro handle).** REQUIRED: street of pixel substance (mustard building band, olive road); PEARL the only hand-drawn element, standing small center, enormous eyes revealed, tiny smile; a bird as a loose cluster of dots mid-frame.

### Seedance prompt

> An eye exam where each loud lens click re-renders reality — into squares, then dots, then wobbling blobs — and the patient loves it. @Image1 as the first frame. @Image2 as reference for the view through the lens. @Image3 as reference for the transformed doctor. @Image4 as reference for the final pixelated street. Shot 1 (0–2.6s): static wide, the towering optometrist rests a finger on the huge pink lens machine, deadpan hold, one loud click. Shot 2 (2.6–6.6s): POV through the round lenses — the eye chart's glyphs snap into chunky squares, click, into round dots, click, into soft quivering blobs, zooming in slightly with each click. Shot 3 (6.6–9.6s): extreme worm's-eye from the chair — with each booming click the towering doctor himself re-renders, legs to squares, torso to dots, then his whole body a quivering blob mosaic, still calmly clicking. Shot 4 (9.6–12s): the small patient steps onto a street where everything is made of chunky pixels, stops, tiny serene smile, holds nearly still to the end. Hand-drawn 2D indie cartoon, flat saturated color fields, wobbly ink outlines, paper grain, subtle frame jitter, deadpan pacing, 12 seconds, vertical 9:16, no text.

---

## Video 3 — "CRUNCHY" (vending machine) — 12.0s generation

**Logline:** A man buys a bag of pixels from a vending machine and eats them like chips. Each crunch costs him resolution. Fully silent comedy — no dialogue cards, one punchline card.

### Cast (locked)

- **GARY** — slouchy man, shoulders up at ear height. Olive-green skin, spindly olive limbs. Huge tired glossy eyes with heavy black-tick bags. Sketchy stubble ticks. Tomato-red tracksuit with a white side stripe.
- **SPRITE-GARY** (final form) — GARY as a coarse pixel sprite about 12 blocks tall; tracksuit red preserved as red blocks; two dark square pixels for eyes; readable as the same guy.

### Set (locked)

Night hallway: chocolate wall band / olive floor band. One white wobbly rectangle of a buzzing tube light at top. THE MACHINE: teal vending machine, warm glowing interior, a 3×4 grid of identical hot-pink bags, each printed with a single black wobbly square; big tomato-red button panel; coin slot. Nothing else in the hallway.
**THE BAG:** hot-pink, single black square print. Contents: loose pixel-substance squares (per `s0-pixels`) with a faint glow.

### Cards

| # | Text | In–out |
|---|---|---|
| C1 (punchline) | `CRUNCHY.` | 11.0s → through outro |

### Shot list (12.0s)

- **SH1 · 0.0–3.0 · wide, flat frontal (= `v3-s1`).** GARY stands before THE MACHINE, motionless 0–1.0. Presses the button 1.2. The coil turns agonizingly slowly 1.4–2.6. THE BAG drops at 2.8 — THUNK. *SFX: fluorescent buzz, slow coil creak, heavy thunk.*
- **SH2 · 3.0–5.2 · THE PUNCH SHOT.** Top-down bird's-eye: GARY tiny and alone on the olive floor. Tears the bag open 3.4 (glow lights his face from below). Eats the first square 4.4 — a deafening echoing CRUNCH. *SFX: paper tear; glass-gravel crunch with long echo.*
- **SH3 · 5.2–9.4 · frontal medium close-up (= `v3-s2`).** He chews staring at nothing; crunch every ~0.8s, and with each crunch a region of him snaps into chunky mismatched squares: left cheek 5.6 → right ear 6.4 → both eyes 7.2 (now two dark square pixels) → top half of the head 8.0 → both hands 8.8. Expression never changes. *SFX: five crunches, each pitched lower than the last; tiny 8-bit blip per transformation.*
- **SH4 · 9.4–12.0 · wide, flat frontal (= `v3-s3`).** Mosaic-GARY holds up the LAST glowing square, regards it 9.4–10.0, eats it 10.2 → his whole body POPS into clean SPRITE-GARY 10.4. Long contented sigh 10.6. A blocky pixel heart floats up from 10.8, drifting slowly. **11.0–12.0 near-still (heart drift only) = OUTRO HANDLE.** *SFX: final crunch, soft "pop", long exhale, quiet 8-bit heart arpeggio.*

### Stills (REQUIRED lists for Codex)

- **`v3-s1` (first frame).** REQUIRED: full hallway per set sheet; THE MACHINE glowing with its 3×4 grid of identical pink square-printed bags; GARY slouched in front, finger on the red button; night gloom, tube light above.
- **`v3-s2` (reference — SH3 mid-state).** REQUIRED: frontal close-up of GARY mid-crunch, one glowing square between his fingers; left cheek and right ear already snapped into chunky mismatched squares while the rest stays hand-drawn; huge tired eyes still intact and staring at nothing; chocolate wall behind.
- **`v3-s3` (reference — SH4 final / outro handle).** REQUIRED: same wide as `v3-s1`; SPRITE-GARY standing where GARY stood, empty pink bag on the floor; one blocky pixel heart floating above his head; machine still glowing.

### Seedance prompt

> A slouchy man in a red tracksuit buys a bag of pixels from a vending machine at night and eats them like chips, losing resolution with every crunch. @Image1 as the first frame. @Image2 as reference for the half-transformed face. @Image3 as reference for the final pixel-sprite form. Shot 1 (0–3s): static wide, he presses the button, the coil turns agonizingly slowly, the pink bag drops with a heavy thunk. Shot 2 (3–5.2s): top-down bird's-eye of him tiny and alone in the hallway; he tears the bag, glow on his face, and eats the first square with a deafening echoing crunch. Shot 3 (5.2–9.4s): frontal close-up — with each rhythmic crunch another part of him snaps into chunky mismatched squares: left cheek, right ear, both eyes, top of the head, both hands; his tired expression never changes. Shot 4 (9.4–12s): wide — he regards the last glowing square, eats it, and his whole body pops into a neat low-res sprite of himself; long contented sigh; a single blocky heart floats slowly up; hold nearly still to the end. Hand-drawn 2D indie cartoon, flat saturated color fields, wobbly ink outlines, paper grain, subtle frame jitter, deadpan pacing, 12 seconds, vertical 9:16, no text.

---

## Video 4 — "CATCH & RELEASE" (the lake) — 13.0s generation

**Logline:** A fisherman catches a low-res fish. He does the right thing. The lake thanks him. The quiet one — no dialogue, near-silence, one punchline card.

### Cast (locked)

- **OTTO** — old fisherman. Salmon skin weathered with tick wrinkles. Huge tired glossy eyes, drooping lids. White scribble beard. **Mustard bucket hat** (key prop — it must survive to the final frame). Chocolate raincoat. Spindly limbs.
- **THE FISH** — a chunky pixel sprite, ~8×5 blocks: teal body, orange fins and tail, one dark square eye. It drips single square droplets. It blinks by its eye-block vanishing for a frame.

### Set (locked)

Dusk lake, two bands: pale-salmon sky (upper half) / dark teal water (lower half), separated by a thin chocolate horizon line. Tiny chocolate wooden boat center. Black wobbly fishing rod. Two or three distant black tick-marks of birds in the sky. Absolute stillness — Lynchian.

### Cards

| # | Text | In–out |
|---|---|---|
| C1 (punchline) | `CATCH & RELEASE.` | 12.0s → through outro |

### Shot list (13.0s)

- **SH1 · 0.0–4.0 · wide, flat frontal (= `v4-s1`).** Total stillness; only water-shimmer ticks. OTTO blinks slowly once at 2.0. At 3.4 the rod BENDS hard. *SFX: crickets, lapping water; reel zip at 3.4.*
- **SH2 · 4.0–7.4 · medium two-shot (= `v4-s2`).** OTTO reels; THE FISH rises from the water at 4.8 and hangs at his eye level, dripping square droplets — plip… plip. They stare at each other 5.4–6.8. THE FISH blinks once at 6.4 with an 8-bit beep. Then 6.8–7.4, **THE PUNCH SHOT insert:** top-down bird's-eye, the tiny boat alone in vast dark water. *SFX: slow reel clicks, square plips, one clean 8-bit beep, deep lake silence.*
- **SH3 · 7.4–10.4 · frontal medium (= `v4-s3` mid-state).** At 7.8 OTTO lowers THE FISH gently back in. At 8.2 the ripples at the contact point turn SQUARE. The squares spread across the water 8.2–9.4, climb into the sky 9.4–10.0, and the boat de-rezzes 10.0–10.4 — a slow cascade of pixel substance, like tetris-snow falling upward and outward. *SFX: soft cascading shimmer over a low warm drone.*
- **SH4 · 10.4–13.0 · wide.** OTTO, serene, sinks slowly into the pixel surface like a man settling into a warm bath (10.4–12.0). The mustard hat is the last thing to go under at 12.0 — and stays FLOATING on the surface. **12.0–13.0 near-still pixel surface + floating hat = OUTRO HANDLE.** *SFX: gentle square-sounding glugs, then near-silence, a single cricket.*

### Stills (REQUIRED lists for Codex)

- **`v4-s1` (first frame).** REQUIRED: two-band dusk composition per set sheet; tiny boat center with OTTO seated motionless, rod out; distant bird ticks; overwhelming stillness.
- **`v4-s2` (reference — SH2).** REQUIRED: medium two-shot — THE FISH hanging on the line at OTTO's eye level, dripping individual square droplets; OTTO's enormous tired eyes fixed on it; salmon dusk sky behind; sprite fish per cast sheet (teal body, orange fins, one dark square eye).
- **`v4-s3` (reference — SH3 mid-state).** REQUIRED: the lake half-transformed — one side still flat dark teal, the other cascading into chunky falling squares spreading across the water and up into the salmon sky; tiny boat caught between the two states.

### Seedance prompt

> A lone old fisherman at dusk catches a fish that is a low-resolution pixel sprite, gently releases it, and the whole world dissolves into pixels. @Image1 as the first frame. @Image2 as reference for the pixel fish two-shot. @Image3 as reference for the dissolving lake. Shot 1 (0–4s): static wide, tiny boat on a still dusk lake, nothing moves but a slow blink; at the end the rod suddenly bends hard. Shot 2 (4–7.4s): medium two-shot — he reels a chunky pixel-sprite fish up to eye level, it drips single square droplets, they stare at each other, the fish blinks once; brief top-down bird's-eye of the tiny boat on the vast dark water. Shot 3 (7.4–10.4s): he lowers the fish gently back in; where it touches, the ripples turn square and spread until water, sky and boat all de-rez into slowly cascading pixels. Shot 4 (10.4–13s): he sinks serenely into the pixel surface like a warm bath, his mustard bucket hat last, the hat left floating; hold nearly still on the calm pixel surface and floating hat to the end. Hand-drawn 2D indie cartoon, flat saturated color fields, wobbly ink outlines, paper grain, subtle frame jitter, quiet melancholic pacing, 13 seconds, vertical 9:16, no text.

---

## Production notes

- **Order of attack:** V3 (CRUNCHY) first — one character, one location, transformation gag = easiest; V2, V4, then V1 (crowd scene, hardest) last with lessons learned.
- **Consistency across the four:** generate all stills in one session with the same style anchors; pass `s0-pixels.png` as a reference in every Seedance call where pixel substance appears (V1 SH4, V2 SH4, V3 bag contents, V4 SH3–4).
- **Local finishing pass (built once):** card template (chunky 3D tomato-red block letters on hot pink, slight wobble, per `frame_029`) · shared outro (pixelate away with dab → mustard → logo) · SFX per shot lists + a warbly thrift-store synth bed (V4 gets near-silence instead).
- **If a multi-shot generation muddles the cuts:** split at the escalation point (V1: start of SH4 · V2: start of SH3 · V3: start of SH3 · V4: start of SH3) and stitch two passes.
