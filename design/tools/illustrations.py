"""Nook illustrations (03 §7): soft, rounded, gouache-like shapes in the warm palette, accent as the highlight.

Each illustration is a list of (element, is_accent). Colors are CSS variables from the token block, so the
canvas renders light and dark automatically. export() writes concrete SVGs for the app: a base layer per mode
and a one-color accent layer that the app tints at runtime (D25).
"""

W, H = 320, 180


def el(tag, attrs, fill):
    a = " ".join(f'{k}="{v}"' for k, v in attrs.items())
    return f'<{tag} {a} style="fill: {fill}"/>'


def rect(x, y, w, h, r, fill):
    return el("rect", {"x": x, "y": y, "width": w, "height": h, "rx": r}, fill)


def ellipse(cx, cy, rx, ry, fill):
    return el("ellipse", {"cx": cx, "cy": cy, "rx": rx, "ry": ry}, fill)


def path(d, fill):
    return el("path", {"d": d}, fill)


def stroke(d, color, w=4, dash=None):
    da = f"; stroke-dasharray: {dash}" if dash else ""
    return f'<path d="{d}" style="fill: none; stroke: {color}; stroke-width: {w}; stroke-linecap: round; stroke-linejoin: round{da}"/>'


def room(name, inner):
    return f'<g class="r-{name}">{inner}</g>'


SHADOW = "color-mix(in srgb, var(--text) 8%, transparent)"
PLANK = "var(--hairline-strong)"
ACC = "var(--accent)"


def plank(y, x=30, w=260):
    return [(rect(x, y, w, 10, 5, PLANK), False), (ellipse(x + w / 2, y + 16, w / 2 - 10, 4, SHADOW), False)]


def plant(x, y, scale=1.0, pot="clay"):
    s = scale
    return [(room("sage", path(f"M{x} {y - 30*s} C{x - 22*s} {y - 44*s} {x - 26*s} {y - 66*s} {x - 8*s} {y - 70*s} C{x - 2*s} {y - 56*s} {x + 2*s} {y - 44*s} {x} {y - 30*s}Z", "var(--ri)")), False),
            (room("sage", path(f"M{x} {y - 30*s} C{x + 20*s} {y - 40*s} {x + 30*s} {y - 58*s} {x + 16*s} {y - 66*s} C{x + 6*s} {y - 54*s} {x} {y - 44*s} {x} {y - 30*s}Z", "var(--rf)")), False),
            (room(pot, path(f"M{x - 16*s} {y - 30*s}h{32*s}l-{4*s} {30*s}h-{24*s}Z", "var(--ri)")), False),
            (room(pot, rect(x - 18 * s, y - 34 * s, 36 * s, 8 * s, 4 * s, "var(--rf)")), False)]


def books(x, y, specs):
    out = []
    for dx, w, h, color, tilt in specs:
        t = f' transform="rotate({tilt} {x + dx + w / 2} {y})"' if tilt else ""
        out.append((f'<g{t}>' + room(color, rect(x + dx, y - h, w, h, 3, "var(--rf)") + rect(x + dx + 3, y - h + 8, w - 6, 3, 1.5, "var(--ri)")) + "</g>", False))
    return out


def jar(x, y, color="mint"):
    return [(room(color, rect(x - 14, y - 34, 28, 34, 8, "var(--rf)")), False),
            (room(color, rect(x - 10, y - 40, 20, 8, 3, "var(--ri)")), False)]


def box(x, y, w, h, color=None, accent=False):
    if accent:
        return [(rect(x, y - h, w, h, 6, ACC), True), (rect(x - 3, y - h - 6, w + 6, 10, 4, ACC), True)]
    return [(room(color, rect(x, y - h, w, h, 6, "var(--rf)")), False), (room(color, rect(x - 3, y - h - 6, w + 6, 10, 4, "var(--ri)")), False)]


