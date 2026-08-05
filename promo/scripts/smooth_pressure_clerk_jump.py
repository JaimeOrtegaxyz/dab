#!/usr/bin/env python3
"""Locally dissolve the one-frame pupil/reflection jump in the clerk push-in."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "videos" / "runs" / "cgt-20260805054327-qrphn" / "video.mp4"
OUTPUT = ROOT / "videos" / "v1-p03-pressure-clerk-smoothed-v1.mp4"
FPS = 24
DURATION = 4.0
FIRST_BLEND_FRAME = 49
LAST_BLEND_FRAME = 53

# Tight black-pupil bounds at the start and end of the problematic interval.
# Only these regions dissolve; the moving face and camera push stay original.
PUPIL_BOXES = {
    49: ((102, 506, 284, 746), (447, 510, 627, 748)),
    53: ((104, 528, 293, 771), (449, 529, 641, 773)),
}


def smoothstep(value: float) -> float:
    return value * value * (3.0 - 2.0 * value)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="dab-pressure-clerk-smooth-") as temporary:
        frame_dir = Path(temporary)
        subprocess.run(
            [
                "/usr/bin/swift",
                str(ROOT / "scripts" / "extract_video_sequence.swift"),
                str(SOURCE),
                str(frame_dir),
                "0",
                str(DURATION),
                str(FPS),
            ],
            check=True,
        )

        frames = sorted(frame_dir.glob("frame_*.jpg"))
        if len(frames) != round(DURATION * FPS):
            raise RuntimeError(f"expected 96 frames, found {len(frames)}")

        with Image.open(frames[FIRST_BLEND_FRAME]) as raw_before:
            before = raw_before.convert("RGB")
        with Image.open(frames[LAST_BLEND_FRAME]) as raw_after:
            after = raw_after.convert("RGB")

        before_pupils = [before.crop(box) for box in PUPIL_BOXES[FIRST_BLEND_FRAME]]
        after_pupils = [after.crop(box) for box in PUPIL_BOXES[LAST_BLEND_FRAME]]

        span = LAST_BLEND_FRAME - FIRST_BLEND_FRAME
        for index in range(FIRST_BLEND_FRAME, LAST_BLEND_FRAME + 1):
            progress = (index - FIRST_BLEND_FRAME) / span
            eased = smoothstep(progress)
            with Image.open(frames[index]) as raw_frame:
                frame = raw_frame.convert("RGB")
            for eye_index in range(2):
                start_box = PUPIL_BOXES[FIRST_BLEND_FRAME][eye_index]
                end_box = PUPIL_BOXES[LAST_BLEND_FRAME][eye_index]
                box = tuple(
                    round(start + (end - start) * progress)
                    for start, end in zip(start_box, end_box)
                )
                width = box[2] - box[0]
                height = box[3] - box[1]
                clean = before_pupils[eye_index].resize((width, height), Image.Resampling.LANCZOS)
                reflected = after_pupils[eye_index].resize((width, height), Image.Resampling.LANCZOS)
                pupil = Image.blend(clean, reflected, eased)
                mask = Image.new("L", (width, height), 0)
                draw = ImageDraw.Draw(mask)
                draw.ellipse((2, 2, width - 3, height - 3), fill=255)
                mask = mask.filter(ImageFilter.GaussianBlur(2.0))
                frame.paste(pupil, (box[0], box[1]), mask)
            frame.save(frames[index], quality=95, subsampling=0)

        subprocess.run(
            [
                "/usr/bin/swift",
                str(ROOT / "scripts" / "encode_image_sequence.swift"),
                str(frame_dir),
                str(FPS),
                str(OUTPUT),
            ],
            check=True,
        )
    print(OUTPUT)


if __name__ == "__main__":
    main()
