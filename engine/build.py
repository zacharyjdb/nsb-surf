"""Build the forecast files the app, widgets and frame read.

    python3 -m engine.build            # writes public/forecast.json and public/summary.json

forecast.json  everything: per spot hourly (16 days) + daily summaries, tides, buoys
summary.json   small: per spot "now" + 16 day ratings, for widgets
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from . import sources, surf

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "public"
SCHEMA_VERSION = 1


def load_config() -> dict:
    return json.loads((ROOT / "engine" / "spots.json").read_text())


def confidence(day_index: int) -> str:
    return "high" if day_index <= 2 else ("medium" if day_index <= 6 else "low")


def fmt_time(t: datetime) -> str:
    h = t.hour % 12 or 12
    return f"{h}:{t.minute:02d}{'a' if t.hour < 12 else 'p'}"


def daily_tide_levels(hilo: list[dict], date: str) -> tuple[float, float]:
    """Low and high water for the calendar day, to normalise tide height to 0–1."""
    same = [p["ft"] for p in hilo if p["t"].strftime("%Y-%m-%d") == date]
    if len(same) < 2:
        same = [p["ft"] for p in hilo]
    return min(same), max(same)


NUDGE_HOURS = 24


def buoy_nudge(wave: dict, obs: dict | None, now_local: datetime) -> float:
    """Ratio of what the nearshore buoy measures now to what the model says now (clamped).

    Models on a coarse offshore grid tend to under-call short-period local wind swell; the buoy
    knows better for the next day or so.
    """
    if not obs or not obs.get("wave_m"):
        return 1.0
    key = now_local.strftime("%Y-%m-%dT%H:00")
    try:
        i = wave["time"].index(key)
    except ValueError:
        return 1.0
    model = wave["wave_height"][i]
    if not model:
        return 1.0
    return max(0.5, min(2.0, obs["wave_m"] / model))


def apply_nudge(wave: dict, ratio: float, now_local: datetime) -> None:
    """Scale wave heights by ratio now, fading back to the raw model over NUDGE_HOURS."""
    if abs(ratio - 1.0) < 0.05:
        return
    start = now_local.strftime("%Y-%m-%dT%H:00")
    k = 0
    for i, ts in enumerate(wave["time"]):
        if ts < start:
            continue
        w = max(0.0, 1 - k / NUDGE_HOURS)
        if w == 0:
            break
        f = 1 + (ratio - 1) * w
        for v in ("wave_height", "swell_wave_height", "secondary_swell_wave_height", "wind_wave_height"):
            if wave[v][i] is not None:
                wave[v][i] *= f
        k += 1


def thin(hourly: list[dict], days_full: int = 7, step: int = 3) -> list[dict]:
    """Keep every hour for the first week, every `step` hours after that (confidence is low anyway)."""
    if not hourly:
        return hourly
    cutoff = hourly[0]["t"][:10]
    first_day = datetime.fromisoformat(cutoff)
    out = []
    for h in hourly:
        t = datetime.fromisoformat(h["t"])
        if (t - first_day).days < days_full or t.hour % step == 0:
            out.append(h)
    return out


def build_spot(spot: dict, wave: dict, wx: dict, hilo: list[dict], shelf: float, now_local: datetime) -> dict:
    times = wave["time"]
    wxh = wx["hourly"]
    wx_index = {t: i for i, t in enumerate(wxh["time"])}
    sun = {d: (rise, sset) for d, rise, sset in zip(wx["daily"]["time"], wx["daily"]["sunrise"], wx["daily"]["sunset"])}

    hourly = []
    for i, ts in enumerate(times):
        row = {v: wave[v][i] for v in sources.WAVE_VARS}
        if row["wave_height"] is None:
            continue
        t = datetime.fromisoformat(ts)
        j = wx_index.get(ts)
        wspd = wxh["wind_speed_10m"][j] if j is not None else None
        wdir = wxh["wind_direction_10m"][j] if j is not None else None
        gust = wxh["wind_gusts_10m"][j] if j is not None else None
        tide_ft = sources.tide_at(hilo, t)
        lo, hi = daily_tide_levels(hilo, ts[:10])
        level = None if tide_ft is None or hi == lo else (tide_ft - lo) / (hi - lo)

        s = surf.surf_height(spot, row, shelf)
        kind = surf.wind_kind(spot, wdir, wspd)
        score = surf.rate(spot, s, kind, wspd or 0, level)
        sst = wave["sst_c"][i]
        hourly.append({
            "t": ts,
            "surf_min_ft": s["min_ft"], "surf_max_ft": s["max_ft"],
            "surf_label": surf.range_label(s["min_ft"], s["max_ft"]),
            "primary": s["primary"], "trains": s["trains"],
            "wind_mph": None if wspd is None else round(wspd), "gust_mph": None if gust is None else round(gust),
            "wind_dir": wdir, "wind_dir_label": surf.cardinal(wdir), "wind_kind": kind,
            "tide_ft": None if tide_ft is None else round(tide_ft, 2),
            "water_f": None if sst is None else round(sst * 9 / 5 + 32),
            "score": round(score, 2), "stars": surf.stars(score),
            "model": wave["model"][i],
        })

    days = []
    by_day: dict[str, list] = {}
    for h in hourly:
        by_day.setdefault(h["t"][:10], []).append(h)
    for di, (date, hours) in enumerate(sorted(by_day.items())):
        rise, sset = sun.get(date, (date + "T07:00", date + "T17:30"))
        light = [h for h in hours if rise[:13] <= h["t"][:13] <= sset[:13]] or hours
        am = [h for h in light if int(h["t"][11:13]) < 12]
        pm = [h for h in light if int(h["t"][11:13]) >= 12]
        best = max(light, key=lambda h: h["score"])
        # Best window: contiguous daylight hours within half a star of the best hour.
        window = [h for h in light if h["score"] >= best["score"] - 0.5]
        mn = min(h["surf_min_ft"] for h in light)
        mx = max(h["surf_max_ft"] for h in light)
        mid = sum((h["surf_min_ft"] + h["surf_max_ft"]) / 2 for h in light) / len(light)
        morning = am[len(am) // 2] if am else light[0]
        afternoon = pm[len(pm) // 2] if pm else light[-1]
        p = best["primary"] or {"period_s": 6, "dir_label": "–"}
        day_tides = [{"t": x["t"].strftime("%Y-%m-%dT%H:%M"), "label": fmt_time(x["t"]),
                      "type": x["type"], "ft": round(x["ft"], 1)}
                     for x in hilo if x["t"].strftime("%Y-%m-%d") == date]

        headline = f'{surf.size_word(mid)}, {surf.quality_word(morning["wind_kind"], morning["wind_mph"] or 0)}.'
        if best["stars"] >= 1:
            am_best = max((h["score"] for h in am), default=-1)
            pm_best = max((h["score"] for h in pm), default=-1)
            advice = "Go early." if am_best > pm_best + 0.3 else ("Afternoon's better." if pm_best > am_best + 0.3 else "All day about the same.")
        else:
            advice = "Rest day."
        wind_line = f'{morning["wind_dir_label"]} {morning["wind_mph"]} mph in the morning'
        if afternoon["wind_dir_label"] != morning["wind_dir_label"] or abs((afternoon["wind_mph"] or 0) - (morning["wind_mph"] or 0)) >= 4:
            wind_line += f', {afternoon["wind_dir_label"]} {afternoon["wind_mph"]} later'
        summary = (f'{surf.range_label(mn, mx)} ft of {p["period_s"]:.0f}s {p["dir_label"]} '
                   f'{surf.swell_word(p["period_s"])}. {wind_line}.')

        days.append({
            "date": date,
            "confidence": confidence(di),
            "surf_min_ft": round(mn, 1), "surf_max_ft": round(mx, 1), "surf_label": surf.range_label(mn, mx),
            "stars": best["stars"], "rating": surf.LABELS[best["stars"]],
            "stars_am": surf.stars(max((h["score"] for h in am), default=0)),
            "stars_pm": surf.stars(max((h["score"] for h in pm), default=0)),
            "best_window": {"start": window[0]["t"], "end": window[-1]["t"]} if best["stars"] >= 1 else None,
            "primary": best["primary"],
            "wind_am": {"mph": morning["wind_mph"], "dir_label": morning["wind_dir_label"], "kind": morning["wind_kind"]},
            "wind_pm": {"mph": afternoon["wind_mph"], "dir_label": afternoon["wind_dir_label"], "kind": afternoon["wind_kind"]},
            "headline": headline, "advice": advice, "summary": summary,
            "tides": day_tides, "sunrise": rise, "sunset": sset,
            "water_f": light[0]["water_f"],
        })

    now_key = now_local.strftime("%Y-%m-%dT%H:00")
    now = next((h for h in hourly if h["t"] >= now_key), hourly[0] if hourly else None)
    nxt = next(({"type": x["type"], "t": x["t"].strftime("%Y-%m-%dT%H:%M"), "label": fmt_time(x["t"]), "ft": round(x["ft"], 1)}
                for x in hilo if x["t"] > now_local.replace(tzinfo=None)), None)
    return {
        "id": spot["id"], "name": spot["name"], "subtitle": spot.get("subtitle", ""),
        "lat": spot["lat"], "lon": spot["lon"], "facing": spot["facing"],
        "tide_station": spot["tide_station"], "model_grid": wave["grid"],
        "now": now, "next_tide": nxt, "days": days, "hourly": thin(hourly),
    }


def main() -> int:
    cfg = load_config()
    tz = cfg["timezone"]
    now_local = datetime.now(ZoneInfo(tz))
    spots = cfg["spots"]
    shelf = cfg["calibration"]["shelf_factor"]

    waves = sources.marine(spots, tz)
    wx = sources.weather(spots, tz)
    tides = {st: sources.tide_hilo(st, now_local.replace(tzinfo=None)) for st in {s["tide_station"] for s in spots}}
    buoys = []
    for b in cfg["buoys"]:
        obs = sources.buoy(b["id"])
        if obs:
            buoys.append({"id": b["id"], "name": b["name"], **obs,
                          "wave_ft": None if obs["wave_m"] is None else round(obs["wave_m"] * surf.M_TO_FT, 1),
                          "water_f": None if obs["water_c"] is None else round(obs["water_c"] * 9 / 5 + 32)})

    raw_buoys = {b["id"]: b for b in buoys}
    for s, w in zip(spots, waves):
        ratio = buoy_nudge(w, raw_buoys.get(s.get("nudge_buoy", cfg.get("nudge_buoy", ""))), now_local)
        w["nudge"] = round(ratio, 2)
        apply_nudge(w, ratio, now_local)

    out_spots = [build_spot(s, w, x, tides[s["tide_station"]], shelf, now_local) for s, w, x in zip(spots, waves, wx)]
    for o, w in zip(out_spots, waves):
        o["buoy_nudge"] = w["nudge"]
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    meta = {"schema": SCHEMA_VERSION, "generated_utc": generated, "timezone": tz,
            "sources": ["Open-Meteo Marine (ECMWF WAM, NOAA GFS-Wave)", "Open-Meteo Forecast",
                        "NOAA CO-OPS tide predictions", "NOAA NDBC buoys"]}

    OUT.mkdir(exist_ok=True)
    forecast = {**meta, "tide_stations": cfg["tide_stations"], "buoys": buoys, "spots": out_spots}
    (OUT / "forecast.json").write_text(json.dumps(forecast, separators=(",", ":")))

    summary = {**meta, "spots": [{
        "id": s["id"], "name": s["name"],
        "now": None if not s["now"] else {k: s["now"][k] for k in ("t", "surf_label", "surf_min_ft", "surf_max_ft", "stars", "wind_mph", "wind_dir_label", "wind_kind", "water_f", "tide_ft")},
        "next_tide": s["next_tide"],
        "days": [{k: d[k] for k in ("date", "surf_label", "stars", "confidence", "headline")} for d in s["days"]],
    } for s in out_spots]}
    (OUT / "summary.json").write_text(json.dumps(summary, separators=(",", ":")))

    for s in out_spots:
        d = s["days"][0]
        print(f'{s["name"]:<18} now {s["now"]["surf_label"]:>4} ft {"★" * s["now"]["stars"]:<5}  '
              f'today: {d["headline"]} {d["advice"]}  |  ' +
              " ".join(f'{x["date"][5:]}:{x["surf_label"]}/{x["stars"]}' for x in s["days"][1:8]))
    print(f"buoys: " + ", ".join(f'{b["id"]} {b["wave_ft"]}ft@{b["dominant_period_s"]}s' for b in buoys))
    print(f'wrote {OUT / "forecast.json"} ({(OUT / "forecast.json").stat().st_size // 1024} KB), summary.json')
    return 0


if __name__ == "__main__":
    sys.exit(main())