def sparkle(x, y, r=7):
    return [(path(f"M{x} {y - r}Q{x + 1.5} {y - 1.5} {x + r} {y}Q{x + 1.5} {y + 1.5} {x} {y + r}Q{x - 1.5} {y + 1.5} {x - r} {y}Q{x - 1.5} {y - 1.5} {x} {y - r}Z", ACC), True)]


def dashed_slot(x, y, w, h):
    return [(stroke(f"M{x + 8} {y - h}h{w - 16}a8 8 0 0 1 8 8v{h - 16}a8 8 0 0 1 -8 8h-{w - 16}a8 8 0 0 1 -8 -8v-{h - 16}a8 8 0 0 1 8 -8Z", PLANK, 3, "6 7"), False)]


ILL = {}

# Welcome: a calm, tidy shelf
ILL["shelf-tidy"] = (plank(70) + books(52, 70, [(0, 14, 44, "sky", 0), (16, 12, 38, "butter", 0), (30, 13, 46, "lavender", -8)])
                     + jar(150, 70, "rose") + plant(232, 70, 0.75)
                     + plank(140) + plant(70, 140, 0.9) + box(126, 140, 50, 34, accent=True) + jar(214, 140, "mint")
                     + books(238, 140, [(0, 12, 40, "clay", 0), (14, 12, 34, "stone", 0)]) + sparkle(266, 30))
# Home empty: one shelf, waiting
ILL["shelf-waiting"] = (plank(130) + plant(70, 130, 0.8) + dashed_slot(110, 130, 56, 52) + dashed_slot(176, 130, 44, 40) + dashed_slot(230, 130, 50, 60)
                        + [(f'<circle cx="204" cy="60" r="20" style="fill: none; stroke: {ACC}; stroke-width: 5"/>', True), (stroke("M204 50v20M194 60h20", ACC, 5), True)])
# Room empty: kitchen shelf with a mug and a viewfinder
ILL["kitchen-empty"] = (plank(128) + [(room("butter", rect(60, 96, 30, 32, 6, "var(--rf)")), False), (room("butter", stroke("M90 104h6a6 6 0 0 1 0 12h-6", "var(--ri)", 4)), False)]
                        + [(stroke(d, ACC, 5), True) for d in ["M130 60v-12a6 6 0 0 1 6-6h12", "M246 42h12a6 6 0 0 1 6 6v12", "M264 104v12a6 6 0 0 1 -6 6h-12", "M148 122h-12a6 6 0 0 1 -6-6v-12"]]
                        + dashed_slot(160, 112, 36, 40) + dashed_slot(206, 112, 32, 32))
# Find, no results: an open, empty drawer and a magnifier
ILL["drawer-empty"] = ([(room("stone", rect(70, 40, 180, 112, 10, "var(--rf)")), False),
                        (room("stone", rect(84, 54, 152, 34, 6, "var(--ri)")), False), (room("stone", rect(146, 66, 28, 8, 4, "var(--rf)")), False),
                        (path("M78 112 L96 92 H224 L242 112 Z", "var(--sunken)"), False),
                        (room("stone", path("M78 112 L96 92 H224 L242 112 Z", "none")), False),
                        (stroke("M78 112 L96 92 H224 L242 112", "var(--hairline-strong)", 2), False),
                        (room("stone", rect(74, 112, 172, 40, 8, "var(--ri)")), False), (room("stone", rect(140, 126, 40, 8, 4, "var(--rf)")), False),
                        (ellipse(160, 160, 100, 5, SHADOW), False),
                        (f'<circle cx="250" cy="44" r="18" style="fill: var(--surface); stroke: {ACC}; stroke-width: 7"/>', True), (stroke("M263 57l15 15", ACC, 8), True)])
