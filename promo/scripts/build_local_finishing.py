#!/usr/bin/env python3
"""Build the reusable dab outro and a source-specific local pixel-away transition."""

from __future__ import annotations

import math
import random
import shutil
import subprocess
import tempfile
import wave
from array import array
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
FPS = 24
WIDTH = 720
HEIGHT = 1280
BRAND_YELLOW = (254, 199, 0)
INK = (20, 20, 20, 255)
PALETTE = (
    (235, 49, 65),
    (247, 103, 62),
    (72, 151, 92),
    (45, 113, 163),
    (127, 75, 157),
)

PASS_6_VIDEO = ROOT / "videos" / "runs" / "cgt-20260805062958-d69l7" / "video.mp4"
FACE_PATH = ROOT.parent / "dab" / "Resources" / "dab-logo.png"
FONT_PATH = ROOT.parent / "dab" / "Resources" / "Inconsolata.ttf"
LOCKUP_PATH = ROOT / "storyboards" / "dab-brand-outro-lockup-v1.png"

TRANSITION_VIDEO = ROOT / "videos" / "v1-coffee-shop-pixel-away-v2.mp4"
OUTRO_VIDEO = ROOT / "videos" / "dab-brand-outro-v1.mp4"
TRANSITION_AUDIO = ROOT / "audio" / "v1-coffee-shop-pixel-away-v1.wav"
OUTRO_AUDIO = ROOT / "audio" / "dab-brand-outro-v1.wav"


def clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def ease(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def app_font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_PATH), size)
    font.set_variation_by_name(weight)
    return font


def draw_centered_text(
    image: Image.Image,
    text: str,
    y: int,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int] = INK,
) -> None:
    draw = ImageDraw.Draw(image)
    bounds = draw.textbbox((0, 0), text, font=font)
    x = (WIDTH - (bounds[2] - bounds[0])) // 2
    draw.text((x, y), text, font=font, fill=fill)


