# Nook app icon

An arched nook with a shelf, a small plant and a leaning book. There's no lettering, so the mark survives the final app name check (PRD §10). The source is `design/tools/app_icon.py`; run it to re-export. The canvas shows it on the **App icon** board.

| File | What it is |
|---|---|
| `1-background-{light,dark}.svg` | Full-bleed fill: Terracotta (light) or espresso (dark) |
| `2-arch-{light,dark}.svg` | The arch and its inner alcove |
| `3-shelf-{light,dark}.svg` | Shelf, pot, leaves and book |
| `preview-{light,dark}.svg` | All layers flattened, for review only |

All colors are tokens from `docs/03_Design_System.md` §2.

## Ready to use: `AppIcon.appiconset`
`AppIcon.appiconset/` is a standard Xcode asset-catalog icon: 1024 px light, dark and tinted PNGs, with no transparency. In P1, drop it into the app's `Assets.xcassets` and it works as-is. iOS 26 and later add their glass treatment to it automatically.

## Optional polish: a `.icon` file in Icon Composer
This gives finer control over the clear and glass looks. Do it whenever there's time, any phase before P13.
Icon Composer is a Mac app with no command-line export, so this step is done by hand. Its file format isn't documented, and hand-writing one risks a file Xcode rejects.

1. Open Icon Composer and create a new icon. Save it as `design/icon/Nook.icon`.
2. Drag in `2-arch-light.svg` as group 1 and `3-shelf-light.svg` as group 2 (front).
3. Set the background to a solid fill of `#AC4C2A`. Don't import `1-background`; Icon Composer owns the background.
4. Switch to the **Dark** appearance. Set the background to `#1B1714`, and swap in the `-dark` layer files (or set their fills to the dark values in `app_icon.py`).
5. Check **Tinted** and **Clear**. Icon Composer builds both from the layers. Give group 2 a little specular highlight and keep group 1 flat, so the shelf reads on glass.
6. Commit `Nook.icon`. In P1, add it to the app target as the AppIcon (Xcode 26 and later read `.icon` directly).

[Verify in SDK] that the 60-pt Home Screen preview still reads with the system's glass treatment applied. If the plant gets lost, scale group 2 up by about 10% and log it in `docs/decisions.md`.
