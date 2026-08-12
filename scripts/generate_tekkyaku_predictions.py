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
PROVERBS = [
    (
        "急がば回れ",
        "急ぐ時ほど、危ない近道を選ばず確かな道を行く方が早い。",
        "競輪も同じです。無理に穴へ飛びつくより、展開の筋が通る一車を見つける方が、最後に財布へやさしい。",
    ),
    (
        "石橋を叩いて渡る",
        "安全そうに見える橋でも、念のため確かめてから渡る。",
        "本命が強く見える番組ほど、相手の食い込みを確かめる。吾輩はそこで赤鉛筆を止めます。",
    ),
    (
        "勝って兜の緒を締めよ",
        "勝ったあとほど油断せず、気を引き締める。",
        "昨日当たったから今日も当たる、とは限りません。的中の翌日こそ買い目を細く、目を厳しくします。",
    ),
    (
        "灯台下暗し",
        "近くにある大事なものほど、かえって見落としやすい。",
        "派手な穴ばかり見ていると、番手の安定やラインの素直な並びを見落とします。そこに妙味が隠れます。",
    ),
    (
        "二兎を追う者は一兎をも得ず",
        "欲張って二つを同時に追うと、どちらも逃す。",
        "3連単も穴も全部欲しい日は危ない。吾輩はまず軸を決め、そこから話を始めます。",
    ),
    (
        "転ばぬ先の杖",
        "失敗する前に、あらかじめ備えておく。",
        "競輪では見送りも立派な杖です。荒れ気配が強い番組で無理をしないのも、予想のうちです。",
    ),
    (
        "雨垂れ石を穿つ",
        "小さな積み重ねでも、続ければ大きな結果になる。",
        "的中率は一日で作れません。外れを隠さず数え、少しずつ癖を直す。吾輩はそこに執念を置きます。",
    ),
    (
        "備えあれば憂いなし",
        "準備ができていれば、いざという時に慌てない。",
        "出走表、脚質、場の相性を先に見ておけば、締切前に妙な欲で手が震えません。",
    ),
    (
        "損して得取れ",
        "目先の損を受け入れて、あとで大きな得を取る。",
        "今日は薄く、明日は厚く。見送る勇気が、次の勝負金を残します。",
    ),
    (
        "猿も木から落ちる",
        "どんな名人でも失敗することがある。",
        "堅く見える軸でも飛ぶ日はあります。だから吾輩は、当たった日より外れた日の理由をよく見ます。",
    ),
    (
        "継続は力なり",
        "小さな努力でも、続ければ確かな力になる。",
        "一度の万車券より、毎日の検証が予想を育てます。吾輩は外れた印も消しません。",
    ),
    (
        "千里の道も一歩から",
        "大きな目標も、最初の小さな一歩から始まる。",
        "回収率を上げる道も一レースずつです。まずは買う理由を数字で言える番組から始めます。",
    ),
    (
        "過ぎたるは猶及ばざるが如し",
        "やりすぎは、足りないことと同じくらい良くない。",
        "買い目を増やしすぎれば、当たっても財布が痩せます。必要な線だけ残すのが博士流です。",
    ),
    (
        "能ある鷹は爪を隠す",
        "本当に力のある者は、むやみに実力を見せびらかさない。",
        "派手なコメントより、静かに数字を積む選手が怖い。出走表の奥を見ます。",
    ),
    (
        "三人寄れば文殊の知恵",
        "複数の考えを合わせれば、良い知恵が生まれる。",
        "脚質、直近成績、バンク傾向。この三つを合わせて初めて買い目に筋が通ります。",
    ),
    (
        "案ずるより産むが易し",
        "始める前に心配するより、実際にやる方が案外たやすい。",
        "迷い続けるより、買う条件と見送る条件を先に決める。そうすれば赤鉛筆はぶれません。",
    ),
    (
        "風が吹けば桶屋が儲かる",
        "一見無関係な出来事も、巡り巡って影響し合う。",
        "風向き、ライン、仕掛けの順番。競輪は小さな変化が最後の着順まで動かします。",
    ),
    (
        "井の中の蛙大海を知らず",
        "狭い世界だけを見ていると、広い世界を理解できない。",
        "一場の成績だけで決めず、周長別の相性や遠征成績まで広げて見ます。",
    ),
    (
        "七転び八起き",
        "何度失敗しても、くじけず立ち上がる。",
        "外れは恥ではありません。同じ外し方を繰り返す方が恥です。吾輩は翌朝また表を開きます。",
    ),
    (
        "善は急げ",
        "良いと思ったことは、ためらわず早く実行する。",
        "良い番組を見つけても締切後では紙くずです。ただし確認だけは急がず済ませます。",
    ),
    (
        "後悔先に立たず",
        "終わったあとで悔やんでも、取り返せない。",
        "締切前の衝動買いは、結果を見てから必ず重くなります。買う根拠を一行書けるか確かめます。",
    ),
    (
        "郷に入っては郷に従え",
        "新しい土地では、その土地の習慣に従うのがよい。",
        "333m、400m、500mでは仕掛けも変わります。選手の力だけでなく、バンクの作法に従います。",
    ),
    (
        "一寸先は闇",
        "ほんの少し先のことでも、何が起きるか分からない。",
        "強い軸にも落車や牽制があります。確率は信じても、絶対という言葉は使いません。",
    ),
    (
        "塵も積もれば山となる",
        "小さなものでも、積み重なれば大きくなる。",
        "100円の差も百日続けば大きい。的中数だけでなく、払戻と購入額を毎日残します。",
    ),
    (
        "覆水盆に返らず",
        "一度起きたことは、元には戻せない。",
        "外れた車券は戻りません。追い上げで取り返そうとせず、次の番組は別勘定にします。",
    ),
]
VENUE_CODE_NAMES = {
    "11": "函館",
    "12": "青森",
    "13": "いわき平",
    "21": "弥彦",
    "22": "前橋",
    "23": "取手",
    "24": "宇都宮",
    "25": "大宮",
    "26": "西武園",
    "27": "京王閣",
    "28": "立川",
    "31": "松戸",
    "34": "川崎",
    "35": "平塚",
    "36": "小田原",
    "37": "伊東",
    "38": "静岡",
    "42": "名古屋",
    "43": "岐阜",
    "44": "大垣",
    "45": "豊橋",
    "46": "富山",
    "47": "松阪",
    "48": "四日市",
    "51": "福井",
    "53": "奈良",
    "54": "向日町",
    "55": "和歌山",
    "56": "岸和田",
    "61": "玉野",
    "62": "広島",
    "63": "防府",
    "71": "高松",
    "73": "小松島",
    "74": "高知",
    "75": "松山",
    "81": "小倉",
    "83": "久留米",
    "84": "武雄",
    "85": "佐世保",
    "86": "別府",
    "87": "熊本",
}
BANK_LENGTH_OVERRIDES = {
    "前橋": 335,
    "松戸": 333,
    "小田原": 333,
    "伊東": 333,
    "富山": 333,
    "奈良": 333,
    "防府": 333,
    "宇都宮": 500,
    "大宮": 500,
    "高知": 500,
}


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


