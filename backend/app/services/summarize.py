import json
import re
from dataclasses import dataclass


@dataclass(frozen=True)
class SummaryResult:
    summary: str
    todos: list[str]
    decisions: list[str]
    model_version: str


def summarize_fallback(full_text: str) -> SummaryResult:
    sentences = re.split(r"[。！？\n]+", full_text)
    summary = "。".join([s.strip() for s in sentences if s.strip()][:2]).strip()
    if summary:
        summary += "。"
    return SummaryResult(summary=summary or "（暂无摘要）", todos=[], decisions=[], model_version="fallback-v1")


def summarize_with_zhipu(*, full_text: str, api_key: str, model: str) -> SummaryResult:
    from zhipuai import ZhipuAI

    client = ZhipuAI(api_key=api_key)
    prompt = (
        "你是智能会议纪要助手。请根据会议全文生成结构化纪要，输出严格 JSON：\n"
        "{\n"
        '  \"summary\": \"一段话摘要（中文）\",\n'
        '  \"todos\": [\"待办1\", \"待办2\"],\n'
        '  \"decisions\": [\"决策1\", \"决策2\"]\n'
        "}\n"
        "要求：待办要可执行、尽量短；决策点要明确。\n"
        "会议全文如下：\n"
        f"{full_text}"
    )

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

