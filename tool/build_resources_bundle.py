#!/usr/bin/env python3
"""Build the Resources bundle for Terminator by Shepherd from Draco's
scheduled-research-source catalogue PDF.

Input : All_Scheduled_Research_Sources_2026-10-23__1.pdf (3,529
        deduplicated sources: the original 3,345 plus 184 review
        additions from the Source_Gap_Review_2026-10-23).
Output: assets/resources.json + assets/resources_manifest.json

The catalogue is structured text: sections headed "<Platform>" /
"<Collection>" followed by "N unique entries", then entries of the form

    SRC-0001 @ab3army
    https://t.me/ab3army
    Tags: EW; RAS; Russia; UAS; UGV; Ukraine
    <description, possibly wrapped>
    Reports: DOC-HUNT; RU
    Current task source | P050 line 203
    <optional trailing note>

This script parses that structure, reconciles every section count, the
per-platform totals and the grand total against the catalogue's own
summary table, and fails loudly if anything does not reconcile — a
partial or misaligned parse must never ship silently.

Re-run when Draco provides an updated catalogue PDF.
"""
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

PDF = Path.home() / "workspace/user/files/All_Scheduled_Research_Sources_2026-10-23__1.pdf"
ROOT = Path(__file__).resolve().parent.parent
OUT_JSON = ROOT / "assets/resources.json"
OUT_MANIFEST = ROOT / "assets/resources_manifest.json"

# Platform totals exactly as printed in the catalogue's own summary table.
EXPECTED_PLATFORMS = {
    "Telegram": 110, "Reddit": 66, "X": 127, "LinkedIn": 388,
    "YouTube": 138, "Facebook": 54, "Instagram": 16, "Threads": 3,
    "GitHub": 9, "Website": 2609, "Substack": 6, "Bluesky": 3,
}
EXPECTED_TOTAL = 3529

# Section header -> (platform, collection). Website sections keep their
# catalogue header as a collection; social sections are their platform.
HEADER_MAP = {
    "Telegram": ("Telegram", None),
    "Reddit": ("Reddit", None),
    "X": ("X", None),
    "LinkedIn": ("LinkedIn", None),
    "YouTube": ("YouTube", None),
    "Facebook": ("Facebook", None),
    "Instagram": ("Instagram", None),
    "Threads": ("Threads", None),
    "Code repositories": ("GitHub", None),
    "News, regional reporting and other websites":
        ("Website", "News & media"),
    "Research, analysis and reference":
        ("Website", "Research & reference"),
    "Robotics, technology and industry":
        ("Website", "Robotics, tech & industry"),
    "Government, military and public authorities":
        ("Website", "Government & military"),
    "Directories, data and discovery tools":
        ("Website", "Directories & data tools"),
    # Review-addition sections (2026-10-23 updated catalogue): the new
    # sources are grouped under fine-grained "Websites: …" headers,
    # plus standalone GitHub and Bluesky sections.
    "GitHub": ("GitHub", None),
    "Bluesky": ("Bluesky", None),
    "Websites: Think tanks and strategic analysis":
        ("Website", "Think tanks & strategic analysis"),
    "Websites: Business finance trade and economics":
        ("Website", "Business, finance & economics"),
    "Websites: Research and reference":
        ("Website", "Research & reference"),
    "Websites: Databases / Repositories":
        ("Website", "Databases & repositories"),
    "Websites: Discovery directories and collection tools":
        ("Website", "Discovery directories & tools"),
    "Websites: Government policy science and public data":
        ("Website", "Government policy & public data"),
    "Websites: Military and defense reporting":
        ("Website", "Military & defense reporting"),
    "Websites: Official international defense":
        ("Website", "Official international defense"),
    "Websites: Ukraine Russia and Eurasia":
        ("Website", "Ukraine, Russia & Eurasia"),
    "Websites: Middle East and North Africa news":
        ("Website", "Middle East & North Africa news"),
    "Websites: Investigations verification and humanitarian":
        ("Website", "Investigations & humanitarian"),
    "Websites: Europe news":
        ("Website", "Europe news"),
    "Websites: U.S. local and state reporting":
        ("Website", "U.S. local & state reporting"),
    "Websites: Space cyber and technology":
        ("Website", "Space, cyber & technology"),
    "Websites: Africa news":
        ("Website", "Africa news"),
    "Websites: Asia news":
        ("Website", "Asia news"),
    "Websites: UAS robotics and aviation":
        ("Website", "UAS, robotics & aviation"),
    "Websites: Official U.S. military":
        ("Website", "Official U.S. military"),
}

