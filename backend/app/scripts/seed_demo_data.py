import json
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from backend.app.core.security import hash_password
from backend.app.db.session import SessionLocal
from backend.app.models.enums import JobStage, JobState, MeetingStatus
from backend.app.models.job import Job
from backend.app.models.meeting import MediaFile, Meeting, MeetingSummary
from backend.app.models.transcript import TranscriptSegment
from backend.app.models.user import User


def _dt_iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()


def _ensure_user(db: Session, *, email: str, password: str, nickname: str) -> User:
    user = db.query(User).filter(User.email == email).one_or_none()
    if user is not None:
        if not user.password_hash:
            user.password_hash = hash_password(password)
            user.nickname = user.nickname or nickname
            db.add(user)
            db.commit()
            db.refresh(user)
        return user

    user = User(email=email, nickname=nickname, password_hash=hash_password(password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _delete_demo_for_user(db: Session, user_id: int) -> int:
    demo_meetings = db.query(Meeting).filter(Meeting.user_id == user_id, Meeting.title.like("DEMO:%")).all()
    if not demo_meetings:
        return 0
    ids = [m.id for m in demo_meetings]

    db.query(TranscriptSegment).filter(TranscriptSegment.meeting_id.in_(ids)).delete(synchronize_session=False)
    db.query(Job).filter(Job.meeting_id.in_(ids)).delete(synchronize_session=False)
    db.query(MeetingSummary).filter(MeetingSummary.meeting_id.in_(ids)).delete(synchronize_session=False)
    db.query(MediaFile).filter(MediaFile.meeting_id.in_(ids)).delete(synchronize_session=False)
    db.query(Meeting).filter(Meeting.id.in_(ids)).delete(synchronize_session=False)
    db.commit()
    return len(ids)


def seed_demo_data(db: Session, *, user: User) -> list[int]:
    deleted = _delete_demo_for_user(db, user.id)
    if deleted:
        print(f"OK: deleted {deleted} existing DEMO meetings")

    now = datetime.now(tz=timezone.utc)

    def mk_meeting(*, title: str, meeting_type: str, status: MeetingStatus, minutes_ago: int) -> Meeting:
        m = Meeting(
            user_id=user.id,
            title=f"DEMO:{title}",
            meeting_type=meeting_type,
            status=status.value,
        )
        db.add(m)
        db.commit()
        db.refresh(m)

        # 让列表排序更像“真实使用”
        created = now - timedelta(minutes=minutes_ago)
        db.query(Meeting).filter(Meeting.id == m.id).update(
            {"created_at": created, "updated_at": created}, synchronize_session=False
        )
        db.commit()
        db.refresh(m)
        return m

    # 1) 已完成（ready）：有转写 + 摘要/待办/决策
    m1 = mk_meeting(title="产品周会（纪要完整）", meeting_type="internal", status=MeetingStatus.ready, minutes_ago=35)
    db.add(
        MeetingSummary(
            meeting_id=m1.id,
            summary_text="本周重点：推进移动端联调与 ASR 精度优化。下周计划上线纪要导出与个人中心设置。",
            todos_json=json.dumps(
                [
                    "将 ASR 模型从 tiny 升级到 medium，并观察耗时与准确度",
                    "完善纪要详情页的编辑/导出入口（先本地，后续接后端）",
                    "整理 README：启动、测试账号、模拟器上传说明",
                ],
                ensure_ascii=False,
            ),
            decisions_json=json.dumps(
                [
                    "MVP 只做会后上传，不做实时录音",
                    "移动端暂不做会员体系，先用占位提示",
                ],
                ensure_ascii=False,
            ),
            model_version="demo",
        )
    )
    segs1 = [
        (0, 5200, "Speaker A", "大家好，今天我们快速过一下本周进度。"),
        (5200, 13800, "Speaker B", "移动端已经接通登录、会议列表和上传处理流程。"),
        (13800, 24000, "Speaker A", "ASR 目前用 tiny 准确度偏低，建议升级到 medium 先试。"),
        (24000, 36000, "Speaker C", "纪要页需要按原型补齐：编辑、导出、空白提示。"),
        (36000, 48000, "Speaker A", "好，那就按这个计划推进，下周复盘。"),
    ]
    for start, end, spk, text in segs1:
        db.add(TranscriptSegment(meeting_id=m1.id, start_ms=start, end_ms=end, speaker_label=spk, text=text))
    db.commit()

    # 2) 已完成（ready）：纪要为空（展示空白页）
    m2 = mk_meeting(title="访谈记录（纪要为空）", meeting_type="interview", status=MeetingStatus.ready, minutes_ago=140)
    db.add(
        MeetingSummary(
            meeting_id=m2.id,
            summary_text="",
            todos_json=json.dumps([], ensure_ascii=False),
            decisions_json=json.dumps([], ensure_ascii=False),
            model_version="demo",
        )
    )
    segs2 = [
        (0, 6200, "Interviewer", "你在使用会议纪要工具时，最看重的是什么？"),
        (6200, 14800, "Guest", "准确度和可编辑性吧，最好还能一键导出分享。"),
        (14800, 23600, "Interviewer", "了解，那我们会优先补齐编辑与导出。"),
    ]
    for start, end, spk, text in segs2:
        db.add(TranscriptSegment(meeting_id=m2.id, start_ms=start, end_ms=end, speaker_label=spk, text=text))
    db.commit()

    # 3) 处理中（processing）：有一个运行中的 job（展示进度）
    m3 = mk_meeting(title="培训录音（处理中）", meeting_type="training", status=MeetingStatus.processing, minutes_ago=8)
    db.add(
        Job(
            meeting_id=m3.id,
            state=JobState.running.value,
            stage=JobStage.asr.value,
            progress=42,
            error_message=None,
        )
    )
    db.commit()

    # 4) 失败（failed）：失败 job（展示错误）
    m4 = mk_meeting(title="外部分享（失败示例）", meeting_type="external", status=MeetingStatus.failed, minutes_ago=420)
    db.add(
        Job(
            meeting_id=m4.id,
            state=JobState.failed.value,
            stage=JobStage.transcode.value,
            progress=7,
            error_message="demo: 转码失败（请重新上传或换音频格式）",
        )
    )
    db.commit()

    # 5+) 列表 / 纪要页滚动测试：多时间梯度与多状态（仍用 DEMO: 前缀，重跑种子会整体替换）
    scroll_rows: list[tuple[str, str, MeetingStatus, int]] = [
        ("滚动#01 晨间同步", "internal", MeetingStatus.ready, 11),
        ("滚动#02 需求澄清", "internal", MeetingStatus.created, 16),
        ("滚动#03 设计走查", "internal", MeetingStatus.ready, 24),
        ("滚动#04 接口评审", "internal", MeetingStatus.uploading, 29),
        ("滚动#05 联调排期", "external", MeetingStatus.ready, 38),
        ("滚动#06 客户演示彩排", "external", MeetingStatus.queued, 46),
        ("滚动#07 季度规划（精简）", "internal", MeetingStatus.ready, 58),
        ("滚动#08 用户访谈 #2", "interview", MeetingStatus.ready, 72),
        ("滚动#09 用户访谈 #3", "interview", MeetingStatus.ready, 95),
        ("滚动#10 新人培训（上）", "training", MeetingStatus.ready, 125),
        ("滚动#11 新人培训（下）", "training", MeetingStatus.ready, 180),
        ("滚动#12 安全合规宣贯", "internal", MeetingStatus.ready, 260),
        ("滚动#13 供应商沟通", "external", MeetingStatus.created, 340),
        ("滚动#14 技术分享：ASR", "internal", MeetingStatus.ready, 520),
        ("滚动#15 技术分享：摘要", "internal", MeetingStatus.ready, 780),
        ("滚动#16 项目复盘（一月）", "internal", MeetingStatus.ready, 1100),
        ("滚动#17 项目复盘（二月）", "internal", MeetingStatus.ready, 1600),
        ("滚动#18 跨部门协调会", "external", MeetingStatus.ready, 2400),
        ("滚动#19 归档：旧录音样本", "training", MeetingStatus.ready, 4000),
        ("滚动#20 归档：压力测试占位", "internal", MeetingStatus.ready, 7200),
    ]
    scroll_meetings: list[Meeting] = []
    empty_summary = json.dumps([], ensure_ascii=False)
    for title, mtype, st, minutes_ago in scroll_rows:
        m = mk_meeting(title=title, meeting_type=mtype, status=st, minutes_ago=minutes_ago)
        scroll_meetings.append(m)
        if st == MeetingStatus.ready:
            db.add(
                MeetingSummary(
                    meeting_id=m.id,
                    summary_text=f"演示数据：{title} 的简要纪要，用于列表滚动与纪要入口测试。",
                    todos_json=empty_summary,
                    decisions_json=empty_summary,
                    model_version="demo",
                )
            )
    db.commit()

    all_demo = [m1, m2, m3, m4, *scroll_meetings]
    print("OK: seeded demo meetings:")
    for m in all_demo:
        print(f"- meeting_id={m.id} title={m.title} status={m.status} created_at={_dt_iso(m.created_at)}")

    return [m.id for m in all_demo]


def main() -> None:
    email = "test@example.com"
    password = "test123456"
    nickname = "测试用户"

    db = SessionLocal()
    try:
        user = _ensure_user(db, email=email, password=password, nickname=nickname)
        seed_demo_data(db, user=user)
    finally:
        db.close()


if __name__ == "__main__":
    main()

