# NSB surf

A personal surf forecast for New Smyrna Beach and Ponce Inlet: a forecast engine, an iPhone app (coming next), and a Swellframe-style e-ink frame for a jailbroken Kindle.

## Forecast engine

`engine/` runs on GitHub Actions every 2 hours and publishes two files to GitHub Pages:

- `forecast.json` has everything for each spot: hourly data for 7 days, then every 3 hours out to day 16. It also has daily summaries, tides and live buoys.
- `summary.json` is the small version used by widgets: "now" plus the 16-day ratings.

Run it locally (Python 3.9+, standard library only):

```bash
python3 -m engine.build
python3 -m unittest discover -s tests -t .
```

### Data
- Waves: Open-Meteo Marine. It uses ECMWF WAM for about 10 days, then NOAA GFS-Wave out to 16 days.
- Wind, sunrise and sunset: Open-Meteo Forecast.
- Tides: NOAA CO-OPS 8721120 (Daytona Beach Shores, ocean side) for the beaches and 8721147 (Ponce Inlet South) for the inlet spots.
- Buoys: NDBC 41070 (Ponce), 41113 (Canaveral nearshore), 41009 (Canaveral offshore). For the next 24 hours, 41070 corrects the model's wave height.

### Kauai
`engine/kauai.json` is a second region (Tunnels, Hanalei Bay, Anahola, PK's, Pakala) on Hawaii time. It publishes `forecast-kauai.json` and `summary-kauai.json`, and the app switches between regions from the header. Tides: NOAA 1611683 (Hanalei), 1611400 (Nawiliwili), 1611347 (Port Allen). Buoys: NDBC 51208 (Hanalei, also corrects Tunnels and Hanalei) and 51201 (Waimea, Oahu). Heights are wave faces, not the Hawaiian scale.

### Tuning
Spots, beach direction, jetty shelter and best tide are in `engine/spots.json`. The math for surf height, wind and ratings is in `engine/surf.py`. All of these are starting guesses, meant to be tuned against real sessions.

## Mockups
`templates/` holds the frame screen designs. `python3 render_mockups.py` renders them to Kindle-size PNGs in `mockups/`.
