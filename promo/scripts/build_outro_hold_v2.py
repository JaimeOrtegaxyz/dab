#!/usr/bin/env python3
"""Encode a real 4.4-second hold of the approved final brand lockup."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "storyboards" / "dab-brand-outro-lockup-v1.png"
OUTPUT = ROOT / "videos" / "dab-brand-outro-hold-v2.mp4"
FPS = 24
DURATION = 4.4


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="dab-outro-hold-") as temporary:
        frame_dir = Path(temporary)
        with Image.open(SOURCE) as source:
            frame = source.convert("RGB")
        for index in range(round(FPS * DURATION)):
            frame.save(frame_dir / f"frame_{index:05d}.jpg", quality=95, subsampling=0)
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