def venue_label(venue: Any, venue_cd: Any = None) -> str:
    raw = str(venue or "").strip()
    code = str(venue_cd or "").strip()
    if raw in VENUE_CODE_NAMES:
        return VENUE_CODE_NAMES[raw]
    if code in VENUE_CODE_NAMES:
        return VENUE_CODE_NAMES[code]
    return raw


def daily_proverb(value: str) -> dict[str, str]:
    try:
        dt = datetime.strptime(value, "%Y%m%d")
        index = dt.toordinal() % len(PROVERBS)
    except ValueError:
        index = sum(ord(ch) for ch in value) % len(PROVERBS)
    title, meaning, keirin = PROVERBS[index]
    return {
        "title": title,
        "meaning": meaning,
        "keirin": keirin,
    }


def daily_fortune(value: str, predictions: list[dict[str, Any]]) -> str:
    fortunes = [
        "大吉。数字の芯が見えやすい日。迷ったら本線を丁寧に。",
        "中吉。前半は慎重、後半に勝負の勘が冴えます。",
        "小吉。欲張らず二車の関係を素直に見ると吉。",
        "吉。人気より直近の脚を信じると、赤鉛筆が落ち着きます。",
        "末吉。穴を追うより、見送る勇気が次の福を呼びます。",
        "中吉。バンクとの相性に目を向けると、思わぬ筋が見えます。",
        "吉。締切前のひらめきより、最初に立てた根拠を大切に。",
        "小吉。相手を広げすぎず、二着候補を一枚ずつ吟味する日。",
        "大吉。直近成績と鉄脚指数が重なる番組に福があります。",
        "吉。朝の一戦は冷静に、夜の一戦は欲を抑えるとよし。",
        "中吉。逃げと差しの割合を見比べると、展開の扉が開きます。",
        "末吉。今日は当てるより、負けを小さくする知恵が光ります。",
    ]
    top = predictions[0] if predictions else {}
    lucky_number = (top.get("prediction") or [None])[0]
    venue = str(top.get("venue") or "本日の一戦")
    base = stable_choice(value, fortunes, 11)
    lucky = f"ラッキー車番は{lucky_number}番、注目会場は{venue}。" if lucky_number else f"注目会場は{venue}。"
    return f"{base} {lucky}"


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


