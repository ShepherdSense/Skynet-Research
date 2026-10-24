#!/usr/bin/env python3
"""Build the offline LAANC grid bundle for PlainRegs.

Downloads the FAA UAS Facility Map data (public, no auth) from the FAA's
ArcGIS FeatureServer, reduces every grid square to (cell, ceiling), and
writes a compact binary asset the app checks on-device, fully offline.

Grid facts (verified 2026-10-23): cells are uniform squares of 1/120 degree
(30 arc-seconds) aligned to a global grid; CEILING is in feet; MAP_EFF is
the chart-cycle effective date. Overlapping cells keep the MINIMUM ceiling
(most restrictive wins).

Re-run this once per 56-day chart cycle to refresh the bundle.

Outputs:
  assets/airspace_grid.bin            format PRG1 (see lib/airspace/)
  assets/airspace_grid_manifest.json  provenance + cycle stamp

Usage: python3 tool/build_airspace_bundle.py
"""
import collections
import concurrent.futures
import json
import math
import struct
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

BASE = (
    "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/arcgis/rest/services/"
    "FAA_UAS_FacilityMap_Data/FeatureServer/0/query"
)
PAGE = 2000
CELLS_PER_DEGREE = 120  # 1/120° cells, verified against live geometry
ROOT = Path(__file__).resolve().parent.parent


def fetch(offset: int) -> dict:
    params = {
        "where": "1=1",
        "outFields": "CEILING,MAP_EFF",
        "orderByFields": "OBJECTID",
        "resultOffset": offset,
        "resultRecordCount": PAGE,
        "f": "geojson",
        "geometryPrecision": 5,
        "returnGeometry": "true",
    }
    url = BASE + "?" + urllib.parse.urlencode(params)
    last_err = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001 - retry any transport error
            last_err = e
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"page at offset {offset} failed: {last_err}")


def _cell_range(lo: float, hi: float, offset: int) -> tuple[int, int]:
    """First/last grid cell index along one axis for a bbox edge pair.

    Grid edges sit exactly on cell boundaries, but the service rounds
    coordinates (geometryPrecision=5), which can push a max edge ~1e-5
    degrees past the boundary — enough to falsely span an extra cell on
    almost every feature. Snap edges that land within tolerance of a
    boundary onto it; genuine off-grid edges (large boundary polygons)
    fall back to floor logic.
    """
    flo = (lo + offset) * CELLS_PER_DEGREE
    fhi = (hi + offset) * CELLS_PER_DEGREE
    tol = 0.01  # in cell units (~0.000083 degrees, ~9 m)
    first = round(flo) if abs(flo - round(flo)) < tol else math.floor(flo)
    last = round(fhi) - 1 if abs(fhi - round(fhi)) < tol else math.floor(fhi)
    return first, max(first, last)


def uvarint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def zigzag(n: int) -> int:
    return (n << 1) ^ (n >> 63) if n >= 0 else ((-n << 1) - 1)


def total_count() -> int:
    url = BASE.replace("/query", "") + "/query?" + urllib.parse.urlencode(
        {"where": "1=1", "returnCountOnly": "true", "f": "json"})
    with urllib.request.urlopen(url, timeout=60) as r:
        return int(json.loads(r.read().decode("utf-8"))["count"])


def main() -> int:
    cells: dict[tuple[int, int], int] = {}
    map_eff = collections.Counter()
    ceilings = collections.Counter()
    features = 0
    multi_cell = 0

    count = total_count()
    offsets = list(range(0, count, PAGE))
    print(f"downloading {count} features in {len(offsets)} pages…",
          flush=True)
    pages: dict[int, dict] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for offset, page in zip(
                offsets, pool.map(fetch, offsets)):
            pages[offset] = page
    for offset in offsets:
        page = pages[offset]
        feats = page.get("features", [])
        for f in feats:
            features += 1
            props = f.get("properties") or {}
            ceiling = props.get("CEILING")
            if ceiling is None:
                continue
            ceiling = int(ceiling)
            ceilings[ceiling] += 1
            if props.get("MAP_EFF"):
                map_eff[props["MAP_EFF"]] += 1
            geom = f.get("geometry") or {}

            # Flatten all coordinate pairs recursively (Polygon and
            # MultiPolygon alike) to get the feature's bounding box.
            def flat(o):
                if isinstance(o, list) and o and isinstance(o[0], (int, float)):
                    yield o
                elif isinstance(o, list):
                    for x in o:
                        yield from flat(x)

            pts = list(flat(geom.get("coordinates", [])))
            if not pts:
                continue
            lons = [p[0] for p in pts]
            lats = [p[1] for p in pts]
            iy0, iy1 = _cell_range(min(lats), max(lats), 90)
            ix0, ix1 = _cell_range(min(lons), max(lons), 180)
            n = 0
            for iy in range(iy0, iy1 + 1):
                for ix in range(ix0, ix1 + 1):
                    key = (iy, ix)
                    if key not in cells or ceiling < cells[key]:
                        cells[key] = ceiling
                    n += 1
            if n > 1:
                multi_cell += 1
        print(f"  offset {offset}: {features} features, {len(cells)} cells",
              flush=True)

    ordered = sorted(cells.items())  # by (iy, ix)
    payload = bytearray()
    payload += b"PRG1"
    payload += struct.pack("<I", len(ordered))
    prev_iy = prev_ix = 0
    for (iy, ix), ceiling in ordered:
        payload += uvarint(iy - prev_iy)
        payload += uvarint(zigzag(ix - prev_ix))
        payload += uvarint(ceiling)
        prev_iy, prev_ix = iy, ix

    assets = ROOT / "assets"
    assets.mkdir(exist_ok=True)
    (assets / "airspace_grid.bin").write_bytes(payload)
    manifest = {
        "dataset": "FAA UAS Facility Maps (LAANC altitude grids)",
        "source": BASE.replace("/query", ""),
        "records_downloaded": features,
        "cells_after_reduction": len(ordered),
        "map_effective": map_eff.most_common(1)[0][0] if map_eff else None,
        "generated_on": time.strftime("%Y-%m-%d"),
        "cell_size_degrees": 1 / CELLS_PER_DEGREE,
        "format": "PRG1: uvarint row-delta, zigzag-varint col-delta, "
                  "uvarint ceiling(ft); overlaps keep minimum ceiling",
        "refresh": "Re-run tool/build_airspace_bundle.py each 56-day "
                   "aeronautical chart cycle.",
    }
    (assets / "airspace_grid_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n")

    print(f"features: {features}, multi-cell features: {multi_cell}")
    print(f"cells: {len(ordered)}, asset bytes: {len(payload)}")
    print(f"ceiling histogram: {dict(sorted(ceilings.items()))}")
    print(f"MAP_EFF values: {dict(map_eff)}")
    print(f"wrote {assets / 'airspace_grid.bin'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
