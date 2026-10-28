# Skynet Research

*(Flutter package name stays `plainregs`; the product is Skynet
Research. Icon: Cooper's real photo, 1600×1600 — ShepherdSense's call
2026-10-23, replacing the robot-face icon, which is kept at
`robot_icon_v2_backup.png`.)*

Find any regulation fast, read the real text, and read a plain-English
explanation of it — **alongside the original, never instead of it.**

> This is an explanation tool, not the law and not legal advice.
> The original regulatory text is what legally counts.

**Status: skeleton (bones), 2026-10-23.** See [DESIGN.md](DESIGN.md) for
scope, architecture, the simplification contract, and the phased roadmap
(federal → FAA/airspace companion docs → Federal Register → Department of
War publications → all 50 state codes).

## ▶ Try the web sim

**Live in your browser, nothing to install:**
https://ShepherdSense.github.io/Skynet-Research/sim/

The real app, compiled for the web. Everything bundled works right
there — the Can I Fly checker with the offline FAA LAANC grid, the
Shepherd fused check, all 50 state matrices, the Research briefs,
and the 3,419-source Resources catalogue. Search and Browse pull
live federal text from eCFR, so those two want an internet
connection. Try the **Site color** slider at the bottom of the
landing page — it recolors the whole app, drone included.

## What works now

- **Can I Fly My Drone?** — a guided checker: answer plain questions about
  your drone and your flight plan, get a **Yes / Not yet / No** determination
  where every item cites the exact rule (49 U.S.C. § 44809, 14 CFR Parts 48,
  89, 107…) and opens it in the Reader. "Don't know" is always an honest
  "check this", never a silent pass. Guidance, not an FAA authorization.
  The airspace step checks your location against the **bundled FAA LAANC
  grid** (all 380,860 facility-map squares, effective 10/1/2026, ~1.4 MB,
  fully offline — refresh per 56-day chart cycle with
  `tool/build_airspace_bundle.py`).
- **Shepherd — Fused Check** (on Browse) — pick a DoD UAS group (1–5),
  say whether live munitions are involved, give a location (GPS or typed
  coordinates for pre-planning), and get one fused summary. Every section
  is labelled REAL DATA, FRAMEWORK, or RESEARCHING — layers still being
  built are never faked.
- **Search** — live full-text search of the US Code of Federal Regulations
  via the official eCFR API (free, no key). Falls back to built-in sample
  sections when offline.
- **Browse** — all 50 CFR titles and the agency list; title → parts →
  sections. Includes a curated **FAA & Airspace** quick-links card
  (FAA rules live in Title 14).
- **Reader** — original text with **Original | Plain English | Both**
  views. Every plain view leads with the legal disclaimer.
- **Research** — ask a plain-language question ("Can I fly my drone
  over a parade?", "Do I need a state permit to film a roof inspection
  in NC?") and get a brief: short answer first, the deciding
  regulations cited and openable in the Reader, an honest "what we
  don't know" section, and dig-deeper follow-ups. Briefs can be
  saved. Currently a hand-written stub over the mapped drone
  material — outside its range it says so instead of guessing.
- **State Regulations — all 50** — the researched 13-category
  drone-law matrix for every state (privacy, law-enforcement use,
  critical infrastructure, takeoff/landing, registration, and more),
  each state stamped with its verification status and date:
  verified, partial (with its research note), or still researching —
  in which case no values are published at all. Shepherd pulls your
  state's rules into its summary when the location names the state.
- **Your Documents** — your own document library: if we haven't
  ingested an official publication, add it yourself (paste the text,
  import a .txt/.md file, or save the official link). It stays on your
  device, becomes searchable like any built-in source, and opens in
  the Reader. Found on the Browse tab.
- **Resources** — ShepherdSense's scheduled-research-source catalogue
  (3,419 of the 3,529 deduplicated websites and social accounts
  from the updated 2026-10-23 inventory PDF, which adds 184 review
  sources including new Substack and Bluesky entries — Telegram
  entries excluded per ShepherdSense): searchable, filterable by platform and
  topic tag (UAS, CUAS, RAS, EW…), each entry showing its report codes
  and kind; tap to open the source. Parsed by
  `tool/build_resources_bundle.py`, which reconciles every count
  against the catalogue's own totals before writing the bundle.
  Recovered records — live access not retested.
- **Events (in Resources)** — the Military Drone Events Register:
  74 U.S. military, allied and defense-industry drone events
  (competitions, exercises, acquisition events, conferences,
  cadet events), verified 2026-10-09, in a Sources | Events
  switch at the top of the Resources tab. Search by name, place,
  host or category, filter by status (Completed, Announced
  dates/window, Past schedule only, Tentative planning, Date
  unconfirmed) or flip on Upcoming only. Tap an event to expand
  it: host, exact dates where verified, evidence notes, and
  buttons to its primary and supporting sources. Built by
  `tool/build_events_bundle.py` from the register workbook —
  it fails loudly unless all 74 rows (E001–E074) reconcile.
- **Plain English (stub)** — hand-written samples for 14 CFR 107.51,
  14 CFR 107.49, and 29 CFR 1910.95. Everything else honestly says
  "not written yet" instead of guessing.
- **Bookmarks** — on-device, no account.

## Run it

```bash
flutter pub get
flutter test        # model, eCFR parsing, simplification guardrails, widgets
flutter run         # Android / Windows / web targets included
```

## Architecture in one paragraph

UI screens depend on two interfaces only: `RegulationSource` (a corpus —
eCFR today; Federal Register, DoW pubs, and state codes plug in via
`lib/services/sources.dart`) and `SimplificationService` (a stub today; a
real engine later, bound by the guardrails in DESIGN.md §4). Dark theme,
purple accents, minimal controls throughout.