def encode_frames(frame_dir: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
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


def extract_transition_source(output_dir: Path) -> None:
    # Freeze the approved V3 brick-rain frame just before the old transition's
    # mismatched cube layout. Pixel removal now starts from one exact picture
    # instead of inheriting motion and geometry from an obsolete generation.
    subprocess.run(
        [
            "/usr/bin/swift",
            str(ROOT / "scripts" / "extract_video_sequence.swift"),
            str(PASS_6_VIDEO),
            str(output_dir),
            "3.15",
            str(1 / FPS),
            str(FPS),
        ],
        check=True,
    )
    source = output_dir / "frame_00000.jpg"
    if not source.is_file():
        raise RuntimeError("could not extract the stable transition source frame")
    for index in range(round(0.7 * FPS)):
        destination = output_dir / f"frame_{index:05d}.jpg"
        if destination != source:
            shutil.copyfile(source, destination)


def build_transition(source_dir: Path, frame_dir: Path) -> None:
    sources = sorted(source_dir.glob("frame_*.jpg"))
    if not sources:
        raise RuntimeError("no transition source frames were extracted")

    tile_size = 24
    rng = random.Random(7127)
    columns = math.ceil(WIDTH / tile_size)
    rows = math.ceil(HEIGHT / tile_size)
    tile_data: dict[tuple[int, int], tuple[float, float, float, tuple[int, int, int]]] = {}
    for row in range(rows):
        for column in range(columns):
            center_x = (column + 0.5) / columns * 2.0 - 1.0
            center_y = (row + 0.5) / rows * 2.0 - 1.0
            distance = min(1.0, math.sqrt(center_x * center_x + center_y * center_y) / math.sqrt(2.0))
            threshold = 0.03 + 0.48 * distance + rng.uniform(0.0, 0.28)
            angle = math.atan2(center_y, center_x) + rng.uniform(-0.35, 0.35)
            drift = rng.uniform(12.0, 34.0)
            color = PALETTE[rng.randrange(len(PALETTE))]
            tile_data[(column, row)] = (threshold, angle, drift, color)

    total = len(sources)
    for index, source_path in enumerate(sources):
        progress = index / max(1, total - 1)
        canvas = Image.new("RGB", (WIDTH, HEIGHT), BRAND_YELLOW)
        if progress < 0.93:
            with Image.open(source_path) as raw:
                source = ImageOps.fit(raw.convert("RGB"), (WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            for row in range(rows):
                top = row * tile_size
                bottom = min(HEIGHT, top + tile_size)
                for column in range(columns):
                    left = column * tile_size
                    right = min(WIDTH, left + tile_size)
                    threshold, angle, drift, flat_color = tile_data[(column, row)]
                    local = clamp((progress - threshold) / 0.24)
                    if local >= 1.0:
                        continue
                    tile = source.crop((left, top, right, bottom))
                    flatten = clamp((progress - max(0.38, threshold - 0.08)) / 0.16)
                    if flatten > 0:
                        flat = Image.new("RGB", tile.size, flat_color)
                        tile = Image.blend(tile, flat, ease(flatten))
                    moved = ease(local)
                    scale = max(0.08, 1.0 - moved * 0.92)
                    scaled_width = max(1, round(tile.width * scale))
                    scaled_height = max(1, round(tile.height * scale))
                    tile = tile.resize((scaled_width, scaled_height), Image.Resampling.LANCZOS)
                    center_x = (left + right) / 2 + math.cos(angle) * drift * moved
                    center_y = (top + bottom) / 2 + math.sin(angle) * drift * moved
                    x = round(center_x - scaled_width / 2)
                    y = round(center_y - scaled_height / 2)
                    canvas.paste(tile, (x, y))
        canvas.save(frame_dir / f"frame_{index:05d}.jpg", quality=94, subsampling=0)


def transparent_face() -> Image.Image:
    with Image.open(FACE_PATH) as raw:
        face = raw.convert("RGBA").resize((360, 360), Image.Resampling.LANCZOS)
    pixels = []
    for red, green, blue, _ in face.getdata():
        difference = max(abs(red - BRAND_YELLOW[0]), abs(green - BRAND_YELLOW[1]), abs(blue - BRAND_YELLOW[2]))
        alpha = min(255, difference * 4)
        pixels.append((red, green, blue, alpha))
    face.putdata(pixels)
    return face


def draw_face_assembly(canvas: Image.Image, face: Image.Image, progress: float) -> None:
    final_x = 180
    final_y = 290
    if progress >= 1.0:
        canvas.alpha_composite(face, (final_x, final_y))
        return

    pieces = (
        (0, 0, 120, 120),
        (120, 0, 240, 120),
        (240, 0, 360, 120),
        (0, 120, 120, 240),
        (120, 120, 240, 240),
        (240, 120, 360, 240),
        (0, 240, 120, 360),
        (120, 240, 240, 360),
        (240, 240, 360, 360),
    )
    rng = random.Random(393)
    for index, box in enumerate(pieces):
        left, top, right, bottom = box
        piece = face.crop(box)
        stagger = index * 0.035
        local = ease(clamp((progress - stagger) / 0.65))
        if local <= 0:
            continue
        dx = (left + right) / 2 - 180
        dy = (top + bottom) / 2 - 180
        distance = 95 + rng.uniform(0, 55)
        start_x = math.copysign(distance, dx if abs(dx) > 1 else rng.choice((-1, 1)))
        start_y = math.copysign(distance, dy if abs(dy) > 1 else rng.choice((-1, 1)))
        scale = 0.68 + 0.32 * local
        piece = piece.resize(
            (max(1, round(piece.width * scale)), max(1, round(piece.height * scale))),
            Image.Resampling.LANCZOS,
        )
        x = final_x + left + start_x * (1.0 - local) + (120 - piece.width) / 2
        y = final_y + top + start_y * (1.0 - local) + (120 - piece.height) / 2
        canvas.alpha_composite(piece, (round(x), round(y)))


def draw_outro_frame(time_seconds: float, face: Image.Image, lockup: Image.Image) -> Image.Image:
    if time_seconds >= 1.55:
        return lockup.copy()

    canvas = Image.new("RGBA", (WIDTH, HEIGHT), (*BRAND_YELLOW, 255))
    if time_seconds >= 0.15:
        face_progress = clamp((time_seconds - 0.15) / 0.55)
        draw_face_assembly(canvas, face, face_progress)

    # A tiny logo pulse suggests the face delivers the slogan without changing
    # the approved final artwork.
    if 1.05 <= time_seconds < 1.22:
        phase = (time_seconds - 1.05) / 0.17
        pulse = 1.0 + 0.025 * math.sin(math.pi * phase)
        pulsed = face.resize(
            (round(face.width * pulse), round(face.height * pulse)),
            Image.Resampling.LANCZOS,
        )
        x = (WIDTH - pulsed.width) // 2
        y = 290 + (face.height - pulsed.height) // 2
        canvas.alpha_composite(pulsed, (x, y))

    if time_seconds >= 0.55:
        title_progress = ease(clamp((time_seconds - 0.55) / 0.30))
        title_y = round(674 - 28 * (1.0 - title_progress))
        draw_centered_text(canvas, "dab", title_y, app_font(72, "Bold"))

    if time_seconds >= 1.10:
        draw_centered_text(canvas, "fuck yeah, pixels", 866, app_font(54, "Medium"))

    if time_seconds >= 1.20:
        pill_progress = ease(clamp((time_seconds - 1.20) / 0.25))
        badge = "free for macOS 14+"
        badge_font = app_font(30, "SemiBold")
        draw = ImageDraw.Draw(canvas)
        bounds = draw.textbbox((0, 0), badge, font=badge_font)
        full_width = bounds[2] - bounds[0] + 58
        current_width = max(2, round(full_width * pill_progress))
        badge_x = (WIDTH - current_width) // 2
        badge_y = 947
        draw.rounded_rectangle(
            (badge_x, badge_y, badge_x + current_width, badge_y + 58),
            radius=min(16, current_width // 2),
            fill=INK,
        )
        if pill_progress > 0.72:
            text_layer = Image.new("RGBA", (full_width, 58), (0, 0, 0, 0))
            text_draw = ImageDraw.Draw(text_layer)
            text_bounds = text_draw.textbbox((0, 0), badge, font=badge_font)
            text_x = (full_width - (text_bounds[2] - text_bounds[0])) // 2
            text_draw.text((text_x, 10), badge, font=badge_font, fill=(*BRAND_YELLOW, 255))
            crop_left = (full_width - current_width) // 2
            canvas.alpha_composite(
                text_layer.crop((crop_left, 0, crop_left + current_width, 58)),
                (badge_x, badge_y),
            )

    if time_seconds >= 1.38:
        strip_progress = ease(clamp((time_seconds - 1.38) / 0.17))
        full_width = len(PALETTE) * 24
        visible_width = max(1, round(full_width * strip_progress))
        strip = Image.new("RGBA", (full_width, 24), (0, 0, 0, 0))
        strip_draw = ImageDraw.Draw(strip)
        for index, color in enumerate(PALETTE):
            strip_draw.rectangle((index * 24, 0, index * 24 + 23, 23), fill=(*color, 255))
        crop_left = (full_width - visible_width) // 2
        canvas.alpha_composite(
            strip.crop((crop_left, 0, crop_left + visible_width, 24)),
            ((WIDTH - visible_width) // 2, 1030),
        )
    return canvas.convert("RGB")


def build_outro(frame_dir: Path) -> None:
    face = transparent_face()
    with Image.open(LOCKUP_PATH) as source:
        lockup = source.convert("RGB")
    frame_count = round(3.2 * FPS)
    for index in range(frame_count):
        frame = draw_outro_frame(index / FPS, face, lockup)
        frame.save(frame_dir / f"frame_{index:05d}.jpg", quality=95, subsampling=0)


def write_audio(
    path: Path,
    duration: float,
    event_builder,
    sample_rate: int = 48_000,
) -> None:
    count = round(duration * sample_rate)
    left = [0.0] * count
    right = [0.0] * count

    def add_tone(
        start: float,
        length: float,
        frequency: float,
        amplitude: float,
        pan: float = 0.0,
        end_frequency: float | None = None,
        roughness: float = 0.0,
    ) -> None:
        first = max(0, round(start * sample_rate))
        last = min(count, first + round(length * sample_rate))
        phase = 0.0
        rng = random.Random(first + round(frequency * 10))
        for sample_index in range(first, last):
            local = (sample_index - first) / max(1, last - first)
            freq = frequency if end_frequency is None else frequency + (end_frequency - frequency) * local
            phase += 2.0 * math.pi * freq / sample_rate
            envelope = math.sin(math.pi * local) ** 0.6 * (1.0 - local) ** 0.45
            value = math.sin(phase) * amplitude * envelope
            if roughness:
                value += (rng.random() * 2.0 - 1.0) * amplitude * roughness * envelope
            left[sample_index] += value * (1.0 - max(0.0, pan))
            right[sample_index] += value * (1.0 + min(0.0, pan))

    event_builder(add_tone)
    peak = max(0.001, max(max(abs(value) for value in left), max(abs(value) for value in right)))
    gain = min(1.0, 0.88 / peak)
    interleaved = array("h")
    for left_value, right_value in zip(left, right):
        interleaved.append(round(clamp(left_value * gain, -1.0, 1.0) * 32767))
        interleaved.append(round(clamp(right_value * gain, -1.0, 1.0) * 32767))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as destination:
        destination.setnchannels(2)
        destination.setsampwidth(2)
        destination.setframerate(sample_rate)
        destination.writeframes(interleaved.tobytes())


def transition_events(add_tone) -> None:
    rng = random.Random(818)
    add_tone(0.00, 0.65, 115, 0.10, end_frequency=46, roughness=0.08)
    for index in range(58):
        start = 0.02 + (index / 58) ** 1.5 * 0.55 + rng.uniform(-0.008, 0.008)
        add_tone(
            start,
            rng.uniform(0.010, 0.034),
            rng.choice((170, 240, 330, 470, 680, 910)) * rng.uniform(0.92, 1.08),
            rng.uniform(0.025, 0.085),
            pan=rng.uniform(-0.8, 0.8),
            roughness=rng.uniform(0.15, 0.45),
        )
    add_tone(0.54, 0.12, 78, 0.16, end_frequency=42, roughness=0.18)


def outro_events(add_tone) -> None:
    add_tone(0.18, 0.52, 240, 0.035, end_frequency=95, roughness=0.32)
    add_tone(0.58, 0.18, 82, 0.22, end_frequency=54, roughness=0.10)
    add_tone(0.72, 0.10, 310, 0.055, end_frequency=190, roughness=0.18)
    # Short nonverbal papery mumble at the slogan beat.
    add_tone(1.01, 0.24, 128, 0.075, end_frequency=112, roughness=0.20)
    add_tone(1.01, 0.24, 510, 0.030, end_frequency=470, roughness=0.12)
    add_tone(1.01, 0.24, 890, 0.018, end_frequency=760, roughness=0.08)
    add_tone(1.10, 0.055, 64, 0.16, roughness=0.22)
    add_tone(1.26, 0.17, 155, 0.075, end_frequency=88, roughness=0.30)
    for index, frequency in enumerate((380, 450, 540, 650, 790)):
        add_tone(1.42 + index * 0.025, 0.036, frequency, 0.045, pan=(index - 2) * 0.22, roughness=0.18)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="dab-local-finishing-") as temporary:
        temp = Path(temporary)
        source_dir = temp / "transition-source"
        transition_frames = temp / "transition-frames"
        outro_frames = temp / "outro-frames"
        source_dir.mkdir()
        transition_frames.mkdir()
        outro_frames.mkdir()
        extract_transition_source(source_dir)
        build_transition(source_dir, transition_frames)
        build_outro(outro_frames)
        encode_frames(transition_frames, TRANSITION_VIDEO)
        encode_frames(outro_frames, OUTRO_VIDEO)

    write_audio(TRANSITION_AUDIO, 0.7, transition_events)
    write_audio(OUTRO_AUDIO, 3.2, outro_events)
    print(TRANSITION_VIDEO)
    print(TRANSITION_AUDIO)
    print(OUTRO_VIDEO)
    print(OUTRO_AUDIO)


if __name__ == "__main__":
    main()
