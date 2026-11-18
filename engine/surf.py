"""Turn offshore model numbers into what a surfer cares about: surf height, wind quality, a rating, words.

Everything here is deliberately simple and tunable. The constants are starting guesses meant to be
calibrated against real sessions at these breaks.
"""
from __future__ import annotations

import math

G = 9.81
M_TO_FT = 3.28084
CARDINALS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
             "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
LABELS = ["Flat", "Poor", "Poor to fair", "Fair", "Good", "Epic"]


def cardinal(deg: float | None) -> str:
    if deg is None:
        return "–"
    return CARDINALS[int(((deg % 360) + 11.25) // 22.5) % 16]


def angle_diff(a: float, b: float) -> float:
    """Smallest absolute difference between two bearings, 0–180."""
    d = abs((a - b) % 360)
    return 360 - d if d > 180 else d


def in_arc(deg: float, start: float, end: float) -> bool:
    """True if bearing is inside the clockwise arc start→end (handles wrap past north)."""
    deg, start, end = deg % 360, start % 360, end % 360
    return start <= deg <= end if start <= end else deg >= start or deg <= end


# ---------------------------------------------------------------- surf height

def exposure(spot: dict, swell_from: float) -> float:
    """How much of a swell from this direction reaches the spot (0–1)."""
    theta = angle_diff(swell_from, spot["facing"])
    # Default is a gentle falloff: over Florida's wide shelf, refraction swings oblique swell toward the
    # beach, so a N swell still reaches an ENE-facing beach far better than deep-water geometry suggests.
    # Steep reef coasts (Hawaii) set a sharper exposure_power in their region calibration.
    if theta >= 100:
        return 0.0  # travelling away from the beach (e.g. offshore-wind chop)
    f = math.cos(math.radians(theta)) ** spot.get("exposure_power", 0.3) if theta < 90 else 0.0
    f = max(f, spot.get("exposure_floor", 0.2))  # refraction wraps a little of nearly-parallel swell in
    for s in spot.get("shelter", []):
        if in_arc(swell_from, s["from"], s["to"]):
            f *= s["factor"]
    return f


def breaker_height_m(h0: float, period: float) -> float:
    """Komar & Gaudiano (1975) breaking height from deep-water height and period."""
    if h0 <= 0 or period <= 0:
        return 0.0
    return 0.39 * G ** 0.2 * (period * h0 ** 2) ** 0.4


def components(row: dict) -> list[dict]:
    """The swell trains in one hourly row, largest first."""
    out = []
    for key, kind in (("swell_wave", "swell"), ("secondary_swell_wave", "swell"), ("wind_wave", "wind")):
        h, p, d = row.get(f"{key}_height"), row.get(f"{key}_period"), row.get(f"{key}_direction")
        if h and p and d is not None and h > 0.05:
            out.append({"h_m": h, "period": p, "dir": d, "kind": kind})
    out.sort(key=lambda c: c["h_m"] ** 2 * c["period"], reverse=True)
    return out


def surf_height(spot: dict, row: dict, shelf_factor: float) -> dict:
    """Estimated surf range (ft) at the beach plus the dominant train."""
    comps = components(row)
    if not comps and row.get("wave_height"):
        comps = [{"h_m": row["wave_height"], "period": row.get("wave_period") or 6,
                  "dir": row.get("wave_direction") or spot["facing"], "kind": "swell"}]
    # Only trains that actually reach this beach (drops offshore-wind chop heading out to sea).
    comps = [c for c in comps if exposure(spot, c["dir"]) > 0]
    energy = 0.0
    best, best_hb = None, -1.0
    for c in comps:
        hb = breaker_height_m(c["h_m"] * exposure(spot, c["dir"]), c["period"]) * shelf_factor
        energy += hb ** 2
        if hb > best_hb:
            best, best_hb = c, hb
    hb = math.sqrt(energy) * M_TO_FT
    return {
        "min_ft": round(hb * 0.8, 1), "max_ft": round(hb * 1.15, 1), "mid_ft": round(hb, 2),
        "primary": None if best is None else {
            "height_ft": round(best["h_m"] * M_TO_FT, 1), "period_s": round(best["period"], 1),
            "dir": round(best["dir"]), "dir_label": cardinal(best["dir"]), "kind": best["kind"],
        },
        "trains": [{"height_ft": round(c["h_m"] * M_TO_FT, 1), "period_s": round(c["period"], 1),
                    "dir": round(c["dir"]), "dir_label": cardinal(c["dir"]), "kind": c["kind"]}
                   for c in comps],
    }


def range_label(min_ft: float, max_ft: float) -> str:
    lo, hi = max(0, int(round(min_ft))), max(0, int(round(max_ft)))
    if hi < 1:
        return "0–1"
    if lo == hi:
        return f"{hi}"
    return f"{lo}–{hi}"


# ---------------------------------------------------------------- wind

def wind_kind(spot: dict, wind_from: float | None, speed: float | None) -> str:
    if wind_from is None or speed is None:
        return "unknown"
    if speed < 3:
        return "glassy"
    d = angle_diff(wind_from, (spot["facing"] + 180) % 360)  # 0 = straight offshore
    if d <= 45:
        return "offshore"
    if d <= 80:
        return "cross-offshore"
    if d <= 110:
        return "cross"
    if d <= 145:
        return "cross-onshore"
    return "onshore"


def wind_points(kind: str, speed: float) -> float:
    if kind == "glassy":
        return 0.6
    if kind == "offshore":
        return 0.8 if speed <= 15 else 0.2
    if kind == "cross-offshore":
        return 0.5 if speed <= 10 else -0.2
    if kind == "cross":
        return 0.1 if speed <= 6 else (-0.4 if speed <= 12 else -0.9)
    if kind in ("cross-onshore", "onshore"):
        return 0.0 if speed <= 4 else (-0.6 if speed <= 8 else (-1.2 if speed <= 14 else -1.8))
    return 0.0


# ---------------------------------------------------------------- rating

def size_points(mid_ft: float) -> float:
    for limit, pts in ((0.8, 0.0), (1.5, 0.8), (2.5, 1.4), (3.5, 2.2), (5, 3.0), (8, 3.6)):
        if mid_ft < limit:
            return pts
    return 3.9


def period_points(period: float) -> float:
    if period >= 12:
        return 0.7
    if period >= 10:
        return 0.5
    if period >= 8:
        return 0.2
    if period < 6:
        return -0.4
    return 0.0


def tide_points(best: str, level: float | None) -> float:
    """level: 0 = the day's low, 1 = the day's high."""
    if level is None or best == "any":
        return 0.0
    band = "low" if level < 0.33 else ("high" if level > 0.66 else "mid")
    if band == best:
        return 0.3
    if {band, best} == {"low", "high"}:
        return -0.3
    return 0.0


def rate(spot: dict, surf: dict, wind_kind_: str, wind_speed: float, tide_level: float | None) -> float:
    """0–5 score (float). Display as round(x)."""
    if surf["mid_ft"] < 0.8:
        return 0.0
    period = surf["primary"]["period_s"] if surf["primary"] else 6
    score = (size_points(surf["mid_ft"]) + period_points(period)
             + wind_points(wind_kind_, wind_speed or 0) + tide_points(spot.get("best_tide", "any"), tide_level))
    return max(0.0, min(5.0, score))


def stars(score: float) -> int:
    return int(math.floor(score + 0.5))


# ---------------------------------------------------------------- words

def size_word(mid_ft: float) -> str:
    for limit, w in ((0.8, "Flat"), (1.5, "Tiny"), (2.5, "Small"), (3.5, "Fun-sized"), (5, "Solid"), (8, "Big")):
        if mid_ft < limit:
            return w
    return "Huge"


def quality_word(kind: str, speed: float) -> str:
    if kind in ("glassy", "offshore") or (kind == "cross-offshore" and speed <= 10):
        return "clean"
    if kind == "cross" and speed <= 8:
        return "fair shape"
    if kind in ("cross-onshore", "onshore") and speed > 12:
        return "blown out"
    if kind in ("cross-onshore", "onshore") and speed <= 5:
        return "a little textured"
    return "bumpy"


def swell_word(period: float) -> str:
    if period >= 9:
        return "groundswell"
    if period >= 7:
        return "swell"
    return "wind swell"
