#!/usr/bin/env python3
"""
Sync team Person JSON-LD in static HTML from lib/config/content/about_content.dart.

The Dart `_team` list is the single source of truth for team members. This
script parses it, resolves `ExternalUrls.founderLinkedIn` from content.yaml,
and rewrites the Person nodes inside the @graph of each target HTML file.

jsonld_combined.json is a separately-enriched artifact (extra entities and
per-person properties not present in the pages), so it is NOT regenerated;
instead only the Dart-owned links are synced into its Person nodes: the
member's LinkedIn/website in sameAs and url, dropping a website (and any
@id minted from it) that the Dart source no longer declares.

Usage:
    python scripts/sync_team_jsonld.py            # sync HTML + combined JSON
    python scripts/sync_team_jsonld.py --check    # exit 1 if out of sync
"""

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

REPO_ROOT = Path(__file__).resolve().parent.parent
DART_SOURCE = REPO_ROOT / "lib" / "config" / "content" / "about_content.dart"
CONTENT_YAML = REPO_ROOT / "content.yaml"
TARGET_HTML = [
    REPO_ROOT / "web" / "index.html",
    REPO_ROOT / "web" / "blog" / "index.html",
]
SITE_URL = "https://integritystudio.ai"
ORG_REF = {"@id": f"{SITE_URL}/#organization"}
JSONLD_BLOCK_RE = re.compile(
    r'(<script type="application/ld\+json">\s*)(\{.*?\})(\s*</script>)',
    re.DOTALL,
)
TEAM_ENTRY_RE = re.compile(r"TeamMemberContent\(\s*(.*?)\s*\),", re.DOTALL)
# A Dart field whose value is one or more adjacent single-quoted literals,
# or a bare identifier expression (e.g. ExternalUrls.founderLinkedIn).
FIELD_RE = re.compile(
    r"(\w+):\s*((?:'(?:[^'\\]|\\.)*'\s*)+|[\w.]+)\s*(?:,|$)", re.DOTALL
)
STRING_LITERAL_RE = re.compile(r"'((?:[^'\\]|\\.)*)'")


def resolve_founder_linkedin() -> str:
    """Resolve urls.external.founder_linkedin from content.yaml."""
    match = re.search(
        r"^\s*founder_linkedin:\s*\"([^\"]+)\"", CONTENT_YAML.read_text(), re.MULTILINE
    )
    if not match:
        sys.exit("error: founder_linkedin not found in content.yaml")
    return match.group(1)


def parse_field_value(raw: str, founder_linkedin: str) -> str:
    """Join adjacent Dart string literals, or resolve a known constant."""
    literals = STRING_LITERAL_RE.findall(raw)
    if literals:
        return "".join(lit.replace("\\'", "'") for lit in literals)
    if raw.strip() == "ExternalUrls.founderLinkedIn":
        return founder_linkedin
    sys.exit(f"error: cannot resolve Dart expression: {raw.strip()}")


def parse_team() -> list[dict]:
    """Parse TeamMemberContent entries out of about_content.dart."""
    source = DART_SOURCE.read_text()
    team_block = source[source.index("_team = ["):]
    founder_linkedin = resolve_founder_linkedin()

    members = []
    for entry in TEAM_ENTRY_RE.finditer(team_block):
        fields = {
            name: parse_field_value(raw, founder_linkedin)
            for name, raw in FIELD_RE.findall(entry.group(1))
        }
        if "name" not in fields:
            continue
        members.append(fields)
    if not members:
        sys.exit(f"error: no TeamMemberContent entries parsed from {DART_SOURCE}")
    return members


