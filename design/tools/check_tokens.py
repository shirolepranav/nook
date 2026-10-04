#!/usr/bin/env python3
"""Checks Nook's color tokens (docs/03_Design_System.md §2) and the mockups in design/screens.

1. Contrast: every text/background pair the design system allows meets WCAG
   (4.5:1 text, 7:1 for High Contrast text and accents, 3:1 for HC borders).
2. Mockups: every hex color in design/screens/*.html is a token or listed in §2.6.
Also prints off-grid spacing and off-scale font sizes as a to-do list (not a failure yet).

Usage: python3 design/tools/check_tokens.py   (exit code 1 on any failure)
"""
import glob
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEX = re.compile(r"#[0-9A-Fa-f]{6}\b")
MODES = ("light", "dark", "hcLight", "hcDark")


def luminance(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    channels = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def table_rows(doc, section):
    """Yields (name, [hex, ...]) for each table row under '### <section>' that holds hex values."""
    body = doc.split(f"### {section}", 1)[1].split("\n### ", 1)[0].split("\n## ", 1)[0]
    for line in body.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        hexes = [h.upper() for h in HEX.findall(line)]
        if line.startswith("|") and hexes:
            name = re.sub(r"[`*]|\(default\)", "", cells[0]).strip()
            yield name, hexes


def load_tokens(doc):
    neutrals = {n: dict(zip(MODES, h)) for n, h in table_rows(doc, "2.1")}
    accents = {}
    for name, h in table_rows(doc, "2.2"):
        on_dark = h[4]
        accents[name] = {m: (h[i], "#FFFFFF" if m in ("light", "hcLight") else on_dark)
                         for i, m in enumerate(MODES)}
    rooms = {n: {"light": (h[0], h[2]), "dark": (h[1], h[3])} for n, h in table_rows(doc, "2.3")}
    semantic = {n: dict(zip(MODES, h)) for n, h in table_rows(doc, "2.4")}
    mockup_only = {h[0] for _, h in table_rows(doc, "2.6")}
    return neutrals, accents, rooms, semantic, mockup_only


def check_contrast(neutrals, accents, rooms, semantic):
    failures = []

    def need(label, fg, bg, minimum):
        ratio = contrast(fg, bg)
        if ratio < minimum:
            failures.append(f"{label}: {fg} on {bg} is {ratio:.2f}:1, needs {minimum}:1")

    surfaces = ("canvas", "surface", "surfaceRaised", "surfaceSunken")
    for mode in MODES:
        hc = mode.startswith("hc")
        text_min = 7 if hc else 4.5
        for s in surfaces:
            bg = neutrals[s][mode]
            for t in ("textPrimary", "textSecondary"):
                need(f"{t} on {s} ({mode})", neutrals[t][mode], bg, text_min)
            for name, colors in {**accents, **semantic}.items():
                fg = colors[mode][0] if name in accents else colors[mode]
                need(f"{name} on {s} ({mode})", fg, bg, text_min)
            if hc:
                for b in ("hairline", "hairlineStrong"):
                    need(f"{b} on {s} ({mode})", neutrals[b][mode], bg, 3)
        for name, colors in accents.items():
            fill, on_accent = colors[mode]
            need(f"onAccent on {name} ({mode})", on_accent, fill, 4.5)
        base = "dark" if mode in ("dark", "hcDark") else "light"
        for name, colors in rooms.items():
            fill, ink = colors[base]
            need(f"{name} room ink ({base})", ink, fill, 4.5)
            for t in ("textPrimary", "textSecondary"):
                need(f"{t} on {name} room ({mode})", neutrals[t][mode], fill, 4.5)
    return failures


def check_mockups(allowed, mapped_to_tokens):
    unknown, todo = {}, {}
    grid, fonts = [], []
    type_scale = {"12", "13", "15", "17", "20", "22", "34"}
    for path in sorted(glob.glob(str(ROOT / "design/screens/*.html"))):
        name = Path(path).name
        html = Path(path).read_text()
        for h in {h.upper() for h in HEX.findall(html)}:
            if h not in allowed:
                unknown.setdefault(h, []).append(name)
            elif h in mapped_to_tokens:
                todo.setdefault(h, []).append(name)
        for prop, values in re.findall(r"(gap|padding|margin)\s*:\s*([0-9.\spx-]+)", html):
            grid += [f"{name} {prop} {v}px" for v in re.findall(r"(\d+(?:\.\d+)?)px", values)
                     if float(v) % 4]
        fonts += [f"{name} font-size {v}px" for v in re.findall(r"font-size:\s*(\d+)px", html)
                  if v not in type_scale]
    return unknown, todo, grid, fonts


def main():
    assert round(contrast("#000000", "#FFFFFF"), 1) == 21.0  # sanity check of the WCAG math

    doc = (ROOT / "docs/03_Design_System.md").read_text()
    neutrals, accents, rooms, semantic, mapping = load_tokens(doc)
    token_hexes = {h for section in ("2.1", "2.2", "2.3", "2.4") for _, row in table_rows(doc, section) for h in row}
    section_26 = doc.split("### 2.6", 1)[1].split("\n## ", 1)[0]
    mapped_to_tokens = {h for line in section_26.splitlines()
                        for h in HEX.findall(line)[:1] if "mockup only" not in line}

    failures = check_contrast(neutrals, accents, rooms, semantic)
    unknown, todo, grid, fonts = check_mockups(token_hexes | mapping, mapped_to_tokens)

    print(f"Contrast: {len(failures)} failure(s)")
    for f in failures:
        print("  FAIL", f)
    print(f"Mockup colors not in tokens or §2.6: {len(unknown)}")
    for h, files in sorted(unknown.items()):
        print("  FAIL", h, "in", ", ".join(sorted(set(files))))
    print(f"Mockup colors to swap for their token in the screen batches: {len(todo)}")
    for h, files in sorted(todo.items()):
        print("  TODO", h, "in", ", ".join(sorted(set(files))))
    # ponytail: spacing and type are reported, not enforced, until the P0 screen rebase lands.
    print(f"Off-grid spacing values (not a multiple of 4, D6): {len(grid)}")
    print(f"Font sizes outside the type scale (§3): {len(fonts)}")
    for line in sorted(set(grid + fonts)):
        print("  TODO", line)
    return 1 if failures or unknown else 0


if __name__ == "__main__":
    sys.exit(main())
