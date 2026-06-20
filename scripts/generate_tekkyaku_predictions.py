import argparse
import json
import math
import re
import sys
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


BASE_URL = "https://snarfnet.github.io/keirin-data"
JST = timezone(timedelta(hours=9))
REPO_ROOT = Path(__file__).resolve().parents[1]


def fetch_json(file_name: str, required: bool = True) -> Any:
    url = f"{BASE_URL}/{file_name}?v={int(datetime.now().timestamp())}"
    try:
        with urllib.request.urlopen(url, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception:
        local = REPO_ROOT / "KeirinPredictor" / "Resources" / file_name
        if local.exists():
            return json.loads(local.read_text(encoding="utf-8"))
        if required:
            raise
        return None


def today_string() -> str:
    return datetime.now(JST).strftime("%Y%m%d")


def date_label(value: str) -> str:
    try:
        dt = datetime.strptime(value, "%Y%m%d")
        return f"{dt.year}年{dt.month}月{dt.day}日"
    except ValueError:
        return value


def compact_date_label(value: str) -> str:
    try:
        dt = datetime.strptime(value, "%Y%m%d")
        return f"{dt.month}/{dt.day}"
    except ValueError:
        return value


def pct(value: float) -> str:
    return f"{value:.1f}%"


def combo(values: list[int]) -> str:
    return "-".join(str(v) for v in values[:3])


def schedule_label(start_time: str | None, race_no: int) -> str:
    if not start_time or ":" not in start_time:
        return ""
    try:
        hour = int(start_time.split(":", 1)[0])
    except ValueError:
        return ""
    if hour >= 20 and race_no <= 9:
        return "ミッドナイト"
    if hour >= 16:
        return "ナイター"
    return "デイ"


def gear_value(text: str | None) -> float:
    try:
        return float(text or "0")
    except ValueError:
        return 0.0


def avg_rank(values: list[Any]) -> float | None:
    numbers = [float(v) for v in values if isinstance(v, (int, float))]
    return sum(numbers) / len(numbers) if numbers else None


def style_fit(style: str, venue: str, venue_stats: dict[str, Any]) -> float:
    stats = venue_stats.get(venue) or {}
    bank = int(stats.get("bank") or 400)
    km = stats.get("km") or {}
    style_key = "逃" if "逃" in style else "捲" if "捲" in style or "両" in style else "差"
    base = float(km.get(style_key) or 0.0)
    bonus = (base - 0.27) * 18
    if style_key == "逃" and bank <= 335:
        bonus += 2.4
    if style_key == "差" and bank >= 400:
        bonus += 1.6
    return bonus


def comment_bonus(comment: str | None) -> tuple[float, str | None]:
    text = comment or ""
    positive = ["調子", "良い", "自力", "練習", "勝負", "自在"]
    negative = ["落車", "ケガ", "欠場", "重い", "力不足", "不安"]
    score = 0.0
    label = None
    if any(word in text for word in positive):
        score += 1.4
        label = "コメント前向き"
    if any(word in text for word in negative):
        score -= 2.0
        label = "コメント注意"
    return score, label


def entry_score(entry: dict[str, Any], race: dict[str, Any], player_stats: dict[str, Any], venue_stats: dict[str, Any]) -> tuple[float, list[str]]:
    name = entry.get("name", "")
    stat = player_stats.get(name) or {}
    venue = race.get("venue", "")
    score = 48.0
    signals: list[str] = []

    live_score = float(entry.get("score") or 0)
    win_rate = float(entry.get("win_rate") or 0)
    top2_rate = float(entry.get("top2_rate") or 0)
    top3_rate = float(entry.get("top3_rate") or 0)

    score += live_score * 0.48
    score += win_rate * 0.30
    score += top2_rate * 0.10
    score += top3_rate * 0.07

    if stat:
        score += float(stat.get("wr") or 0) * 24
        score += float(stat.get("t2") or 0) * 8
        score += float(stat.get("t3") or 0) * 3
        form = float(stat.get("fm") or 0)
        score += max(0, form - 6.0) * 1.7
        recent = avg_rank(stat.get("rr") or [])
        if recent is not None:
            score += max(0, 4.2 - recent) * 2.2
            if recent <= 2.0:
                signals.append("近況上位")
        venue_records = stat.get("vs") or {}
        venue_record = venue_records.get(venue) or {}
        venue_runs = float(venue_record.get("r") or 0)
        venue_wins = float(venue_record.get("w") or 0)
        if venue_runs >= 20:
            score += min(8.0, (venue_wins / max(venue_runs, 1)) * 10)
            signals.append("場相性あり")
        dominant = stat.get("dk") or entry.get("style") or ""
        score += style_fit(str(dominant), venue, venue_stats)
    else:
        score += style_fit(str(entry.get("style") or ""), venue, venue_stats)

    cb, label = comment_bonus(entry.get("comment"))
    score += cb
    if label:
        signals.append(label)

    if gear_value(entry.get("gear")) >= 3.92:
        score += 0.8
    if win_rate >= 30:
        signals.append("勝率上位")
    if top3_rate >= 60:
        signals.append("3着内安定")

    return round(score, 3), signals[:4]


def softmax_prob(scores: list[float]) -> list[float]:
    if not scores:
        return []
    top = max(scores)
    spread = max(scores) - min(scores)
    temperature = max(6.8, min(11.0, 10.5 - spread / 8))
    weights = [math.exp((s - top) / temperature) for s in scores]
    total = sum(weights) or 1
    return [w / total for w in weights]


def analyze_race(race: dict[str, Any], player_stats: dict[str, Any], venue_stats: dict[str, Any]) -> dict[str, Any] | None:
    entries = race.get("entries") or []
    if len(entries) < 3:
        return None

    scored = []
    for entry in entries:
        score, signals = entry_score(entry, race, player_stats, venue_stats)
        item = dict(entry)
        item["tekkyaku_score"] = score
        item["signals"] = signals
        scored.append(item)

    scored.sort(key=lambda e: e["tekkyaku_score"], reverse=True)
    probs = softmax_prob([e["tekkyaku_score"] for e in scored])
    for entry, prob in zip(scored, probs):
        entry["win_probability"] = round(prob * 100, 1)

    prediction = [int(e["umaban"]) for e in scored[:3]]
    axis = scored[0]
    second = scored[1]
    third = scored[2]
    gap12 = axis["tekkyaku_score"] - second["tekkyaku_score"]
    gap13 = axis["tekkyaku_score"] - third["tekkyaku_score"]
    axis_win = min(float(axis["win_probability"]), 60.0)
    chaos = max(0.0, min(100.0, 58 - gap13 * 2.4 + (8 - gap12) * 2.0))

    if axis_win >= 34 and gap12 >= 5.5 and chaos < 48:
        grade = "S"
        action = "買い"
        action_reason = "軸が抜けていて、相手も絞りやすい"
    elif axis_win >= 28 and gap12 >= 3.0 and chaos < 60:
        grade = "A"
        action = "買い"
        action_reason = "本命の形が見え、勝負条件を満たす"
    elif axis_win >= 23:
        grade = "B"
        action = "注目"
        action_reason = "上位候補は見えるが、相手の食い込みに注意"
    else:
        grade = "候"
        action = "押さえ"
        action_reason = "指数上位から候補に追加"

    reasons = [
        action_reason,
        f"軸候補 {axis.get('name', '')}",
        f"軸1着目安 {axis_win:.0f}%",
    ]
    if gap12 >= 5:
        reasons.append("2番手との差があり、軸評価を上げる")
    if chaos >= 58:
        reasons.append("混戦気配。買い目は広げすぎない")
    for signal in axis.get("signals") or []:
        reasons.append(signal)

    start_time = race.get("start_time") or ""
    return {
        "race_id": race.get("race_id", ""),
        "date": race.get("date", ""),
        "venue": race.get("venue", ""),
        "venue_cd": race.get("venue_cd", ""),
        "race_no": int(race.get("race_no") or 0),
        "start_time": start_time,
        "schedule_label": schedule_label(start_time, int(race.get("race_no") or 0)),
        "prediction": prediction,
        "trifecta": prediction,
        "exacta": prediction[:2],
        "wide": prediction[:2],
        "axis_name": axis.get("name", ""),
        "axis_win_estimate": round(axis_win, 1),
        "chaos_score": round(chaos, 1),
        "grade": grade,
        "action_label": action,
        "action_reason": action_reason,
        "quality": round(axis_win * 2 + {"S": 24, "A": 16, "B": 8}.get(grade, 0) + (40 if action == "買い" else 0) - max(0, chaos - 55) * 1.4, 2),
        "reasons": reasons[:6],
        "top_entries": [
            {
                "umaban": int(e.get("umaban") or 0),
                "name": e.get("name", ""),
                "score": round(float(e.get("tekkyaku_score") or 0), 1),
                "win_probability": e.get("win_probability", 0),
                "style": e.get("style", ""),
                "signals": e.get("signals", []),
            }
            for e in scored[:5]
        ],
    }


def pick_races(entries_data: dict[str, Any], target_date: str | None) -> tuple[str, list[dict[str, Any]]]:
    races = entries_data.get("races") or []
    days = entries_data.get("days") or []
    if target_date:
        selected = [r for r in races if (r.get("date") or entries_data.get("date")) == target_date and r.get("entries")]
        return target_date, selected
    today = today_string()
    candidates = sorted([d for d in days if d >= today]) or [entries_data.get("date") or today]
    for day in candidates:
        selected = [r for r in races if (r.get("date") or day) == day and r.get("entries")]
        if selected:
            return day, selected
    day = entries_data.get("date") or today
    return day, [r for r in races if r.get("entries")]


def result_for_date(date: str) -> dict[str, list[int]]:
    data = fetch_json(f"results_{date}.json", required=False)
    if not data:
        return {}
    out: dict[str, list[int]] = {}
    for result in data.get("results") or []:
        finishers = sorted(result.get("finishers") or [], key=lambda f: int(f.get("rank") or 99))
        out[result.get("race_id", "")] = [int(f.get("umaban") or 0) for f in finishers[:3]]
    return out


@dataclass
class HitStats:
    total: int = 0
    win: int = 0
    trifecta: int = 0
    exacta: int = 0
    wide: int = 0

    def as_dict(self) -> dict[str, Any]:
        def rate(value: int) -> float:
            return round(value / self.total * 100, 1) if self.total else 0.0

        return {
            "completed": self.total,
            "win_count": self.win,
            "win_rate": rate(self.win),
            "trifecta_count": self.trifecta,
            "trifecta_rate": rate(self.trifecta),
            "exacta_count": self.exacta,
            "exacta_rate": rate(self.exacta),
            "wide_count": self.wide,
            "wide_rate": rate(self.wide),
        }


def evaluate_history(out_dir: Path, current_date: str) -> tuple[HitStats, dict[str, Any]]:
    stats = HitStats()
    previous_date = (datetime.strptime(current_date, "%Y%m%d") - timedelta(days=1)).strftime("%Y%m%d")
    previous = {"date": previous_date, "total": 0, "hits": []}
    for path in sorted(out_dir.glob("predictions_*.json")):
        match = re.search(r"predictions_(\d{8})\.json$", path.name)
        if not match:
            continue
        date = match.group(1)
        if date >= current_date:
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        actuals = result_for_date(date)
        if not actuals:
            continue
        for pick in data.get("predictions") or []:
            actual = actuals.get(pick.get("race_id"))
            pred = [int(v) for v in pick.get("prediction", [])[:3]]
            if not actual or len(pred) < 3 or len(actual) < 3:
                continue
            stats.total += 1
            if pred[0] == actual[0]:
                stats.win += 1
            if pred[:3] == actual[:3]:
                stats.trifecta += 1
            if pred[:2] == actual[:2]:
                stats.exacta += 1
            if set(pred[:2]).issubset(set(actual[:3])):
                stats.wide += 1
            if date == previous_date:
                previous["total"] += 1
                labels = []
                if pred[:3] == actual[:3]:
                    labels.append("3連単的中")
                if pred[:2] == actual[:2]:
                    labels.append("2車単的中")
                if set(pred[:2]).issubset(set(actual[:3])):
                    labels.append("ワイド的中")
                if pred[0] == actual[0]:
                    labels.append("1着的中")
                if labels:
                    previous["hits"].append({
                        "venue": pick.get("venue", ""),
                        "race_no": pick.get("race_no", 0),
                        "label": labels[0],
                        "predicted": pred,
                        "actual": actual,
                    })
    return stats, previous


def build_note(date: str, predictions: list[dict[str, Any]], stats: dict[str, Any], previous: dict[str, Any]) -> tuple[str, str]:
    top = predictions[0] if predictions else {}
    first_label = f"{top.get('venue', '本日の競輪')}{top.get('race_no', '')}R"
    first_start = top.get("start_time") or ""
    title = f"鉄脚博士の競輪予想｜{date_label(date)} {first_label}{(' 発走' + first_start) if first_start else ''} 本日の一押し{len(predictions)}本"
    lines = [
        title,
        "",
        "どうも、鉄脚博士です。",
        f"今日は展開、脚質、指数、直近の数字を見て、勝負候補を{len(predictions)}本に絞りました。",
        "買い目だけではなく、なぜそこを見るのかも短く添えます。",
        "",
        "先に数字を出します。盛りません。",
        "",
        "【現在の的中率】",
        f"集計対象: 鉄脚博士の予想から結果が出た{stats['completed']}レース",
        f"1着的中: {stats['win_count']}/{stats['completed']}（{pct(stats['win_rate'])}）",
        f"3連単: {stats['trifecta_count']}/{stats['completed']}（{pct(stats['trifecta_rate'])}）",
        f"2車単: {stats['exacta_count']}/{stats['completed']}（{pct(stats['exacta_rate'])}）",
        f"ワイド: {stats['wide_count']}/{stats['completed']}（{pct(stats['wide_rate'])}）",
        "",
        "※的中を保証するものではありません。",
        "※車券購入は20歳以上です。無理のない範囲で楽しんでください。",
        "※有料部分は200円です。",
        "",
        "【前日的中実績】",
    ]
    if previous["total"] == 0:
        lines.append("前日分はまだ集計中です。結果がそろい次第、ここへ入れます。")
    elif not previous["hits"]:
        lines.append(f"{date_label(previous['date'])}は的中なし。外れも隠さず載せます。")
    else:
        lines.append(f"{date_label(previous['date'])}の的中: {len(previous['hits'])}/{previous['total']}")
        for hit in previous["hits"][:8]:
            lines.append(f"・{hit['venue']} {hit['race_no']}R {hit['label']} / 予 {combo(hit['predicted'])} → 結 {combo(hit['actual'])}")
        if len(previous["hits"]) > 8:
            lines.append(f"・ほか{len(previous['hits']) - 8}件")

    lines += [
        "",
        "さて、今日も素直に見ます。",
        "無料部分では上位2本だけ出します。残りの一押し、買い目候補、理由は有料部分です。",
        "",
    ]
    for idx, pick in enumerate(predictions[:2], 1):
        lines.append(note_block(idx, pick, paid=False))
    lines += [
        "",
        "## ここから先は",
        f"本日の一押し全{len(predictions)}本、買い目候補、見解です。",
        "ここから先は有料部分です。価格は200円です。",
        "",
        "【本日の一押し一覧】",
    ]
    for idx, pick in enumerate(predictions, 1):
        lines.append(note_block(idx, pick, paid=True))
    lines += [
        "",
        "【最後に】",
        "的中率はそのまま載せています。良い日も悪い日も数字を見て、予想精度を少しずつ上げていきます。",
        "",
        "#競輪予想 #鉄脚博士 #本日の一押し",
    ]
    return title, "\n".join(lines)


def note_block(index: int, pick: dict[str, Any], paid: bool) -> str:
    pred = pick.get("prediction") or []
    exacta = pick.get("exacta") or []
    wide = pick.get("wide") or []
    reasons = pick.get("reasons") or []
    shown = reasons[:4 if paid else 2]
    reason_text = "\n".join(f"  - {r}" for r in shown) or "  - 出走表と指数を確認してから最終判断"
    start = f" {pick.get('start_time')}発走" if pick.get("start_time") else ""
    return f"""
{index}. {pick.get('venue')} {pick.get('race_no')}R{start}
判定: {pick.get('action_label')} {pick.get('grade')}
予想: {combo(pred)}
3連単候補: {combo(pred)}
2車単候補: {combo(exacta) if len(exacta) >= 2 else "-"}
ワイド候補: {combo(wide) if len(wide) >= 2 else "-"}
理由:
{reason_text}
""".rstrip()


def write_outputs(out_dir: Path, date: str, payload: dict[str, Any], note: str) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    json_text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    for name in [f"predictions_{date}.json", "latest.json"]:
        (out_dir / name).write_text(json_text, encoding="utf-8")
    for name in [f"note_draft_{date}.md", "latest.md"]:
        (out_dir / name).write_text(note + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", help="Target date as YYYYMMDD")
    parser.add_argument("--out", default="generated/tekkyaku")
    parser.add_argument("--min-picks", type=int, default=10)
    args = parser.parse_args()

    out_dir = Path(args.out)
    entries_data = fetch_json("upcoming_entries.json", required=False) or fetch_json("today_entries.json")
    player_stats = fetch_json("player_stats.json")
    venue_stats = fetch_json("venue_stats.json")
    target_date, races = pick_races(entries_data, args.date)
    for race in races:
        race.setdefault("date", target_date)

    picks = []
    for race in races:
        analysis = analyze_race(race, player_stats, venue_stats)
        if analysis:
            picks.append(analysis)
    picks.sort(key=lambda p: (-float(p["quality"]), int(p["race_no"])))
    predictions = picks[: max(args.min_picks, min(len(picks), args.min_picks))]
    for idx, pick in enumerate(predictions, 1):
        pick["rank"] = idx

    stats, previous = evaluate_history(out_dir, target_date)
    stats_dict = stats.as_dict()
    title, note = build_note(target_date, predictions, stats_dict, previous)
    payload = {
        "generated_at": datetime.now(JST).isoformat(timespec="seconds"),
        "source": BASE_URL,
        "date": target_date,
        "date_label": date_label(target_date),
        "note_title": title,
        "stats": stats_dict,
        "previous": previous,
        "predictions": predictions,
        "note_markdown": note,
    }
    write_outputs(out_dir, target_date, payload, note)
    print(f"Generated {len(predictions)} picks for {target_date} into {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