def bank_profile(
    venue: str,
    axis: dict[str, Any],
    venue_stats: dict[str, Any],
    venue_details: dict[str, Any],
) -> dict[str, Any]:
    stats = venue_stats.get(venue) or {}
    details = venue_details.get(venue) or {}
    bank = int(details.get("bank") or stats.get("bank") or BANK_LENGTH_OVERRIDES.get(venue, 400))
    races = int(stats.get("races") or 0)
    km = stats.get("km") or {}
    rates = {key: float(km.get(key) or 0.0) for key in ("差", "捲", "逃")}

    if bank <= 335:
        character = "一周が短い短走路。仕掛けの遅れと位置取りの差が響きやすい。"
    elif bank >= 500:
        character = "一周が長い長走路。最後まで脚を残す配分が問われやすい。"
    else:
        character = "標準的な400m走路。脚質だけでなく、ラインと仕掛けどころを合わせて見たい。"

    axis_name = str(axis.get("name") or "軸候補")
    style = str(axis.get("style") or "")
    style_key = "逃" if "逃" in style else "捲" if "捲" in style or "両" in style else "差"
    strongest = max(rates, key=rates.get) if any(rates.values()) else ""
    axis_rate = rates.get(style_key, 0.0)

    if strongest and style_key == strongest:
        insight = f"集計上は{strongest}が最も多い。{axis_name}の脚質とバンク傾向が重なる点を買う。"
    elif strongest and axis_rate:
        insight = f"集計上は{strongest}が最多。{axis_name}は{style_key}タイプだけに、得意な形へ持ち込めるかが鍵になる。"
    elif strongest:
        insight = f"集計上は{strongest}が最も多い。{axis_name}の位置取りと仕掛けどころを重く見る。"
    else:
        insight = f"{axis_name}の脚質と、周長に合う仕掛けどころを重く見る。"

    return {
        "bank": bank,
        "races": races,
        "rates": {key: round(value * 100, 1) for key, value in rates.items()},
        "opened_year": details.get("opened_year"),
        "straight_m": details.get("straight_m"),
        "max_cant": details.get("max_cant"),
        "character": details.get("character") or character,
        "sources": details.get("sources") or [],
        "insight": insight,
    }


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


def stable_choice(key: str, options: list[str], salt: int = 0) -> str:
    if not options:
        return ""
    value = sum(ord(ch) for ch in key) + salt * 97
    return options[value % len(options)]


def style_phrase(style: str) -> str:
    if "逃" in style:
        return "先に踏んで場を作れる"
    if "追" in style:
        return "前を使って最後に脚を残せる"
    if "両" in style:
        return "自力も追走も選べる"
    return "流れに合わせて脚を出せる"


def factual_prediction_lines(
    venue: str,
    axis: dict[str, Any],
    second: dict[str, Any],
    gap12: float,
    player_stats: dict[str, Any],
    bank: dict[str, Any],
) -> list[str]:
    axis_name = str(axis.get("name") or "軸候補")
    second_name = str(second.get("name") or "相手候補")
    stat = player_stats.get(axis_name) or {}
    lines: list[str] = []

    recent_ranks = [int(v) for v in (stat.get("rr") or []) if str(v).isdigit()]
    score = float(axis.get("score") or 0)
    facts = []
    if score:
        facts.append(f"競走得点{score:.2f}")
    if recent_ranks:
        recent_wins = sum(rank == 1 for rank in recent_ranks)
        recent_top3 = sum(rank <= 3 for rank in recent_ranks)
        facts.append(
            f"直近{len(recent_ranks)}走は1着{recent_wins}回・3着内{recent_top3}回、平均{sum(recent_ranks) / len(recent_ranks):.1f}着"
        )
    style = str(stat.get("s") or axis.get("style") or "")
    if style:
        facts.append(f"脚質は{style}型")
    if facts:
        lines.append(f"{axis_name}は" + "、".join(facts) + "。ここを軸評価の土台にした。")

    kimarite = [str(v) for v in (stat.get("rk") or []) if v]
    if kimarite:
        counts = {key: kimarite.count(key) for key in ("逃", "捲", "差") if kimarite.count(key)}
        if counts:
            breakdown = "・".join(f"{key}{value}回" for key, value in counts.items())
            lines.append(f"直近の決まり手記録は{breakdown}。どの形で勝ち切っているかも指数へ入れた。")

    axis_score = float(axis.get("tekkyaku_score") or 0)
    second_score = float(second.get("tekkyaku_score") or 0)
    lines.append(
        f"鉄脚指数は{axis_name}{axis_score:.1f}、{second_name}{second_score:.1f}で差は{gap12:.1f}。相手筆頭は{second_name}とした。"
    )

    rates = bank.get("rates") or {}
    strongest = max(("差", "捲", "逃"), key=lambda key: float(rates.get(key) or 0))
    strongest_rate = float(rates.get(strongest) or 0)
    if strongest_rate:
        lines.append(
            f"{venue}は{int(bank.get('bank') or 400)}m、みなし直線{float(bank.get('straight_m') or 0):g}m。"
            f"過去集計では{strongest}が{strongest_rate:.1f}%で最多、この傾向と脚質の噛み合わせまで見た。"
        )
    return lines


