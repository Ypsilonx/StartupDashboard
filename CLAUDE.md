# CLAUDE.md

## Co je to za projekt

Startup dashboard pro Windows napsaný čistě v PowerShell + WinForms (žádné externí knihovny, žádný package manager). Po spuštění zobrazí počasí a předpověď pro nakonfigurovanou lokalitu, agregované RSS zprávy, rychlé spuštění vybraných aplikací a nabízí přístup k systémovým informacím Windows a k aktualizacím software přes winget.

Doména: [[powershell-workflow]]. Cílí výhradně na **PowerShell 7+** (`pwsh.exe`), kompatibilita s 5.1 se neřeší.

## Spouštění a ověření

```powershell
# spuštění
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\StartupInfo.ps1

# kontrola syntaxe (vypíše chyby, jinak OK)
pwsh -NoProfile -Command '$e=$null; [System.Management.Automation.Language.Parser]::ParseFile("scripts\dashboard\StartupDashboard.ps1", [ref]$null, [ref]$e) | Out-Null; if ($e) { $e } else { "OK" }'
```

Automatizované testy ani lint nejsou — ověření = syntax-check dotčeného souboru + spuštění a vizuální kontrola UI.

## Architektura

Vstupní wrapper → WinForms UI → modul s datovou logikou:

- `scripts/StartupInfo.ps1` — stabilní vstupní cesta, jen deleguje na `dashboard/StartupDashboard.ps1`.
- `scripts/dashboard/StartupDashboard.ps1` — veškeré WinForms UI (jeden velký skript): bezrámečkové okno s vlastní hlavičkou, světlý/tmavý motiv (z registru `AppsUseLightTheme`), panely počasí/zpráv/rychlého spuštění, okno Software. Na síť nesahá přímo (výjimka: `Start-Process` pro odkazy a nastavení).
- `scripts/dashboard/Dashboard.Core.psm1` — datová logika bez WinForms. Exporty: `Get-DashboardConfig`, `Save-DashboardConfig`, `Get-WeatherSnapshot`, `Get-NewsFeedItems`, `Get-AvailableSoftwareUpdates`. Interní: `Convert-WeatherCodeToText`, `Normalize-TextForMatch`, `Get-ChmiCurrentWeather`.
- `scripts/dashboard/DashboardConfig.json` — veřejná výchozí konfigurace (`location`, `newsFeeds`, `quickApps`), jen neutrální lokalita.
- `scripts/dashboard/DashboardConfig.local.json` — soukromá konfigurace (gitignore). Pokud existuje, má přednost; UI si aktivní cestu drží v `$script:ActiveConfigPath` a `Save-DashboardConfig` (přidání/odebrání aplikace) zapisuje **tam**, nikdy do veřejného souboru, pokud local existuje.
- `scripts/dashboard/NewsCache.json` — generovaná cache zpráv (gitignore); při startu se zobrazí, pak proběhne online refresh.

### Datové zdroje

- **Počasí**: Open-Meteo (`api.open-meteo.com`) pro aktuální stav a 7denní předpověď + ČHMÚ (`data-provider.chmi.cz`) pro reálnou teplotu z nejbližší stanice (název stanice vs. `location.name` bez diakritiky přes `Normalize-TextForMatch`). Veřejná IP přes `api.ipify.org`.
- **Zprávy**: RSS/Atom z konfigurace, parsované přes `[xml]` (RSS `<item>` i Atom `<entry>`).
- **Software**: `winget upgrade --accept-source-agreements --disable-interactivity`, výstup parsovaný regexem po sloupcích; upgrade jedné aplikace přes `winget upgrade --id ... --exact`.

### Designová rozhodnutí

- Tlačítko **„Systém“** záměrně otevírá `ms-settings:about`, ne vlastní okno se souhrnem HW/SW.
- Instalace jako Scheduled Task byla odstraněna a neplánuje se — spouští se ručně.
- Průhlednost okna: `$dashboardOpacity` v `StartupDashboard.ps1` (~ř. 497).

## Jazyk

UI texty a chybové hlášky v češtině s plnou diakritikou. JSON s českým textem (konfigurace, cache) vždy čti/zapisuj s `-Encoding UTF8`.
