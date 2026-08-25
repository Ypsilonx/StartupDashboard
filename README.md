# Startup Dashboard (PowerShell)

![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg)

Jednoduchý startup dashboard pro Windows, který po spuštění zobrazí:
- počasí a 7denní předpověď pro vybranou lokalitu,
- agregované zprávy z RSS s krátkou anotací,
- rychlý přístup k vybraným aplikacím,
- rychlý přístup k systémovým informacím a aktualizacím software.

Projekt je psaný v PowerShell + WinForms, bez externích knihoven.

![Ukázka dashboardu v tmavém motivu](docs/dashboard-screenshot.png)

## Co to umí

- Bezrámečkové, mírně průhledné okno s vlastní hlavičkou — přesun tažením za hlavičku, tlačítka minimalizovat/zavřít.
- Světlý/tmavý motiv — při startu se odvodí ze systémového nastavení Windows (pokud máš nastavené automatické přepínání motivu Windows v určitou hodinu, dashboard to zohlední při každém spuštění), ručně jde přepnout tlačítkem ☀/☾ v hlavičce.
- Panel počasí s vizuální ikonou podle aktuální teploty a 7denní předpovědí (scrollovatelná tabulka).
- Panel zpráv z více RSS zdrojů (ČT24, Seznam Zprávy, České noviny/ČTK, Lupa, Root) s krátkou anotací článku v náhledovém panelu (klik vybere a zobrazí anotaci, dvojklik otevře článek v prohlížeči).
- Filtrování zpráv podle zdroje (checkboxy + ALL jako výchozí).
- Rychlé spuštění vybraných aplikací — ikony s jedním klikem spustí aplikaci, tlačítko "+ Přidat" přidá novou (ikona se vytáhne přímo z `.exe`/`.lnk`), pravým klikem jde aplikaci odebrat.
- Tlačítko "Systém" otevře systémové nastavení Windows (`ms-settings:about`) s HW/SW přehledem počítače.
- Okno "Software" se seznamem aplikací s dostupnou novou verzí, průběhovým ukazatelem při načítání/upgradu a tlačítkem pro upgrade přes winget.

## Struktura projektu

```text
docs/
  dashboard-screenshot.png           # ukázkový screenshot pro README
scripts/
  StartupInfo.ps1                    # vstupní skript (wrapper)
  dashboard/
    StartupDashboard.ps1             # hlavní WinForms UI
    Dashboard.Core.psm1              # datové funkce (počasí, RSS, aktualizace software)
    DashboardConfig.json             # konfigurace lokality, RSS feedů a rychlého spuštění
    NewsCache.json                   # automaticky generovaná lokální cache zpráv
```

## Požadavky

