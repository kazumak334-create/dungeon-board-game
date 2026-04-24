"""異常検知ルールセット R1~R7"""
import re
from typing import Optional


def detect(buffer: list) -> Optional[dict]:
    joined = "\n".join(buffer)

    if _r3_error_log(buffer):
        return {"rule": "R3", "message": "エラーログ検出", "lines": _get_error_lines(buffer)}

    if _r7_null_reference(joined):
        return {"rule": "R7", "message": "Null参照エラー検出"}

    if _r6_autoload_missing(joined):
        return {"rule": "R6", "message": "Autoload未登録の疑い"}

    if _r4_scene_infinite_loop(buffer):
        return {"rule": "R4", "message": "シーン遷移ループ疑い"}

    if _r2_event_push_no_process(buffer):
        return {"rule": "R2", "message": "EVENTが連続してSTATEが更新されていない"}

    if _r1_start_without_done(buffer):
        return {"rule": "R1", "message": "処理開始後にdone未到達（ハング疑い）"}

    return None


def _r1_start_without_done(buf: list) -> bool:
    starts = [l for l in buf if "start" in l.lower() and "[STATE]" in l]
    dones = [l for l in buf if "done" in l.lower() or "complete" in l.lower()]
    return len(starts) > 0 and len(dones) == 0 and len(buf) > 30


def _r2_event_push_no_process(buf: list) -> bool:
    recent = buf[-20:]
    events = sum(1 for l in recent if "[EVENT]" in l)
    states = sum(1 for l in recent if "[STATE]" in l)
    return events >= 5 and states == 0


def _r3_error_log(buf: list) -> bool:
    return any("[ERROR]" in l for l in buf[-10:])


def _get_error_lines(buf: list) -> list:
    return [l for l in buf if "[ERROR]" in l]


def _r4_scene_infinite_loop(buf: list) -> bool:
    scenes = [l for l in buf[-30:] if "scene" in l.lower() and "[STATE]" in l]
    if len(scenes) < 5:
        return False
    unique = set(re.sub(r"\[.*?\]", "", s) for s in scenes)
    return len(unique) <= 2


def _r6_autoload_missing(text: str) -> bool:
    return "Node not found" in text or "Invalid get index" in text


def _r7_null_reference(text: str) -> bool:
    return "Null Instance" in text or "null reference" in text.lower()