# Paywall: a full, happy shelf
ILL["shelf-full"] = (plank(72) + books(40, 72, [(0, 12, 40, "sky", 0), (14, 13, 46, "clay", 0), (29, 12, 36, "butter", 0), (43, 13, 42, "lavender", -10)])
                     + jar(130, 72, "mint") + plant(176, 72, 0.6) + box(206, 72, 36, 26, "rose") + jar(266, 72, "butter")
                     + plank(144) + box(46, 144, 44, 32, accent=True) + plant(124, 144, 0.85) + books(150, 144, [(0, 14, 46, "sage", 0), (16, 12, 40, "stone", 0), (30, 13, 44, "sky", 6)])
                     + box(204, 144, 40, 28, "clay") + jar(268, 144, "lavender") + sparkle(280, 26) + sparkle(30, 30, 5))
# Warranties empty: receipt with a ribbon
ILL["receipt-ribbon"] = ([(path("M110 28h100v128l-12-8-13 8-12-8-13 8-12-8-13 8-12-8-13 8Z", "var(--surface)"), False),
                          (stroke("M110 28h100v128l-12-8-13 8-12-8-13 8-12-8-13 8-12-8-13 8Z", "var(--hairline-strong)", 2), False)]
                         + [(rect(126, y, w, 6, 3, "var(--hairline)"), False) for y, w in [(48, 56), (64, 68), (80, 44), (100, 68)]]
                         + [(f'<circle cx="214" cy="118" r="23" style="fill: var(--surface); stroke: {ACC}; stroke-width: 6"/>', True), (path("M200 138l-8 30 14-8 8 12 6-28Z", ACC), True),
                            (path("M228 138l8 30-14-8-8 12-6-28Z", ACC), True), (stroke("m204 118 7 7 14-14", ACC, 5), True)])
# Lent out empty: a box changing hands
ILL["box-hands"] = ([(room("rose", path("M20 120c30-6 52-4 74 6l6 22c-30 0-58-4-80-10Z", "var(--rf)")), False),
                     (room("rose", ellipse(100, 130, 18, 14, "var(--ri)")), False),
                     (room("sky", path("M300 120c-30-6-52-4-74 6l-6 22c30 0 58-4 80-10Z", "var(--rf)")), False),
                     (room("sky", ellipse(220, 130, 18, 14, "var(--ri)")), False)]
                    + box(122, 128, 76, 58, accent=True) + [(ellipse(160, 166, 70, 5, SHADOW), False)] + sparkle(160, 34))
# Recently Deleted empty: a clean, empty bin
ILL["bin-empty"] = ([(room("stone", path("M112 64h96l-10 96h-76Z", "var(--rf)")), False),
                     (room("stone", rect(104, 50, 112, 16, 8, "var(--ri)")), False), (room("stone", rect(146, 40, 28, 12, 6, "var(--ri)")), False),
                     (room("stone", stroke("M140 84l4 60M160 84v60M180 84l-4 60", "var(--ri)", 3)), False), (ellipse(160, 166, 70, 5, SHADOW), False)]
                    + sparkle(236, 52) + sparkle(84, 82, 6) + sparkle(244, 112, 5))

LABELS = {"a calm, tidy shelf": "shelf-tidy", "empty shelf, waiting": "shelf-waiting", "empty kitchen shelf": "kitchen-empty",
          "empty drawer": "drawer-empty", "a full, happy shelf": "shelf-full", "receipt with a ribbon": "receipt-ribbon",
          "a box changing hands": "box-hands", "an empty bin": "bin-empty"}


def svg(name, height="100%"):
    body = "".join(e for e, _ in ILL[name])
    return f'<svg viewBox="0 0 {W} {H}" width="100%" height="{height}" aria-hidden="true" preserveAspectRatio="xMidYMid meet">{body}</svg>'