def build_hakase_copy(
    race: dict[str, Any],
    axis: dict[str, Any],
    second: dict[str, Any],
    third: dict[str, Any],
    gap12: float,
    chaos: float,
    axis_win: float,
    grade: str,
    action: str,
    player_stats: dict[str, Any],
    bank: dict[str, Any],
) -> tuple[str, str, list[str]]:
    key = f"{race.get('race_id', '')}-{axis.get('name', '')}"
    axis_name = axis.get("name", "")
    second_name = second.get("name", "")
    third_name = third.get("name", "")
    venue = race.get("venue", "")
    start = race.get("start_time") or ""
    schedule = schedule_label(start, int(race.get("race_no") or 0))
    axis_style = str(axis.get("style") or "")
    axis_line = style_phrase(axis_style)

    if grade == "S":
        action_options = [
            f"吾輩の赤鉛筆はここで止まった。{axis_name}から素直に入る。",
            f"ここで妙な小細工をすると、かえって外す。{axis_name}の頭を厚く見る。",
            f"出走表を三度見ても、最後は{axis_name}に戻る。軸はここである。",
            f"疑い深い吾輩でも、この並びには逆らいにくい。{axis_name}中心。",
            f"{axis_name}の数字だけが、紙の上で妙に静かに光っている。ここは逆らわない。",
            f"人気の有無より、脚の筋が通っている。吾輩は{axis_name}を先に置く。",
        ]
    elif grade == "A":
        action_options = [
            f"勝負気配はある。{axis_name}を軸に、相手を間違えないように見る。",
            f"本線は{axis_name}。ただし相手は一枚だけ慎重に拾う。",
            f"ここは買い目を広げすぎるより、{axis_name}から絞る方が面白い。",
            f"地味だが悪くない。{axis_name}の脚を信じて組み立てる。",
            f"大声で叫ぶほどではないが、{axis_name}の形はよい。こういう静かな番組を拾いたい。",
            f"{axis_name}を軸に据える。相手は欲を出さず、流れに合う者だけ残す。",
        ]
    elif action == "注目":
        action_options = [
            f"{axis_name}は買い材料あり。ただし、勝負札を切るなら相手確認がいる。",
            f"軸候補は{axis_name}。吾輩なら見送りにせず、まずここを覗く。",
            f"荒れ目も残るが、{axis_name}の存在は軽く扱えん。",
            f"派手な勝負ではない。{axis_name}を中心に様子を見る一戦。",
            f"うまい汁だけ吸おうとすると痛い目を見る。とはいえ{axis_name}は消せない。",
            f"ここは鼻息を荒くしない。{axis_name}から入り、相手で値段を作る。",
        ]
    else:
        action_options = [
            f"強くは押さないが、{axis_name}の数字は捨てにくい。",
            f"ここは渋い。買うなら{axis_name}から薄く、無理はしない。",
            f"吾輩なら大勝負は避ける。それでも{axis_name}は候補に残す。",
            f"迷う番組じゃ。軸を置くなら{axis_name}、ただし深追い禁物。",
            f"胸を張って買いとは言わない。ただ、{axis_name}を外して眺めるのも落ち着かない。",
            f"見送り寄りの目で見ても、{axis_name}だけは紙面の端に残った。",
        ]
    action_reason = stable_choice(key, action_options, 1)

    lead_options = [
        f"朝から出走表を眺めていたが、{venue}のこの番組はじわじわ味が出る。",
        f"ぬるい茶を前にして見直した。こういうレースは人気より脚の置き場である。",
        f"吾輩は派手な穴だけを追う男ではない。残る脚を持つ者から見る。",
        f"何度も紙片に書いたが、最後に残ったのはこの並びだった。",
        f"競輪ばかり見ていると、こういう細かい差が気になって仕方ない。",
        f"{venue}の番組表を開いた瞬間、少し眉が動いた。これは捨て置けない。",
        f"世間は忙しいが、吾輩の一日は出走表で始まる。この一戦は足を止めて見たい。",
        f"数字は無口だが、時々こちらをじっと見る。今日のこの番組がそれである。",
        f"妙に整いすぎたレースより、少し癖のある番組の方が本音を出す。",
    ]
    lead = stable_choice(key, lead_options, 2)

    if schedule == "ミッドナイト":
        time_options = [
            "夜の番組は気配が軽い選手を買いたくなるが、ここは数字の芯を優先する。",
            "ミッドナイトは欲が顔を出しやすい。吾輩は眠気より指数を信じる。",
            "夜更けの競輪は妙に荒く見える。そこで一度、軸の強さへ戻る。",
        ]
    elif schedule == "ナイター":
        time_options = [
            "ナイターは流れが一変することもある。だからこそ軸の安定感を重く見る。",
            "灯りの下では脚色がよく見える。だが吾輩は、最後に残る形を見る。",
            "ナイターの空気に浮かされず、番組の骨を見たい。",
        ]
    elif start:
        time_options = [
            "早めの時間帯は変に欲を出さず、形が見えるところから入る。",
            "日中の番組は淡々とした顔をしている。こういう時ほど基本が効く。",
            "まだ場が荒れきる前なら、素直な脚順を軽く扱わない。",
        ]
    else:
        time_options = [
            "時間帯の色は薄いが、番組の骨格ははっきりしている。",
            "発走時刻に頼らず見ても、狙いどころはぼんやりしていない。",
            "時計の情報は少ない。ならば脚と並びをまっすぐ見る。",
        ]
    time_line = stable_choice(key, time_options, 3)

    if gap12 >= 8:
        gap_options = [
            f"{axis_name}と{second_name}の差は数字以上に見える。吾輩ならここを太く取る。",
            f"{second_name}も悪くない。だが主役の椅子は、今日は{axis_name}の方へ寄っている。",
            f"軸と相手の差がはっきり出た。ここで迷うと、かえって買い目が濁る。",
        ]
    elif gap12 >= 5:
        gap_options = [
            f"{second_name}も悪くないが、軸の座りは{axis_name}が上。ここを見落とすと悔いが残る。",
            f"差は絶対ではない。それでも一番手に置くなら、吾輩は{axis_name}を選ぶ。",
            f"{second_name}の食い込みは見る。だが予想の芯まで渡すほどではない。",
        ]
    else:
        gap_options = [
            f"{second_name}との差は大きくない。だから相手の順番まで雑に決めてはいけない。",
            f"ここは紙一重である。軸を決めても、相手を粗末に扱うと痛い。",
            f"数字は接近している。こういう日は一着だけでなく、二着三着の顔つきまで見る。",
        ]
    gap_line = stable_choice(key, gap_options, 4)

    if chaos >= 58:
        chaos_options = [
            f"ただし混戦の匂いはある。{third_name}まで拾って、欲張りすぎない。",
            f"荒れる芽は残る。{third_name}を軽く見ると、あとで渋い顔になる。",
            f"ここは波風が立つ。吾輩は深追いせず、拾う所だけ拾う。",
        ]
    elif chaos >= 45:
        chaos_options = [
            f"乱れる余地は少しある。一本釣りより、相手をきれいに押さえる方が吾輩好み。",
            f"穏やかに見えて、小さな揺れはある。相手の順番を丁寧に置きたい。",
            f"大荒れとは言わないが、決め打ちだけでは少し窮屈だ。",
        ]
    else:
        chaos_options = [
            f"荒れ気配は強くない。こういう日は素直さがいちばん怖い武器になる。",
            f"変なひねりは要らない。素直に見た者が、最後に少し笑う番組である。",
            f"穴の影は濃くない。吾輩はここで無理に物語を作らない。",
        ]
    chaos_line = stable_choice(key, chaos_options, 5)

    style_options = [
        f"{axis_name}は{axis_line}タイプ。ここは脚の出しどころが合う。",
        f"{axis_name}の脚質なら、流れが少し早くても我慢が利く。",
        f"脚の使い方を見ると、{axis_name}はこの並びで窮屈になりにくい。",
        f"{axis_name}は自分の仕事を知っている。こういう選手は予想の土台にしやすい。",
    ]
    style_line = stable_choice(key, style_options, 6)
    data_lines = factual_prediction_lines(venue, axis, second, gap12, player_stats, bank)
    story = "\n".join([lead, time_line, *data_lines, style_line, chaos_line])

    reasons = [
        action_reason,
        *data_lines[:3],
        f"博士の軸は{axis_name}",
        f"軸1着目安 {axis_win:.0f}%",
        f"相手筆頭は{second_name}、三番手は{third_name}",
    ]
    if gap12 >= 5:
        reasons.append("軸と相手の差を評価")
    if chaos >= 58:
        reasons.append("混戦気配あり。買い目は広げすぎない")
    for signal in axis.get("signals") or []:
        if signal not in reasons:
            reasons.append(signal)
    return action_reason, story, reasons[:7]