FURNITURE = (
    "RESEARCH SOURCE INVENTORY",
    "Source inclusion and tags describe recovered records",
)
ENTRY_RE = re.compile(r"^SRC-(\d{4})\s*(.*)$")
COUNT_RE = re.compile(r"^(\d+) unique entries$")
KIND_RE = re.compile(
    r"^(Current task source|Historical research / discovery|"
    r"Directory / registered source|Related research|"
    r"Review addition)\s*\|\s*(.*)$")


def extract_text(pdf: Path) -> list[str]:
    raw = subprocess.run(
        ["pdftotext", "-raw", str(pdf), "-"],
        capture_output=True, text=True, check=True).stdout
    lines = []
    for ln in raw.splitlines():
        ln = ln.replace("\f", "").rstrip()
        if any(ln.startswith(f) for f in FURNITURE):
            continue
        lines.append(ln)
    return lines


def join_wrapped(parts: list[str]) -> str:
    return re.sub(r"\s+", " ", " ".join(p.strip() for p in parts)).strip()


def parse(lines: list[str]) -> list[dict]:
    entries: list[dict] = []
    platform = collection = None
    section_expected = None
    section_seen = 0
    header_buf: list[str] = []
    i = 0
    n = len(lines)

    def flush_section():
        if section_expected is not None and section_seen != section_expected:
            raise SystemExit(
                f"Section count mismatch before line {i}: expected "
                f"{section_expected}, parsed {section_seen}")

    while i < n:
        line = lines[i]
        m = COUNT_RE.match(line.strip())
        if m:
            flush_section()
            header = None
            for k in (1, 2, 3):
                cand = join_wrapped(header_buf[-k:])
                if cand in HEADER_MAP:
                    header = cand
                    break
            if header is None:
                raise SystemExit(
                    f"Unknown section header near: {header_buf[-3:]!r}")
            platform, collection = HEADER_MAP[header]
            section_expected = int(m.group(1))
            section_seen = 0
            header_buf = []
            i += 1
            continue
        m = ENTRY_RE.match(line)
        if m:
            if platform is None:
                raise SystemExit(f"Entry before any section: {line!r}")
            entry, i = parse_entry(lines, i, m)
            entry["platform"] = platform
            if collection:
                entry["collection"] = collection
            entries.append(entry)
            section_seen += 1
            header_buf = []
            continue
        if line.strip():
            header_buf.append(line)
        i += 1
    flush_section()
    return entries


def parse_entry(lines: list[str], i: int, m: re.Match) -> tuple[dict, int]:
    n = len(lines)
    src_num = int(m.group(1))
    name_parts = [m.group(2)]
    i += 1
    # Name may wrap; it ends at the URL line, Tags:, or Reports:.
    while i < n:
        s = lines[i].strip()
        if s.startswith("http") or s.startswith("Tags:") or \
                s.startswith("Reports:") or ENTRY_RE.match(lines[i]):
            break
        if s:
            name_parts.append(s)
        i += 1
    url = None
    if i < n and lines[i].strip().startswith("http"):
        url_parts = [lines[i].strip()]
        i += 1
        # Long URLs wrap mid-token across lines. A continuation line has
        # no spaces and is not a field line; join without a space (a
        # hyphen at a wrap point belongs to the URL).
        while i < n:
            s = lines[i].strip()
            if not s or " " in s or s.startswith("Tags:") or \
                    s.startswith("Reports:") or ENTRY_RE.match(lines[i]):
                break
            url_parts.append(s)
            i += 1
        url = "".join(url_parts)
    tags: list[str] = []
    if i < n and lines[i].strip().startswith("Tags:"):
        tag_text = lines[i].strip()[len("Tags:"):]
        i += 1
        # A wrapped tag list continues until the description's first line
        # is indistinguishable; tags never contain lowercase sentence text,
        # so stop when a line ends with '.' or starts a known field.
        tags = [t.strip() for t in tag_text.split(";") if t.strip()]
    desc_parts: list[str] = []
    while i < n:
        s = lines[i].strip()
        if s.startswith("Reports:") or ENTRY_RE.match(lines[i]):
            break
        if s:
            desc_parts.append(s)
        i += 1
    reports: list[str] = []
    kind = origin = None
    if i < n and lines[i].strip().startswith("Reports:"):
        rep_parts = [lines[i].strip()[len("Reports:"):]]
        i += 1
        while i < n:
            s = lines[i].strip()
            km = KIND_RE.match(s)
            if km:
                kind, origin = km.group(1), km.group(2).strip()
                i += 1
                break
            if ENTRY_RE.match(lines[i]) or COUNT_RE.match(s):
                break
            if s:
                rep_parts.append(s)
            i += 1
        reports = [r.strip() for r in join_wrapped(rep_parts).split(";")
                   if r.strip()]
    note_parts: list[str] = []
    while i < n:
        s = lines[i].strip()
        if ENTRY_RE.match(lines[i]) or COUNT_RE.match(s):
            break
        # Section headers precede a count line; stop accumulating if the
        # upcoming lines form one (handled by peeking: a note never
        # contains "unique entries").
        if s:
            note_parts.append(s)
        i += 1
        # If the buffered tail is actually a section header, rewind so the
        # main loop can consume it: detect by looking ahead for a count.
        j = i
        while j < n and not lines[j].strip():
            j += 1
        if j < n and COUNT_RE.match(lines[j].strip()) and note_parts:
            # The note buffer holds header lines, not a note.
            i -= len(note_parts)
            note_parts = []
            break
    name = join_wrapped(name_parts)
    if url is None:
        # 30 Website entries print no URL line; the entry name carries
        # the domain: "Maris-Tech maris-tech.com (open saved source
        # link)". Recover the URL mechanically from that printed domain.
        m2 = re.match(r"^(.*?)\s+(\S+\.\S+)\s+\(open saved source link\)$",
                      name)
        if m2:
            name, url = m2.group(1), "https://" + m2.group(2)
    entry = {
        "id": f"SRC-{src_num:04d}",
        "name": name,
        "tags": tags,
        "reports": reports,
        "description": join_wrapped(desc_parts),
    }
    if url:
        entry["url"] = url
    if kind:
        entry["kind"] = kind
    if origin:
        entry["origin"] = origin
    note = join_wrapped(note_parts)
    if note:
        entry["note"] = note
    return entry, i


