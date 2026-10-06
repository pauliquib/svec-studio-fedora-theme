# Svec Studio Icons

Icon pack pro Fedoru / KDE Plasma ve stylu [Svec Studio](https://github.com/pauliquib/svec-studio) — outline SVG ikony (`viewBox="0 0 24 24"`, `stroke="currentColor"`, `stroke-width="1.75"`).

Pack pokrývá standardní freedesktop jména (`folder`, `document-save`, `applications-*`, `battery-*`, `network-*`…), takže po aktivaci přebarvuje systémové ikony — Dolphin, Kickoff, Plasma panel, MIME ikony i nainstalované aplikace. Nemapané ikony padají na `Inherits=breeze`.

## Varianty

| Téma | Verze | Chování |
|------|-------|---------|
| `SvecStudio-Accent` | v2 | `ColorScheme-Accent` → Plasma přebarví podle **akcentní barvy** systému |
| `SvecStudio-White` | v1.1 | pevně bílé `#ffffff` |
| `SvecStudio-Black` | v1.2 | pevně černé `#000000` |

Každá varianta obsahuje ~2 200 ikon napříč kontexty `apps`, `places`, `actions`, `mimetypes`, `devices`, `status`, `emblems`, `intl`.

Accent varianta používá stejný mechanismus jako Breeze (`<style id="current-color-scheme">` + `class="ColorScheme-Accent"` + `FollowsColorScheme=true`), mimo KDE se renderuje fallback `#3daee9`.

## Instalace

```bash
# z předvygenerovaných themat (themes/)
cp -r themes/SvecStudio-* ~/.local/share/icons/

# nebo rovnou build + instalace
python3 build.py --install
```

Aktivace: **System Settings → Colors & Themes → Icons → „Svec Studio Icons"**, případně:

```bash
kwriteconfig6 --file kdeglobals --group Icons --key Theme SvecStudio-Accent
systemctl --user restart plasma-plasmashell.service
```

## Rebuild po úpravě ikon

```bash
# přidej/uprav SVG v src/ (název souboru = název ikony svec-<name>)
# pro standardní freedesktop jméno přidej řádek do FDO_MAP v build.py
python3 build.py --install
```

Poznámky:

- Aplikace s `Icon=/absolutní/cesta.png` v `.desktop` souboru téma obchází — přepiš na jméno ikony (user překryv v `~/.local/share/applications/`).
- Syntetické ikony (baterie, UPS, `osd-*`…) generuje `build.py` přímo.
- Logo Svec Studia (`cz.svec.Studio`, `svec-studio`, `start-here*`) zůstává barevné ve všech variantách.

## Struktura

```
src/       zdrojové SVG ikony (svec-*.svg, ručně kreslené glyphy: zed, claude, docker, ventoy, stm32cubeide…)
logo.svg   logo Svec Studia
build.py   generátor → themes/ (+ --install do ~/.local/share/icons)
themes/    předvygenerované SvecStudio-{Accent,White,Black} icon themy
```

## Credits

Glyphy částečně vychází z [Tabler Icons](https://tabler.io/icons) (MIT) a ikon Svec Studia.

## License

MIT — viz [LICENSE](LICENSE).
