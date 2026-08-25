# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Co je to za projekt

Startup dashboard pro Windows napsaný čistě v PowerShell + WinForms (žádné externí knihovny, žádný package manager). Po spuštění zobrazí počasí a předpověď pro nakonfigurovanou lokalitu, agregované RSS zprávy, a nabízí rychlý přístup k systémovým informacím Windows a k aktualizacím software přes winget.

## Spouštění a vývoj

Projekt vyžaduje **PowerShell 7+** (`pwsh.exe`), ne Windows PowerShell 5.1 (`powershell.exe`) — jsou to dvě oddělené instalace/exe, jedna nenahrazuje druhou. Klíčový důvod: `pwsh` defaultně čte soubory jako UTF-8, zatímco `powershell.exe` bez explicitního `-Encoding` padá zpět na systémovou ANSI codepage a láme českou diakritiku. Proto je v kódu (`Get-Content ... -Encoding UTF8`) i v požadavcích na `pwsh.exe` vždy třeba tuto verzi respektovat.

Spuštění dashboardu:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\StartupInfo.ps1
```

Ověření syntaxe jednotlivého souboru bez jeho spuštění (užitečné po editaci):
```powershell
pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('cesta\k\souboru.ps1', [ref]$null, [ref]$null) | Out-Null; 'OK'"
```

Neexistují automatizované testy ani lint konfigurace — validace je manuální (spuštění + vizuální kontrola UI) a syntax-check parserem výše.

## Architektura

Tenká vrstva vstupního bodu → WinForms UI vrstva → modul s čistou datovou/business logikou:

- `scripts/StartupInfo.ps1` — kompatibilní vstupní wrapper, jen deleguje na `dashboard/StartupDashboard.ps1`. Existuje kvůli zachování stabilní cesty pro případné budoucí spouštěče.
- `scripts/dashboard/StartupDashboard.ps1` — veškerá WinForms UI logika (jeden velký skript, žádné oddělené view-modely): sestavení formuláře, layout panelů, event handlery tlačítek, vykreslování počasí/ikon, práce s `ListView` pro zprávy a `DataGridView` pro předpověď/software. Importuje `Dashboard.Core.psm1` a volá jeho exportované funkce; UI samo nikdy nesahá na síť přímo (výjimka: `Start-Process` pro otevírání odkazů/systémového nastavení).
- `scripts/dashboard/Dashboard.Core.psm1` — veškerá datová logika bez závislosti na WinForms, exportovaná přes `Export-ModuleMember`: `Get-DashboardConfig`, `Get-WeatherSnapshot`, `Get-NewsFeedItems`, `Get-AvailableSoftwareUpdates`. Interní pomocné funkce (`Convert-WeatherCodeToText`, `Normalize-TextForMatch`, `Get-ChmiCurrentWeather`) nejsou exportované.
- `scripts/dashboard/DashboardConfig.json` — konfigurace lokality (`location.name/latitude/longitude`) a seznamu RSS feedů (`newsFeeds[].name/url`). Runtime konfigurace, needituje se přes kód.
- `scripts/dashboard/NewsCache.json` — automaticky generovaná lokální cache poslední sady zpráv; UI ji při startu nejdřív načte pro rychlé zobrazení, pak spustí online refresh přes RSS.

### Datové zdroje

- **Počasí**: Open-Meteo API (`api.open-meteo.com`) pro aktuální stav a 7denní předpověď + ČHMÚ (`data-provider.chmi.cz`) pro doplňkovou reálnou teplotu z nejbližší české stanice (matchování názvu stanice na `location.name` bez diakritiky přes `Normalize-TextForMatch`). Veřejná IP se zjišťuje přes `api.ipify.org`.
- **Zprávy**: RSS/Atom feedy nakonfigurované v `DashboardConfig.json`, parsované ručně přes `[xml]` (podporuje jak RSS `<item>`, tak Atom `<entry>` strukturu).
- **Software**: `winget upgrade --accept-source-agreements --disable-interactivity`, výstup se parsuje regexem po sloupcích; upgrade jednotlivé aplikace se spouští z `Show-SoftwareWindow` přes `winget upgrade --id ... --exact`.

### Důležitá designová rozhodnutí

- Tlačítko **"Systém"** záměrně otevírá nativní Windows nastavení (`Start-Process 'ms-settings:about'`), nejde o vlastní okno se souhrnem HW/SW — toto je vědomá volba, ne nedodělaná funkce.
- Instalace/odinstalace jako naplánovaná úloha (Scheduled Task) byla z projektu odstraněna a zatím se neplánuje — dashboard se spouští čistě manuálně.
- `Set-StrictMode -Version Latest` a `$ErrorActionPreference = 'Stop'` jsou na začátku každého skriptu — nová chybová místa by měla tento vzorec dodržet, ne ho tiše obcházet.

## Jazyk a kódování

Veškerý UI text, chybové hlášky a komentáře v kódu jsou v češtině s plnou diakritikou. Při čtení/zápisu jakéhokoli souboru s českým textem (JSON konfigurace, cache) vždy používej explicitní `-Encoding UTF8` u `Get-Content`/`Set-Content` — bez toho dochází k lámání diakritiky na Windows PowerShell 5.1 (viz sekce Spouštění výše). `ConvertFrom-Json -AsHashtable` se nepoužívá, protože vyžaduje PS6+; `Get-DashboardConfig` místo toho ručně staví hashtable z `$parsed.PSObject.Properties`, aby zůstala kompatibilní i se staršími PowerShell verzemi, i když projekt jinak cílí na PS7+.
