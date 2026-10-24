#!/usr/bin/env python3
"""Nook app icon layers (PRD §3): an arched nook with a shelf and a small plant. No lettering, so it survives a rename.

Writes 1024×1024 layer SVGs to design/icon/ for Icon Composer, plus a flat preview per appearance.
Colors are design tokens (03 §2): Terracotta, surface, canvas, room clay and sage.
Run: python3 design/tools/app_icon.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "icon"

APPEARANCES = {
    # background, arch, alcove (inner), shelf, pot, leaf dark, leaf light, book
    "light": ("#AC4C2A", "#FFFDFA", "#F7F3EE", "#9A4527", "#9A4527", "#3F6B48", "#DCE7DA", "#2E6488"),
    "dark": ("#1B1714", "#EA8B64", "#F0B59A", "#4A3329", "#4A3329", "#2F3D31", "#A9CBAE", "#2B3A46"),
    # Grayscale; iOS applies the user's tint (exported as an 8-bit gray PNG).
    "tinted": ("#131313", "#949494", "#B6B6B6", "#2B2B2B", "#2B2B2B", "#2C2C2C", "#B6B6B6", "#2B2B2B"),
}

# D68: the mark was 41% of the canvas wide and read small on the Home Screen. Scaled 1.2× about
# its own middle (y 547) and centered, it fills 50% × 68% with even top and bottom margins.
MARK = "translate(512 512) scale(1.2) translate(-512 -547)"

ARCH = "M300 836V470a212 212 0 0 1 424 0v366Z"
ALCOVE = "M344 836V482a168 168 0 0 1 336 0v354Z"


def layers(c):
    bg, arch, alcove, shelf, pot, leaf_d, leaf_l, book = c
    return {
        "1-background": f'<rect width="1024" height="1024" fill="{bg}"/>',
        "2-arch": f'<path d="{ARCH}" fill="{arch}"/><path d="{ALCOVE}" fill="{alcove}"/>',
        "3-shelf": (f'<rect x="326" y="668" width="372" height="30" rx="15" fill="{shelf}"/>'
                    '<g transform="translate(494 668) scale(1.3) translate(-494 -668)">'
                    f'<path d="M452 668l-10-84h104l-10 84Z" fill="{pot}"/><rect x="434" y="572" width="120" height="22" rx="11" fill="{pot}"/>'
                    f'<path d="M494 574c-46-30-60-80-24-112 22 30 30 62 24 112Z" fill="{leaf_d}"/>'
                    f'<path d="M494 574c42-22 64-70 36-104-24 26-36 58-36 104Z" fill="{leaf_l}"/></g>'
                    f'<rect x="606" y="540" width="44" height="128" rx="8" fill="{book}" transform="rotate(-10 628 668)"/>'),
    }


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{body}</svg>\n'


def mark(body):
    return f'<g transform="{MARK}">{body}</g>'


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for mode, colors in APPEARANCES.items():
        ls = {name: body if name == "1-background" else mark(body) for name, body in layers(colors).items()}
        for name, body in ls.items():
            (OUT / f"{name}-{mode}.svg").write_text(svg(body))
        (OUT / f"preview-{mode}.svg").write_text(svg("".join(ls.values())))
    print("wrote", len(list(OUT.glob("*.svg"))), "files to", OUT)