def export(out_dir):
    """Concrete SVGs for the app (D25): <name>-light.svg, <name>-dark.svg (base layer) and <name>-accent.svg (template)."""
    import re
    light = {"--canvas": "#F7F3EE", "--surface": "#FFFDFA", "--sunken": "#EFE8DF", "--hairline": "#E4DACE", "--hairline-strong": "#C9BBAB", "--text": "#2A2420"}
    dark = {"--canvas": "#1B1714", "--surface": "#25201C", "--sunken": "#141110", "--hairline": "#3A322B", "--hairline-strong": "#5A4F45", "--text": "#F3ECE3"}
    rooms = {"clay": (("#F1DDD3", "#9A4527"), ("#4A3329", "#F0B59A")), "sage": (("#DCE7DA", "#3F6B48"), ("#2F3D31", "#A9CBAE")),
             "sky": (("#D8E6F0", "#2E6488"), ("#2B3A46", "#A6CBE6")), "lavender": (("#E5DDEE", "#66508A"), ("#3A3245", "#C8B6E2")),
             "butter": (("#F4E9C9", "#7E5F12"), ("#463C22", "#E9CF86")), "rose": (("#F2DADF", "#9A3F57"), ("#47303A", "#EDB0C0")),
             "stone": (("#E6E1DA", "#5E554C"), ("#3B3631", "#CFC6BC")), "mint": (("#D6ECE5", "#2F7360"), ("#2A4039", "#A3D6C6"))}
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, parts in ILL.items():
        for mode, table in (("light", light), ("dark", dark)):
            idx = 0 if mode == "light" else 1
            body = []
            for e, is_acc in parts:
                if is_acc:
                    continue

                def room_sub(m):
                    fill, ink = rooms[m.group(1)][idx]
                    return m.group(2).replace("var(--rf)", fill).replace("var(--ri)", ink)
                e = re.sub(r'<g class="r-(\w+)">(.*?)</g>', room_sub, e)
                for k, val in table.items():
                    e = e.replace(f"var({k})", val)
                e = e.replace("color-mix(in srgb, " + table["--text"] + " 8%, transparent)", table["--text"] + '; fill-opacity: 0.08')
                body.append(e)
            (out_dir / f"{name}-{mode}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">' + "".join(body) + "</svg>\n")
        acc = "".join(e.replace("var(--accent)", "#000000").replace("var(--surface)", "none") for e, is_acc in parts if is_acc)
        (out_dir / f"{name}-accent.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">{acc}</svg>\n')


def catalog(svg_dir, catalog_dir):
    """NookUI's Illustrations.xcassets (D25): <name> (light + dark base) and <name>-accent (template)."""
    import json
    import shutil
    info = {"author": "xcode", "version": 1}
    shutil.rmtree(catalog_dir, ignore_errors=True)
    catalog_dir.mkdir(parents=True)
    (catalog_dir / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    for name in ILL:
        base = catalog_dir / f"{name}.imageset"
        base.mkdir()
        for mode in ("light", "dark"):
            shutil.copy(svg_dir / f"{name}-{mode}.svg", base)
        images = [{"filename": f"{name}-light.svg", "idiom": "universal"},
                  {"appearances": [{"appearance": "luminosity", "value": "dark"}],
                   "filename": f"{name}-dark.svg", "idiom": "universal"}]
        props = {"preserves-vector-representation": True}
        (base / "Contents.json").write_text(json.dumps({"images": images, "info": info, "properties": props}, indent=2) + "\n")
        accent = catalog_dir / f"{name}-accent.imageset"
        accent.mkdir()
        shutil.copy(svg_dir / f"{name}-accent.svg", accent)
        props = {"preserves-vector-representation": True, "template-rendering-intent": "template"}
        images = [{"filename": f"{name}-accent.svg", "idiom": "universal"}]
        (accent / "Contents.json").write_text(json.dumps({"images": images, "info": info, "properties": props}, indent=2) + "\n")


if __name__ == "__main__":
    from pathlib import Path
    root = Path(__file__).resolve().parents[2]
    export(root / "design/illustrations")
    catalog(root / "design/illustrations", root / "Packages/NookUI/Sources/NookUI/Resources/Illustrations.xcassets")