def analyze_race(
    race: dict[str, Any],
    player_stats: dict[str, Any],
    venue_stats: dict[str, Any],
    venue_details: dict[str, Any],
) -> dict[str, Any] | None:
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
    elif axis_win >= 28 and gap12 >= 3.0 and chaos < 60:
        grade = "A"
        action = "買い"
    elif axis_win >= 23:
        grade = "B"
        action = "注目"
    else:
        grade = "候"
        action = "押さえ"
    bank = bank_profile(str(race.get("venue") or ""), axis, venue_stats, venue_details)
    action_reason, story, reasons = build_hakase_copy(
        race,
        axis,
        second,
        third,
        gap12,
        chaos,
        axis_win,
        grade,
        action,
        player_stats,
        bank,
    )

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
        "story": story,
        "bank_profile": bank,
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
    candidates = sorted(d for d in days if d >= today)
    for day in candidates:
        selected = [r for r in races if (r.get("date") or day) == day and r.get("entries")]
        if selected:
            return day, selected
    return today, []


def result_for_date(date: str) -> dict[str, dict[str, Any]]:
    data = fetch_json(f"results_{date}.json", required=False)
    if not data:
        return {}
    out: dict[str, dict[str, Any]] = {}
    for result in data.get("results") or []:
        finishers = sorted(result.get("finishers") or [], key=lambda f: int(f.get("rank") or 99))
        out[result.get("race_id", "")] = {
            "finishers": [int(f.get("umaban") or 0) for f in finishers[:3]],
            "paybacks": result.get("paybacks") or [],
        }
    return out


