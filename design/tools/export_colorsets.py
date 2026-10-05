#!/usr/bin/env python3
"""Writes NookUI's color sets from the token tables in docs/03_Design_System.md §2.

03 is the only source of color values: edit the tables there, then run this script.
Typing ~50 color sets × 4 appearances by hand would drift from the doc.

Outputs (both replaced on every run):
- Packages/NookUI/Sources/NookUI/Resources/Colors.xcassets: neutrals, semantic colors,
  Accent/<name>, OnAccent/<name>, Room/<name>Fill, Room/<name>Ink
- Nook/Resources/Assets.xcassets/LaunchBackground.colorset: the `canvas` token again,
  because the launch screen can't read package resources (L-01)

Usage: python3 design/tools/export_colorsets.py
"""
import json
import shutil
from pathlib import Path

from check_tokens import ROOT, load_tokens

CATALOG = ROOT / "Packages/NookUI/Sources/NookUI/Resources/Colors.xcassets"
APP_CATALOG = ROOT / "Nook/Resources/Assets.xcassets"
INFO = {"author": "xcode", "version": 1}
APPEARANCES = {
    "light": [],
    "dark": [{"appearance": "luminosity", "value": "dark"}],
    "hcLight": [{"appearance": "contrast", "value": "high"}],
    "hcDark": [{"appearance": "luminosity", "value": "dark"}, {"appearance": "contrast", "value": "high"}],
}


def color(hex_value):
    r, g, b = (hex_value[i:i + 2] for i in (1, 3, 5))
    components = {"red": f"0x{r}", "green": f"0x{g}", "blue": f"0x{b}", "alpha": "1.000"}
    return {"color-space": "srgb", "components": components}


def write_colorset(folder, name, by_mode):
    """by_mode maps light/dark/hcLight/hcDark to a hex value; missing HC modes are left out."""
    entries = []
    for mode, hex_value in by_mode.items():
        entry = {"color": color(hex_value), "idiom": "universal"}
        if APPEARANCES[mode]:
            entry["appearances"] = APPEARANCES[mode]
        entries.append(entry)
    path = folder / f"{name}.colorset"
    path.mkdir(parents=True)
    (path / "Contents.json").write_text(json.dumps({"colors": entries, "info": INFO}, indent=2) + "\n")


def write_namespace(folder):
    folder.mkdir(parents=True)
    contents = {"info": INFO, "properties": {"provides-namespace": True}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def camel(name):
    return name[0].lower() + name[1:]


def main():
    neutrals, accents, rooms, semantic, _ = load_tokens((ROOT / "docs/03_Design_System.md").read_text())

    shutil.rmtree(CATALOG, ignore_errors=True)
    CATALOG.mkdir(parents=True)
    (CATALOG / "Contents.json").write_text(json.dumps({"info": INFO}, indent=2) + "\n")

    for name, by_mode in {**neutrals, **semantic}.items():
        write_colorset(CATALOG, name, by_mode)

    for folder in ("Accent", "OnAccent", "Room"):
        write_namespace(CATALOG / folder)
    for name, by_mode in accents.items():
        write_colorset(CATALOG / "Accent", camel(name), {m: pair[0] for m, pair in by_mode.items()})
        write_colorset(CATALOG / "OnAccent", camel(name), {m: pair[1] for m, pair in by_mode.items()})
    for name, by_mode in rooms.items():
        # Room colors need no High Contrast variant (03 §2.3).
        write_colorset(CATALOG / "Room", f"{camel(name)}Fill", {m: pair[0] for m, pair in by_mode.items()})
        write_colorset(CATALOG / "Room", f"{camel(name)}Ink", {m: pair[1] for m, pair in by_mode.items()})

    launch = APP_CATALOG / "LaunchBackground.colorset"
    shutil.rmtree(launch, ignore_errors=True)
    write_colorset(APP_CATALOG, "LaunchBackground", {m: neutrals["canvas"][m] for m in ("light", "dark")})

    count = len(neutrals) + len(semantic) + 2 * len(accents) + 2 * len(rooms)
    print(f"Wrote {count} color sets to {CATALOG.relative_to(ROOT)} and LaunchBackground to the app catalog")


if __name__ == "__main__":
    main()
