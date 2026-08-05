# Coffee Shop — final production specification

**Status:** final and approved. The finished delivery is
`videos/v1-coffee-shop-full-workflow-v5-final.mp4`.

This is the single Coffee Shop source of truth. It replaces every versioned
animatic, production, workflow, and review note that preceded it. The final is a
26-second modular edit assembled from six short Seedance generations, local
captions and continuity repairs, a reusable local outro, a supplied voice sting,
and a locally mixed music bed.

## Final timeline

| Timeline | Beat | Approved source |
| --- | --- | --- |
| 0.0–4.0 s | Wide angry complaint | `cgt-20260805070106-5ch8m`, full 4.0 s |
| 4.0–6.6 s | Close “with pixels” complaint | `cgt-20260805054321-68sf8`, source 0.0–2.6 s |
| 6.6–10.6 s | Oppressive clerk push-in | `cgt-20260805054327-qrphn`, full 4.0 s, pupil repair applied locally |
| 10.6–13.8 s | Sustained animal laughter | `cgt-20260805053809-tks5r`, source 0.0–3.2 s |
| 13.8–14.5 s | Blink-fast cup glance | `cgt-20260805054332-r8r2j`, source 0.45–1.15 s |
| 14.5–17.7 s | Immediate overhead brick rain | `cgt-20260805062958-d69l7`, source 0.0–3.2 s |
| 17.7–18.4 s | Local pixel-away transition | frozen approved aftermath |
| 18.4–21.6 s | Standalone animated dab outro | local |
| 21.6–26.0 s | Approved final lockup hold | local 4.4-second hold |

The content shots use hard cuts. The story ending does not animate directly into
the brand card: the local pixel-away transition removes the frozen aftermath and
reveals yellow, then the reusable standalone outro begins.

## Captions

Captions are local overlays, immediate rather than faded, with no background
rectangle. They use pale salmon fill and a thick ink-black outline.

| Timeline | Exact caption |
| --- | --- |
| 1.5–2.1 s | `HEY.` |
| 2.1–3.6 s | `THIS AIN'T MY ORDER.` |
| 4.4–6.6 s | `I ORDERED MINE` / `WITH PIXELS.` |

## Sound direction

Seedance generates the voices and physical effects for each content pass. The
performances are unintelligible but emphatically **not mumbled**: loud, angry,
raspy, abrasive, animal, and causally connected to what is visible. Strange
sound works when the wrong material still belongs to the right action—a paper
cup can resonate like wet sheet metal; falling blocks can strike like ceramic
wardrobes inside dumpsters. Whispering, sparse ambience, polite cartoon acting,
canned laughter, stock boings, generic magic, and random unrelated noise are
failures.

Music is never requested from Seedance. The local bed is
`audio/source-user/OHMYGAWD.mp3`, intentionally excluded from Git. Source time
19.5 seconds lands at the yellow reveal at final time 18.4 seconds. The local
voice sting is `audio/source-user/fuckyeahpixels.mp3` and starts at 19.5 seconds.
The music rises from 30% to 33% through the story and to 48% across the
pixel-away transition, then continues through the extended final hold.

Final decoded audio measures approximately −12.5 dBFS RMS with a −2.3 dBFS
decoded peak.

## Approved Seedance passes

All passes are vertical 720p, four seconds, with generated audio enabled and no
watermark. References are attached in the order shown.

## Pass 01 — left-hand angry wide

**References:** `v1-a1-wide-idle.png`, `v1-a1-angry-left-hand-v1.png`,
`v1-s1.png`.

### Seedance prompt

> [Image 1] is the exact neutral opening frame. [Image 2] is the exact angry target pose and the absolute anatomy reference. [Image 3] locks the original cast, room geography, palette, cup design, and correct hand ownership. Keep one locked-off wide shot with no zoom, push-in, crop, or cut. Mabel begins with the upright white cup in her LEFT hand, meaning the arm on the IMAGE-RIGHT side of her body next to the hot-pink counter. That same image-right forearm and hand must visibly own and grip the cup for every frame. The cup may rise slightly toward the clerk but must stay on the image-right side of her torso; it never crosses the center of her body, never transfers to her other hand, never touches the counter, and never leaves frame. After less than one second Mabel erupts into loud furious unintelligible raspy gibberish. Her empty RIGHT hand, on the IMAGE-LEFT side of her body, makes one compact angry point or chop without approaching the cup. Her mouth and eyebrows perform forcefully while the queue remains stiff and uncomfortable. AUDIO IS LOUD AND FOREGROUNDED: abrasive cracked gravel nonsense, like a broken megaphone scraped through sandpaper, with forceful nonverbal phonemes, a nasal snort, a dry voice crack, sleeve snaps, and a strangely heavy liquid slosh. Preserve the hand-drawn 2D indie-cartoon style, wobbly ink, saturated flat colors, paper grain, and handmade jitter. No understandable words, whispering, timid mumbling, music, captions, readable text, logos, watermark, camera move, crossed arms, cup swap, cup in the image-left hand, or cup on the counter.