def winning_paybacks(predicted: list[int], paybacks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    combinations = {
        "3連単": "-".join(str(v) for v in predicted[:3]),
        "2車単": "-".join(str(v) for v in predicted[:2]),
        "ワイド": "-".join(str(v) for v in sorted(predicted[:2])),
    }
    hits = []
    for ticket_type in ("3連単", "2車単", "ワイド"):
        expected = combinations[ticket_type]
        for item in paybacks:
            if str(item.get("type") or "") != ticket_type:
                continue
            raw = str(item.get("combination") or "").replace(" ", "").replace("=", "-")
            parts = [part for part in re.split(r"[^0-9]+", raw) if part]
            actual = "-".join(sorted(parts, key=int)) if ticket_type == "ワイド" else "-".join(parts)
            if actual == expected:
                hits.append({"type": ticket_type, "payout": int(item.get("payout") or 0)})
                break
    return hits


@dataclass
class HitStats:
    total: int = 0
    win: int = 0
    trifecta: int = 0
    exacta: int = 0
    wide: int = 0
    payout: int = 0

    def as_dict(self) -> dict[str, Any]:
        def rate(value: int) -> float:
            return round(value / self.total * 100, 1) if self.total else 0.0

        investment = self.total * 300
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
            "investment": investment,
            "payout": self.payout,
            "profit": self.payout - investment,
            "return_rate": round(self.payout / investment * 100, 1) if investment else 0.0,
        }


def evaluate_history(out_dir: Path, current_date: str) -> tuple[HitStats, dict[str, Any]]:
    stats = HitStats()
    previous_date = (datetime.strptime(current_date, "%Y%m%d") - timedelta(days=1)).strftime("%Y%m%d")
    previous = {"date": previous_date, "total": 0, "payout": 0, "wide_payout": 0, "hits": []}
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
            result = actuals.get(pick.get("race_id")) or {}
            actual = result.get("finishers") or []
            pred = [int(v) for v in pick.get("prediction", [])[:3]]
            if not actual or len(pred) < 3 or len(actual) < 3:
                continue
            payback_hits = winning_paybacks(pred, result.get("paybacks") or [])
            race_payout = sum(int(item.get("payout") or 0) for item in payback_hits)
            stats.total += 1
            stats.payout += race_payout
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
                previous["payout"] += race_payout
                previous["wide_payout"] += sum(
                    int(item.get("payout") or 0) for item in payback_hits if item.get("type") == "ワイド"
                )
                if payback_hits:
                    previous["hits"].append({
                        "venue": pick.get("venue", ""),
                        "race_no": pick.get("race_no", 0),
                        "paybacks": payback_hits,
                        "predicted": pred,
                        "actual": actual,
                    })
    return stats, previous


