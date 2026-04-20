from dataclasses import dataclass
import os


@dataclass(frozen=True)
class AsrSegment:
    start_ms: int
    end_ms: int
    text: str


def transcribe_with_faster_whisper(audio_path: str, model_name: str, hf_endpoint: str | None = None) -> list[AsrSegment]:
    from faster_whisper import WhisperModel

    if hf_endpoint:
        os.environ.setdefault("HF_ENDPOINT", hf_endpoint)
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")

    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(audio_path, vad_filter=True)
    out: list[AsrSegment] = []
    for s in segments:
        text = (s.text or "").strip()
        if not text:
            continue
        out.append(AsrSegment(start_ms=int(float(s.start) * 1000), end_ms=int(float(s.end) * 1000), text=text))
    return out

