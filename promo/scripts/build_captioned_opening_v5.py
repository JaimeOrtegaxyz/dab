#!/usr/bin/env python3
"""Burn captions into the complete four-second V5 wide complaint pass."""

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
SOURCE = ROOT / "videos" / "runs" / "cgt-20260805070106-5ch8m" / "video.mp4"
OUTPUT = ROOT / "videos" / "v1-p01-left-hand-wide-captioned-v5.mp4"
DURATION = 4.0


@dataclass(frozen=True)
class Caption:
    start: float
    end: float
    text: str
    y: int


CAPTIONS = (
    Caption(1.5, 2.1, "HEY.", 1035),
    Caption(2.1, 3.6, "THIS AIN'T MY ORDER.", 1035),
)


def add_caption(frame: Image.Image, caption: Caption) -> None:
    compact_length = len(caption.text.replace("\n", ""))
    font_size = 52 if compact_length < 17 else 42
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    draw = ImageDraw.Draw(frame)
    bounds = draw.multiline_textbbox((0, 0), caption.text, font=font, spacing=2, align="center")
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


def main() -> None:
    frame_count = math.ceil(DURATION * FPS)
    with tempfile.TemporaryDirectory(prefix="dab-captioned-v5-") as temporary:
        frame_dir = Path(temporary)
        subprocess.run(
            [
                "/usr/bin/swift",
                str(ROOT / "scripts" / "extract_video_sequence.swift"),
                str(SOURCE),
                str(frame_dir),
                "0",
                str(frame_count / FPS),
                str(FPS),
            ],
            check=True,
        )
        for index, frame_path in enumerate(sorted(frame_dir.glob("frame_*.jpg"))):
            with Image.open(frame_path) as raw:
                frame = ImageOps.fit(raw.convert("RGB"), (WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            time_seconds = index / FPS
            for caption in CAPTIONS:
                if caption.start <= time_seconds < caption.end:
                    add_caption(frame, caption)
            frame.save(frame_path, quality=95, subsampling=0)
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