## Pass 02 — angry pixels close

**References:** `v1-a2-mabel-mumble-v3.png`, `v1-s1.png`.

### Seedance prompt

> [Image 1] is the exact close composition and Mabel-to-counter distance; [Image 2] is cast and room continuity only. Mabel points hard at the cup and finishes an angry unintelligible sentence directly at the clerk. Keep Noodle and Granny Toad immediately behind her and the counter against her arm. Her face and shoulders visibly vibrate with projection; the cup remains intact. Preserve the illustration style, costumes, palette, paper texture, and wobbly line. AUDIO IS VERY LOUD: her voice is a sustained raspy noisy yell in nonsense phonemes, double-tracked imperfectly as if a second gravelly voice leaks out half a note lower. It must sound furious and exciting while remaining impossible to transcribe. Add one violent nasal snort, a dry voice crack, finger fabric squeak, and an absurdly resonant tap when she indicates the cup. No whisper, low mumble, restrained acting, understandable language, music, rhythm bed, cartoon boing, clean ADR, readable text, subtitles, logos, or watermark.

## Pass 03 — pressure clerk

**References:** `v1-a3-clerk-neutral.png`, `v1-s2-v4.png`, `v1-s1.png`.

### Seedance prompt

> Begin from [Image 1] with the clerk staring dead forward at Mabel. Creep continuously into the exact rough worried close-up in [Image 2]; the cup is reflected in both forward-facing eyes, the large sweat drop forms on green forehead skin rather than the visor, and the drawing becomes tactile and unpleasantly detailed. [Image 3] is continuity only. He never speaks. AUDIO IS OPPRESSIVE AND LOUD, not quiet ambience: fluorescent electricity swells into an unstable mechanical pressure tone, both huge eyes make amplified wet-rubber friction as they tense, the sweat bead lands with an impossible ceramic plink, and his single swallow sounds like a heavy animal gulp through a drainpipe. In the final tenth of a second, cut almost everything to a vacuum so the next laughter can explode. No generic suspense riser, heartbeat, whisper, speech, music, cinematic sting, readable text, subtitles, logos, or watermark.

## Pass 04 — animal laughter

**References:** `v1-s1.png`, `v1-a4-laughter.png`.

### Seedance prompt

> Use [Image 1] for the exact wide camera and cast positions. After no more than a tenth of a second, the clerk and all four people in line violently snap into the full laughter pose in [Image 2]. They keep laughing and physically shaking for the entire clip on different rhythms. Mabel alone remains silent and rigid with the cup. Do not shorten the laughter, settle them early, or add blocks. Preserve the room, cast, costumes, palette, wobbly ink, paper grain, and grotesque-cute anatomy. AUDIO MUST ERUPT AT NEAR-MAXIMUM LOUDNESS AND STAY LOUD: five clearly different uncontrolled laughs overlap. One long-necked customer repeatedly breaks into a full donkey bray; another barks like a seal through a human mouth; one produces a hyena-like saw cackle; Granny Toad has a low chesty coughing roar; the clerk's laugh is a dry machine-gun rasp. Add loud gasps, knee slaps, counter rattles, uvula flaps, shoe scrapes, and one body briefly laughing with no air. It should be shocking, hilarious, animal and embarrassing—not a polite cartoon crowd. No canned laugh track, duplicated library laugh, audience applause, quiet chuckles, whispers, music, jingle, boings, readable text, subtitles, logos, or watermark.

## Pass 05 — cup glance

**References:** `v1-a5-cup-inspect.png`, `v1-a6-overhead-rain-start.png`,
`s0-pixels.png`.

### Seedance prompt

