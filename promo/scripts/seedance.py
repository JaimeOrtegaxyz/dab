#!/usr/bin/env python3
"""Submit and retrieve Seedance jobs through BytePlus ModelArk.

Each production pass has a named preset and a prompt section in its current
production specification. The runner embeds local stills as Base64 image inputs,
submits one asynchronous task, polls it, downloads the result, and writes a
secret-free reproducibility manifest.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import mimetypes
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = PROJECT_ROOT / "seedance-presets.json"
ENV_PATH = PROJECT_ROOT / ".env"
RUNS_DIR = PROJECT_ROOT / "videos" / "runs"
MAX_REQUEST_BYTES = 64 * 1024 * 1024
TERMINAL_STATUSES = {"succeeded", "failed", "expired", "cancelled"}


class SeedanceError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_dotenv(path: Path) -> None:
    """Load simple KEY=VALUE entries without executing shell syntax."""
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        if key and key not in os.environ:
            os.environ[key] = value


def load_config() -> Dict[str, Any]:
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SeedanceError(f"Cannot read {CONFIG_PATH}: {exc}") from exc


def resolve_model(config: Dict[str, Any], model_alias: str) -> str:
    try:
        model_config = config["models"][model_alias]
    except KeyError as exc:
        choices = ", ".join(sorted(config.get("models", {})))
        raise SeedanceError(f"Unknown model alias '{model_alias}'. Choose: {choices}") from exc
    return os.getenv(model_config["env"], model_config["default"])


def resolve_base_url(config: Dict[str, Any]) -> str:
    base_config = config["base_url"]
    base_url = os.getenv(base_config["env"], base_config["default"]).rstrip("/")
    parsed = urllib.parse.urlparse(base_url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise SeedanceError("SEEDANCE_API_BASE_URL must be an HTTPS URL")
    return base_url


def get_preset(config: Dict[str, Any], preset_name: str) -> Dict[str, Any]:
    try:
        return config["presets"][preset_name]
    except KeyError as exc:
        choices = ", ".join(sorted(config.get("presets", {})))
        raise SeedanceError(f"Unknown preset '{preset_name}'. Choose: {choices}") from exc


def extract_seedance_prompt(markdown_path: Path, heading_prefix: str) -> str:
    lines = markdown_path.read_text(encoding="utf-8").splitlines()
    section_start: Optional[int] = None
    section_end = len(lines)
    for index, line in enumerate(lines):
        if line.startswith(heading_prefix):
            section_start = index
            break
    if section_start is None:
        raise SeedanceError(f"Cannot find '{heading_prefix}' in {markdown_path}")
    for index in range(section_start + 1, len(lines)):
        if lines[index].startswith("## "):
            section_end = index
            break
    prompt_heading: Optional[int] = None
    for index in range(section_start, section_end):
        if lines[index].strip() == "### Seedance prompt":
            prompt_heading = index
            break
    if prompt_heading is None:
        raise SeedanceError(f"Cannot find Seedance prompt under '{heading_prefix}'")
    prompt_lines: List[str] = []
    for line in lines[prompt_heading + 1 : section_end]:
        if line.startswith(">"):
            prompt_lines.append(line[1:].lstrip())
        elif prompt_lines and line.strip():
            break
    prompt = " ".join(prompt_lines).strip()
    if not prompt:
        raise SeedanceError(f"Seedance prompt under '{heading_prefix}' is empty")
    # ModelArk refers to array-ordered assets as [Image 1], [Video 1], etc.
    prompt = re.sub(r"@(Image|Video|Audio)(\d+)", r"[\1 \2]", prompt)
    return prompt


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def image_data_url(path: Path) -> str:
    mime_type, _ = mimetypes.guess_type(path.name)
    if mime_type not in {"image/jpeg", "image/png", "image/webp", "image/gif", "image/bmp", "image/tiff"}:
        raise SeedanceError(f"Unsupported image type: {path}")
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def build_request(
    config: Dict[str, Any], preset_name: str, model_alias: str
) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    preset = get_preset(config, preset_name)
    specification = preset.get("production_spec", preset.get("production_bible"))
    prompt_section = preset.get("prompt_section", preset.get("video_heading"))
    if not specification or not prompt_section:
        raise SeedanceError(
            f"Preset '{preset_name}' must define production_spec and prompt_section"
        )
    specification_path = PROJECT_ROOT / specification
    prompt = extract_seedance_prompt(specification_path, prompt_section)
    content: List[Dict[str, Any]] = [{"type": "text", "text": prompt}]
    image_manifest: List[Dict[str, Any]] = []
    for image_config in preset["images"]:
        image_path = PROJECT_ROOT / image_config["path"]
        if not image_path.is_file():
            raise SeedanceError(f"Missing preset image: {image_path}")
        content.append(
            {
                "type": "image_url",
                "image_url": {"url": image_data_url(image_path)},
                "role": image_config["role"],
            }
        )
        image_manifest.append(
            {
                "label": image_config["label"],
                "path": image_config["path"],
                "role": image_config["role"],
                "bytes": image_path.stat().st_size,
                "sha256": sha256_file(image_path),
            }
        )
    payload = {
        "model": resolve_model(config, model_alias),
        "content": content,
        "generate_audio": preset["generate_audio"],
        "resolution": preset["resolution"],
        "ratio": preset["ratio"],
        "duration": preset["duration"],
        "watermark": preset["watermark"],
        "return_last_frame": preset["return_last_frame"],
        "execution_expires_after": preset["execution_expires_after"],
    }
    manifest_request = {
        "preset": preset_name,
        "output_slug": preset.get("output_slug"),
        "model_alias": model_alias,
        "model": payload["model"],
        "production_spec": specification,
        "prompt_section": prompt_section,
        "target_edit_seconds": preset.get("target_edit_seconds"),
        "target_timeline": preset.get("target_timeline"),
        "prompt": prompt,
        "images": image_manifest,
        "generate_audio": payload["generate_audio"],
        "resolution": payload["resolution"],
        "ratio": payload["ratio"],
        "duration": payload["duration"],
        "watermark": payload["watermark"],
        "return_last_frame": payload["return_last_frame"],
        "execution_expires_after": payload["execution_expires_after"],
    }
    return payload, manifest_request


def request_bytes(payload: Dict[str, Any]) -> bytes:
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    if len(body) > MAX_REQUEST_BYTES:
        raise SeedanceError(
            f"Request is {len(body) / 1024 / 1024:.1f} MB; ModelArk limit is 64 MB"
        )
    return body


def api_request(
    base_url: str,
    api_key: str,
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    timeout: int = 90,
) -> Dict[str, Any]:
    url = f"{base_url}{path}"
    body = request_bytes(payload) if payload is not None else None
    request = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "dab-promo-seedance-runner/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        try:
            details = json.loads(error_body)
        except json.JSONDecodeError:
            details = error_body[:1000]
        raise SeedanceError(f"ModelArk HTTP {exc.code}: {details}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise SeedanceError(f"ModelArk request failed: {exc}") from exc


def require_api_key() -> str:
    api_key = os.getenv("SEEDANCE_API_KEY", "").strip()
    if not api_key:
        raise SeedanceError(f"SEEDANCE_API_KEY is missing; add it to {ENV_PATH}")
    return api_key


def safe_task_id(task_id: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9._-]+", task_id):
        raise SeedanceError("Task ID contains unexpected characters")
    return task_id


def write_json_atomic(path: Path, value: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def status_summary(status: Dict[str, Any]) -> Dict[str, Any]:
    allowed = {
        "id",
        "model",
        "status",
        "usage",
        "created_at",
        "updated_at",
        "seed",
        "resolution",
        "ratio",
        "duration",
        "framespersecond",
        "service_tier",
        "execution_expires_after",
        "generate_audio",
        "draft",
        "priority",
        "output_format",
        "error",
    }
    return {key: value for key, value in status.items() if key in allowed}


def download_file(url: str, destination: Path, timeout: int = 300) -> Path:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise SeedanceError("ModelArk returned a non-HTTPS output URL")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": "dab-promo-seedance-runner/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response, temporary.open("wb") as handle:
            shutil.copyfileobj(response, handle, length=1024 * 1024)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise SeedanceError(f"Download failed for {destination.name}: {exc}") from exc
    if temporary.stat().st_size == 0:
        raise SeedanceError(f"Downloaded an empty file for {destination.name}")
    os.replace(temporary, destination)
    return destination


def detect_image_extension(path: Path) -> str:
    with path.open("rb") as handle:
        signature = handle.read(12)
    if signature.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if signature.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if signature.startswith(b"RIFF") and signature[8:12] == b"WEBP":
        return ".webp"
    return ".img"


def download_outputs(status: Dict[str, Any], run_dir: Path) -> Dict[str, str]:
    content = status.get("content") or {}
    outputs: Dict[str, str] = {}
    video_url = content.get("video_url")
    if video_url:
        video_path = run_dir / "video.mp4"
        if not video_path.exists():
            download_file(video_url, video_path)
        outputs["video"] = str(video_path.relative_to(PROJECT_ROOT))
    frame_url = content.get("last_frame_url")
    if frame_url:
        temporary_frame = run_dir / "last-frame.download"
        if not any((run_dir / f"last-frame{suffix}").exists() for suffix in (".jpg", ".png", ".webp", ".img")):
            download_file(frame_url, temporary_frame)
            extension = detect_image_extension(temporary_frame)
            final_frame = run_dir / f"last-frame{extension}"
            os.replace(temporary_frame, final_frame)
        else:
            final_frame = next(
                run_dir / f"last-frame{suffix}"
                for suffix in (".jpg", ".png", ".webp", ".img")
                if (run_dir / f"last-frame{suffix}").exists()
            )
        outputs["last_frame"] = str(final_frame.relative_to(PROJECT_ROOT))
    return outputs


def poll_task(
    base_url: str,
    api_key: str,
    task_id: str,
    poll_interval: int,
    timeout: int,
) -> Dict[str, Any]:
    deadline = time.monotonic() + timeout
    previous_status: Optional[str] = None
    while True:
        status = api_request(
            base_url,
            api_key,
            "GET",
            f"/contents/generations/tasks/{urllib.parse.quote(task_id)}",
            timeout=60,
        )
        current_status = str(status.get("status", "unknown"))
        if current_status != previous_status:
            print(f"{task_id}: {current_status}", flush=True)
            previous_status = current_status
        if current_status in TERMINAL_STATUSES:
            return status
        if time.monotonic() >= deadline:
            raise SeedanceError(f"Timed out while waiting for {task_id}")
        time.sleep(poll_interval)


def print_validation(manifest_request: Dict[str, Any], payload_size: int) -> None:
    print(f"Preset: {manifest_request['preset']}")
    print(f"Model: {manifest_request['model']}")
    print(
        f"Output: {manifest_request['duration']}s, {manifest_request['resolution']}, "
        f"{manifest_request['ratio']}, audio={manifest_request['generate_audio']}"
    )
    if manifest_request.get("target_edit_seconds") is not None:
        print(
            f"Target edit: {manifest_request['target_edit_seconds']}s at "
            f"{manifest_request.get('target_timeline', 'unspecified timeline')}"
        )
    print(f"Images: {len(manifest_request['images'])}")
    for image in manifest_request["images"]:
        print(f"  {image['label']}: {image['path']} ({image['bytes'] / 1024 / 1024:.1f} MB)")
    print(f"Encoded request: {payload_size / 1024 / 1024:.1f} MB / 64 MB")
    print(f"Prompt characters: {len(manifest_request['prompt'])}")


def command_models(config: Dict[str, Any]) -> int:
    base_url = resolve_base_url(config)
    response = api_request(base_url, require_api_key(), "GET", "/models", timeout=30)
    models = sorted(
        model.get("id", "")
        for model in response.get("data", [])
        if "seedance" in model.get("id", "").lower()
    )
    if not models:
        print("No Seedance models returned for this key.")
        return 1
    print("Seedance models available to this key:")
    for model in models:
        print(f"  {model}")
    return 0


def command_validate(config: Dict[str, Any], args: argparse.Namespace) -> int:
    payload, manifest_request = build_request(config, args.preset, args.model)
    body = request_bytes(payload)
    print_validation(manifest_request, len(body))
    print("Validation passed. No API request was sent.")
    return 0


def command_generate(config: Dict[str, Any], args: argparse.Namespace) -> int:
    base_url = resolve_base_url(config)
    api_key = require_api_key()
    payload, manifest_request = build_request(config, args.preset, args.model)
    body = request_bytes(payload)
    print_validation(manifest_request, len(body))
    print("Submitting one paid ModelArk generation...", flush=True)
    created = api_request(
        base_url,
        api_key,
        "POST",
        "/contents/generations/tasks",
        payload=payload,
        timeout=120,
    )
    task_id = safe_task_id(str(created.get("id", "")))
    if not task_id:
        raise SeedanceError(f"ModelArk did not return a task ID: {created}")
    run_dir = RUNS_DIR / task_id
    manifest_path = run_dir / "job.json"
    manifest = {
        "schema_version": 1,
        "provider": config["provider"],
        "api_base_url": base_url,
        "task_id": task_id,
        "submitted_at": utc_now(),
        "request": manifest_request,
        "status": "submitted",
        "local_outputs": {},
    }
    write_json_atomic(manifest_path, manifest)
    print(f"Task: {task_id}", flush=True)
    print(f"Manifest: {manifest_path.relative_to(PROJECT_ROOT)}", flush=True)
    if args.no_wait:
        return 0
    status = poll_task(base_url, api_key, task_id, args.poll_interval, args.timeout)
    manifest["status"] = status.get("status")
    manifest["completed_at"] = utc_now()
    manifest["response"] = status_summary(status)
    if status.get("status") == "succeeded":
        manifest["local_outputs"] = download_outputs(status, run_dir)
    write_json_atomic(manifest_path, manifest)
    if status.get("status") != "succeeded":
        raise SeedanceError(f"Task {task_id} ended with status {status.get('status')}")
    for label, path in manifest["local_outputs"].items():
        print(f"{label}: {path}")
    return 0


def command_status(config: Dict[str, Any], args: argparse.Namespace) -> int:
    task_id = safe_task_id(args.task_id)
    base_url = resolve_base_url(config)
    api_key = require_api_key()
    if args.wait:
        status = poll_task(base_url, api_key, task_id, args.poll_interval, args.timeout)
    else:
        status = api_request(
            base_url,
            api_key,
            "GET",
            f"/contents/generations/tasks/{urllib.parse.quote(task_id)}",
            timeout=60,
        )
        print(f"{task_id}: {status.get('status', 'unknown')}")
    run_dir = RUNS_DIR / task_id
    manifest_path = run_dir / "job.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = {
            "schema_version": 1,
            "provider": config["provider"],
            "api_base_url": base_url,
            "task_id": task_id,
            "request": None,
            "local_outputs": {},
        }
    manifest["status"] = status.get("status")
    manifest["checked_at"] = utc_now()
    manifest["response"] = status_summary(status)
    if args.download and status.get("status") == "succeeded":
        manifest["local_outputs"] = download_outputs(status, run_dir)
    write_json_atomic(manifest_path, manifest)
    print(json.dumps(status_summary(status), indent=2, sort_keys=True))
    if manifest.get("local_outputs"):
        print("Local outputs:")
        for label, path in manifest["local_outputs"].items():
            print(f"  {label}: {path}")
    return 0 if status.get("status") != "failed" else 1


def build_parser(config: Dict[str, Any]) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("models", help="List Seedance models enabled for the API key")

    preset_choices = sorted(config.get("presets", {}))
    model_choices = sorted(config.get("models", {}))

    validate = subparsers.add_parser("validate", help="Validate a preset without calling the API")
    validate.add_argument("preset", choices=preset_choices)
    validate.add_argument("--model", choices=model_choices, default="mini")

    generate = subparsers.add_parser("generate", help="Submit, poll, and download one generation")
    generate.add_argument("preset", choices=preset_choices)
    generate.add_argument("--model", choices=model_choices, default="mini")
    generate.add_argument("--no-wait", action="store_true", help="Return after task submission")
    generate.add_argument("--poll-interval", type=int, default=10)
    generate.add_argument("--timeout", type=int, default=3600)

    status = subparsers.add_parser("status", help="Inspect or resume a task by ID")
    status.add_argument("task_id")
    status.add_argument("--wait", action="store_true", help="Poll until the task is terminal")
    status.add_argument("--download", action="store_true", help="Download outputs when succeeded")
    status.add_argument("--poll-interval", type=int, default=10)
    status.add_argument("--timeout", type=int, default=3600)
    return parser


def main() -> int:
    load_dotenv(ENV_PATH)
    config = load_config()
    parser = build_parser(config)
    args = parser.parse_args()
    if args.command == "models":
        return command_models(config)
    if args.command == "validate":
        return command_validate(config, args)
    if args.command == "generate":
        return command_generate(config, args)
    if args.command == "status":
        return command_status(config, args)
    parser.error("Unknown command")
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SeedanceError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
