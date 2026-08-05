#!/usr/bin/env python3
"""Burn the approved local caption into the Coffee Shop close complaint."""

from __future__ import annotations

import math
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
FPS = 24
WIDTH = 720
HEIGHT = 1280
FONT_PATH = Path("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf")


@dataclass(frozen=True)
class Caption:
    start: float
    end: float
    text: str
    y: int


CLIPS = (
    {
        "source": ROOT / "videos" / "runs" / "cgt-20260805054321-68sf8" / "video.mp4",
        "duration": 2.6,
        "output": ROOT / "videos" / "v1-p02-with-pixels-captioned-v2.mp4",
        "captions": (Caption(0.4, 2.6, "I ORDERED MINE\nWITH PIXELS.", 1010),),
    },
)


def add_caption(frame: Image.Image, caption: Caption) -> None:
    compact_length = len(caption.text.replace("\n", ""))
    font_size = 52 if compact_length < 17 else 42
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    draw = ImageDraw.Draw(frame)
    bounds = draw.multiline_textbbox(
        (0, 0), caption.text, font=font, spacing=2, align="center"
    )
    draw.multiline_text(
        (WIDTH // 2, caption.y - bounds[1]),
        caption.text,
        font=font,
        fill="#F5C6AE",
        anchor="ma",
        align="center",
        spacing=2,
        stroke_width=6,
        stroke_fill="#14100E",
    )


def build_clip(source: Path, duration: float, captions: tuple[Caption, ...], output: Path) -> None:
    frame_count = math.ceil(duration * FPS)
    extraction_duration = frame_count / FPS
    with tempfile.TemporaryDirectory(prefix="dab-captioned-clip-") as temporary:
        frame_dir = Path(temporary)
        subprocess.run(
            [
                "/usr/bin/swift",
                str(ROOT / "scripts" / "extract_video_sequence.swift"),
                str(source),
                str(frame_dir),
                "0",
                str(extraction_duration),
                str(FPS),
            ],
            check=True,
        )
        for index, frame_path in enumerate(sorted(frame_dir.glob("frame_*.jpg"))):
            time_seconds = index / FPS
            with Image.open(frame_path) as raw:
                frame = ImageOps.fit(
                    raw.convert("RGB"), (WIDTH, HEIGHT), Image.Resampling.LANCZOS
                )
            for caption in captions:
                if caption.start <= time_seconds < caption.end:
                    add_caption(frame, caption)
            frame.save(frame_path, quality=95, subsampling=0)
        subprocess.run(
            [
                "/usr/bin/swift",
                str(ROOT / "scripts" / "encode_image_sequence.swift"),
                str(frame_dir),
                str(FPS),
                str(output),
            ],
            check=True,
        )


def main() -> None:
    for clip in CLIPS:
        build_clip(
            source=clip["source"],
            duration=clip["duration"],
            captions=clip["captions"],
            output=clip["output"],
        )
        print(clip["output"])


if __name__ == "__main__":
    main()
