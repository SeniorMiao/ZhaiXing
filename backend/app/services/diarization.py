from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import numpy as np
import scipy.sparse.linalg
import torch
from sklearn.cluster import AgglomerativeClustering
from sklearn.cluster._kmeans import k_means
from sklearn.metrics.pairwise import cosine_similarity

_REPO_ROOT = Path(__file__).resolve().parents[3]
_3D_SPEAKER_ROOT = _REPO_ROOT / "third_party" / "3D-Speaker"


@dataclass(frozen=True)
class DiarSegment:
    start_ms: int
    end_ms: int
    speaker_id: int


def _ensure_3dspeaker_on_path() -> None:
    root = str(_3D_SPEAKER_ROOT)
    if not _3D_SPEAKER_ROOT.is_dir():
        raise RuntimeError(
            "未找到 3D-Speaker。请在项目根执行: "
            "powershell -ExecutionPolicy Bypass -File scripts/install-3dspeaker.ps1"
        )
    if root not in sys.path:
        sys.path.insert(0, root)


def _compressed_seg(seg_list: list[list[float | int]]) -> list[list[float | int]]:
    new_seg_list: list[list[float | int]] = []
    for i, seg in enumerate(seg_list):
        seg_st, seg_ed, cluster_id = seg
        if i == 0:
            new_seg_list.append([seg_st, seg_ed, cluster_id])
        elif cluster_id == new_seg_list[-1][2]:
            if seg_st > new_seg_list[-1][1]:
                new_seg_list.append([seg_st, seg_ed, cluster_id])
            else:
                new_seg_list[-1][1] = seg_ed
        else:
            if seg_st < new_seg_list[-1][1]:
                p = (new_seg_list[-1][1] + seg_st) / 2
                new_seg_list[-1][1] = p
                seg_st = p
            new_seg_list.append([seg_st, seg_ed, cluster_id])
    return new_seg_list


def _merge_vad_regions(regions: list[list[float]], gap: float = 0.5) -> list[list[float]]:
    if not regions:
        return regions
    merged: list[list[float]] = [regions[0][:]]
    for st, ed in regions[1:]:
        if st - merged[-1][1] <= gap:
            merged[-1][1] = ed
        else:
            merged.append([st, ed])
    return merged


def _energy_vad(wav: torch.Tensor, sample_rate: int, frame_ms: int = 30, threshold: float = 0.0005) -> list[list[float]]:
    mono = wav[0].numpy()
    frame_len = max(1, int(sample_rate * frame_ms / 1000))
    regions: list[list[float]] = []
    in_speech = False
    start = 0.0
    for i in range(0, len(mono), frame_len):
        frame = mono[i : i + frame_len]
        if frame.size == 0:
            continue
        energy = float(np.mean(frame * frame))
        t = i / sample_rate
        if energy >= threshold:
            if not in_speech:
                start = t
                in_speech = True
        elif in_speech:
            regions.append([start, t])
            in_speech = False
    if in_speech:
        regions.append([start, len(mono) / sample_rate])
    if not regions:
        regions.append([0.0, len(mono) / sample_rate])
    return regions


def _estimate_speaker_count(laplacian: np.ndarray, min_spks: int = 1, max_spks: int = 8) -> int:
    k = min(max_spks + 1, laplacian.shape[0])
    if k <= min_spks:
        return min_spks
    lambdas, _ = scipy.sparse.linalg.eigsh(laplacian, k=k, which="SM")
    gaps = [float(lambdas[i + 1]) - float(lambdas[i]) for i in range(len(lambdas) - 1)]
    if not gaps:
        return min_spks
    offset = min_spks - 1
    best = int(np.argmax(gaps[offset : max_spks])) + min_spks
    return max(min_spks, min(best, max_spks))


def _spectral_cluster(embeddings: np.ndarray, speaker_num: int | None = None) -> np.ndarray:
    n = embeddings.shape[0]
    if n <= 1:
        return np.zeros(n, dtype=int)

    sim = cosine_similarity(embeddings, embeddings)
    pval = 0.012
    n_elems = min(int((1 - pval) * n), n - 6)
    n_elems = max(n_elems, 1)
    pruned = sim.copy()
    for i in range(n):
        low = np.argsort(pruned[i, :])[:n_elems]
        pruned[i, low] = 0
    sym = 0.5 * (pruned + pruned.T)
    np.fill_diagonal(sym, 0)
    degree = np.sum(np.abs(sym), axis=1)
    lap = -sym
    np.fill_diagonal(lap, degree)

    if speaker_num is None:
        speaker_num = _estimate_speaker_count(lap)
    speaker_num = max(1, min(speaker_num, n))
    if n < 40:
        dist = 1.0 - sym
        np.fill_diagonal(dist, 0.0)
        model = AgglomerativeClustering(n_clusters=speaker_num, metric="precomputed", linkage="average")
        return model.fit_predict(dist)

    k = min(speaker_num + 1, n)
    _, eig_vecs = scipy.sparse.linalg.eigsh(lap, k=k, which="SM")
    emb = eig_vecs[:, :speaker_num]
    _, labels, _ = k_means(emb, speaker_num)
    return labels


