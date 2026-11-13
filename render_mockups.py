"""Render the canvas mockup templates (templates/*.dc.html) to Kindle-sized PNGs.

Expands the small subset of the .dc.html template syntax the mockups use
({{hole}} lookups and <sc-for>), writes plain HTML, then screenshots it with
headless Chrome at the Paperwhite 3 resolution (1072x1448).

Usage: python3 render_mockups.py
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1072, 1448


def stars(n):
    return "★" * n + "☆" * (5 - n)


def week_vals():
    raw = [
        ["THU", "11/12", 1.7, 1.8, "1–2", 8, "ENE", 74, 4, "WNW", 294, "OFF", "10:01a", 2],
        ["FRI", "11/13", 2.1, 2.6, "2–3", 5, "N", 358, 10, "NW", 315, "X-OFF", "10:41a", 2],
        ["SAT", "11/14", 3.0, 3.4, "3", 5, "N", 355, 8, "NW", 310, "X-OFF", "11:23a", 3],
        ["SUN", "11/15", 1.9, 2.8, "2", 5, "NE", 34, 5, "N", 5, "SIDE", "12:08p", 2],
        ["MON", "11/16", 2.8, 3.5, "3", 5, "ENE", 63, 8, "ENE", 65, "ON", "12:54p", 1],
        ["TUE", "11/17", 3.7, 4.1, "3–4", 5, "E", 75, 8, "NE", 45, "ON", "1:44p", 2],
        ["WED", "11/18", 4.4, 4.8, "4–5", 6, "ENE", 68, 11, "NE", 53, "ON", "2:39p", 2],
    ]
    days = []
    for i, r in enumerate(raw):
        today = i == 0
        days.append({
            "day": r[0], "date": r[1], "range": r[4], "period": r[5],
            "minPx": round(r[2] * 52), "maxPx": round(r[3] * 52),
            "swellDir": r[6], "swellDeg": r[7], "wind": f"{r[8]} {r[9]}",
            "windDeg": r[10], "windTag": r[11], "hi": r[12], "stars": stars(r[13]),
            "rule": "none" if i == 0 else "2px solid #000",
            "bg": "#000000" if today else "transparent",
            "fg": "#ffffff" if today else "#000000",
            "barFg": "#ffffff" if today else "#000000",
        })
    return {"days": days, "filterVal": "none"}


def today_vals():
    raw = [["6a", 1.8, 9, 294, "4"], ["8a", 1.8, 8, 219, "5"], ["10a", 1.8, 8, 223, "7"],
           ["12p", 1.7, 8, 266, "8"], ["2p", 1.7, 8, 266, "7"], ["4p", 1.7, 7, 247, "7"],
           ["6p", 1.6, 7, 220, "6"]]
    hours = [{
        "t": r[0], "ft": f"{r[1]:.1f}", "per": r[2], "deg": r[3], "wind": r[4],
        "bg": "#000000" if i == 2 else "transparent",
        "fg": "#ffffff" if i == 2 else "#000000",
    } for i, r in enumerate(raw)]
    return {"hours": hours, "filterVal": "none"}


def lookup(path, scope):
    val = scope
    for part in path.split("."):
        val = val[part]
    return str(val)


def fill(text, scope):
    return re.sub(r"\{\{\s*([\w.$]+)\s*\}\}", lambda m: lookup(m.group(1), scope), text)


def expand(src, vals):
    body = re.search(r"<x-dc>(.*)</x-dc>", src, re.S).group(1)
    helmet = re.search(r"<helmet>(.*?)</helmet>", body, re.S)
    head = helmet.group(1) if helmet else ""
    body = body.replace(helmet.group(0), "") if helmet else body

    def loop(m):
        items = vals[re.search(r"\{\{\s*(\w+)\s*\}\}", m.group(1)).group(1)]
        name = m.group(2)
        return "".join(fill(m.group(3), {**vals, name: it}) for it in items)

    body = re.sub(r'<sc-for list="([^"]+)" as="(\w+)"[^>]*>(.*?)</sc-for>', loop, body, flags=re.S)
    body = fill(body, vals)
    return f'<!doctype html><html lang="en"><head><meta charset="utf-8">{head}' \
           f'<style>html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:#fff}}</style>' \
           f'</head><body>{body}</body></html>'


def render(name, vals):
    src = (ROOT / "templates" / f"{name}.dc.html").read_text()
    out_dir = ROOT / "mockups"
    html_path = out_dir / f"{name}.html"
    png_path = out_dir / f"{name}.png"
    html_path.write_text(expand(src, vals))
    subprocess.run([
        CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--force-device-scale-factor=1", f"--window-size={W},{H}",
        "--virtual-time-budget=8000", f"--screenshot={png_path}", html_path.as_uri(),
    ], check=True, capture_output=True)
    print("wrote", png_path)


if __name__ == "__main__":
    render("week", week_vals())
    render("today", today_vals())