def build_note(
    date: str,
    predictions: list[dict[str, Any]],
    stats: dict[str, Any],
    previous: dict[str, Any],
    proverb: dict[str, str],
) -> tuple[str, str]:
    top = predictions[0] if predictions else {}
    fortune = daily_fortune(date, predictions)
    previous_investment = int(previous.get("total") or 0) * 300
    previous_payout = int(previous.get("payout") or 0)
    previous_profit = previous_payout - previous_investment
    previous_return = round(previous_payout / previous_investment * 100, 1) if previous_investment else 0.0
    previous_wide_investment = int(previous.get("total") or 0) * 100
    previous_wide_payout = int(previous.get("wide_payout") or 0)
    previous_wide_profit = previous_wide_payout - previous_wide_investment
    previous_wide_return = (
        round(previous_wide_payout / previous_wide_investment * 100, 1) if previous_wide_investment else 0.0
    )
    first_label = f"{top.get('venue', '本日の競輪')}{top.get('race_no', '')}R"
    first_start = top.get("start_time") or ""
    title = f"鉄脚博士の競輪予想｜{date_label(date)} {first_label}{(' 発走' + first_start) if first_start else ''} 本日の一押し{len(predictions)}本"
    lines = [
        title,
        "",
        "吾輩は鉄脚博士である。",
        "現代にまぎれて競輪ばかり眺めている、少し偏屈な男です。",
        f"今日は展開、脚質、指数、直近の数字を見て、勝負候補を{len(predictions)}本に絞りました。",
        "買い目だけではなく、吾輩がどこで赤鉛筆を止めたのかも書きます。",
        "",
        "【本日のことわざ】",
        proverb["title"],
        f"意味: {proverb['meaning']}",
        f"競輪で言えば: {proverb['keirin']}",
        "",
        f"博士流今日の占い: {fortune}",
        "",
        "先に数字を出します。盛りません。",
        "",
        "【現在の的中率】",
        "",
        f"集計対象: 鉄脚博士の予想から結果が出た{stats['completed']}レース",
        f"1着的中: {stats['win_count']}/{stats['completed']}（{pct(stats['win_rate'])}）",
        f"3連単: {stats['trifecta_count']}/{stats['completed']}（{pct(stats['trifecta_rate'])}）",
        f"2車単: {stats['exacta_count']}/{stats['completed']}（{pct(stats['exacta_rate'])}）",
        f"ワイド: {stats['wide_count']}/{stats['completed']}（{pct(stats['wide_rate'])}）",
        "",
        "【100円ずつ買った場合の収支】",
        "",
        "購入条件: 各レースの3連単・2車単・ワイドを各100円（1レース300円）",
        f"前日: 購入額 {previous_investment:,}円 / 払戻額 {previous_payout:,}円 / 収支 {previous_profit:+,}円 / 回収率 {previous_return:.1f}%",
        f"ワイドのみ: 購入額 {previous_wide_investment:,}円 / 払戻額 {previous_wide_payout:,}円 / 収支 {previous_wide_profit:+,}円 / 回収率 {previous_wide_return:.1f}%",
        "",
        "【前日的中実績】",
        "",
    ]
    if previous["total"] == 0:
        lines.append("前日分はまだ集計中です。結果がそろい次第、ここへ入れます。")
    elif not previous["hits"]:
        lines.append(f"{date_label(previous['date'])}は的中なし。外れも隠さず載せます。")
    else:
        lines.append(f"{date_label(previous['date'])}の的中: {len(previous['hits'])}/{previous['total']}")
        lines.append("※払戻金は100円購入時の金額です。")
        for hit in previous["hits"][:8]:
            result_label = " / ".join(
                f"{item['type']}的中 {int(item['payout']):,}円" for item in hit["paybacks"]
            )
            lines.append(
                f"・{hit['venue']} {hit['race_no']}R　{result_label}　"
                f"☆予想: {combo(hit['predicted'])}　→ 結果: {combo(hit['actual'])}"
            )
        if len(previous["hits"]) > 8:
            lines.append(f"・ほか{len(previous['hits']) - 8}件")

    lines += [
        "",
        "さて、今日も素直に見ます。",
        "無料部分では上位1本だけ出します。残りの一押し、買い目候補、理由は有料部分です。",
        "",
    ]
    for idx, pick in enumerate(predictions[:1], 1):
        lines.append(note_block(idx, pick, paid=False))
    lines += [
        "",
        "## ここから先は",
        f"有料部分では、本日の一押し全{len(predictions)}本の買い目候補と見解を出します。",
        "",
        "対象レース:",
    ]
    for idx, pick in enumerate(predictions, 1):
        lines.append(f"・{idx}. {pick.get('venue')} {pick.get('race_no')}R")
    lines += [
        "",
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
        "#競輪 #競輪予想 #鉄脚博士 #本日の一押し #競輪好き #競輪データ #データ予想 #車券予想 #3連単予想 #2車単予想 #ワイド予想 #競輪場 #競輪ファン #今日の競輪 #KEIRIN",
    ]
    return title, "\n".join(lines)


