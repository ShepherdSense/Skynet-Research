#!/usr/bin/env python3
"""Build assets/states_matrix.json from the verified state research.

Sources (official-host research, 2026-10-23):
  ~/workspace/research_notes/plainregs-drone-regs/states.md        (NC)
  ~/workspace/research_notes/plainregs-drone-regs/states-batch-*.md

Discipline carried into the data:
- Per-state status from the batches' own completeness accounting:
  verified / partial (verified core, flagged gaps — caveat shipped) /
  unverified (Indiana: official host unopenable, ALL cells provisional
  from mirrors -> shipped as researching with NO categories, per the
  verification pass: "nothing may be published as verified").
- A state whose categories 1-9 all score as absence is flagged
  noDroneLawFound: a verified absence IS real data.
- Fails loudly on any state missing its 13-row matrix.

Run: python3 tool/build_states_matrix.py
"""

import json
import re
import sys
from pathlib import Path

NOTES = Path.home() / "workspace/research_notes/plainregs-drone-regs"
OUT = Path(__file__).resolve().parent.parent / "assets/states_matrix.json"
VERIFIED_DATE = "2026-10-23"

STATES = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
    "California": "CA", "Colorado": "CO", "Connecticut": "CT",
    "Delaware": "DE", "Florida": "FL", "Georgia": "GA", "Hawaii": "HI",
    "Idaho": "ID", "Illinois": "IL", "Indiana": "IN", "Iowa": "IA",
    "Kansas": "KS", "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME",
    "Maryland": "MD", "Massachusetts": "MA", "Michigan": "MI",
    "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO",
    "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
    "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM",
    "New York": "NY", "North Carolina": "NC", "North Dakota": "ND",
    "Ohio": "OH", "Oklahoma": "OK", "Oregon": "OR", "Pennsylvania": "PA",
    "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD",
    "Tennessee": "TN", "Texas": "TX", "Utah": "UT", "Vermont": "VT",
    "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
    "Wisconsin": "WI", "Wyoming": "WY",
}
CODE2NAME = {v: k for k, v in STATES.items()}

CATEGORIES = [
    "Privacy / surveillance", "Trespass / airspace",
    "Law-enforcement use", "Government operators",
    "Critical infrastructure", "Emergency scenes",
    "Takeoff / landing", "Local preemption",
    "State registration / permit", "Other conduct offenses",
    "Remedies & penalties", "Government data rules",
    "Exception breadth",
]

ABSENCE = re.compile(
    r"^(none|silent|no |—|–|-+$|not )", re.IGNORECASE)


def clean(text: str) -> str:
    text = text.replace("\\|", "|")
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = text.replace("`", "")
    return re.sub(r"\s+", " ", text).strip()


def headline_of(value: str) -> str:
    v = clean(value)
    for sep in (" — ", " – "):
        if sep in v:
            v = v.split(sep)[0]
            break
    if len(v) > 80:
        cut = re.split(r"[.;]", v)[0]
        if len(cut) >= 12:
            v = cut
    return v[:90].strip()


def split_row(line: str):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) > 4:  # stray pipes inside basis text
        cells = cells[:3] + [" | ".join(cells[3:])]
    return cells


def find_tables(lines):
    """Yield (header_index, rows) for each 13-category matrix table."""
    i = 0
    while i < len(lines):
        if re.match(r"\|\s*#\s*\|\s*Category\s*\|", lines[i]) and \
                "Controlled values" not in lines[i] and \
                "Question it answers" not in lines[i]:
            rows = []
            j = i + 1
            while j < len(lines):
                m = re.match(r"\|\s*(\d{1,2})\s*\|", lines[j])
                if m and 1 <= int(m.group(1)) <= 13:
                    rows.append((int(m.group(1)), split_row(lines[j])))
                    j += 1
                elif re.match(r"\|[\s\-|:]+\|", lines[j]):
                    j += 1  # separator line
                else:
                    break
            if len(rows) >= 10:
                yield i, lines[i], rows
            i = j
        else:
            i += 1


def state_for_table(lines, header_idx, header_line):
    cells = split_row(header_line)
    if len(cells) >= 3:
        m = re.search(r"\b([A-Z]{2})\s+value\b", cells[2])
        if m and m.group(1) in CODE2NAME:
            return CODE2NAME[m.group(1)]
        for name in STATES:
            if name.lower() in cells[2].lower():
                return name
    # fall back: nearest preceding heading naming exactly one state.
    # Longest names win: "Virginia" inside "West Virginia" is not a
    # separate match.
    for k in range(header_idx - 1, max(-1, header_idx - 200), -1):
        if lines[k].startswith("#"):
            found = [n for n in STATES
                     if re.search(rf"\b{re.escape(n)}\b", lines[k],
                                  re.IGNORECASE)]
            found = [n for n in found
                     if not any(n != m and n.lower() in m.lower()
                                for m in found)]
            if len(found) == 1:
                return found[0]
    return None


