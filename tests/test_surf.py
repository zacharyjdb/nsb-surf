import unittest

from engine import surf
from engine.build import thin

SPOT = {"facing": 70, "best_tide": "mid", "shelter": []}
JETTY = {"facing": 65, "best_tide": "mid", "shelter": [{"from": 330, "to": 30, "factor": 0.6}]}


def row(h, p, d):
    return {"swell_wave_height": h, "swell_wave_period": p, "swell_wave_direction": d}


class Geometry(unittest.TestCase):
    def test_cardinal(self):
        self.assertEqual(surf.cardinal(0), "N")
        self.assertEqual(surf.cardinal(359), "N")
        self.assertEqual(surf.cardinal(74), "ENE")
        self.assertEqual(surf.cardinal(270), "W")

    def test_arc_wraps_north(self):
        self.assertTrue(surf.in_arc(350, 330, 30))
        self.assertTrue(surf.in_arc(10, 330, 30))
        self.assertFalse(surf.in_arc(90, 330, 30))

    def test_exposure(self):
        self.assertAlmostEqual(surf.exposure(SPOT, 70), 1.0)
        self.assertEqual(surf.exposure(SPOT, 250), 0.0)  # offshore chop never reaches the beach
        self.assertLess(surf.exposure(SPOT, 0), surf.exposure(SPOT, 45))
        self.assertLess(surf.exposure(JETTY, 0), surf.exposure(SPOT, 0))  # jetty shadow


class Height(unittest.TestCase):
    def test_bigger_and_longer_is_bigger(self):
        small = surf.surf_height(SPOT, row(0.5, 8, 75), 0.6)["mid_ft"]
        big = surf.surf_height(SPOT, row(1.5, 8, 75), 0.6)["mid_ft"]
        long_ = surf.surf_height(SPOT, row(1.5, 12, 75), 0.6)["mid_ft"]
        self.assertLess(small, big)
        self.assertLess(big, long_)

    def test_typical_small_day(self):
        # ~1.8 ft at 8 s from ENE should read as roughly 1-2 ft at the beach.
        s = surf.surf_height(SPOT, row(0.55, 8, 74), 0.6)
        self.assertTrue(1.0 <= s["mid_ft"] <= 2.5, s)

    def test_range_label(self):
        self.assertEqual(surf.range_label(0.2, 0.4), "0–1")
        self.assertEqual(surf.range_label(1.4, 2.2), "1–2")
        self.assertEqual(surf.range_label(2.6, 3.2), "3")


class Wind(unittest.TestCase):
    def test_kinds(self):
        self.assertEqual(surf.wind_kind(SPOT, 250, 8), "offshore")
        self.assertEqual(surf.wind_kind(SPOT, 70, 8), "onshore")
        self.assertEqual(surf.wind_kind(SPOT, 160, 8), "cross")
        self.assertEqual(surf.wind_kind(SPOT, 70, 2), "glassy")


class Rating(unittest.TestCase):
    def test_offshore_beats_onshore(self):
        s = surf.surf_height(SPOT, row(1.2, 10, 70), 0.6)
        off = surf.rate(SPOT, s, "offshore", 8, 0.5)
        on = surf.rate(SPOT, s, "onshore", 15, 0.5)
        self.assertGreater(off, on)

    def test_flat_is_zero(self):
        s = surf.surf_height(SPOT, row(0.1, 5, 70), 0.6)
        self.assertEqual(surf.rate(SPOT, s, "offshore", 5, 0.5), 0.0)

    def test_bounds(self):
        s = surf.surf_height(SPOT, row(5, 16, 70), 0.6)
        self.assertLessEqual(surf.rate(SPOT, s, "glassy", 0, 0.5), 5.0)


class Thinning(unittest.TestCase):
    def test_hourly_first_week_then_three_hourly(self):
        hours = [{"t": f"2026-11-{13 + d:02d}T{h:02d}:00"} for d in range(10) for h in range(24)]
        out = thin(hours)
        self.assertEqual(len([h for h in out if h["t"] < "2026-11-20"]), 7 * 24)
        self.assertEqual(len([h for h in out if h["t"] >= "2026-11-20"]), 3 * 8)


if __name__ == "__main__":
    unittest.main()