> Start on [Image 1] for only a blink: Mabel gives the intact cup one fast suspicious look. The cup emits nothing. Within the first quarter-second, make a hard cut to the wide composition in [Image 2] as heavy outlined color blocks matching [Image 3] slam straight down from above across the room. The first block is already entering at the cut and a second hits the counter or floor immediately. Mabel snaps her eyes upward; the room begins shielding heads. No slow build, no floating cubes, no upward motion, no cup geyser. AUDIO IS SUDDEN AND HUGE: the quick cup glance gets an amplified eyeball squeak and one angry nasal inhale, then the first overhead block lands like a ceramic wardrobe dropped inside a steel dumpster. Following blocks combine hollow wood, cracked pottery, giant teeth, and bassy rubber impacts, all tightly synchronized and loud enough to interrupt the laughter. No magical whoosh, sparkle, explosion library, music, riser, whisper, intelligible speech, readable text, subtitles, logos, or watermark.

Only source 0.45–1.15 seconds is used. The slower model-created transition is
discarded.

## Pass 06 — clean-start brick rain

**References:** `v1-a6-pre-impact-clean-v1.png`, `v1-s3.png`,
`s0-pixels.png`.

### Seedance prompt

> Start exactly from [Image 1]: the entire air is empty, every character is already looking upward and shielding their head, and Mabel holds the intact cup. Hold this clean anticipation for only about one tenth of a second. Then the FIRST real colored block enters dynamically from beyond the top edge and accelerates downward. Within another two tenths of a second, a violent ceiling-to-floor rain of heavy fist-sized blocks matching [Image 3] fills the room. The blocks are actual moving objects animated through space—never a still illustration, never suspended, and never accompanied by drawn speed lines or motion lines. Nothing emerges from Mabel's cup. The clerk and line duck, are struck from above, and are buried beneath local piles; tall characters cannot remain above the final horizon. Reach the calm buried aftermath in [Image 2] within about two seconds, then let one teal-sleeved hand make a final small movement. AUDIO IS MAXIMAL AND LOUD: the first block hits like a ceramic wardrobe inside a steel dumpster, followed by dense synchronized wooden, pottery, bowling-ball-in-rubber, giant-tooth, and wet-cardboard impacts. Add brief animal yelps and brays that become violently muffled under the pile, then slam to near-silence with one trapped wheeze. No blocks visible at frame zero, no static hovering blocks, no drawn motion lines, no cup geyser, no music, no readable text, no captions, no logos, no watermark.

## Local finishing

- Burn captions into the two complaint clips.
- Repair the clerk reflection discontinuity over source frames 49–53 by
  feather-compositing only the pupil interiors. Never dissolve the complete face.
- Cut the clean brick-rain source at 3.2 seconds, before the bottom cubes shift.
- Freeze the approved source at 3.15 seconds to seed the 0.7-second local
  pixel-away transition.
- Animate the standalone dab outro locally and append a 4.4-second encoded hold
  of `storyboards/dab-brand-outro-lockup-v1.png`.
- Assemble at 720 × 1280, 24 fps, then master the complete mix and replace the
  assembly audio in one final pass.

The current rebuild scripts are `build_captioned_opening_v5.py`,
`build_captioned_clips.py`, `smooth_pressure_clerk_jump.py`,
`build_local_finishing.py`, `build_outro_hold_v2.py`,
`assemble_coffee_workflow_v5.swift`, `master_audio.swift`, and
`replace_video_audio.swift`.

## Process rules learned here

1. Shape the whole film with stills and a timed local animatic before paying for
   video generations. Add mild local movement so timing can be judged.
2. Split generations at concrete scene changes. Use a start frame for every
   pass; add an end frame only when the final geography or physical result must
   be controlled. Too many anchors suppress useful model invention.
3. Treat object ownership, screen side, distance to furniture, background cast,
   and first-frame contents as explicit continuity constraints. When a close
   reference drifts, crop the approved wide first and use that crop as the image
   generation reference.
4. Prefer a clean hard cut over asking one generation to perform an unnecessary
   camera move. Modular passes make individual failures cheap to replace.
5. Protect comedy timing. Tension close-ups, group laughter, and aftermath holds
   need room; violent punchlines should happen quickly. Do not shorten the kicker
   merely to satisfy an arbitrary total duration.
6. Never draw future motion into a first frame. No suspended blocks or speed
   lines: start with clean anticipation and let the video model create movement.
7. Fix tiny discontinuities locally when the performance is otherwise good.
   Region-only dissolves, stable-frame holds, hard cuts, and local transitions
   are preferable to rerunning an entire strong generation.
8. Build the brand outro as an independent reusable module. Transition into it
   locally so future promos can share the same ending.
9. Keep generated music out of content prompts. Generate bold voices and effects
   with the scene, then align and mix licensed or supplied music locally.
10. During production, keep every review artifact outside Git. At approval,
    retain only current source media locally and commit the final delivery plus
    deliberately reusable source material.
