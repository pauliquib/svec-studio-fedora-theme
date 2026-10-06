# Svec Studio Icons

Icon pack pro Fedoru / KDE Plasma ve stylu [Svec Studio](https://github.com/pauliquib/svec-studio) — outline SVG ikony (`viewBox="0 0 24 24"`, `stroke="currentColor"`, `stroke-width="1.75"`).

Pack pokrývá **všechna jména, která obsahuje Breeze** (7 100+) — buď přímým mapováním na Svec Studio glyphy, nebo dogenerovanými ikonami (`build.py` při buildu načte nainstalovaný Breeze a pro každé chybějící jméno vybere glyph podle klíčových slov / neutrální per kontext). Po aktivaci tedy přebarvuje celý systém včetně System Tray, Plasma appletů a KCM stránek — žádný barevný Breeze fallback.

## Varianty

| Téma | Verze | Chování |
|------|-------|---------|
| `SvecStudio-Accent` | v2 | `ColorScheme-Accent` → Plasma přebarví podle **akcentní barvy** systému |
| `SvecStudio-White` | v1.1 | pevně bílé `#ffffff` |
| `SvecStudio-Black` | v1.2 | pevně černé `#000000` |

Každá varianta obsahuje ~8 600 ikon napříč kontexty `apps`, `places`, `actions`, `mimetypes`, `devices`, `status`, `emblems`, `emotes`, `categories`, `preferences`, `applets`, `intl`.

Accent varianta používá stejný mechanismus jako Breeze (`<style id="current-color-scheme">` + `class="ColorScheme-Accent"` + `FollowsColorScheme=true`), mimo KDE se renderuje fallback `#3daee9`.

## Screenshots — všech 542 zdrojových ikon

| Accent | White | Black |
|--------|-------|-------|
| ![Accent](screenshots/screenshots-accent.png) | ![White](screenshots/screenshots-white-on-dark.png) | ![Black](screenshots/screenshots-black-on-light.png) |

## Instalace

```bash
# z předvygenerovaných themat (themes/)
cp -r themes/SvecStudio-* ~/.local/share/icons/

# nebo rovnou build + instalace
python3 build.py --install
```

Aktivace: **System Settings → Colors & Themes → Icons → „Outline Icons (Accent / White / Black)"**, případně:

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
- Breeze completion: `build.py` při buildu čte `/usr/share/icons/breeze` — jména, která Breeze má a pack ne, doplní nejbližším svec glyphem (pravidla `RULES` + `CTX_FALLBACK` v `build.py`). Bez nainstalovaného Breeze se krok přeskočí.
- `svec-studio` / `cz.svec.Studio` / `start-here*` je neutrální outline „S" mark (`src/svec-studio.svg`) — přebarvuje se s variantou jako ostatní ikony.

## Struktura

```
src/       zdrojové SVG ikony (svec-*.svg; ručně kreslené: svec-zed, svec-claude, svec-docker,
           svec-ventoy, svec-stm32cubeide, svec-studio = neutrální "S" mark…)
build.py   generátor → themes/ (+ --install do ~/.local/share/icons)
themes/    předvygenerované SvecStudio-{Accent,White,Black} icon themy
```

## Credits

Glyphy částečně vychází z [Tabler Icons](https://tabler.io/icons) (MIT) a ikon Svec Studia.

## License

MIT — viz [LICENSE](LICENSE).
