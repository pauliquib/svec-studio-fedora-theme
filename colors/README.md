# Svec Studio Colours

Nativní modul (KCM) do Nastavení systému KDE Plasma 6. Barvy panelu, oken a akcentu se v něm
nastavují na jednom místě a změny jsou vidět v živém náhledu dřív, než je použiješ.

V Nastavení systému se jmenuje **Panel & Window Colours** (Barvy a motivy → Panel & Window Colours),
spustit ho jde i příkazem
`kcmshell6 kcm_svec_colors`.

## Co umí

**Základní nastavení**

- Barva akcentu.
- Barva panelu.
- Barva záhlaví aktivního okna a záhlaví neaktivních oken. Neaktivní záhlaví lze jedním kliknutím
  odvodit z aktivního (tmavší, světlejší, vybledlá, stejná).
- Okraje oken: velikost okraje, tenký obrys kolem okna, zaoblené rohy a okraje u maximalizovaných
  oken. Okraj má stejnou barvu jako záhlaví.

**Rozšířené** (rozbalovací sekce)

- Barva textu v záhlaví aktivního a neaktivního okna a barva textu na panelu.
- Pozadí oken, seznamů a textových polí.
- Zarovnání titulku, velikost tlačítek, přechod na záhlaví a kroužek kolem tlačítka Zavřít.
- Stín: velikost, síla a barva.
- Načtení hodnot z aktuálního systému, například po změně na jiné stránce nastavení.

**Motivy (uložené kombinace)**

- Celé nastavení se dá uložit pod vlastním jménem (**Uložit jako…**) a později znovu vybrat.
- Vestavěné motivy: *Breeze Dark*, *Sand*, *Midnight* a *Graphite*.
- Motiv se dá exportovat do souboru `.colortheme` a na jiném počítači importovat (starší soubory
  `.svectheme` jde importovat taky).
- Úprava vestavěného motivu se uloží jako tvoje kopie. Tlačítkem **Obnovit** se vrátíš k původní
  verzi.

## Instalace

Závislosti (Fedora):

    sudo dnf install cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel \
        kf6-kcmutils-devel kf6-kconfig-devel kf6-kconfigwidgets-devel \
        kf6-kwidgetsaddons-devel kf6-ki18n-devel kf6-kcoreaddons-devel

Sestavení a instalace (spusť v běžném terminálu, `sudo` se zeptá na heslo):

    ./install.sh

Odinstalace:

    ./install.sh --uninstall

Pokud bylo Nastavení systému během instalace otevřené, úplně ho zavři a spusť znovu.

## Jak to funguje

Při **Použít** modul:

1. zapíše akcent do `~/.config/kdeglobals`,
2. vygeneruje barevné schéma `SvecStudio-<hash>` z Breeze Dark a použije ho
   (`plasma-apply-colorscheme`),
3. zapíše barvy záhlaví i přímo do `kdeglobals`. `plasma-apply-colorscheme` totiž nekopíruje
   skupinu `[Colors:Header][Inactive]`, ze které dekorace Breeze bere barvu neaktivního záhlaví,
4. vygeneruje Plasma style `svec-studio-panel-<hash>` z Breeze Dark s barvou panelu a použije ho
   (`plasma-apply-desktoptheme`),
5. zapíše nastavení okrajů a stínu do `~/.config/breezerc` a `~/.config/kwinrc`,
6. smaže dřív vygenerovaná schémata a styly, které se už nepoužívají, a přenačte KWin.

V seznamu barevných schémat se vygenerované schéma jmenuje *Custom (Panel & Window Colours)*,
v seznamu Plasma stylů *Custom Panel*. Hash v názvu souboru se mění s barvami. Plasma totiž schéma nebo styl se stejným jménem znovu nepoužije.

| Soubor | Obsah |
|---|---|
| `~/.config/svec-studio-colorsrc` | aktuální nastavení modulu |
| `~/.local/share/svec-studio-colors/presets/*.colortheme` | tvoje uložené motivy |
| `/usr/share/svec-studio-colors/presets/*.colortheme` | vestavěné motivy |

Soubor `.colortheme` je obyčejný INI se skupinami `[Colors]` a `[Decoration]`. Klíče, které
v něm chybí, mají výchozí hodnoty Breeze Dark.

## Omezení

- Okraje, obrys a stín fungují jen s dekorací oken **Breeze**. U jiné dekorace modul zobrazí
  upozornění a použije jen barvy.
- Schéma i Plasma style vycházejí z Breeze Dark. Světlý základ zatím není.
