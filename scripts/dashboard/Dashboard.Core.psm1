Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Načte konfiguraci dashboardu ze souboru JSON.

.PARAMETER ConfigPath
Volitelná cesta ke konfiguraci. Pokud není zadaná, použije se DashboardConfig.json vedle modulu.

.OUTPUTS
System.Collections.Hashtable
#>
function Get-DashboardConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'DashboardConfig.json')
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Konfigurační soubor neexistuje: $ConfigPath"
    }

    $content = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    $parsed = $content | ConvertFrom-Json

    $cfg = @{}
    foreach ($property in $parsed.PSObject.Properties) {
        $cfg[$property.Name] = $property.Value
    }

    if (-not $cfg.ContainsKey('location')) {
        throw 'V konfiguraci chybí sekce location.'
    }

    if (-not $cfg.ContainsKey('newsFeeds')) {
        $cfg['newsFeeds'] = @()
    }

    if (-not $cfg.ContainsKey('quickApps')) {
        $cfg['quickApps'] = @()
    }

    return $cfg
}

<#
.SYNOPSIS
Uloží konfiguraci dashboardu do souboru JSON.

.PARAMETER Config
Hashtable konfigurace (typicky výsledek Get-DashboardConfig se změnou).

.PARAMETER ConfigPath
Volitelná cesta ke konfiguraci. Pokud není zadaná, použije se DashboardConfig.json vedle modulu.

.OUTPUTS
System.Void
#>
function Save-DashboardConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter()]
        [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'DashboardConfig.json')
    )

    $json = $Config | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $ConfigPath -Value $json -Encoding UTF8
}

<#
.SYNOPSIS
Převede weather code z Open-Meteo na lidský popis.

.PARAMETER Code
Kód počasí z Open-Meteo API.

.OUTPUTS
System.String
#>
function Convert-WeatherCodeToText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Code
    )

    switch ($Code) {
        0 { 'Jasno' }
        1 { 'Převážně jasno' }
        2 { 'Polojasno' }
        3 { 'Zataženo' }
        45 { 'Mlha' }
        48 { 'Namrzající mlha' }
        51 { 'Slabé mrholení' }
        53 { 'Mrholení' }
        55 { 'Husté mrholení' }
        61 { 'Slabý déšť' }
        63 { 'Déšť' }
        65 { 'Silný déšť' }
        66 { 'Slabý mrznoucí déšť' }
        67 { 'Mrznoucí déšť' }
        71 { 'Slabé sněžení' }
        73 { 'Sněžení' }
        75 { 'Silné sněžení' }
        77 { 'Sněhová zrna' }
        80 { 'Přeháňky' }
        81 { 'Dešťové přeháňky' }
        82 { 'Silné přeháňky' }
        85 { 'Sněhové přeháňky' }
        86 { 'Silné sněhové přeháňky' }
        95 { 'Bouřka' }
        96 { 'Bouřka s kroupami' }
        99 { 'Silná bouřka s kroupami' }
        default { 'Neznámý stav' }
    }
}

<#
.SYNOPSIS
Normalizuje text pro porovnávání bez diakritiky.

.PARAMETER InputText
Vstupní text.

.OUTPUTS
System.String
#>
function Normalize-TextForMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText
    )

    $normalized = $InputText.Normalize([Text.NormalizationForm]::FormD)
    $chars = New-Object System.Collections.Generic.List[char]

    foreach ($ch in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$chars.Add($ch)
        }
    }

    return (-join $chars).ToLowerInvariant()
}

<#
.SYNOPSIS
Načte aktuální teplotu ze zdroje ČHMÚ pro lokalitu.

.PARAMETER LocationName
Název lokality, pro kterou se má dohledat stanice.

