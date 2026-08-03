# Seedance workflow

This folder uses the official BytePlus ModelArk API in the AP Southeast region.
The integration was probed and verified on 2026-08-03 with the account's
`SEEDANCE_API_KEY`.

## Confirmed API shape

- Base URL: `https://ark.ap-southeast.bytepluses.com/api/v3`
- List enabled models: `GET /models`
- Create a video task: `POST /contents/generations/tasks`
- Retrieve a task: `GET /contents/generations/tasks/{task_id}`
- Mini model: `dreamina-seedance-2-0-mini-260615`
- Standard model: `dreamina-seedance-2-0-260128`
- Authentication: `Authorization: Bearer $SEEDANCE_API_KEY`

Reference images are sent as `content` entries with type `image_url` and role
`reference_image`. The runner embeds local files as Base64 data URLs, which
avoids temporary public uploads. The production bible's `@Image1` syntax is
translated to ModelArk's `[Image 1]` syntax at request time.

## Commands

Run these from `promo/`:

```bash
# Validate paths, prompt extraction, and the 64 MB request limit. No API call.
python3 scripts/seedance.py validate coffee-shop

# Optional non-billable check of the models enabled for the key.
python3 scripts/seedance.py models

# Submit one paid Mini job, wait for it, and download its outputs.
python3 scripts/seedance.py generate coffee-shop --model mini

# Inspect an existing task. Add --wait or --download when needed.
python3 scripts/seedance.py status TASK_ID --download
```

Every new job gets a unique folder at `videos/runs/{task_id}/` containing:

- `video.mp4`
- `last-frame.jpg` or `last-frame.png`
- `job.json`, a sanitized reproducibility manifest with the prompt, settings,
  local input paths and hashes, API status, and local output paths

API keys and signed output URLs are never written to job manifests.

## Tested coffee-shop run

- Task: `cgt-20260803100447-p69ct`
- Model: `dreamina-seedance-2-0-mini-260615`
- Output: 12.04 seconds, 720×1280, 24 fps, silent, no watermark
- Files: `videos/v1-coffee-shop-mini.mp4` and
  `videos/v1-coffee-shop-mini-last-frame.jpg`
- Sanitized request/response record:
  `videos/runs/cgt-20260803100447-p69ct/job.json`

Mini preserved the illustration style and cast reasonably well, but compressed
the planned four-shot choreography: it skipped the cashier fisheye and laughter
beats, turned the eruption into a foreground pixel pile, and reached the flooded
arm ending only at the final moment. The next production experiment should use
the two-generation fallback described in `seedance-videos.md`.