- Windows 10/11
- PowerShell 7+ (spouští se přes `pwsh.exe`, https://aka.ms/powershell)
- Internetové připojení pro počasí a RSS
- Winget (pro sekci aktualizací software)

## Instalace

1. Nainstaluj [PowerShell 7+](https://aka.ms/powershell) (`pwsh.exe`), pokud ho ještě nemáš.
2. Stáhni si projekt (naklonuj repozitář nebo na GitHubu stáhni ZIP a rozbal):

   ```powershell
   git clone <URL-tohoto-repozitáře>
   ```

   (URL najdeš na GitHubu po vytvoření repozitáře pod tlačítkem "Code".)

3. Uprav si podle potřeby `scripts/dashboard/DashboardConfig.json` (viz sekce [Konfigurace](#konfigurace)).

Žádná další instalace, package manager ani administrátorská práva nejsou potřeba.

## Rychlý start (manuální spuštění)

Spusť dashboard přímo z rootu projektu:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\StartupInfo.ps1
```

## Konfigurace

Konfigurační soubor: `scripts/dashboard/DashboardConfig.json`

### Lokalita pro počasí

```json
"location": {
  "name": "Praha",
  "latitude": 50.0755,
  "longitude": 14.4378
}
```

### Zdroje zpráv (RSS)

```json
"newsFeeds": [
  { "name": "ČT24 Domácí", "url": "https://ct24.ceskatelevize.cz/rss/domaci" },
  { "name": "Seznam Zprávy", "url": "https://www.seznamzpravy.cz/rss" }
]
```

Doporučení pro přidání nového feedu:
- URL musí vracet validní RSS/Atom.
- Každý zdroj musí mít unikátní `name` (používá se ve filtru zdrojů).
- Po změně konfigurace stačí dashboard znovu otevřít nebo stisknout "Obnovit dashboard".

### Rychlé spuštění aplikací

```json
"quickApps": [
  { "name": "Poznámkový blok", "path": "C:\\Windows\\notepad.exe" }
]
```

Nemusíš to editovat ručně — pohodlnější je tlačítko "+ Přidat" v panelu "Rychlé spuštění" (vybereš `.exe`/`.lnk` přes dialog), které si nastavení samo uloží zpátky do konfiguračního souboru. Odebrání jde přes pravý klik na ikonu aplikace.

### Lokální konfigurace (soukromá lokalita)

`DashboardConfig.json` je součástí repozitáře a obsahuje jen neutrální výchozí lokalitu (Praha) — nehodí se do něj ukládat vlastní bydliště, protože soubor je veřejný.

Pro vlastní nastavení vytvoř vedle něj soubor `scripts/dashboard/DashboardConfig.local.json` se stejnou strukturou (viz výše). Pokud existuje, dashboard ho automaticky použije místo `DashboardConfig.json`. Tento soubor je v `.gitignore`, takže zůstane jen lokálně a nedostane se do gitu.

## Poznámky k implementaci

- Zprávy jsou řazené od nejnovějších po nejstarší.
- Při startu se nejdřív zobrazí obsah `NewsCache.json` (pokud existuje) a následně proběhne online aktualizace.
- Filtrování zpráv pracuje pouze nad lokálně načtenými daty (bez síťového volání).
- Síťové načítání RSS probíhá jen při startu dashboardu a po kliknutí na "Obnovit zprávy" nebo "Obnovit dashboard".
- Pokud winget není dostupný, sekce aktualizací software zobrazí informativní stav.
- V okně "Software" se zobrazují jen aplikace s dostupnou novou verzí, každý řádek má vlastní tlačítko "Upgradovat". Winget vrací výstup až po doběhnutí celého příkazu, takže průběhový ukazatel je jen orientační (marquee styl), ne skutečné procento.
- Motiv (světlý/tmavý) se čte z registru Windows (`AppsUseLightTheme`) při každém startu — žádný vlastní časovač na přepínání.
- Míru průhlednosti okna lze upravit v `scripts/dashboard/StartupDashboard.ps1` (proměnná `$dashboardOpacity`, hodnota 0.0–1.0).

## Typický provozní postup

1. Uprav `DashboardConfig.json` (lokalita + feedy).
2. Otestuj manuální spuštění `StartupInfo.ps1`.
3. Při změně URL feedu nebo layoutu zkontroluj, že odkazy jdou otevřít tlačítkem "Otevřít článek".

## Troubleshooting

- Dashboard se neotevře:
  - ověř, že existuje `scripts/dashboard/StartupDashboard.ps1`.
  - spusť skript ručně v PowerShellu a zkontroluj chybový výstup.

- Nejsou data počasí/zpráv:
  - zkontroluj internetové připojení.
  - ověř funkčnost URL v `DashboardConfig.json`.

## Licence

Projekt je dostupný pod licencí [MIT](./LICENSE) — je možné jej svobodně stahovat, používat, upravovat i dále šířit, včetně komerčního využití, při zachování copyright poznámky.

## Poděkování

Tento projekt vznikl ve spolupráci s AI asistentem [Claude](https://claude.com/claude-code) (Anthropic), který pomáhal s návrhem, laděním a dokumentací kódu.