.OUTPUTS
System.Collections.Hashtable
#>
function Get-ChmiCurrentWeather {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocationName
    )

    $result = [ordered]@{
        Source = 'ČHMÚ'
        Location = $LocationName
        Station = 'N/A'
        Temperature = 'N/A'
        LastMeasurement = 'N/A'
        Status = 'N/A'
    }

    try {
        $initUrl = 'https://data-provider.chmi.cz/api/map/init/aktualni-pocasi.aktualni-teplota'
        $initData = Invoke-RestMethod -Uri $initUrl -Method Get -TimeoutSec 10

        $vectorLayer = $initData.layers | Where-Object { $_.id -eq 'layer_vector' } | Select-Object -First 1
        if ($null -eq $vectorLayer -or $vectorLayer.dataParts.Count -eq 0) {
            $result.Status = 'Nenalezena vrstva stanic'
            return $result
        }

        $lastRef = $vectorLayer.dataParts[-1].dataRef
        $dataUrl = '{0}{1}' -f $vectorLayer.dataRefBase, $lastRef
        $stationData = Invoke-RestMethod -Uri $dataUrl -Method Get -TimeoutSec 10

        $target = Normalize-TextForMatch -InputText $LocationName

        $feature = $stationData.features |
            Where-Object { (Normalize-TextForMatch -InputText $_.properties.name) -eq $target } |
            Select-Object -First 1

        if ($null -eq $feature) {
            $feature = $stationData.features |
                Where-Object { (Normalize-TextForMatch -InputText $_.properties.name) -like ('*{0}*' -f $target) } |
                Select-Object -First 1
        }

        if ($null -eq $feature) {
            $result.Status = 'Lokalita nebyla nalezena v datech ČHMÚ'
            return $result
        }

        $measurementUtc = Get-Date $feature.properties.lastMeasurement
        $measurementLocal = [TimeZoneInfo]::ConvertTimeFromUtc($measurementUtc.ToUniversalTime(), [TimeZoneInfo]::Local)

        $result.Station = [string]$feature.properties.name
        $result.Temperature = ('{0} {1}' -f $feature.properties.value, $feature.properties.unit)
        $result.LastMeasurement = $measurementLocal.ToString('dd.MM.yyyy HH:mm:ss')
        $result.Status = 'OK'
        return $result
    }
    catch {
        $result.Status = ('Chyba: {0}' -f $_.Exception.Message)
        return $result
    }
}

<#
.SYNOPSIS
Načte aktuální počasí a sedmidenní předpověď.

.PARAMETER LocationName
Název lokality pro data ČHMÚ.

.PARAMETER Latitude
Zeměpisná šířka lokality.

.PARAMETER Longitude
Zeměpisná délka lokality.

.OUTPUTS
System.Collections.Hashtable
#>
function Get-WeatherSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocationName,

        [Parameter(Mandatory = $true)]
        [double]$Latitude,

        [Parameter(Mandatory = $true)]
        [double]$Longitude
    )

    $snapshot = [ordered]@{
        Location = $LocationName
        PublicIp = 'N/A'
        Current = $null
        Forecast = @()
        Chmi = $null
        Status = 'OK'
    }

    try {
        $ipResponse = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -Method Get -TimeoutSec 5
        if ($ipResponse.ip) {
            $snapshot.PublicIp = [string]$ipResponse.ip
        }
    }
    catch {
        $snapshot.Status = 'Částečná chyba online dotazu'
    }

    try {
        $query = @(
            'https://api.open-meteo.com/v1/forecast?'
            "latitude=$Latitude"
            "longitude=$Longitude"
            'current=temperature_2m,relative_humidity_2m,cloud_cover,apparent_temperature,wind_speed_10m,weather_code'
            'daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
            'forecast_days=8'
            'timezone=Europe%2FPrague'
        ) -join '&'

        $meteo = Invoke-RestMethod -Uri $query -Method Get -TimeoutSec 10

        $snapshot.Current = [ordered]@{
            Temperature = ('{0:N1} °C' -f [double]$meteo.current.temperature_2m)
            Feel = ('{0:N1} °C' -f [double]$meteo.current.apparent_temperature)
            Humidity = ('{0} %' -f [int]$meteo.current.relative_humidity_2m)
            CloudCover = ('{0} %' -f [int]$meteo.current.cloud_cover)
            Wind = ('{0:N1} km/h' -f [double]$meteo.current.wind_speed_10m)
            Condition = Convert-WeatherCodeToText -Code ([int]$meteo.current.weather_code)
            Time = (Get-Date $meteo.current.time).ToString('dd.MM.yyyy HH:mm')
        }

        $forecast = @()
        for ($i = 1; $i -le 7; $i++) {
            $forecast += [PSCustomObject]@{
                Date = (Get-Date $meteo.daily.time[$i]).ToString('ddd dd.MM.')
                Condition = Convert-WeatherCodeToText -Code ([int]$meteo.daily.weather_code[$i])
                Min = ('{0:N1} °C' -f [double]$meteo.daily.temperature_2m_min[$i])
                Max = ('{0:N1} °C' -f [double]$meteo.daily.temperature_2m_max[$i])
                RainChance = ('{0} %' -f [int]$meteo.daily.precipitation_probability_max[$i])
            }
        }

        $snapshot.Forecast = $forecast
    }
    catch {
        $snapshot.Status = 'Chyba načítání předpovědi'
        $snapshot.Current = [ordered]@{
            Temperature = 'N/A'
            Feel = 'N/A'
            Humidity = 'N/A'
            CloudCover = 'N/A'
            Wind = 'N/A'
            Condition = 'N/A'
            Time = 'N/A'
        }
        $snapshot.Forecast = @()
    }

    $snapshot.Chmi = Get-ChmiCurrentWeather -LocationName $LocationName
    return $snapshot
}