def main() -> None:
    if not PDF.exists():
        raise SystemExit(f"Catalogue PDF not found: {PDF}")
    entries = parse(extract_text(PDF))

    # The catalogue's summary table counts Substack publications as
    # their own platform (6), but they are printed inside Website
    # sections. Reclassify by URL host so the reconciliation below
    # matches the catalogue's own totals.
    for e in entries:
        url = e.get("url", "")
        if "substack.com" in url:
            e["platform"] = "Substack"

    by_platform = Counter(e["platform"] for e in entries)
    if dict(by_platform) != EXPECTED_PLATFORMS:
        raise SystemExit(
            f"Platform totals mismatch:\n parsed={dict(by_platform)}\n "
            f"expected={EXPECTED_PLATFORMS}")
    if len(entries) != EXPECTED_TOTAL:
        raise SystemExit(f"Total mismatch: {len(entries)} != {EXPECTED_TOTAL}")
    ids = [e["id"] for e in entries]
    if len(set(ids)) != len(ids):
        raise SystemExit("Duplicate SRC ids parsed")

    # Draco (2026-10-23): remove all Telegram. Excluded AFTER the
    # reconciliation above, so the counts still prove the parse
    # against the catalogue's own table; the shipped bundle simply
    # omits the platform.
    excluded = [e for e in entries if e["platform"] == "Telegram"]
    entries = [e for e in entries if e["platform"] != "Telegram"]
    by_platform = Counter(e["platform"] for e in entries)
    print(f"excluded {len(excluded)} Telegram entries per Draco; "
          f"shipping {len(entries)}")

    tag_counts = Counter(t for e in entries for t in e["tags"])
    report_counts = Counter(r for e in entries for r in e["reports"])
    stats = {
        "entries": len(entries),
        "with_url": sum(1 for e in entries if "url" in e),
        "with_tags": sum(1 for e in entries if e["tags"]),
        "with_reports": sum(1 for e in entries if e["reports"]),
        "with_kind": sum(1 for e in entries if "kind" in e),
        "no_url_names": [e["name"] for e in entries if "url" not in e][:10],
    }
    payload = {
        "catalogue": "All scheduled research sources",
        "catalogueDate": "2026-10-23",
        "note": ("Recovered inventory of research sources. Inclusion and "
                 "tags describe recovered records; live access was not "
                 "retested. Telegram sources are excluded."),
        "entries": entries,
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False,
                                   separators=(",", ":")))
    manifest = {
        "catalogue": payload["catalogue"],
        "catalogueDate": payload["catalogueDate"],
        "entries": len(entries),
        "byPlatform": dict(by_platform),
        "topTags": tag_counts.most_common(40),
        "topReports": report_counts.most_common(40),
        "parseStats": stats,
    }
    OUT_MANIFEST.write_text(json.dumps(manifest, indent=1,
                                       ensure_ascii=False))
    print(json.dumps(stats, indent=1))
    print("top tags:", tag_counts.most_common(12))
    print(f"wrote {OUT_JSON} ({OUT_JSON.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