class CamPlusDiarizer:
    """3D-Speaker CAM++ without FunASR VAD / fastcluster (Python 3.14 compatible)."""

    def __init__(self, model_cache_dir: str | None = None, speaker_num: int | None = None) -> None:
        _ensure_3dspeaker_on_path()
        from speakerlab.utils.builder import build
        from speakerlab.utils.config import Config
        from speakerlab.utils.utils import circle_pad, download_model_from_modelscope

        self._circle_pad = circle_pad
        self.speaker_num = speaker_num

        emb_conf = {
            "model_id": "iic/speech_campplus_sv_zh_en_16k-common_advanced",
            "revision": "v1.0.0",
            "model_ckpt": "campplus_cn_en_common.pt",
            "embedding_model": {
                "obj": "speakerlab.models.campplus.DTDNN.CAMPPlus",
                "args": {"feat_dim": 80, "embedding_size": 192},
            },
            "feature_extractor": {
                "obj": "speakerlab.process.processor.FBank",
                "args": {"n_mels": 80, "sample_rate": 16000, "mean_nor": True},
            },
        }
        cache_dir = download_model_from_modelscope(
            emb_conf["model_id"], emb_conf["revision"], model_cache_dir
        )
        ckpt = os.path.join(cache_dir, emb_conf["model_ckpt"])
        config = Config(emb_conf)
        self.feature_extractor = build("feature_extractor", config)
        self.embedding_model = build("embedding_model", config)
        state = torch.load(ckpt, map_location="cpu", weights_only=True)
        self.embedding_model.load_state_dict(state)
        self.embedding_model.eval()
        self.fs = self.feature_extractor.sample_rate

    def _load_wav(self, wav_path: str) -> torch.Tensor:
        import soundfile as sf
        import torchaudio

        data, fs = sf.read(wav_path, dtype="float32", always_2d=False)
        if data.ndim > 1:
            data = data.mean(axis=1)
        wav = torch.from_numpy(np.asarray(data, dtype=np.float32)).unsqueeze(0)
        if fs != self.fs:
            wav = torchaudio.functional.resample(wav, orig_freq=fs, new_freq=self.fs)
        return wav

    def _chunk(self, st: float, ed: float, dur: float = 1.5, step: float = 0.75) -> list[list[float]]:
        chunks: list[list[float]] = []
        subseg_st = st
        while subseg_st + dur < ed + step:
            subseg_ed = min(subseg_st + dur, ed)
            chunks.append([subseg_st, subseg_ed])
            subseg_st += step
        if not chunks and ed > st:
            chunks.append([st, ed])
        return chunks

    def _extract_embeddings(self, chunks: list[list[float]], wav: torch.Tensor) -> np.ndarray:
        wavs = [wav[0, int(st * self.fs) : int(ed * self.fs)] for st, ed in chunks]
        max_len = max(x.shape[0] for x in wavs)
        wavs = [self._circle_pad(x, max_len) for x in wavs]
        wavs = torch.stack(wavs).unsqueeze(1)
        embeddings: list[torch.Tensor] = []
        batch_st = 0
        batch_size = 64
        with torch.no_grad():
            while batch_st < len(chunks):
                batch = wavs[batch_st : batch_st + batch_size]
                feats = torch.vmap(self.feature_extractor)(batch)
                embeddings.append(self.embedding_model(feats).cpu())
                batch_st += batch_size
        return torch.cat(embeddings, dim=0).numpy()

    def __call__(self, wav_path: str, speaker_num: int | None = None) -> list[list[float | int]]:
        wav_data = self._load_wav(wav_path)
        duration = wav_data.shape[1] / self.fs
        vad_time = _merge_vad_regions(_energy_vad(wav_data, self.fs))
        if not vad_time:
            vad_time = [[0.0, duration]]
        chunks = [c for st, ed in vad_time for c in self._chunk(st, ed)]
        if not chunks:
            return []
        embeddings = self._extract_embeddings(chunks, wav_data)
        spk = speaker_num if speaker_num is not None else self.speaker_num
        labels = _spectral_cluster(embeddings, spk)
        output = [[i[0], i[1], int(j)] for i, j in zip(chunks, labels)]
        return _compressed_seg(output)


@lru_cache(maxsize=1)
def _get_diarizer(model_cache_dir: str | None, speaker_num: int | None) -> CamPlusDiarizer:
    return CamPlusDiarizer(model_cache_dir=model_cache_dir, speaker_num=speaker_num)


def diarize_audio(
    wav_path: str,
    *,
    model_cache_dir: str | None = None,
    speaker_num: int | None = None,
) -> list[DiarSegment]:
    diarizer = _get_diarizer(model_cache_dir, speaker_num)
    raw = diarizer(wav_path, speaker_num=speaker_num)
    return [
        DiarSegment(
            start_ms=int(float(start_s) * 1000),
            end_ms=int(float(end_s) * 1000),
            speaker_id=int(spk_id),
        )
        for start_s, end_s, spk_id in raw
    ]


def speaker_label(speaker_id: int) -> str:
    if 0 <= speaker_id < 26:
        return f"Speaker {chr(ord('A') + speaker_id)}"
    return f"Speaker {speaker_id + 1}"


def _overlap_ms(a_start: int, a_end: int, b_start: int, b_end: int) -> int:
    return max(0, min(a_end, b_end) - max(a_start, b_start))


def assign_speaker_labels(asr_segments: list, diar_segments: list[DiarSegment]) -> list[str]:
    if not diar_segments:
        return ["Speaker A"] * len(asr_segments)

    labels: list[str] = []
    for seg in asr_segments:
        best_id = diar_segments[0].speaker_id
        best_overlap = -1
        mid = (seg.start_ms + seg.end_ms) // 2
        for d in diar_segments:
            overlap = _overlap_ms(seg.start_ms, seg.end_ms, d.start_ms, d.end_ms)
            if overlap > best_overlap:
                best_overlap = overlap
                best_id = d.speaker_id
        if best_overlap <= 0:
            for d in diar_segments:
                if d.start_ms <= mid <= d.end_ms:
                    best_id = d.speaker_id
                    break
        labels.append(speaker_label(best_id))
    return labels
