import json
import re
from dataclasses import dataclass

_SPEAKER_PREFIX = re.compile(r"^Speaker [A-Z0-9]+:\s*", re.IGNORECASE)


@dataclass(frozen=True)
class SummaryResult:
    summary: str
    todos: list[str]
    decisions: list[str]
    model_version: str


def _strip_speaker_lines(full_text: str) -> list[str]:
    lines: list[str] = []
    for raw in full_text.splitlines():
        line = raw.strip()
        if not line:
            continue
        line = _SPEAKER_PREFIX.sub("", line).strip()
        if line:
            lines.append(line)
    return lines


def summarize_fallback(full_text: str) -> SummaryResult:
    """Local fallback when Zhipu API key is absent. Not a true LLM summary."""
    lines = _strip_speaker_lines(full_text)
    if not lines:
        return SummaryResult(summary="（暂无摘要）", todos=[], decisions=[], model_version="fallback-v2")

    body = "\n".join(lines)
    sentences = [s.strip() for s in re.split(r"(?<=[。！？!?])", body) if s.strip()]
    if not sentences:
        sentences = lines

    summary_parts: list[str] = []
    char_count = 0
    for s in sentences:
        if char_count >= 400:
            break
        if not s.endswith(("。", "！", "？", ".", "!", "?")):
            s += "。"
        summary_parts.append(s)
        char_count += len(s)

    summary = "".join(summary_parts) if summary_parts else "。".join(lines[:5]) + "。"
    if len(lines) > len(summary_parts):
        summary = f"【要点摘录】\n{summary}\n\n（未配置智谱 API，以上为转写摘录，非 AI 归纳摘要。配置 ZHIPU_API_KEY 后可生成结构化纪要。）"

    todos: list[str] = []
    decisions: list[str] = []
    todo_kw = ("待办", "需要", "负责", "跟进", "完成", "提交", "确认", "安排", "截止")
    decision_kw = ("决定", "决策", "同意", "确定", "方案", "采用", "通过", "定为")

    for line in lines:
        if any(k in line for k in todo_kw) and 4 < len(line) <= 120:
            todos.append(line)
        elif any(k in line for k in decision_kw) and 4 < len(line) <= 120:
            decisions.append(line)

    return SummaryResult(
        summary=summary,
        todos=todos[:10],
        decisions=decisions[:10],
        model_version="fallback-v2",
    )


def _looks_english(text: str) -> bool:
    letters = re.findall(r"[A-Za-z]", text)
    cjk = re.findall(r"[\u4e00-\u9fff]", text)
    return len(letters) > len(cjk) * 2


def _build_zhipu_prompt(full_text: str) -> str:
    if _looks_english(full_text):
        return (
            "You are a meeting-minutes assistant. Summarize the transcript below.\n"
            "Return strict JSON only:\n"
            "{\n"
            '  "summary": "one-paragraph summary in English",\n'
            '  "todos": ["action item 1", "action item 2"],\n'
            '  "decisions": ["decision 1", "decision 2"]\n'
            "}\n"
            "Rules: todos must be actionable and concise; decisions must be explicit; do not copy the transcript verbatim.\n"
            "Transcript:\n"
            f"{full_text}"
        )
    return (
        "你是智能会议纪要助手。请根据会议全文生成结构化纪要，输出严格 JSON：\n"
        "{\n"
        '  "summary": "一段话摘要（中文）",\n'
        '  "todos": ["待办1", "待办2"],\n'
        '  "decisions": ["决策1", "决策2"]\n'
        "}\n"
        "要求：待办要可执行、尽量短；决策点要明确；不要照抄原文，要归纳。\n"
        "会议全文如下：\n"
        f"{full_text}"
    )


def summarize_with_zhipu(*, full_text: str, api_key: str, model: str) -> SummaryResult:
    from zhipuai import ZhipuAI

    client = ZhipuAI(api_key=api_key)
    prompt = _build_zhipu_prompt(full_text)

    resp = client.chat.completions.create(model=model, messages=[{"role": "user", "content": prompt}], temperature=0.2)
    content = getattr(resp.choices[0].message, "content", None) or ""

    try:
        data = json.loads(content)
    except Exception:
        m = re.search(r"\{[\s\S]*\}", content)
        if not m:
            return summarize_fallback(full_text)
        data = json.loads(m.group(0))

    summary = str(data.get("summary") or "").strip() or "（暂无摘要）"
    todos = [str(x).strip() for x in (data.get("todos") or []) if str(x).strip()]
    decisions = [str(x).strip() for x in (data.get("decisions") or []) if str(x).strip()]
    return SummaryResult(summary=summary, todos=todos[:20], decisions=decisions[:20], model_version=f"zhipu:{model}")
