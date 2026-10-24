# PlainRegs — Design

**Working name:** PlainRegs (rename freely — no branding is baked into the code;
the app title lives in one place, `lib/app.dart`).

**One-liner:** Find any regulation fast, read the real text, and read a
plain-English explanation of it — side by side, never instead of it.

**Draco's bar (applies to every screen):** easy to install, easy to
understand, easy to operate, looks dope. Super-clean minimal UI, dark mode,
purple accents, few visible controls. Every flow must pass the
tired-operator-in-the-field test: no help file, no second app, no terminal.

Status: **BONES (skeleton)** — 2026-10-23. Screens navigate, the data and
simplification layers are real interfaces with working implementations, and
the app runs end-to-end offline against sample data. It is not a finished
product; see "Known limits" and "Open questions".

---

## 1. Scope

### v1 corpus (this skeleton)
- **US federal regulations — the Code of Federal Regulations (CFR)** via the
  official **eCFR API** (National Archives / GPO). Free, public, no API key,
  updated daily.
  - Full-text search across all 50 titles
  - Browse by CFR title (1–50) and by agency
  - Read the current section text

### Explicitly NOT in v1 (but the architecture is ready for them)
"All the regulations" is bigger than the CFR. These corpora are **not** in
eCFR and each needs its own source adapter (see §3):

| Corpus | Where it actually lives | Notes |
|---|---|---|
| Military pubs (AFI / DAFI / AFMAN, Army ARs, etc.) | AF e-Publishing, Army Publishing Directorate | Mostly PDFs; needs ingest + OCR/parse pipeline |
| State regulations | 50 separate state admin codes / registers | No single API; per-state scrapers/APIs where offered |
| Federal Register (rules as proposed/final) | federalregister.gov API (free, public) | Easiest second source — same family as eCFR |
| U.S. Code (statutes, not regulations) | OLRC / govinfo APIs | Different citation system (U.S.C.) |
| Local / municipal codes | Municode, American Legal, Qcode, … | Fragmented, some paywalled |
| Executive orders, OMB circulars, agency guidance | Mixed | Guidance ≠ regulation; must be labelled as such |

**Draco's answer (2026-10-23): "everything"** — federal regulations, state
regulations, Department of War regulations, FAA regulations, and airspace
requirements. So the registry (§3) is the product: corpora plug in in phases
without the UI changing.

Phased roadmap (same UI, new `RegulationSource` adapters):

1. **Phase 1 — Federal CFR (this skeleton).** eCFR, all 50 titles.
2. **Phase 1b — FAA + airspace as a curated collection, not a separate
   corpus.** FAA regulations *are* federal regulations (14 CFR — Aeronautics
   and Space; 49 CFR — Transportation), so they are already searchable in
   Phase 1. What makes "airspace" feel separate is that the full picture
   also lives in the FAA AIM, FAA Orders (e.g. JO 7400 series), Advisory
   Circulars, and NOTAMs — none of which are in the CFR. Phase 1b adds:
   one-tap FAA/Airspace filters (14 CFR Parts 71, 73, 91, 93, 99, 105, 107,
   121, 135, 136, 137 + 49 CFR Part 830), then adapters for AIM / FAA Orders /
   ACs as companion sources, clearly labelled *guidance vs. regulation*.
3. **Phase 2 — Federal Register** (proposed + final rules, executive
   orders) — free public API, easiest add.
4. **Phase 3 — Department of War.** DoDI/DoDM, DAFI/AFI/AFMAN/AFPAM,
   Army Regulations, MCOs, SECNAVINST, etc. Source: AF e-Publishing and
   sister-service publishing sites. Mostly PDFs — needs an ingest pipeline
   (fetch → parse → index), not a live API. This is the biggest build.
5. **Phase 4 — State regulations: ALL 50, batch-wise** (Draco,
   2026-10-23: "I would like it to be available in all states" — the
   NC-pilot framing is superseded). The 13-category drone-law matrix
   was researched for all 50 states in five batches plus the NC
   exemplar and ships as bundled data (§15): a state flips from
   RESEARCHING to real data when its research is verified — state by
   state, no big-bang dependency. Full statute-text adapters per
   state remain a later layer on top of the matrix.
6. **Phase 5 — The rest:** U.S. Code, municipal codes, agency guidance.

### Non-goals
- Legal advice. The app explains regulations; it does not advise, and the
  plain-English view is not the law (see §4).
- Editing, submitting comments, or filing anything.
- Accounts / cloud sync in the skeleton. Bookmarks are on-device only.

---

## 2. Product shape

Four surfaces, bottom navigation, nothing else competing for attention:

1. **Search** — one big field. Type words ("how high can I fly a drone") or a
   citation ("14 CFR 107.51"). Results show citation, heading, and a matched
   excerpt.
2. **Browse** — the 50 CFR titles as a clean list, plus an Agencies view.
   Title → chapters/parts → sections → Reader.
3. **Reader** — the original regulatory text, exactly as published.
   A segmented control switches **Original | Plain | Both**:
   - *Original* — the legal text.
   - *Plain* — the plain-English explanation, always headed by the
     disclaimer banner and a one-tap jump back to the original.
   - *Both* — side-by-side on wide screens, stacked (plain first? No —
     original first) on narrow ones. The plain view is **presented
     alongside the original, never instead of it**.
4. **Bookmarks** — minimal: bookmark from the Reader, tap to return, swipe
   to remove. Stored on-device.
