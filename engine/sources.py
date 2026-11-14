"""Fetch raw data: Open-Meteo (waves, wind, sun), NOAA CO-OPS (tides), NDBC (buoys).

Standard library only, so the GitHub Action needs no installs.
"""
from __future__ import annotations

import json
import math
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

UA = "surf-forecast-engine/1.0 (personal, non-commercial)"

MARINE_URL = "https://marine-api.open-meteo.com/v1/marine"
WEATHER_URL = "https://api.open-meteo.com/v1/forecast"
TIDES_URL = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
NDBC_URL = "https://www.ndbc.noaa.gov/data/realtime2/{id}.{ext}"

WAVE_VARS = [
    "wave_height", "wave_period", "wave_direction",
    "swell_wave_height", "swell_wave_period", "swell_wave_direction",
    "secondary_swell_wave_height", "secondary_swell_wave_period", "secondary_swell_wave_direction",
    "wind_wave_height", "wind_wave_period", "wind_wave_direction",
]
FORECAST_DAYS = 16


def _get(url: str, params: dict | None = None, retries: int = 6) -> str:
    if params:
        url = url + "?" + urllib.parse.urlencode(params)
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode("utf-8")
        except Exception as e:  # network hiccup: back off and retry (5, 10, 20, 40, 60s)
            last = e
            if attempt < retries - 1:
                time.sleep(min(5 * 2 ** attempt, 60))
    raise RuntimeError(f"GET failed after {retries} tries: {url}: {last}")


def _get_json(url: str, params: dict) -> object:
    return json.loads(_get(url, params))


def _as_list(d: object) -> list:
    """Open-Meteo returns a dict for one location and a list for several."""
    return d if isinstance(d, list) else [d]


def marine(spots: list, tz: str) -> list[dict]:
    """Per spot: hourly wave components, merged from ECMWF (~10 days) then GFS-Wave (to 16 days).

    Returns one dict per spot: {time: [...], <var>: [...], model: [...], sst_c: [...]}.
    """
    lats = ",".join(str(s["lat"]) for s in spots)
    lons = ",".join(str(s["lon"]) for s in spots)
    base = {"latitude": lats, "longitude": lons, "timezone": tz,
            "forecast_days": FORECAST_DAYS, "length_unit": "metric"}
    best = _as_list(_get_json(MARINE_URL, {**base, "hourly": ",".join(WAVE_VARS + ["sea_surface_temperature"])}))
    gfs = _as_list(_get_json(MARINE_URL, {**base, "hourly": ",".join(WAVE_VARS), "models": "ncep_gfswave025"}))

    out = []
    for b, g in zip(best, gfs):
        bh, gh = b["hourly"], g["hourly"]
        n = len(bh["time"])
        merged = {"time": bh["time"], "model": [], "grid": [b["latitude"], b["longitude"]]}
        for v in WAVE_VARS:
            merged[v] = [None] * n
        for i in range(n):
            use_best = bh["wave_height"][i] is not None
            src = bh if use_best else gh
            merged["model"].append("ecmwf" if use_best else "gfs")
            for v in WAVE_VARS:
                merged[v][i] = src.get(v, [None] * n)[i]
        sst = bh.get("sea_surface_temperature", [None] * n)
        # Carry the last known SST forward; it changes slowly.
        last = None
        filled = []
        for x in sst:
            last = x if x is not None else last
            filled.append(last)
        merged["sst_c"] = filled
        out.append(merged)
    return out


def weather(spots: list, tz: str) -> list[dict]:
    """Per spot: hourly wind (mph) plus daily sunrise/sunset."""
    params = {
        "latitude": ",".join(str(s["lat"]) for s in spots),
        "longitude": ",".join(str(s["lon"]) for s in spots),
        "hourly": "wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m,weather_code",
        "daily": "sunrise,sunset",
        "wind_speed_unit": "mph", "temperature_unit": "fahrenheit",
        "timezone": tz, "forecast_days": FORECAST_DAYS,
    }
    return _as_list(_get_json(WEATHER_URL, params))


def tide_hilo(station: str, start: datetime) -> list[dict]:
    """High/low predictions (works for both harmonic and subordinate stations).

    Fetched in 9-day chunks: subordinate stations sometimes reject longer ranges.
    """
    preds: dict[str, dict] = {}
    first = start - timedelta(days=1)
    for offset in range(0, FORECAST_DAYS + 2, 9):
        params = {
            "product": "predictions", "application": "surf_forecast_engine",
            "begin_date": (first + timedelta(days=offset)).strftime("%Y%m%d"), "range": 9 * 24,
            "datum": "MLLW", "station": station, "time_zone": "lst_ldt",
            "units": "english", "interval": "hilo", "format": "json",
        }
        d = _get_json(TIDES_URL, params)
        if "predictions" not in d:
            raise RuntimeError(f"NOAA tides {station}: {d}")
        for p in d["predictions"]:
            preds[p["t"]] = p
    return [{"t": datetime.strptime(p["t"], "%Y-%m-%d %H:%M"), "ft": float(p["v"]), "type": p["type"]}
            for _, p in sorted(preds.items())]


def tide_at(hilo: list[dict], t: datetime) -> float | None:
    """Tide height between two turning points via cosine interpolation (close to the real curve)."""
    for a, b in zip(hilo, hilo[1:]):
        if a["t"] <= t <= b["t"]:
            f = (t - a["t"]).total_seconds() / (b["t"] - a["t"]).total_seconds()
            return a["ft"] + (b["ft"] - a["ft"]) * (1 - math.cos(math.pi * f)) / 2
    return None


def _num(x: str) -> float | None:
    return None if x in ("MM", "N/A", "") else float(x)


def buoy(buoy_id: str) -> dict | None:
    """Latest NDBC observation. Times are UTC."""
    try:
        txt = _get(NDBC_URL.format(id=buoy_id, ext="txt")).splitlines()
    except RuntimeError:
        return None
    rows = [l.split() for l in txt if l and not l.startswith("#")]
    if not rows:
        return None
    cols = txt[0].lstrip("#").split()
    obs = None
    # First row with a wave height (some rows are met-only).
    for r in rows[:12]:
        row = dict(zip(cols, r))
        if _num(row.get("WVHT", "MM")) is not None:
            obs = row
            break
    if obs is None:
        return None
    out = {
        "observed_utc": f'{obs["YY"]}-{obs["MM"]}-{obs["DD"]}T{obs["hh"]}:{obs["mm"]}:00Z',
        "wave_m": _num(obs["WVHT"]), "dominant_period_s": _num(obs["DPD"]),
        "mean_dir": _num(obs["MWD"]), "water_c": _num(obs["WTMP"]),
    }
    # Swell / wind-sea split, when the buoy publishes spectral summaries.
    try:
        spec = _get(NDBC_URL.format(id=buoy_id, ext="spec")).splitlines()
        scols = spec[0].lstrip("#").split()
        srow = dict(zip(scols, [l.split() for l in spec if l and not l.startswith("#")][0]))
        out.update({"swell_m": _num(srow["SwH"]), "swell_period_s": _num(srow["SwP"]),
                    "swell_dir": srow["SwD"], "windsea_m": _num(srow["WWH"]),
                    "windsea_period_s": _num(srow["WWP"])})
    except (RuntimeError, IndexError, KeyError):
        pass
    return out