def person_node(member: dict) -> dict:
    slug = re.sub(r"[^a-z0-9]+", "-", member["name"].lower()).strip("-")
    node = {
        "@type": "Person",
        "@id": f"{SITE_URL}/#person-{slug}",
        "name": member["name"],
        "jobTitle": member["role"],
        "description": member["bio"],
        "worksFor": ORG_REF,
    }
    same_as = [
        url
        for url in (member.get("linkedInUrl"), member.get("websiteUrl"))
        if url
    ]
    if same_as:
        node["sameAs"] = same_as
    if member.get("websiteUrl"):
        node["url"] = member["websiteUrl"]
    return node


def sync_html(html_path: Path, people: list[dict], check: bool) -> bool:
    """Replace Person nodes in the file's JSON-LD @graph. Returns True if changed."""
    original = html_path.read_text()
    match = JSONLD_BLOCK_RE.search(original)
    if not match:
        sys.exit(f"error: no JSON-LD block found in {html_path}")

    data = json.loads(match.group(2))
    graph = data.get("@graph")
    if graph is None:
        sys.exit(f"error: JSON-LD in {html_path} has no @graph")

    non_person = [node for node in graph if node.get("@type") != "Person"]
    insert_at = next(
        (i for i, node in enumerate(graph) if node.get("@type") == "Person"),
        len(graph),
    )
    data["@graph"] = non_person[:insert_at] + people + non_person[insert_at:]

    rendered = json.dumps(data, indent=2, ensure_ascii=False)
    updated = (
        original[: match.start()]
        + match.group(1)
        + rendered
        + match.group(3)
        + original[match.end():]
    )
    changed = updated != original
    if changed and not check:
        html_path.write_text(updated)
    return changed


COMBINED_JSON = REPO_ROOT / "jsonld_combined.json"


def sync_combined(members: list[dict], check: bool) -> bool:
    """Sync Dart-owned links into the enriched combined graph. True if changed."""
    original = COMBINED_JSON.read_text()
    data = json.loads(original)
    by_name = {m["name"]: m for m in members}
    dead_hosts = set()

    for node in data["@graph"]:
        if node.get("@type") != "Person" or node.get("name") not in by_name:
            continue
        member = by_name[node["name"]]
        website = member.get("websiteUrl")
        linkedin = member.get("linkedInUrl")

        same_as = node.get("sameAs", [])
        if not isinstance(same_as, list):
            same_as = [same_as]
        stale_website = node.get("url") if node.get("url") != website else None
        if stale_website:
            same_as = [u for u in same_as if u != stale_website]
            dead_hosts.add(urlparse(stale_website).hostname)
        for link in (linkedin, website):
            if link and link not in same_as:
                same_as.append(link)
        if same_as:
            node["sameAs"] = same_as
        if website:
            node["url"] = website
        else:
            node.pop("url", None)

    updated = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    # Repoint any @id minted from a dropped personal domain at the team page.
    for host in dead_hosts:
        pattern = re.compile(rf"https?://{re.escape(host)}/#person\b")
        for match in set(pattern.findall(updated)):
            node = next(n for n in data["@graph"] if n.get("@id") == match)
            slug = re.sub(r"[^a-z0-9]+", "-", node["name"].lower()).strip("-")
            updated = updated.replace(match, f"{SITE_URL}/team/{slug}#person")

    changed = updated != original
    if changed and not check:
        COMBINED_JSON.write_text(updated)
    return changed


def main() -> None:
    check = "--check" in sys.argv[1:]
    members = parse_team()
    people = [person_node(m) for m in members]

    changed = []
    for html_path in TARGET_HTML:
        if sync_html(html_path, people, check):
            changed.append(html_path.relative_to(REPO_ROOT))
    if sync_combined(members, check):
        changed.append(COMBINED_JSON.relative_to(REPO_ROOT))

    if check:
        if changed:
            print(f"out of sync with {DART_SOURCE.name}: {', '.join(map(str, changed))}")
            sys.exit(1)
        print("team JSON-LD in sync")
        return

    for path in changed:
        print(f"updated {path}")
    if not changed:
        print("already in sync")


if __name__ == "__main__":
    main()