<#
.SYNOPSIS
Načte přehled zpráv z RSS feedů.

.PARAMETER Feeds
Seznam feedů ve tvaru @{ name = '...'; url = '...' }.

.PARAMETER MaxItemsPerFeed
Maximální počet položek na jeden feed.

.OUTPUTS
System.Object[]
#>
function Get-NewsFeedItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Feeds,

        [Parameter()]
        [int]$MaxItemsPerFeed = 5
    )

    function Convert-NewsNodeToText {
        param([Parameter()][object]$Node)

        if ($null -eq $Node) {
            return ''
        }

        if ($Node -is [System.Xml.XmlElement]) {
            return $Node.InnerText.Trim()
        }

        if ($Node.PSObject.Properties['#text']) {
            return ([string]$Node.'#text').Trim()
        }

        return ([string]$Node).Trim()
    }

    function Convert-NewsNodeToAnnotation {
        param([Parameter()][object]$Node)

        $raw = Convert-NewsNodeToText -Node $Node
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return ''
        }

        # Popisky ve feedech často obsahují HTML značky (např. <p>, <img>) - pro krátkou
        # anotaci je odstraníme a dekódujeme HTML entity (&amp; apod.).
        $stripped = ($raw -replace '<[^>]+>', ' ') -replace '\s+', ' '
        $decoded = [System.Net.WebUtility]::HtmlDecode($stripped).Trim()

        if ($decoded.Length -gt 220) {
            $decoded = $decoded.Substring(0, 220).TrimEnd() + '…'
        }

        return $decoded
    }

    function Resolve-NewsItemLink {
        param([Parameter(Mandatory = $true)][object]$Entry)

        $link = Convert-NewsNodeToText -Node $Entry.link
        if (-not [string]::IsNullOrWhiteSpace($link)) {
            return $link
        }

        if ($Entry.link -and $Entry.link.href) {
            $atomLink = Convert-NewsNodeToText -Node $Entry.link.href
            if (-not [string]::IsNullOrWhiteSpace($atomLink)) {
                return $atomLink
            }
        }

        if ($Entry.guid) {
            $guidLink = Convert-NewsNodeToText -Node $Entry.guid
            if ($guidLink -match '^https?://') {
                return $guidLink
            }
        }

        return ''
    }

    $items = New-Object System.Collections.Generic.List[object]

    foreach ($feed in $Feeds) {
        $sourceName = [string]$feed.name
        $url = [string]$feed.url

        if ([string]::IsNullOrWhiteSpace($url)) {
            continue
        }

        try {
            [xml]$rss = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).Content
            $feedItems = @()
            if ($rss.rss -and $rss.rss.channel -and $rss.rss.channel.item) {
                $feedItems = @($rss.rss.channel.item | Select-Object -First $MaxItemsPerFeed)
            }
            elseif ($rss.feed -and $rss.feed.entry) {
                $feedItems = @($rss.feed.entry | Select-Object -First $MaxItemsPerFeed)
            }

            foreach ($entry in $feedItems) {
                $published = $null
                if ($entry.pubDate) {
                    try {
                        $published = (Get-Date (Convert-NewsNodeToText -Node $entry.pubDate))
                    }
                    catch {
                        $published = $null
                    }
                }
                elseif ($entry.updated) {
                    try {
                        $published = (Get-Date (Convert-NewsNodeToText -Node $entry.updated))
                    }
                    catch {
                        $published = $null
                    }
                }
                elseif ($entry.published) {
                    try {
                        $published = (Get-Date (Convert-NewsNodeToText -Node $entry.published))
                    }
                    catch {
                        $published = $null
                    }
                }

                $titleText = Convert-NewsNodeToText -Node $entry.title
                $linkText = Resolve-NewsItemLink -Entry $entry
                if ([string]::IsNullOrWhiteSpace($titleText)) {
                    $titleText = '(bez názvu)'
                }

                $descriptionNode = if ($entry.description) { $entry.description }
                    elseif ($entry.summary) { $entry.summary }
                    elseif ($entry.'content:encoded') { $entry.'content:encoded' }
                    elseif ($entry.content) { $entry.content }
                    else { $null }
                $annotationText = Convert-NewsNodeToAnnotation -Node $descriptionNode

                $items.Add([PSCustomObject]@{
                    Source = $sourceName
                    Title = $titleText
                    Link = $linkText
                    Published = $published
                    Description = $annotationText
                })
            }
        }
        catch {
            $items.Add([PSCustomObject]@{
                Source = $sourceName
                Title = ('Chyba načítání feedu: {0}' -f $_.Exception.Message)
                Link = ''
                Published = $null
                Description = ''
            })
        }
    }

    return $items |
        Sort-Object @{ Expression = { if ($null -eq $_.Published) { [datetime]::MinValue } else { $_.Published } }; Descending = $true }
}