def completeness_map(lines):
    """Parse a batch's completeness summary table, when present."""
    out = {}
    for idx, line in enumerate(lines):
        m = re.match(r"\|\s*([A-Z][a-zA-Z ]+?)\s*\|\s*\*?\*?(Full|Partial)",
                     line)
        if m and m.group(1).strip() in STATES:
            cells = split_row(line)
            out[m.group(1).strip()] = (
                m.group(2).lower(),
                clean(cells[2]) if len(cells) > 2 else "",
            )
    return out


def region_status(lines, start, end):
    text = "\n".join(lines[start:end])
    m = re.search(r"Completeness:\s*\*?\*?\s*(FULL|PARTIAL)", text)
    if m:
        return m.group(1).lower()
    m = re.search(r"Research status:\*\*\s*(FULL|PARTIAL)", text)
    if m:
        return m.group(1).lower()
    return None


def main():
    results = {}   # name -> dict
    problems = []

    files = [("states.md", "exemplar")] + [
        (f"states-batch-{i}.md", f"batch {i}") for i in range(1, 6)]
    file_lines = {}
    heading_pos = {}   # name -> (file, index) best heading position
    for fname, _ in files:
        file_lines[fname] = (NOTES / fname).read_text().splitlines()
        for idx, line in enumerate(file_lines[fname]):
            if line.startswith("#"):
                for name in STATES:
                    if re.search(rf"\b{re.escape(name)}\b", line,
                                 re.IGNORECASE):
                        heading_pos.setdefault(name, (fname, idx))

    comp_all = {}
    for fname, _ in files:
        comp_all.update(completeness_map(file_lines[fname]))

    # Batch 5's summary is prose: all full except Tennessee (partial).
    for name in ["Texas", "Utah", "Vermont", "Virginia", "Washington",
                 "West Virginia", "Wisconsin", "Wyoming"]:
        comp_all.setdefault(name, ("full", ""))
    comp_all.setdefault(
        "Tennessee",
        ("partial",
         "Tennessee Code Annotated is published online only via "
         "LexisNexis; cells rest on capitol.tn.gov and tn.gov official "
         "documents (VERIFIED–OFFICIAL SUMMARY), with a short UNREAD "
         "list in the research file."))

    for fname, _tag in files:
        lines = file_lines[fname]
        for hidx, header, rows in find_tables(lines):
            name = state_for_table(lines, hidx, header)
            if name is None:
                problems.append(f"{fname} line {hidx+1}: table with no "
                                f"state attribution")
                continue
            if name in results:
                problems.append(f"duplicate matrix for {name} ({fname})")
                continue
            cats = []
            for num, cells in sorted(rows):
                if len(cells) < 4:
                    problems.append(f"{name}: row {num} has "
                                    f"{len(cells)} cells")
                    continue
                cats.append({
                    "n": num,
                    "name": CATEGORIES[num - 1],
                    "headline": headline_of(cells[2]),
                    "detail": clean(cells[2]),
                    "basis": clean(cells[3]),
                })
            # status: completeness map first, then region text
            status, caveat = None, ""
            if name in comp_all:
                level, caveat = comp_all[name]
                status = "verified" if level == "full" else "partial"
            if status is None:
                hfname, hpos = heading_pos.get(name, (fname, 0))
                lvl = region_status(file_lines[hfname], hpos, hidx) \
                    if hfname == fname else None
                status = {"full": "verified", "partial": "partial"}.get(
                    lvl or "", "partial")
            results[name] = {
                "name": name,
                "code": STATES[name],
                "status": status,
                "verifiedDate": VERIFIED_DATE,
                "caveat": caveat[:400],
                "categories": cats,
            }

    # NC is the hand-built exemplar: full depth, cells verified
    # against full text on ncleg.gov (states.md §2).
    if "North Carolina" in results:
        results["North Carolina"]["status"] = "verified"

    # Indiana: first pass could not read the JS-rendered official
    # code, so batch 2's cells are mirror-provisional (UNREAD, with
    # the pre-2019 Cat. 3/13 errors). The live-browser addendum in
    # states-in-verification.md verified Indiana on iga.in.gov
    # (2026 Indiana Code) — replace the parsed cells wholesale with
    # the verified record below (source: that addendum, 2026-10-23).
    if "Indiana" in results:
        v = "Verified on iga.in.gov (2026 Indiana Code), live-browser addendum 2026-10-23."
        cats = {
            1: ("image-capture offense",
                "Remote aerial voyeurism (IC 35-45-4-5(g)–(h)), remote "
                "aerial harassment (IC 35-45-10-6), sex-offender UAV "
                "offense (IC 35-42-4-12.5); UAV use is not a defense to "
                "invasion of privacy (IC 35-46-1-15.1(b)). A UAV counts "
                "as a “tracking device” (IC 35-31.5-2-337.6), pulling "
                "UAVs into IC 35-46-8.5-1.", v),
            2: ("silent",
                "No express or altitude-threshold airspace-trespass "
                "section found.", v),
            3: ("warrant required",
                "IC 35-33-5-9 — SHORT FORM confirmed on official text: "
                "a law-enforcement officer must obtain a search warrant "
                "to use a UAV on or over private property, or to search, "
                "surveil, or photograph private property or the persons, "
                "items, or structures on it, without the owner's "
                "consent; no warrant is needed where none would be "
                "required for a non-UAV search. The (A)–(H) exception "
                "list in older texts is pre-2019 law — not current.",
                v + " https://iga.in.gov/laws/2026/ic/titles/35#35-33-5-9"),
            4: ("none",
                "No permit, test, or approved-manufacturer list for "
                "non-LE government operators found.", v),
            5: ("correctional contraband only",
                "No standalone correctional overflight ban; contraband "
                "delivery by UAV is trafficking with an inmate — IC "
                "35-44.1-3-5(b) (Class A misdemeanor; Level 5 felony for "
                "drugs/intoxicants/weapons/phones) and IC 35-44.1-3-6(c). "
                "Critical-infrastructure OVERFLIGHT is a verified "
                "negative: IC 35-46-10 is a physical-entry scheme with "
                "no airspace language.", v),
            6: ("statute",
                "IC 35-44.1-4-10 — public-safety remote aerial "
                "interference (interfering with law enforcement, fire, "
                "EMS, or search-and-rescue performing official duties).",
                v),
            7: ("none found",
                "No state consent statute and no state-park ban "
                "(statute or rule) located in the verified pass.", v),
            8: ("none found",
                "Verified negative: no drone preemption provision, and "
                "no preemption language in any UAV section read.", v),
            9: ("none",
                "Verified negative: no registration scheme (whole-code "
                "“drone”/“unmanned” searches plus a Title 8 structure "
                "scan). IC 5-28-44 is a UAS test-site economic-"
                "development chapter, not registration.", v),
            10: ("offense list + contingent counter-UAS authority",
                 "Hunting: IC 14-22-6-16 bans knowingly using a UAV to "
                 "search, scout, or locate game as an aid to taking it "
                 "(14 days before through the season; DNR/government, "
                 "education/research, animal-care, and ag/nuisance "
                 "exemptions; Class C misdemeanor via IC 14-22-38-1). "
                 "CONTINGENT — NOT ACTIVE LAW: IC Title 10 Article 22 "
                 "(P.L.72-2026), “Counter-Unmanned Aircraft System "
                 "Authority,” covers high-risk sites (critical "
                 "infrastructure, correctional facilities, airports, "
                 "large events) with the state police as coordinating "
                 "agency — it applies ONLY if a federal law authorizing "
                 "state/local counter-UAS is enacted AND the governor "
                 "publishes notice (IC 10-22-1-1).", v),
            11: ("evidence exclusion + graded penalties",
                 "IC 35-33-5-10: material obtained in violation of "
                 "§ 35-33-5-9, and derivative evidence, is inadmissible "
                 "in administrative and judicial proceedings. The 2017 "
                 "offenses grade Class A misdemeanor to Level 6 felony "
                 "(priors/publishing); trafficking reaches Level 5.", v),
            12: ("none found",
                 "No retention- or disclosure-limit section for "
                 "government drone data located.", v),
            13: ("narrow",
                 "Consent plus general warrant-law incorporation only "
                 "(IC 35-33-5-9 short form). No enumerated lawful-use "
                 "list survives in current law.", v),
        }
        results["Indiana"]["status"] = "verified"
        results["Indiana"]["caveat"] = (
            "Verified on the official host (iga.in.gov, 2026 Indiana "
            "Code) in a live-browser pass, 2026-10-23 — the code is "
            "JS-rendered, which defeated text fetching in the first "
            "pass. One item is contingent, not active law: the IC "
            "10-22 counter-UAS article (see Other conduct offenses).")
        results["Indiana"]["categories"] = [
            {"n": n, "name": CATEGORIES[n - 1], "headline": h,
             "detail": d, "basis": b}
            for n, (h, d, b) in sorted(cats.items())
        ]

    missing = [n for n in STATES if n not in results]
    for name in missing:
        problems.append(f"missing state: {name}")
    for name, r in results.items():
        if r["status"] != "unverified" and len(r["categories"]) != 13:
            problems.append(
                f"{name}: {len(r['categories'])} categories (want 13)")

    if problems:
        print("PROBLEMS:", file=sys.stderr)
        for p in problems:
            print(" -", p, file=sys.stderr)
        # still write what we have? No — fail loudly per discipline.
        sys.exit(1)

    for r in results.values():
        if r["status"] == "unverified":
            r["noDroneLawFound"] = False
            continue
        first9 = [c for c in r["categories"] if c["n"] <= 9]
        r["noDroneLawFound"] = all(
            ABSENCE.match(c["headline"]) for c in first9)

    states = sorted(results.values(), key=lambda r: r["name"])
    doc = {
        "generated": VERIFIED_DATE,
        "source": "research_notes/plainregs-drone-regs/states*.md",
        "states": states,
    }
    OUT.write_text(json.dumps(doc, indent=1, ensure_ascii=False))
    counts = {}
    for s in states:
        counts[s["status"]] = counts.get(s["status"], 0) + 1
    print(f"states: {len(states)}  statuses: {counts}")
    print("noDroneLawFound:",
          [s['code'] for s in states if s['noDroneLawFound']])
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
