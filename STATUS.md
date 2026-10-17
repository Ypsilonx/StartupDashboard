# Stav projektu

<!-- Přepisuje se na aktuální stav, není to deník. Max. ~30 řádků. -->

Aktualizováno: 2026-10-17

## Cíl

Funkční osobní startup dashboard; aktuálně hotový, bez rozpracovaného milníku.

## Hotovo

- Počasí (Open-Meteo + ČHMÚ) a 7denní předpověď.
- RSS zprávy s anotací, filtrem zdrojů a lokální cache.
- Rychlé spuštění aplikací (přidání přes dialog, odebrání pravým klikem, ukládání do aktivní konfigurace).
- Bezrámečkové okno, světlý/tmavý motiv podle Windows + ruční přepínač.
- Okno Software s upgradem přes winget; tlačítko Systém → `ms-settings:about`.
- Soukromá konfigurace přes `DashboardConfig.local.json`.
- Audit dokumentace (2026-10-17): CLAUDE.md aktualizovaný podle kódu, opravený syntax-check, README s URL repa, tento STATUS.md.

## Rozpracováno

- Nic.

## Další krok

- Žádný naplánovaný.

## Otevřené otázky / slepé uličky

- ❌ Syntax-check přes `ParseFile(..., [ref]$null, [ref]$null)` – chyby zahodí a vždy vypíše OK. Platný příkaz je v CLAUDE.md.
- ❌ Instalace jako Scheduled Task – odstraněna, dashboard se spouští ručně. Nevracet se bez nového důvodu.
