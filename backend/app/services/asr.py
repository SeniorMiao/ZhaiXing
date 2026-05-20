from __future__ import annotations

import gc
import os
import shutil
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from functools import lru_cache


@dataclass(frozen=True)
class AsrSegment:
    start_ms: int
    end_ms: int
    text: str


def _limit_cpu_threads() -> None:
    """Reduce MKL/OMP peak memory on CPU-only machines."""
    for key in ("OMP_NUM_THREADS", "MKL_NUM_THREADS", "OPENBLAS_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
        os.environ.setdefault(key, "1")


def _apply_hf_env(hf_endpoint: str | None) -> None:
    if hf_endpoint:
        os.environ.setdefault("HF_ENDPOINT", hf_endpoint)
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")


def _resolve_language(language: str | None) -> str | None:
    if language is None:
        return None
    lang = language.strip().lower()
    if lang in {"", "auto", "detect"}:
        return None
    return lang


def _ffmpeg_exe() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg  # type: ignore

    return imageio_ffmpeg.get_ffmpeg_exe()


def _wav_duration_sec(path: str) -> float:
    with wave.open(path, "rb") as w:
        return w.getnframes() / float(w.getframerate())


@lru_cache(maxsize=2)
def _get_whisper_model(model_name: str, hf_endpoint: str | None):
    from faster_whisper import WhisperModel

    _limit_cpu_threads()
    _apply_hf_env(hf_endpoint)
    return WhisperModel(model_name, device="cpu", compute_type="int8", cpu_threads=1)


def release_asr_model() -> None:
    _get_whisper_model.cache_clear()
    gc.collect()


def _build_transcribe_kwargs(
    *,
    language: str | None,
    initial_prompt: str | None,
    vad_filter: bool,
) -> dict:
    lang = _resolve_language(language)
    kwargs: dict = {
        "vad_filter": vad_filter,
        "beam_size": 1,
        "best_of": 1,
        "vad_parameters": {"min_silence_duration_ms": 500},
    }
    if lang is not None:
        kwargs["language"] = lang
    if initial_prompt:
        kwargs["initial_prompt"] = initial_prompt
    elif lang == "zh":
        kwargs["initial_prompt"] = "这是一段中文会议录音，包含讨论、计划与工作安排。"
    return kwargs


def _segments_from_result(segments, offset_ms: int) -> list[AsrSegment]:
    out: list[AsrSegment] = []
    for s in segments:
        text = (s.text or "").strip()
        if not text:
            continue
        out.append(
            AsrSegment(
                start_ms=offset_ms + int(float(s.start) * 1000),
                end_ms=offset_ms + int(float(s.end) * 1000),
                text=text,
            )
        )
    return out


def _transcribe_file(
    model,
    audio_path: str,
    offset_ms: int,
    *,
    language: str | None,
    initial_prompt: str | None,
    vad_filter: bool,
) -> list[AsrSegment]:
    kwargs = _build_transcribe_kwargs(
        language=language,
        initial_prompt=initial_prompt,
        vad_filter=vad_filter,
    )
    segments, _info = model.transcribe(audio_path, **kwargs)
    return _segments_from_result(segments, offset_ms)


def transcribe_with_faster_whisper(
    audio_path: str,
    model_name: str,
    hf_endpoint: str | None = None,
    *,
    language: str | None = "auto",
    initial_prompt: str | None = None,
    chunk_seconds: int = 300,
) -> list[AsrSegment]:
    """Transcribe audio; long files are split to avoid VAD OOM on full-length mel matrices."""
    model = _get_whisper_model(model_name, hf_endpoint)
    duration = _wav_duration_sec(audio_path)

    if duration <= chunk_seconds:
        return _transcribe_file(
            model,
            audio_path,
            0,
            language=language,
            initial_prompt=initial_prompt,
            vad_filter=True,
        )

    ffmpeg = _ffmpeg_exe()
    merged: list[AsrSegment] = []
    start_sec = 0.0
    idx = 0
    with tempfile.TemporaryDirectory(prefix="zx_asr_") as tmp:
        while start_sec < duration:
            seg_dur = min(float(chunk_seconds), duration - start_sec)
            chunk_path = os.path.join(tmp, f"chunk_{idx:04d}.wav")
            subprocess.run(
                [
                    ffmpeg,
                    "-y",
                    "-i",
                    audio_path,
                    "-ss",
                    str(start_sec),
                    "-t",
                    str(seg_dur),
                    "-ac",
                    "1",
                    "-ar",
                    "16000",
                    chunk_path,
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            merged.extend(
                _transcribe_file(
                    model,
                    chunk_path,
                    int(start_sec * 1000),
                    language=language,
                    initial_prompt=initial_prompt,
                    vad_filter=True,
                )
            )
            start_sec += seg_dur
            idx += 1
            gc.collect()

    return merged