5. **Can I Fly?** — guided drone determination (added later the same day at
   Draco's direction): a short wizard that ends in a cited yes / not-yet /
   no determination. Full design in §8.

Theme: dark, purple accent (`#8B7CF6`-family on near-black), large readable
body text in the Reader (regulations are walls of text; line height and
measure matter more than chrome).

---

## 3. Data layer

One interface, many corpora. UI code never talks to eCFR directly.

```dart
abstract class RegulationSource {
  String get id;            // 'ecfr'
  String get displayName;   // 'US Federal Regulations (CFR)'
  Future<List<SearchHit>> search(String query, {int page, String? agencySlug});
  Future<List<CfrTitle>> titles();
  Future<List<Agency>> agencies();
  Future<StructureNode> structure(int titleNumber, {String? date});
  Future<RegSection> fetchSection(RegulationRef ref);
}
```

Implementations:
- `EcfrSource` — real, against the live API (below). Takes an injectable
  `http.Client` so tests run against fixtures with no network.
- `SampleSource` — 3 canned sections, zero network. Used by tests and as the
  first-run/offline demo, so the skeleton runs end-to-end with no key and
  no connection.

### eCFR API (verified live 2026-10-23, base `https://www.ecfr.gov`)
No key, no auth. Endpoints used:

| Need | Endpoint |
|---|---|
| Titles + currency dates | `GET /api/versioner/v1/titles.json` |
| Full-text search | `GET /api/search/v1/results?query=…&page=…&per_page=…` (+ optional `agency_slugs[]=…`) |
| Agencies | `GET /api/admin/v1/agencies.json` |
| Title structure tree | `GET /api/versioner/v1/structure/{YYYY-MM-DD}/title-{n}.json` |
| Section full text (XML) | `GET /api/versioner/v1/full/{YYYY-MM-DD}/title-{n}.xml?part=…&section=…` |

Notes / traps found while verifying:
- The **full-text endpoint requires a compression-permitting
  `Accept-Encoding`** or it returns an error XML. Dart's `http` handles gzip
  automatically; anything hand-rolled must not forget this.
- "Current" is per-title: `titles.json` gives each title's
  `up_to_date_as_of`. `EcfrSource` resolves the date from there instead of
  guessing "today" (weekends / publication lag).
- Full-text XML is a simple `DIV8/HEAD/P` structure for a section; the
  skeleton extracts head + paragraphs to plain text. Tables, appendices and
  complex nested lists are **lossy** in the skeleton — flagged in §6.
- Live quirks found in the 2026-10-23 smoke check (all handled in
  `EcfrSource`): search **headings** carry `<strong>` highlight markup just
  like excerpts (stripped); the same section repeats **once per historical
  version** in search results (deduped by citation); the full-text endpoint
  throws **transient 503s** under load (one retry).
- Structure JSON for a large title is big (Title 14 ≈ 17 MB). The skeleton
  decodes it whole and shows chapters/parts; production needs caching and
  probably a trimmed local index. Flagged in §6.

Adding a corpus = adding one `RegulationSource` implementation + registering
it in `lib/services/sources.dart`. Search/Browse/Reader don't change.

---

## 4. Simplification layer — the contract

Also an interface, so the engine can change without touching the UI:

```dart
abstract class SimplificationService {
  Future<Simplification> simplify(RegSection section);
}
class Simplification {
  String plainText;        // the explanation
  List<String> keyPoints;  // short bullets, drawn only from the text
  bool isStub;             // true until a real engine backs this
  // disclaimer is a constant, not a field an engine can omit:
  static const disclaimer = 'This is a plain-English explanation to help '
      'you understand. It is not the law. The original text is what '
      'legally counts.';
}
```

Implementations:
- `StubSimplificationService` (**in the skeleton**) — a small map of
  hand-written sample simplifications (14 CFR 107.51, 14 CFR 107.49,
  29 CFR 1910.95). For anything else it returns an honest *not-yet* result:
  it says no plain version exists yet and gives reading guidance. **It never
  fabricates an explanation.**
- Future real engine (not in skeleton, needs Draco's call): on-device or
  cloud LLM behind this same interface. No API key is wired into the
  skeleton, deliberately.

### Guardrails (baked in, non-negotiable for any future engine)
1. **Explain, never legislate.** A simplification may restate, reorder, and
   define terms. It must never add an obligation, remove one, soften a
   "shall/must" into a "should", or invent numbers, deadlines, or exceptions
   that aren't in the original.
2. **Disclaimer on every plain view.** The exact constant above renders at
   the top of every Plain/Both view. It is a compile-time constant in the
   shared model, not copy an engine supplies.
3. **Always alongside.** There is no route that shows plain text without a
   visible path to — and in Both view, the literal presence of — the
   original. Numbers and citations in a simplification must trace to the
   original section on screen.
4. **Target reading level ≈ 8th grade.** Short sentences, everyday words,
   define any legal term that must be kept ("for example, 'shall' means
   'must'").
5. **Uncertainty is shown, not smoothed over.** If the original is ambiguous
   or the engine is unsure, the plain view says so plainly instead of
   guessing.
6. **No legal advice.** Explanations describe what the text says, never what
   the reader should do about their specific situation.

---

## 5. Tech

- **Flutter** (matches Shepherd / Pack Out), one codebase: Android first,
  Windows + web targets created.
- **Direction (2026-10-23, §16): site-first.** The web build becomes
  an installable PWA — one front end for iPhone, Android, and
  desktop, no app-store gate. The Flutter front end stays; the
  corpus and the AI move server-side behind the existing interfaces.
- Deps kept minimal: `http` (eCFR), `shared_preferences` (bookmarks).
  No state-management framework — `ChangeNotifier` stores are enough at
  this size.
- Layout:
  ```
  lib/
    main.dart                 entry point, wires real services
    app.dart                  MaterialApp, theme, nav shell
    theme.dart                dark + purple
    models/                   RegulationRef, SearchHit, CfrTitle, Agency,
                              StructureNode, RegSection, Simplification, Bookmark
    services/
      regulation_source.dart  the corpus interface
      ecfr_source.dart        live eCFR implementation
      sample_source.dart      offline canned corpus
      simplification_service.dart  interface + disclaimer constant
      stub_simplification_service.dart  hand-written samples
      sources.dart            registry (add a corpus here)
    state/bookmarks_store.dart
    screens/                  search, browse, title detail, reader, bookmarks
  test/                       model, eCFR parsing (MockClient fixtures),
                              stub simplification guardrails, widget smoke test
  ```

## 6. Known limits of the skeleton

- Reader text extraction from eCFR XML is paragraph-level: tables,
  footnotes, appendices, and deeply nested enumerations render flattened.
- Browse decodes a title's full structure JSON in memory; large titles are
  slow on first load and nothing is cached to disk yet.
- Search is eCFR's search, as-is (relevance order, excerpt highlighting
  stripped to plain text). No citation-parser shortcut yet ("107.51" alone
  goes through search like everything else).
- Simplifications exist for exactly 3 sample sections (stub). Everything
  else honestly reports "not written yet".
- Bookmarks store citation + heading only, and re-fetch text on open —
  no offline full-text cache.
- No iOS target was created in this environment (add with
  `flutter create --platforms=ios .` on a Mac).

## 8. "Can I Fly My Drone?" — the determination checker (added 2026-10-23)

Draco's requirement: *"somebody should be able to use the app and determine
whether they can or cannot fly a drone that they have."* This is the app's
first guided decision flow, and the template for future ones (hunting,
boating, job-site safety… any "can I do X?" domain).

Shape:
- A wizard tab (**Can I Fly?**) plus a card on Search. One plain question
  per step, big tap targets: why you're flying → drone weight →
  registration → TRUST / Remote Pilot certificate → Remote ID → airspace →
  the flight plan (height, line of sight, over people, night).
- A pure-Dart rule engine (`lib/flycheck/fly_check.dart`,
  `evaluateFlyCheck`) maps answers to outcomes. It is a pure function —
  every scenario is unit-tested without the UI.
- Verdicts: **Yes** / **Not yet — fix these first** (every fix states the
  concrete action: register on DroneZone, take free TRUST, get LAANC…) /
  **No — not the way you described it** (the plan itself breaks a rule;
  each blocker says what to change) / **Can't tell yet** / **Different
  rulebook** (government/military = public aircraft ops, honest off-ramp).

Guardrails (same spirit as §4, applied to determinations):
1. **Every outcome cites its rule** (49 U.S.C. § 44809, 14 CFR Part 48/89,
   107.31/107.41/107.51/107.61/107.29, Part 107 Subpart D) and readable
   citations open the rule in the Reader, original + plain.
2. **"Don't know" never becomes a silent pass.** Unknowns produce *check*
   outcomes and cap the verdict at "Not yet".
3. **The result is guidance, not authorization.** The result screen states
   it plainly: not legal advice, not an FAA authorization; local/park/
   property rules and TFRs still apply; check B4UFLY.
4. **Rules are data, not vibes.** Thresholds used: registration ≥0.55 lb
   (Part 48); Part 107 and recreational both <55 lb; 400 ft cap; VLOS;
   night = training + 3-mile anti-collision light; over-people = Subpart D
   categories (engine returns *check*, because category compliance can't
   be determined from a yes/no answer — by design).

Known limits: no drone-model database (weight/Remote ID/category are
user-reported), U.S. civil operations only. (Airspace is no longer a
limit — see §8.1.)

### 8.1 LAANC grid check (added 2026-10-23, Draco approved)

The wizard's airspace step now checks the phone's location against the
**FAA UAS Facility Maps (LAANC altitude grids)**, bundled into the app:

- **Source:** FAA ADDS FeatureServer
  (`services6.arcgis.com/…/FAA_UAS_FacilityMap_Data/FeatureServer/0`),
  public, no auth. 380,860 grid squares, dataset refreshed 2026-10-23,
  `MAP_EFF 10/1/2026`.
- **Reduction (verified):** the squares are a uniform 1/120° (30″) grid,
  so each feature reduces to exactly one cell + its CEILING (feet) —
  380,860 features → 380,860 cells → a **1.4 MB binary asset**
  (`assets/airspace_grid.bin`, format PRG1) via
  `tool/build_airspace_bundle.py`. Overlaps (none in the current cycle
  after cell-snapping) would keep the minimum ceiling. A coordinate-
  rounding artifact in the source (geometryPrecision) initially bled
  ceilings one cell over; the build script snaps edges to grid lines,
  and the bundle is verified point-by-point against the live API
  (KFAY = 400, downtown Fayetteville = 400, LAX core = 0).
- **Runtime:** fully offline point lookup on-device
  (`lib/airspace/`); the location fix never leaves the phone. The wizard
  shows the grid ceiling + the data's effective-date stamp.
- **Refresh cadence: re-run the build script once per 56-day
  aeronautical chart cycle** and ship the new bundle with an app update.
- **Honesty rules, unchanged:** the maps are informational — they do
  NOT authorize a flight (LAANC approval still comes from an
  FAA-approved app), they don't show TFRs/NOTAMs/stadium/restricted
  areas/park rules, and a 0-foot square yields a "not yet — manual
  authorization via DroneZone or fly elsewhere" outcome, never a ban
  claim. No location permission / outside US coverage → the original
  self-report flow, never a silent pass.

## 9. Open questions for Draco

1. ~~Second corpus?~~ **Answered 2026-10-23: everything** — federal, state,
   Department of War, FAA, airspace. Phased roadmap in §1.
2. ~~Simplification/research engine?~~ **Answered 2026-10-23 (§16):**
   a small RAG "hunter" over the centrally ingested corpus is the
   foundation; a larger cloud model is an optional escalation tier
   for hard simplifications, not the base. Hand-written stubs remain
   as the curated fallback layer.
3. ~~Name?~~ **Answered 2026-10-23: "Skynet Research"** (first
   "Terminator by Shepherd", renamed the same day) — Cooper icon
   reworked to a robot face with a purple laser eye, the robotics
   fitted to his muzzle and chin (same dog, same comtacs;
   `assets/icon/icon.png`, launcher icons regenerated for
   Android / web / Windows).
4. ~~Audience?~~ **Answered 2026-10-23: military only.** The
   audience is service members and DoW users, not the general
   public. Consequences: the Shepherd/DoW layers are first-class
   citizens, not add-ons; plain-English can assume a military
   reader (ranks, MAJCOMs, COAs need no civilian translation);
   distribution is through unit channels, not public marketing.
   The civil layers (Part 107, recreational rules, the 50-state
   matrix) stay — service members fly under FAA rules in the NAS
   and fly recreationally off duty. **Military-only does NOT change
   the sourcing rule: public sources only, nothing CAC-gated or
   CUI is ever ingested** — audience is not authorization, and the
   app must never become a place where sensitive material accretes.
   Disclaimers stay at full strength regardless (guidance, not
   legal advice, not an authorization).
   **Access: OPEN (Draco, same day — supersedes a code-gate
   idea considered and dropped the same evening).** No access
   code, no accounts, no gate. The *audience* is military —
   the tool is designed for, worded for, and spread among
   service members — but anyone who reaches the site can use
   it. That fits the sourcing rule: the corpus is entirely
   public law and public publications, so there is nothing in
   it that needs a gate.

## 10. Shepherd mode — the fused check (added 2026-10-23, Draco's spec)

Browse carries one button per branch/office (FAA Regulations — live;
Federal — All Titles — live; State Regulations and Department of War —
status pages while research runs) and, above them, the **SHEPHERD**
button. Shepherd is the fusion layer: instead of reading each corpus
separately, the user answers three things and gets one summary for that
aircraft at that spot:

1. **What group drone will be used?** DoD joint Groups 1–5 (bands and
   examples in `lib/shepherd/shepherd.dart`, highest-attribute rule).
2. **Will live munitions be used?** Yes → the summary's munitions
   section states the DoW framework plainly: armed aircraft are never
   authorized by civil rules or LAANC; employment runs through the
   military chain, weapons safety/range control, and designated
   airspace. Shepherd summarizes public governance only and clears
   nothing.
3. **Location** — current fix, or coordinates typed in manually for
   pre-planning (the same offline grid bundle as §8.1).

Fusion honesty: every summary section is labelled **REAL DATA** (the
grid), **FRAMEWORK** (established public frameworks: UAS groups, civil
weight classes, munitions governance), or **RESEARCHING** (state and
DoW publication layers, shown as placeholders with what they will
cover). A layer that isn't built is never paraphrased into existence.
Research agents were tasked 2026-10-23 with the FAA / state / DoW
drone-regulation inventories (`~/workspace/research_notes/drone-regs-*.md`);
their findings decide the next adapters.

## 11. Resources — the research-source catalogue (added 2026-10-23)

Draco's ask: a resource function built from his scheduled-research
catalogue (`All_Scheduled_Research_Sources_2026-10-23__1.pdf` — 3,529
deduplicated websites and social accounts recovered from 24 research
task prompts, tagged by topic and by the report codes that use them:
RU, IRAN, BRICS-U, UAS-W, DOC-HUNT, LINKEDIN-M, …). The updated
catalogue adds 184 review sources (Source_Gap_Review_2026-10-23) to
the original 3,345, including the first Bluesky entries and three
more Substack newsletters.

- **Fifth nav tab "Resources"**: full-text search (name, description,
  tags, report codes), platform filter chips with counts (Website
  2,609 · LinkedIn 388 · YouTube 138 · X 127 · Reddit 66 · Facebook 54
  · Instagram 16 · GitHub 9 · Substack 6 · Threads 3 · Bluesky 3 —
  Telegram's 110 are excluded per Draco, so 3,419 ship), topic tag
  chips (top 14 by frequency), kind badge (Current task source /
  Directory / Historical / Review addition). Tapping an entry opens
  the source in the browser.
  Website entries carry their catalogue collection (News & media,
  Research & reference, Robotics/tech/industry, Government & military,
  Directories & data tools, plus the review additions' finer-grained
  collections). The tab builds lazily on first visit so
  the catalogue never parses at startup.
- **Data**: `tool/build_resources_bundle.py` runs `pdftotext -raw` on
  the PDF and parses the SRC-NNNN entry structure (joining URLs that
  wrap mid-token; recovering the 30 Website URLs printed only as
  domains in entry names). It **reconciles every section count, the
  per-platform totals, and the 3,529 grand total against the
  catalogue's own summary table and fails loudly on any mismatch** —
  the bundle parsed 3,529/3,529 with URL, tags, reports and
  kind on every entry (Substack entries are reclassified by URL host:
  the catalogue counts them as their own platform but prints them
  inside Website sections). Output: `assets/resources.json`
  (+ manifest). Re-run the script when Draco provides an updated
  catalogue.
- **Honesty**: the catalogue's own caveat is shown in the UI — sources
  are recovered records; account ownership, activity and live access
  were not rechecked. Resources are research leads, not authorities;
  nothing here is regulation text.

## 11b. Events — the Military Drone Events Register (added 2026-10-24)

Draco's ask (with the register workbook
`Military_Drone_Events_Register_2026-10-09__1.xlsx`): an events
section inside the Resources tab. The register holds **74 events**
(E001–E074, verified 2026-10-09): U.S. military, allied and
defense-industry drone events — warfighter competitions (17),
conferences/expos (9), technology and acquisition competitions,
joint competitions/experiments, demonstrations/exercises, SOF
assessments, industry days and cadet/STEM events. Statuses:
Completed 40 · Announced dates 17 · Announced window 7 · Past
schedule only 5 · Tentative planning 3 · Date unconfirmed 2.
Exact-start dates run 2025-03-07 → 2027-05-17; 54 events carry an
exact start, 20 do not (their full date is unverified). Every
event carries a primary source URL; 18 carry a supporting one.

- **UI**: a Sources | Events segmented control at the top of
  the Resources tab (the tab count does not change). Events view:
  free-text search (name, window, status, location, host,
  category, focus, notes), status chips with counts, an
  "Upcoming only" toggle (exact start today or later), newest
  first by exact start with undated events last. Each event is
  an expandable card: window, location, host, publisher, exact
  dates (or "Exact dates not verified"), focus, participation,
  evidence notes, and Primary / Supporting source buttons.
- **Data**: `tool/build_events_bundle.py` reads the workbook
  (sheet "Events", header row 8) and writes
  `assets/events.json` (+ manifest). It **fails loudly** unless
  the header matches exactly, all 74 rows are present in
  E001–E074 order, every row has a name, window, status,
  location, host, category, focus, notes and primary URL, every
  status is in the register's own set, and every row is verified
  2026-10-09. Re-run on a new register.
- **Honesty**: the register's caveat rides in the UI —
  public-source inventory (local, classified, unannounced and
  older unit events may be missing); future dates remain subject
  to change; "Past schedule only" means a published past date
  without a reviewed completion report, and "Completed" means
  occurrence corroborated.

## 12. Authorities home & the Shepherd fusion (structure, 2026-10-23)

Draco's structure directive (via the main chat): top-level buttons per
authority, one prominent SHEPHERD fusion button, and research maps as
the corpus plan. This section records the structure; §10 holds the
Shepherd implementation detail.

**Research-map inputs (the corpus plan of record).** Three official-
source maps built by research agents from the main chat live in
`~/workspace/research_notes/plainregs-drone-regs/`:

- `faa.md` — 16 entries: 49 U.S.C. § 44809, 14 CFR Parts 48 / 89 / 107
  (incl. Subpart D), TRUST, LAANC, waivers, COA / public-aircraft, AIM
  Ch. 11. UNREAD list (incl. Advisory Circular PDFs and the
  post-2024-amendment consolidated § 44809 text) — UNREAD items become
  **titled placeholders in the app, never summarized from guesswork**.
- `states.md` — a 13-category matrix for all 50 states; North Carolina
  at full depth. It caught that NC's knowledge-test and permit
  sections (§§ 63-95/96) were **repealed Dec 1, 2024** (S.L. 2024-15)
  even though the legislature's site still prints them — repealed text
  is never presented as current law. FL's drone statute is § 934.50.
  The other 46 states are ingest-plan depth.
- `dow.md` — 22 entries: DoD issuances, UAS Groups 1–5 definitions,
  the approval-chain summary, and per-service stacks. DAFMAN 11-501
  was read in full. **Space Force has no standalone UAS publications**
  — it is governed under Department of the Air Force pubs, so its app
  button resolves to the Air Force stack. Navy is the thinnest stack
  after Space Force; model-specific NATOPS stay restricted
  placeholders.

Supporting inventories from this side chat's own agents
(`~/workspace/research_notes/drone-regs-{faa,states,dow}-2026-10-23.md`)
feed the same plan. Anything any map marks restricted or UNREAD stays
a titled placeholder — that rule is hard.

**Authorities home (Browse hub, standing).** SHEPHERD card on top,
then one button per authority: **FAA Regulations** (live → Title 14),
**Federal — All Titles** (live), **State Regulations** (map landed —
status page carrying the NC repeal caution), **Department of War**
(map landed), and under it the individual services: **Air Force**
(AFPD 11-5 → DAFMAN 11-501/11-502 → AFMAN 11-202 Vol 3), **Army**
(AR 95-1 + TC series), **Navy** (OPNAVINST 3710.7 + NAVAIRINST
13034.1), **Marine Corps** (NAVMC 3500.107 + MARADMINs), and **Space
Force → Air Force stack** (labelled as resolving to the DAF stack, per
the map's verified finding). Every button opens the existing
Browse/Reader/plain-English flow via the same `RegulationSource`
adapter pattern — no UI fork; today the not-yet-ingested authorities
open status pages naming their governing publications and approval
chains, and each becomes a live corpus by adding an adapter.

**The Shepherd fusion flow (Draco's order, hard spec).**

1. **What group drone?** DoD UAS Groups 1–5, each with a plain-English
   helper (weight / altitude / speed class; highest-attribute rule).
2. **Live munitions?** Yes/no.
3. **Location** — three ways: *use my current location* (GPS, checked
   on-device against the bundled grid; the fix never leaves the
   device), *place name* (city/state or address, resolved via
   OpenStreetMap Nominatim — only the place name leaves the device —
   then checked against the same on-device grid), or *coordinates*
   (lat/lon typed for pre-planning). Manual entry exists precisely so
   pre-planning doesn't require being there.

The fused summary answers for that aircraft at that place, layer by
layer — federal airspace/LAANC ceiling from the grid bundle, the
state layer for the state the location falls in, DoW/service rules
when applicable — each section labelled REAL DATA / FRAMEWORK /
RESEARCHING until its corpus lands, each claim cited to its source
regulation and openable in the Reader, plain English first with the
original alongside.

**Guardrails (hard requirements).** The Shepherd summary is
regulatory guidance — **not a flight authorization and not legal
advice** — and says so. If live munitions = yes, the summary names the
governing DoW/service publications and approval authorities (from
`dow.md`) and flags that armed operations sit under DoW/service
authority and range/airspace approval chains; it offers **no
operational or employment guidance, ever**. "Don't know" stays a
check outcome, never a silent pass. Public sources only; CAC-gated
material is a link out or a titled placeholder, never copied in.

**Roadmap fold-in.** The phased roadmap in §1 stands; this structure
rides on it: FAA companion docs (Phase 1b) ingest from `faa.md`, the
DoW ingest (Phase 3) from `dow.md` service-by-service in map order
(Air Force first — most completely public), and the state matrix
(Phase 4 — all 50, batch-wise, §15) from `states.md` + the five
batch files. Shepherd's RESEARCHING sections flip to REAL DATA per
layer — and, for states, per state — as each lands.

**Wiring status (2026-10-23, maps landed).** The three maps are now
wired as the corpus plan in the app itself, not just in this design:
the Browse-hub authority/service status pages carry the maps'
findings (governing publications, approval chains, the SF→DAF
resolution, the NC repeal caution), and Shepherd's fusion sections
consume the maps as inputs — the live-munitions section names the
governing publications and approval authorities from `dow.md`
(public-aircraft status + FAA COA path; DAFMAN 11-501 approval chain;
AR 95-1; OPNAVINST 3710.7 / NAVAIRINST 13034.1; NAVMC 3500.107), and
the state/DoW sections cite the landed maps while staying labelled
RESEARCHING until the corpora are actually ingested. Two ingest rules
from the maps are binding: **§ 44809's current text is pulled at build
time** (the post-2024-amendment consolidated text is on `faa.md`'s
UNREAD list), and the airspace layer must always carry the explicit
TFR/NOTAM check step — there is no verified machine-readable public
TFR source, and the grid sections already say so.

## 13. Your Documents — user-loaded official documentation (2026-10-23)

Draco's ask: "build in a way for people to load in official
documentation in case we miss something." We will miss things — this
is the pressure valve, and it uses the architecture's own pattern.

- **What it is.** A personal document library (Browse hub → **Your
  Documents**). The user adds an official document with title,
  citation, issuing authority (FAA / federal / state / each DoW
  service / other), an optional official link, and the text itself —
  pasted, or imported from a .txt/.md file. A link-only entry (no
  text) is allowed and behaves honestly: it opens the official source
  externally, and inside the app it explains itself rather than
  pretending to hold the text.
- **How it plugs in.** Added documents are a corpus:
  `UserDocsSource implements RegulationSource` (id `userdocs`),
  appended to the source registry in `main.dart`. They are searched
  from the Search tab (user hits merged first — if you added it, it's
  probably what you want), fetched through `fetchSectionFor`, and
  read in the standard Reader with provenance stamped "Added by you ·
  <authority> · <date>". Bookmarks work on them unchanged. No UI fork
  anywhere — the adapter pattern doing exactly what it was built for.
- **Storage & privacy.** On-device only (`UserDocsStore`,
  SharedPreferences, same pattern as bookmarks): no account, no
  cloud, nothing uploaded. The add form says so, and also says the
  quiet part out loud: *only add documents you have the right to keep;
  never add classified or CAC-gated material.*
- **Honesty limits.** Plain-English explanations are **not** written
  for user documents — the Reader's plain view returns the standard
  "not written yet" guidance, and the form says so up front; the
  user's text is the original, which is what counts. A 1M-character
  per-document cap refuses oversize adds with an explanation (split it
  or add the link) — never a silent truncation.
- **Deliberately not in v1.** PDF text extraction on-device: the add
  form states it plainly and offers paste-or-link instead. PDF ingest
  belongs to the central server-side pipeline in the PWA plan (§9 /
  main-chat direction), where extraction can be done once, well, for
  everyone — when that lands, PDFs join this same library shape.

## 14. Research function (added 2026-10-23, Draco's ask)

"Have a research function built into the app for folks doing
research… helpful and makes sense to the average person." Research is
the **free-form sibling of the Shepherd button**: Shepherd is the
structured flow (group → munitions → location) for the fly/don't-fly
question; Research takes open-ended questions across all corpora.

**UX shape.** A Research tab: one question field, example-question
chips, and the brief below. Saved briefs list under the answer.
Language rule: no legalese without a one-line plain definition inline;
~8th-grade reading level, same standard as the Plain English view.

**Brief anatomy (fixed — every brief has all four parts).**

1. **Short answer** — plain English first, always.
2. **Why** — the 2–4 regulations that actually decide it. Each is
   cited; a citation is tappable into the Reader **only when the app
   can really open it** (a live eCFR section/part today). Statutes,
   state laws, and DoW publications not yet ingested are cited by
   label with the citation object marked non-openable — named
   honestly, never dressed up as readable text.
3. **What we don't know** — the gaps: corpora not yet covered,
   restricted/UNREAD publications, anything the sources didn't
   settle. A brief never papers over a gap with a confident sentence.
4. **Dig deeper** — follow-up questions (tappable, they re-ask) and
   the path onward.

Plus the standing disclaimer on every brief (a compile-time constant
on `ResearchBrief`, same pattern as the simplification disclaimer):
guidance and explanation — not legal advice; the original text is
what legally counts. **Save/export**: briefs save to
`SavedBriefsStore` — the Bookmarks idea extended to briefs, not a
forked system; a saved brief reopens in place.

**Architecture.** `ResearchService` behind an interface (the
RegulationSource/SimplificationService pattern), wired as
`AppServices.research`. **Stub first**: `StubResearchService` —
hand-written briefs over the material already verified by the
research maps and the fly-checker: over-people/parades (107.39 +
Subpart D + § 44809), NC permits & roof work (the Dec 2024 repeal,
§§ 15A-300.1/.2, 107.61), what changed in Part 107 (Subpart D, night,
Part 89, TRUST; the § 44809 post-2024 text flagged as a gap, never
quoted), night flight (107.29/107.31), registration (Part 48),
LAANC/controlled airspace (107.41/107.51 + the in-app grid; TFR gap
named), military/government ops (public aircraft + COA + service
stacks from `dow.md`), waivers (107.200/107.205). Matching is
keyword-scored; anything outside the stub's range returns a
**not-covered brief** — no answer, the gaps named, covered topics
offered as follow-ups. The stub never fabricates.

**The engine question is now decided** (§16, 2026-10-23): the
designated implementation is the hunter — a small RAG model over
the centrally ingested corpus, answering only from retrieved,
cited passages. The stub remains the running implementation (and
the curated fallback layer) until the backend stands; the swap
happens behind this interface with no UI changes.

## 15. State matrix — all 50, batch-wise (landed 2026-10-23)

Draco: "I would like it to be available in all states." The state
phase is all 50 from the start, consumed **batch-wise**: five
research batches (`states-batch-1..5.md`, ten states each) plus the
NC exemplar (`states.md`) in
`~/workspace/research_notes/plainregs-drone-regs/`, each state scored
on the same 13 categories against its official code host.

**Pipeline.** `tool/build_states_matrix.py` converts the research
notes into `assets/states_matrix.json` (~320 KB). It attributes each
13-row matrix table to its state (header code, else nearest
state-naming heading — longest names win, the Virginia/West Virginia
trap), derives per-state status from the batches' own completeness
accounting, and **fails loudly** unless all 50 states convert with
13 categories each. Re-run it whenever a batch is corrected or
re-verified; the app picks the data up with no code changes — that
is the per-state flip mechanism.

**Status model (the verification discipline, in data).**

- `verified` — read on the official host / full official text.
- `partial` — verified core with flagged gaps; the batch's caveat
  text ships with the state and is displayed with it.
- `unverified` — research exists but could not be verified on the
  official host. Shipped as RESEARCHING with **no categories at
  all** — no mirror-provisional values, ever. Indiana was the case
  (iga.in.gov is JS-rendered; fetchers got empty shells) until a
  live-browser pass read the 2026 Indiana Code in full and verified
  it (addendum in `states-in-verification.md`); the status remains
  in the model for any future state that fails verification.
- **A verified absence is real data.** A state scored as having no
  drone-specific provision is shown as exactly that — "no state
  drone law found on top of the federal rules — verified [date]" —
  which is useful, and different from RESEARCHING in kind, not just
  degree. (In the 2026-10-23 data no state is a pure sweep across
  categories 1–9 — nearly every state has at least a correctional,
  parks, or law-enforcement provision — so the flag currently fires
  for none; the mechanism stands ready.)

**Verification dates are part of the data.** Every state carries
its `verifiedDate`, surfaced in the States list chip, the state
detail header, and Shepherd's state section. State law is exactly
where the NC repeal lesson applies (§ 63-95/96, repealed while still
printed), so the date is never decoration.

**Surfaces.** Browse → **State Regulations** opens the full matrix:
searchable 50-state list with status chips, per-state detail with
all 13 categories (headline, plain detail, citation basis, research
note). **Shepherd** consumes the same data: when the location is a
place name naming a state, the state section flips to REAL DATA with
that state's substantive categories and verified date (armed runs
get it framed as local-awareness context — state civil law doesn't
govern federal military ops); an unverified state flips the section
to a named RESEARCHING with its caveat; raw coordinates (no state
name) get the pointer section explaining the place-name path.

**Standing as of 2026-10-23:** all 50 states carry data — **20
verified, 30 partial, 0 unverified.** Indiana closed last: § 35-33-5-9
confirmed SHORT FORM on official text (warrant required; exceptions
narrow — the pre-2019 (A)–(H) list is not current law), and one
genuinely new item entered the matrix as **contingent authority,
not active law**: IC Title 10 Article 22 (P.L.72-2026), a state
counter-UAS article that activates only if a federal law authorizes
state/local counter-UAS *and* the governor publishes notice.
Tennessee remains summary-grade by source type (TCA is
LexisNexis-walled; its scores rest on official legislative
documents). Next state work: periodic re-verification as
legislatures amend (the matrix carries 2026-effective changes the
batches caught), and — later — full statute-text adapters per
state on top of the matrix.

## 16. Architecture — site-first PWA, central ingest, the hunter

**Decided 2026-10-23 (Draco, main chat).** This section resolves the
form-factor and engine questions and is the plan of record. It is
sequenced so nothing in flight breaks: the states matrix (§15) and
Shepherd mode keep working against the current skeleton, and every
swap lands behind the existing interfaces.

### 16.1 Site-first: one PWA, every device

PlainRegs becomes a website built as an **installable PWA** — one
codebase serving iPhone (Safari → Add to Home Screen), Android, and
desktop, with no app-store gate. Draco's reasoning, recorded: an app
alone locks out iOS. The existing Flutter front end already builds
for web and **stays as the front end**; native wrappers are a later
option from the same base, not the plan of record. (Remaining PWA
work when the backend stands: installability polish — manifest,
icons, service-worker caching of the app shell and offline assets.)

### 16.2 Corpus ingested centrally

All source documents — eCFR, FAA publications, the 50-state codes
(as the matrix batches land), public DoW publications — are
**ingested server-side into a searchable index**. Why central, in
Draco's framing and on the merits:

- The full corpus is far too big to ship to a phone.
- A repeal or amendment (the NC lesson: §§ 63-95/96 repealed while
  still printed) propagates to every user the moment the index
  refreshes — no app update, no stale on-device law.
- Devices stay light; refresh cycles live in one place.

**The ingestion pipeline is a first-class component**: fetch →
parse → chunk into passages with full citation metadata (corpus,
title/part/section, source URL, retrieval date, verification
status) → index → **refresh on a per-source cadence with
change/repeal detection** (diff against the previous ingest; a
changed or vanished section flags its simplifications and briefs
for regeneration and review). Cadences: eCFR daily; FAA pubs on
publication/change; state codes per the matrix re-verification
cadence; the LAANC facility maps keep their own 56-day cycle
(on-device bundle refresh, §8.1). The research verification
discipline carries over unchanged: UNREAD/restricted/CAC-gated
material is never ingested — titled placeholders and links only.

### 16.3 The hunter — a small AI over the corpus (RAG, not a chatbot)

A **small model** does query understanding, retrieval, and
reranking over the indexed passages, and drafts plain-English
briefs and simplifications **only from retrieved passages — every
claim cited to its passage**. It powers both the Research function
(§14) and the SimplificationService (§4). Hard rule, carried over
from the stubs and non-negotiable: **the hunter answers from the
corpus or says it doesn't know.** No answering from model memory;
an uncovered question returns the same honest not-covered shape
the stub returns today, with the gaps computed from actual corpus
coverage. The hand-written stubs stay as the fallback/curated
layer until the backend stands (and as the quality bar after).

**Escalation tier:** a larger cloud model is an optional top tier
for hard simplifications (Draco's first instinct — kept, as the
escalation, not the foundation). Escalated output follows the same
rules: drafted from retrieved passages, fully cited, same
disclaimers.

### 16.4 On-device keeps the offline story — and its honest trade-off

Stays local: the **LAANC grid bundle** (offline airspace answers in
the field), **bookmarks**, **cached briefs and sections**, and the
user's own documents (§13 — private by design; server ingest is
for public corpora). The trade-off, stated plainly: **Research and
fresh simplifications need connectivity**; offline means grid +
cached material only. No pretending otherwise in the UI.

**Operational note (open item, not hidden):** backend hosting and
ops cost is real but small (ingest jobs, an index, one small-model
service). Host choice, refresh monitoring, and cost ownership are
open operational items for when the backend build starts.

### 16.5 Interfaces → backend endpoints

The existing Dart interfaces map to the backend one-for-one — the
front end swaps implementations, not shapes:

| Front-end interface (today) | Backend endpoint (plan) |
|---|---|
| `RegulationSource.search()` | `GET /v1/search?q=&corpus=` |
| `RegulationSource.fetchTitles()` | `GET /v1/titles` |
| `RegulationSource.browseStructure()` | `GET /v1/titles/{n}/structure` |
| `RegulationSource.fetchSection()` | `GET /v1/sections/{corpus}/{citation}` |
| `SimplificationService.simplify()` | `POST /v1/simplify {ref}` → `{plainText, citations[], tier}` |
| `ResearchService.ask()` | `POST /v1/research {question}` → the §14 brief anatomy as JSON |
| `AirspaceService` | stays on-device (offline grid, §8.1) |
| `UserDocsSource` | stays on-device (§13) |

**Migration path:** stubs remain the wired implementations until
the backend stands; then `HunterSimplificationService` and
`HunterResearchService` (and an index-backed `RegulationSource`)
replace them in `main.dart` — the same one-line registry swap the
corpus adapters already use. The current skeleton keeps working at
every step.
