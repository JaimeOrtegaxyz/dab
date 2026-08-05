# Seedance promo workflow

This folder contains a tested modular workflow for building vertical dab promos
with BytePlus ModelArk and Seedance 2.0. The Coffee Shop film is finished; its
approved prompts, edit, local corrections, and lessons live in
`storyboards/v1-coffee-shop-production.md`. Use the same production path for the
remaining concepts in `seedance-videos.md`.

## Confirmed API

- Base URL: `https://ark.ap-southeast.bytepluses.com/api/v3`
- Enabled models: `GET /models`
- Create task: `POST /contents/generations/tasks`
- Read task: `GET /contents/generations/tasks/{task_id}`
- Mini: `dreamina-seedance-2-0-mini-260615`
- Standard: `dreamina-seedance-2-0-260128`
- Authentication: `Authorization: Bearer $SEEDANCE_API_KEY`

Local references are embedded as Base64 `image_url` entries with role
`reference_image`. Prompt references such as `@Image1` are translated to
ModelArk's `[Image 1]` syntax. Every downloaded job is stored beneath
`videos/runs/{task_id}/` with a secret-free manifest; generated source media is
ignored by Git.

## Production path

1. Write the complete joke and rough timing before generating video.
2. Generate only the stills needed to describe concrete scene changes.
3. Build a timed local animatic with small moves and exact captions.
4. Split the approved animatic into modular Seedance passes.
5. Give every pass a start reference. Add an end reference only when the physical
   result or final geography truly matters.
6. Validate prompts and inputs locally, then submit one paid Mini job at a time.
7. Review picture, performance, sound, continuity, and usable edit window
   separately. Replace only the failed pass.
8. Assemble locally with hard cuts, captions, music, reusable transitions, and
   brand outro.
9. Repair small discontinuities locally when the source performance is otherwise
   strong.
10. Master and verify the final cut, then clean all obsolete review material.

## Creative guardrails learned from Coffee Shop

- Modular beats are more controllable than asking one generation to direct a
  complete commercial.
- A hard cut is often better than an unnecessary generated camera move.
- Explicitly lock hand ownership, screen side, furniture distance, background
  cast, and frame-zero contents.
- Never include suspended action or motion lines in a first frame. Begin with
  clean anticipation.
- Unintelligible voice must still be loud and expressive. “Gibberish” works;
  “mumbling” produces timid audio.
- Weird sound should be physically connected to the visible event, even when its
  material is deliberately wrong.
- Protect the laughter, tension hold, impact speed, and aftermath. Do not shorten
  the joke to fit an arbitrary runtime.
- Use pupil-only or object-only dissolves, frozen stable frames, and local cuts
  for tiny continuity repairs; full-frame dissolves create visible ghosting.
- Keep music out of Seedance prompts. Generate scene voices and effects, then mix
  supplied music locally.
- Build the dab outro as an independent reusable module and transition into it
  locally.

## Safe commands

Run commands from `promo/`. Validation creates no paid task:

```bash
python3 scripts/seedance.py validate coffee-01-angry-wide
python3 scripts/seedance.py validate coffee-02-angry-pixels
python3 scripts/seedance.py validate coffee-03-pressure-clerk
python3 scripts/seedance.py validate coffee-04-animal-laughter
python3 scripts/seedance.py validate coffee-05-cup-glance
python3 scripts/seedance.py validate coffee-06-brick-rain
```

The optional model-list check is also non-billable:

```bash
python3 scripts/seedance.py models
```

Submit one approved pass:

```bash
python3 scripts/seedance.py generate coffee-04-animal-laughter --model mini
```

Inspect, resume, or download a submitted task:

```bash
python3 scripts/seedance.py status TASK_ID --wait --download
```

Standard should be considered only after a difficult pass repeatedly fails on
Mini and neither the references nor prompt can resolve the failure.

## Repository hygiene

- Commit specifications, presets, scripts, deliberately reusable source audio,
  and approved final deliveries.
- Keep generated Seedance clips, intermediate renders, masters, review frames,
  diagnostic extractions, and temporary music local and ignored.
- At approval, keep only the source passes and local intermediates used by the
  final. Delete superseded generations, animatics, mixes, and review artifacts.
- Never store API keys or signed output URLs in Git.