<#
.SYNOPSIS
Načte dostupné aktualizace aplikací pomocí wingetu.

.OUTPUTS
System.Collections.Hashtable
#>
function Get-AvailableSoftwareUpdates {
    [CmdletBinding()]
    param()

    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $wingetCmd) {
        return [ordered]@{
            Status = 'winget není dostupný'
            Updates = @()
            RawOutput = 'Příkaz winget nebyl nalezen.'
        }
    }

    try {
        $raw = (winget upgrade --accept-source-agreements --disable-interactivity | Out-String)
    }
    catch {
        return [ordered]@{
            Status = ('Chyba wingetu: {0}' -f $_.Exception.Message)
            Updates = @()
            RawOutput = ''
        }
    }

    $updates = New-Object System.Collections.Generic.List[object]
    $lines = $raw -split "`r?`n"

    # Winget zarovnává sloupce na pevnou šířku znaků (ne vždy 2+ mezerami mezi sloupci),
    # proto se pozice sloupců zjišťují z hlavičky a data se z nich vyřezávají jako substring,
    # aby parsování nezáviselo na počtu mezer mezi hodnotami (např. "v1.0.74 v1.0.75").
    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Name\s+Id\s+Version\s+Available\s+Source\s*$') {
            $headerIndex = $i
            break
        }
    }

    if ($headerIndex -ge 0) {
        $header = $lines[$headerIndex]
        $nameStart = $header.IndexOf('Name')
        $idStart = $header.IndexOf('Id')
        $versionStart = $header.IndexOf('Version')
        $availableStart = $header.IndexOf('Available')
        $sourceStart = $header.IndexOf('Source')

        for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) {
                break
            }
            # Datové řádky tabulky vždy pokrývají i sloupec Source; jakmile řádek
            # nedosahuje této délky, jde už o souhrnný text za tabulkou
            # (např. "2 upgrades available." nebo "N package(s) have..."), a tabulka končí.
            if ($line.Length -lt $sourceStart) {
                break
            }

            $name = $line.Substring($nameStart, $idStart - $nameStart).Trim()
            $id = $line.Substring($idStart, $versionStart - $idStart).Trim()

            if ([string]::IsNullOrWhiteSpace($id)) {
                break
            }

            $current = $line.Substring($versionStart, $availableStart - $versionStart).Trim()
            $available = $line.Substring($availableStart, $sourceStart - $availableStart).Trim()
            $source = $line.Substring($sourceStart).Trim()

            $updates.Add([PSCustomObject]@{
                Name = $name
                Id = $id
                CurrentVersion = $current
                AvailableVersion = $available
                Source = $source
            })
        }
    }

    $status = if ($updates.Count -gt 0) { 'OK' } else { 'Nenalezeny žádné aktualizace nebo se nepodařilo zpracovat výstup' }

    return [ordered]@{
        Status = $status
        Updates = $updates
        RawOutput = $raw.Trim()
    }
}

Export-ModuleMember -Function Get-DashboardConfig, Save-DashboardConfig, Get-WeatherSnapshot, Get-NewsFeedItems, Get-AvailableSoftwareUpdates