def note_block(index: int, pick: dict[str, Any], paid: bool) -> str:
    pred = pick.get("prediction") or []
    exacta = pick.get("exacta") or []
    wide = pick.get("wide") or []
    reasons = pick.get("reasons") or []
    shown = reasons[:6 if paid else 4]
    reason_text = "\n".join(f"・{r}" for r in shown) or "・出走表と指数を確認してから最終判断"
    story = pick.get("story") or "数字だけでは味気ないが、ここは軸の脚を素直に見る。"
    bank = pick.get("bank_profile") or {}
    bank_rates = bank.get("rates") or {}
    bank_lines = []
    if bank:
        bank_lines = [
            f"🚴{pick.get('venue')}競輪場の特徴",
            f"・{bank.get('bank')}mバンク。",
        ]
        if bank.get("straight_m"):
            bank_lines.append(f"・みなし直線は{float(bank.get('straight_m')):g}m。")
        if bank.get("max_cant"):
            bank_lines.append(f"・最大カントは{bank.get('max_cant')}。")
        bank_lines.append(f"・{bank.get('character')}")
        if bank.get("races"):
            bank_lines.append(
                f"・過去{int(bank.get('races')):,}レースの決まり手: "
                f"差し{float(bank_rates.get('差') or 0):.1f}% / "
                f"捲り{float(bank_rates.get('捲') or 0):.1f}% / "
                f"逃げ{float(bank_rates.get('逃') or 0):.1f}%"
            )
        bank_lines.append(f"・博士の読み: {bank.get('insight')}")
    bank_text = "\n".join(bank_lines)
    bank_section = f"バンクメモ:\n{bank_text}" if bank_text else ""
    start = f" {pick.get('start_time')}発走" if pick.get("start_time") else ""
    return f"""
{index}. {pick.get('venue')} {pick.get('race_no')}R{start}
判定: {pick.get('action_label')} {pick.get('grade')}
予想: {combo(pred)}
3連単候補: {combo(pred)}
2車単候補: {combo(exacta) if len(exacta) >= 2 else "-"}
ワイド候補: {combo(wide) if len(wide) >= 2 else "-"}

博士の見立て:

{story}

{bank_section}

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
    venue_details = fetch_json("venue_details.json", required=False) or {}
    target_date, races = pick_races(entries_data, args.date)
    if not races:
        raise RuntimeError(f"No entry races available for {target_date}")
    for race in races:
        race.setdefault("date", target_date)
        race["venue"] = venue_label(race.get("venue"), race.get("venue_cd"))

    picks = []
    for race in races:
        analysis = analyze_race(race, player_stats, venue_stats, venue_details)
        if analysis:
            picks.append(analysis)
    picks.sort(key=lambda p: (-float(p["quality"]), int(p["race_no"])))
    predictions = picks[: max(args.min_picks, min(len(picks), args.min_picks))]
    for idx, pick in enumerate(predictions, 1):
        pick["rank"] = idx

    stats, previous = evaluate_history(out_dir, target_date)
    stats_dict = stats.as_dict()
    proverb = daily_proverb(target_date)
    title, note = build_note(target_date, predictions, stats_dict, previous, proverb)
    payload = {
        "generated_at": datetime.now(JST).isoformat(timespec="seconds"),
        "source": BASE_URL,
        "date": target_date,
        "date_label": date_label(target_date),
        "note_title": title,
        "daily_proverb": proverb,
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
