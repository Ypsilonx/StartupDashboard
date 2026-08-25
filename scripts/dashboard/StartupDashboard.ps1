Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Spustí hlavní dashboard s počasím, zprávami a přístupem k systému a softwaru.
#>

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Dashboard.Core.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

<#
.SYNOPSIS
Vrátí ikonu podle teploty.

.PARAMETER TemperatureText
Teplota ve formátu např. "23.1 °C".

.OUTPUTS
System.String
#>
function Get-WeatherIconState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemperatureText
    )

    if ($TemperatureText -match '^-?\d+[\.,]?\d*') {
        $tempNum = [double](($matches[0]) -replace ',', '.')
        if ($tempNum -ge 24) { return 'Sunny' }
        if ($tempNum -ge 12) { return 'Cloudy' }
        return 'Rain'
    }

    return 'Unknown'
}

<#
.SYNOPSIS
Zjistí aktuálně nastavený motiv aplikací ve Windows (světlý/tmavý).

.OUTPUTS
System.String - 'Dark' nebo 'Light'. Při chybě čtení registru (starší Windows apod.) vrací 'Light'.
#>
function Get-SystemThemePreference {
    try {
        $value = Get-ItemPropertyValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop
        if ($value -eq 0) {
            return 'Dark'
        }
        return 'Light'
    }
    catch {
        return 'Light'
    }
}

<#
.SYNOPSIS
Vrátí sadu barev pro zadaný motiv dashboardu.

.PARAMETER Mode
'Light' nebo 'Dark'.

.OUTPUTS
System.Collections.Hashtable
#>
function Get-DashboardThemePalette {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Light', 'Dark')]
        [string]$Mode
    )

    if ($Mode -eq 'Dark') {
        return @{
            FormBack       = [System.Drawing.Color]::FromArgb(30, 32, 36)
            SurfaceAlt     = [System.Drawing.Color]::FromArgb(44, 47, 53)
            TextPrimary    = [System.Drawing.Color]::FromArgb(232, 235, 240)
            TextSecondary  = [System.Drawing.Color]::FromArgb(188, 194, 204)
            TextMuted      = [System.Drawing.Color]::FromArgb(150, 157, 168)
            GridBack       = [System.Drawing.Color]::FromArgb(40, 43, 48)
            GridText       = [System.Drawing.Color]::FromArgb(228, 231, 236)
            GridHeaderBack = [System.Drawing.Color]::FromArgb(56, 60, 68)
            GridHeaderText = [System.Drawing.Color]::FromArgb(232, 235, 240)
            GridLine       = [System.Drawing.Color]::FromArgb(64, 68, 76)
            ButtonBack     = [System.Drawing.Color]::FromArgb(58, 62, 70)
            ButtonText     = [System.Drawing.Color]::FromArgb(232, 235, 240)
        }
    }

    return @{
        FormBack       = [System.Drawing.Color]::FromArgb(242, 246, 251)
        SurfaceAlt     = [System.Drawing.Color]::FromArgb(236, 244, 253)
        TextPrimary    = [System.Drawing.Color]::FromArgb(25, 54, 93)
        TextSecondary  = [System.Drawing.Color]::FromArgb(47, 73, 107)
        TextMuted      = [System.Drawing.Color]::FromArgb(77, 95, 120)
        GridBack       = [System.Drawing.Color]::White
        GridText       = [System.Drawing.Color]::Black
        GridHeaderBack = [System.Drawing.Color]::FromArgb(230, 236, 245)
        GridHeaderText = [System.Drawing.Color]::FromArgb(25, 54, 93)
        GridLine       = [System.Drawing.Color]::FromArgb(210, 218, 228)
        ButtonBack     = [System.Drawing.Color]::FromArgb(240, 243, 247)
        ButtonText     = [System.Drawing.Color]::Black
    }
}

<#
.SYNOPSIS
Otevře seznam aplikací s dostupnými aktualizacemi a umožní spustit upgrade pro každou z nich.

.OUTPUTS
System.Void
#>
function Show-SoftwareWindow {
    # Okno se otevírá znovu při každém kliknutí, stačí tedy přečíst aktuální paletu jednou při
    # sestavení - na rozdíl od hlavního okna zde nepotřebujeme přepínač měnit za běhu.
    $palette = Get-DashboardThemePalette -Mode $script:CurrentThemeMode

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Software - aktualizace'
    $form.StartPosition = 'CenterParent'
    $form.Size = New-Object System.Drawing.Size(1120, 720)
    $form.MinimumSize = New-Object System.Drawing.Size(900, 560)
    $form.BackColor = $palette.FormBack

    $gridUpdates = New-Object System.Windows.Forms.DataGridView
    $gridUpdates.Dock = 'Fill'
    $gridUpdates.ReadOnly = $true
    $gridUpdates.AutoGenerateColumns = $false
    $gridUpdates.AllowUserToAddRows = $false
    $gridUpdates.AllowUserToDeleteRows = $false
    $gridUpdates.SelectionMode = 'FullRowSelect'
    $gridUpdates.MultiSelect = $false
    $gridUpdates.RowHeadersVisible = $false
    $gridUpdates.AllowUserToResizeRows = $false
    $gridUpdates.AutoSizeColumnsMode = 'None'
    $gridUpdates.BackgroundColor = $palette.GridBack
    $gridUpdates.GridColor = $palette.GridLine
    $gridUpdates.DefaultCellStyle.BackColor = $palette.GridBack
    $gridUpdates.DefaultCellStyle.ForeColor = $palette.GridText
    $gridUpdates.DefaultCellStyle.SelectionBackColor = $palette.GridHeaderBack
    $gridUpdates.DefaultCellStyle.SelectionForeColor = $palette.GridText
    $gridUpdates.ColumnHeadersDefaultCellStyle.BackColor = $palette.GridHeaderBack
    $gridUpdates.ColumnHeadersDefaultCellStyle.ForeColor = $palette.GridHeaderText

    $colId = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colId.Name = 'Id'
    $colId.HeaderText = 'Id'
    $colId.Visible = $false

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.Name = 'Name'
    $colName.HeaderText = 'Aplikace'
    $colName.AutoSizeMode = 'Fill'
    $colName.MinimumWidth = 240

    $colCurrent = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colCurrent.Name = 'CurrentVersion'
    $colCurrent.HeaderText = 'Původní verze'
    $colCurrent.Width = 140

    $colAvailable = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAvailable.Name = 'AvailableVersion'
    $colAvailable.HeaderText = 'Nová verze'
    $colAvailable.Width = 140

    $colSource = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colSource.Name = 'Source'
    $colSource.HeaderText = 'Zdroj'
    $colSource.Width = 100

    $colUpgrade = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colUpgrade.Name = 'UpgradeAction'
    $colUpgrade.HeaderText = ''
    $colUpgrade.Text = 'Upgradovat'
    $colUpgrade.UseColumnTextForButtonValue = $true
    $colUpgrade.Width = 140
    $colUpgrade.FlatStyle = [System.Windows.Forms.FlatStyle]::System

    [void]$gridUpdates.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@(
        $colId,
        $colName,
        $colCurrent,
        $colAvailable,
        $colSource,
        $colUpgrade
    ))

    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock = 'Top'
    $topPanel.Height = 62
    $topPanel.BackColor = $palette.FormBack

    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = 'Obnovit software'
    $refreshButton.Location = New-Object System.Drawing.Point(12, 10)
    $refreshButton.Size = New-Object System.Drawing.Size(140, 30)
    $refreshButton.BackColor = $palette.ButtonBack
    $refreshButton.ForeColor = $palette.ButtonText

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = 'Zavřít'
    $closeButton.Location = New-Object System.Drawing.Point(990, 10)
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $closeButton.Anchor = 'Top,Right'
    $closeButton.BackColor = $palette.ButtonBack
    $closeButton.ForeColor = $palette.ButtonText

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = 'Stav: připraveno'
    $statusLabel.Location = New-Object System.Drawing.Point(170, 12)
    $statusLabel.Size = New-Object System.Drawing.Size(810, 22)
    $statusLabel.ForeColor = $palette.TextSecondary

    # Winget vrací výstup až po doběhnutí celého příkazu, takže nejde zjistit reálné procento
    # průběhu - marquee styl aspoň jasně ukáže, že se něco děje, a v jaké fázi (viz statusLabel).
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $progressBar.MarqueeAnimationSpeed = 30
    $progressBar.Location = New-Object System.Drawing.Point(170, 38)
    $progressBar.Size = New-Object System.Drawing.Size(810, 10)
    $progressBar.Visible = $false

    $refreshUpdates = {
        try {
            $statusLabel.Text = 'Stav: načítám dostupné aktualizace...'
            $progressBar.Visible = $true
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

            $updatesInfo = Get-AvailableSoftwareUpdates

            $gridUpdates.Rows.Clear()
            foreach ($update in $updatesInfo.Updates) {
                $rowIndex = $gridUpdates.Rows.Add()
                $row = $gridUpdates.Rows[$rowIndex]
                $row.Cells['Id'].Value = [string]$update.Id
                $row.Cells['Name'].Value = [string]$update.Name
                $row.Cells['CurrentVersion'].Value = [string]$update.CurrentVersion
                $row.Cells['AvailableVersion'].Value = [string]$update.AvailableVersion
                $row.Cells['Source'].Value = [string]$update.Source
                $row.Cells['UpgradeAction'].Value = 'Upgradovat'
            }

            if ($gridUpdates.Rows.Count -eq 0) {
                $statusLabel.Text = ('Stav: {0}' -f $updatesInfo.Status)
            }
            else {
                $statusLabel.Text = ('Stav: nalezeno {0} aktualizací' -f $gridUpdates.Rows.Count)
            }

            if ($gridUpdates.Columns['Name']) {
                $gridUpdates.Columns['Name'].AutoSizeMode = 'Fill'
            }
        }
        catch {
            $statusLabel.Text = ('Stav: chyba při načítání software - {0}' -f $_.Exception.Message)
            [System.Windows.Forms.MessageBox]::Show(
                ("Nepodařilo se načíst aktualizace software.`n`n{0}" -f $_.Exception.Message),
                'Software',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $progressBar.Visible = $false
            $gridUpdates.ClearSelection()
        }
    }

    $gridUpdates.Add_CellContentClick({
        param($sender, $e)

        if ($e.RowIndex -lt 0) {
            return
        }

        if ($sender.Columns[$e.ColumnIndex].Name -ne 'UpgradeAction') {
            return
        }

        $row = $sender.Rows[$e.RowIndex]
        $appId = [string]$row.Cells['Id'].Value
        $appName = [string]$row.Cells['Name'].Value

        if ([string]::IsNullOrWhiteSpace($appId)) {
            [System.Windows.Forms.MessageBox]::Show(
                'U této aplikace chybí identifikátor pro winget upgrade.',
                'Software',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            ('Spustit upgrade pro "{0}"?' -f $appName),
            'Software',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($null -eq $wingetCmd) {
            [System.Windows.Forms.MessageBox]::Show(
                'winget není k dispozici, upgrade nelze spustit.',
                'Software',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        try {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $progressBar.Visible = $true
            $statusLabel.Text = ('Stav: aktualizuji {0}...' -f $appName)

            $null = & winget upgrade --id $appId --exact --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                throw ('winget vrátil chybový kód {0}' -f $LASTEXITCODE)
            }
            $statusLabel.Text = ('Stav: upgrade pro {0} dokončen' -f $appName)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                ("Upgrade pro {0} selhal.`n`n{1}" -f $appName, $_.Exception.Message),
                'Software',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            & $refreshUpdates
        }
    })

    $refreshAction = {
        & $refreshUpdates
    }

    $refreshButton.Add_Click($refreshAction)
    $closeButton.Add_Click({ $form.Close() })

    [void]$topPanel.Controls.Add($refreshButton)
    [void]$topPanel.Controls.Add($closeButton)
    [void]$topPanel.Controls.Add($statusLabel)
    [void]$topPanel.Controls.Add($progressBar)

    [void]$form.Controls.Add($gridUpdates)
    [void]$form.Controls.Add($topPanel)

    $form.Add_Shown({
        $form.ActiveControl = $refreshButton
    })

    & $refreshAction
    [void]$form.ShowDialog()
}

<#
.SYNOPSIS
Otevře dialog pro přidání aplikace do panelu rychlého spuštění.

.OUTPUTS
System.Management.Automation.PSCustomObject se jmény vlastností name/path, nebo $null při zrušení.
#>
function Show-AddQuickAppDialog {
    $palette = Get-DashboardThemePalette -Mode $script:CurrentThemeMode

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Přidat aplikaci'
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.Size = New-Object System.Drawing.Size(460, 190)
    $dialog.BackColor = $palette.FormBack

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = 'Název:'
    $nameLabel.Location = New-Object System.Drawing.Point(12, 18)
    $nameLabel.Size = New-Object System.Drawing.Size(80, 22)
    $nameLabel.ForeColor = $palette.TextSecondary

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Location = New-Object System.Drawing.Point(100, 15)
    $nameBox.Size = New-Object System.Drawing.Size(330, 22)
    $nameBox.BackColor = $palette.GridBack
    $nameBox.ForeColor = $palette.GridText

    $pathLabel = New-Object System.Windows.Forms.Label
    $pathLabel.Text = 'Cesta:'
    $pathLabel.Location = New-Object System.Drawing.Point(12, 52)
    $pathLabel.Size = New-Object System.Drawing.Size(80, 22)
    $pathLabel.ForeColor = $palette.TextSecondary

    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Location = New-Object System.Drawing.Point(100, 49)
    $pathBox.Size = New-Object System.Drawing.Size(250, 22)
    $pathBox.BackColor = $palette.GridBack
    $pathBox.ForeColor = $palette.GridText

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Text = 'Procházet...'
    $browseButton.Location = New-Object System.Drawing.Point(358, 47)
    $browseButton.Size = New-Object System.Drawing.Size(72, 26)
    $browseButton.BackColor = $palette.ButtonBack
    $browseButton.ForeColor = $palette.ButtonText

    $browseButton.Add_Click({
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Filter = 'Aplikace a zástupci (*.exe;*.lnk)|*.exe;*.lnk|Všechny soubory (*.*)|*.*'
        if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $pathBox.Text = $openDialog.FileName
            if ([string]::IsNullOrWhiteSpace($nameBox.Text)) {
                $nameBox.Text = [System.IO.Path]::GetFileNameWithoutExtension($openDialog.FileName)
            }
        }
    })

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'Přidat'
    $okButton.Location = New-Object System.Drawing.Point(254, 116)
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.BackColor = $palette.ButtonBack
    $okButton.ForeColor = $palette.ButtonText

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Zrušit'
    $cancelButton.Location = New-Object System.Drawing.Point(350, 116)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.BackColor = $palette.ButtonBack
    $cancelButton.ForeColor = $palette.ButtonText

    [void]$dialog.Controls.AddRange(@($nameLabel, $nameBox, $pathLabel, $pathBox, $browseButton, $okButton, $cancelButton))
    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($nameBox.Text) -or [string]::IsNullOrWhiteSpace($pathBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Vyplň název i cestu k aplikaci.',
            'Přidat aplikaci',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return $null
    }

    return [PSCustomObject]@{
        name = $nameBox.Text.Trim()
        path = $pathBox.Text.Trim()
    }
}

$localConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'DashboardConfig.local.json'
if (Test-Path -LiteralPath $localConfigPath) {
    $config = Get-DashboardConfig -ConfigPath $localConfigPath
    $script:ActiveConfigPath = $localConfigPath
}
else {
    $config = Get-DashboardConfig
    $script:ActiveConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'DashboardConfig.json'
}
$location = $config.location

$script:QuickApps = New-Object System.Collections.Generic.List[object]
foreach ($quickApp in @($config.quickApps)) {
    if ($null -eq $quickApp) {
        continue
    }
    $script:QuickApps.Add([PSCustomObject]@{ name = [string]$quickApp.name; path = [string]$quickApp.path })
}
$weatherState = 'Unknown'

# Světlý/tmavý motiv se při startu odvodí z aktuálního nastavení Windows (Nastavení > Barvy) -
# pokud tam máš nastavené automatické přepínání v určitou hodinu, dashboard to při každém
# spuštění zohlední bez vlastního časovače. Ručně jde přepnout tlačítkem ☀/☾ v hlavičce.
$script:CurrentThemeMode = Get-SystemThemePreference
$script:Palette = Get-DashboardThemePalette -Mode $script:CurrentThemeMode
$script:NewsRowTextColor = $script:Palette.GridText

# Průhlednost okna (0.0 = neviditelné, 1.0 = plně neprůhledné) - uprav podle vlastního vkusu.
$dashboardOpacity = 0.94

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Můj startup dashboard'
$form.StartPosition = 'CenterScreen'
# Bez systémového rámečku (žádný titulek/okraj OS) - vlastní hlavička, tažení a ovládací
# tlačítka se řeší níž na $headerPanel; okno proto má i pevnou velikost (bez resize úchytů).
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size(1260, 780)
$form.BackColor = $script:Palette.FormBack
$form.AutoScaleMode = 'Dpi'
$form.Opacity = $dashboardOpacity

$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = 'Fill'
$mainPanel.Padding = New-Object System.Windows.Forms.Padding(14)
$mainPanel.BackColor = $script:Palette.FormBack

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = 'Top'
$headerPanel.Height = 100

$headerPanel.Add_Paint({
    param($sender, $e)

    $rect = $sender.ClientRectangle
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(24, 66, 125),
        [System.Drawing.Color]::FromArgb(54, 118, 189),
        0
    )
    $e.Graphics.FillRectangle($brush, $rect)
    $brush.Dispose()

    $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $sunBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 201, 66))
    $cloudBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(224, 235, 248))
    $e.Graphics.FillEllipse($sunBrush, $rect.Width - 108, 14, 60, 60)
    $e.Graphics.FillEllipse($cloudBrush, $rect.Width - 155, 44, 58, 30)
    $e.Graphics.FillEllipse($cloudBrush, $rect.Width - 120, 38, 66, 34)
    $sunBrush.Dispose()
    $cloudBrush.Dispose()
})

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'Můj startup dashboard'
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.BackColor = [System.Drawing.Color]::Transparent
$titleLabel.Location = New-Object System.Drawing.Point(16, 14)
$titleLabel.Size = New-Object System.Drawing.Size(400, 34)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = 'Počasí, předpověď, zprávy, systém a software na jednom místě'
$subtitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(221, 236, 255)
$subtitleLabel.BackColor = [System.Drawing.Color]::Transparent
$subtitleLabel.Location = New-Object System.Drawing.Point(18, 50)
$subtitleLabel.Size = New-Object System.Drawing.Size(680, 24)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = 'Stav: připraveno'
$statusLabel.AutoSize = $false
$statusLabel.BackColor = [System.Drawing.Color]::Transparent
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(221, 236, 255)
$statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$statusLabel.Location = New-Object System.Drawing.Point(18, 72)
$statusLabel.Size = New-Object System.Drawing.Size(760, 20)

# Vlastní ovládací tlačítka (bez systémového rámečku chybí Windows titulek s min/close).
# Pozor: nejde je umisťovat na pevné X - headerPanel je zúžený o Padding(14) na $mainPanel,
# takže reálná šířka není 1260, ale ~1232. Proto FlowLayoutPanel dokovaný doprava, který se
# šířce vždy přizpůsobí sám, místo ručního výpočtu souřadnic.
$headerControlsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$headerControlsPanel.Dock = 'Right'
$headerControlsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$headerControlsPanel.AutoSize = $true
$headerControlsPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$headerControlsPanel.BackColor = [System.Drawing.Color]::Transparent
$headerControlsPanel.Padding = New-Object System.Windows.Forms.Padding(0, 12, 12, 0)

$minimizeButton = New-Object System.Windows.Forms.Button
$minimizeButton.Text = '–'
$minimizeButton.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$minimizeButton.ForeColor = [System.Drawing.Color]::White
$minimizeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$minimizeButton.FlatAppearance.BorderSize = 0
$minimizeButton.BackColor = [System.Drawing.Color]::FromArgb(54, 118, 189)
$minimizeButton.Size = New-Object System.Drawing.Size(30, 26)
$minimizeButton.Margin = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)
$minimizeButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$headerCloseButton = New-Object System.Windows.Forms.Button
$headerCloseButton.Text = '✕'
$headerCloseButton.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$headerCloseButton.ForeColor = [System.Drawing.Color]::White
$headerCloseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$headerCloseButton.FlatAppearance.BorderSize = 0
$headerCloseButton.BackColor = [System.Drawing.Color]::FromArgb(200, 60, 60)
$headerCloseButton.Size = New-Object System.Drawing.Size(30, 26)
$headerCloseButton.Cursor = [System.Windows.Forms.Cursors]::Hand

# Ruční přepínač motivu - ikona ukazuje AKTUÁLNĚ aktivní režim (☀ světlý / ☾ tmavý), klik přepne.
$themeToggleButton = New-Object System.Windows.Forms.Button
$themeToggleButton.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$themeToggleButton.ForeColor = [System.Drawing.Color]::White
$themeToggleButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$themeToggleButton.FlatAppearance.BorderSize = 0
$themeToggleButton.BackColor = [System.Drawing.Color]::FromArgb(54, 118, 189)
$themeToggleButton.Size = New-Object System.Drawing.Size(30, 26)
$themeToggleButton.Margin = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)
$themeToggleButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$themeToggleButton.Text = if ($script:CurrentThemeMode -eq 'Dark') { '☾' } else { '☀' }

$minimizeButton.Add_Click({ $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })
$headerCloseButton.Add_Click({ $form.Close() })
$themeToggleButton.Add_Click({
    $script:CurrentThemeMode = if ($script:CurrentThemeMode -eq 'Dark') { 'Light' } else { 'Dark' }
    $script:Palette = Get-DashboardThemePalette -Mode $script:CurrentThemeMode
    $themeToggleButton.Text = if ($script:CurrentThemeMode -eq 'Dark') { '☾' } else { '☀' }
    & $applyDashboardTheme
})

# V RightToLeft flow se první přidaný ovládací prvek umístí úplně vpravo - proto Zavřít první.
[void]$headerControlsPanel.Controls.Add($headerCloseButton)
[void]$headerControlsPanel.Controls.Add($minimizeButton)
[void]$headerControlsPanel.Controls.Add($themeToggleButton)

[void]$headerPanel.Controls.Add($titleLabel)
[void]$headerPanel.Controls.Add($subtitleLabel)
[void]$headerPanel.Controls.Add($statusLabel)
[void]$headerPanel.Controls.Add($headerControlsPanel)

# Okno bez rámečku nejde přesouvat systémovým titulkem - tažením za hlavičku (mimo tlačítka)
# přepočítáváme polohu formuláře ručně, bez volání Windows API. Explicitní Capture zajistí,
# že se tažení nepřeruší, i když kurzor při rychlém pohybu na okamžik opustí hlavičku.
$script:IsDraggingWindow = $false
$script:DragCursorStart = New-Object System.Drawing.Point(0, 0)
$script:DragFormStart = New-Object System.Drawing.Point(0, 0)

$beginWindowDrag = {
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:IsDraggingWindow = $true
        $script:DragCursorStart = [System.Windows.Forms.Cursor]::Position
        $script:DragFormStart = $form.Location
        $sender.Capture = $true
    }
}
$moveWindowDrag = {
    if ($script:IsDraggingWindow) {
        $cursorNow = [System.Windows.Forms.Cursor]::Position
        $deltaX = $cursorNow.X - $script:DragCursorStart.X
        $deltaY = $cursorNow.Y - $script:DragCursorStart.Y
        $form.Location = New-Object System.Drawing.Point(($script:DragFormStart.X + $deltaX), ($script:DragFormStart.Y + $deltaY))
    }
}
$endWindowDrag = {
    param($sender, $e)
    $script:IsDraggingWindow = $false
    $sender.Capture = $false
}

foreach ($dragSource in @($headerPanel, $titleLabel, $subtitleLabel)) {
    $dragSource.Cursor = [System.Windows.Forms.Cursors]::SizeAll
    $dragSource.Add_MouseDown($beginWindowDrag)
    $dragSource.Add_MouseMove($moveWindowDrag)
    $dragSource.Add_MouseUp($endWindowDrag)
}

$bodyLayout = New-Object System.Windows.Forms.TableLayoutPanel
$bodyLayout.Dock = 'Fill'
$bodyLayout.BackColor = [System.Drawing.Color]::Transparent
$bodyLayout.ColumnCount = 2
$bodyLayout.RowCount = 1
$bodyLayout.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 10)
[void]$bodyLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 44)))
[void]$bodyLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 56)))

$weatherGroup = New-Object System.Windows.Forms.GroupBox
$weatherGroup.Text = ('Počasí a předpověď ({0})' -f $location.name)
$weatherGroup.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$weatherGroup.Dock = 'Fill'
$weatherGroup.BackColor = [System.Drawing.Color]::Transparent

$weatherLayout = New-Object System.Windows.Forms.TableLayoutPanel
$weatherLayout.Dock = 'Fill'
$weatherLayout.BackColor = [System.Drawing.Color]::Transparent
$weatherLayout.RowCount = 4
$weatherLayout.ColumnCount = 1
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 110)))
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 120)))
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 170)))
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

$weatherCurrentPanel = New-Object System.Windows.Forms.Panel
$weatherCurrentPanel.Dock = 'Fill'
$weatherCurrentPanel.BackColor = $script:Palette.SurfaceAlt

$weatherCurrentPanel.Add_Paint({
    param($sender, $e)

    $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    switch ($weatherState) {
        'Sunny' {
            $sunBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 195, 56))
            $e.Graphics.FillEllipse($sunBrush, 16, 14, 64, 64)
            $sunBrush.Dispose()
        }
        'Cloudy' {
            $cloudBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(184, 203, 223))
            $e.Graphics.FillEllipse($cloudBrush, 22, 30, 34, 24)
            $e.Graphics.FillEllipse($cloudBrush, 43, 26, 40, 30)
            $e.Graphics.FillEllipse($cloudBrush, 68, 34, 26, 18)
            $cloudBrush.Dispose()
        }
        'Rain' {
            $cloudBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(167, 187, 209))
            $rainBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 146, 228))
            $e.Graphics.FillEllipse($cloudBrush, 24, 24, 56, 34)
            $e.Graphics.FillEllipse($cloudBrush, 58, 30, 32, 24)
            $e.Graphics.FillRectangle($rainBrush, 34, 56, 4, 16)
            $e.Graphics.FillRectangle($rainBrush, 48, 56, 4, 16)
            $e.Graphics.FillRectangle($rainBrush, 62, 56, 4, 16)
            $cloudBrush.Dispose()
            $rainBrush.Dispose()
        }
        default {
            $neutralBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(167, 177, 194))
            $e.Graphics.FillEllipse($neutralBrush, 20, 20, 56, 56)
            $neutralBrush.Dispose()
        }
    }
})

$lblTemp = New-Object System.Windows.Forms.Label
$lblTemp.Text = 'Teplota: --'
$lblTemp.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$lblTemp.ForeColor = $script:Palette.TextPrimary
$lblTemp.Location = New-Object System.Drawing.Point(110, 14)
$lblTemp.Size = New-Object System.Drawing.Size(370, 32)

$lblCondition = New-Object System.Windows.Forms.Label
$lblCondition.Text = 'Stav: --'
$lblCondition.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$lblCondition.ForeColor = $script:Palette.TextSecondary
$lblCondition.Location = New-Object System.Drawing.Point(112, 50)
$lblCondition.Size = New-Object System.Drawing.Size(430, 22)

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Text = 'Aktualizace: --'
$lblTime.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$lblTime.ForeColor = $script:Palette.TextMuted
$lblTime.Location = New-Object System.Drawing.Point(112, 74)
$lblTime.Size = New-Object System.Drawing.Size(430, 22)

[void]$weatherCurrentPanel.Controls.Add($lblTemp)
[void]$weatherCurrentPanel.Controls.Add($lblCondition)
[void]$weatherCurrentPanel.Controls.Add($lblTime)

$weatherDetails = New-Object System.Windows.Forms.TextBox
$weatherDetails.Multiline = $true
$weatherDetails.ReadOnly = $true
$weatherDetails.ScrollBars = 'Vertical'
$weatherDetails.WordWrap = $false
$weatherDetails.Dock = 'Fill'
$weatherDetails.Font = New-Object System.Drawing.Font('Consolas', 10)
$weatherDetails.HideSelection = $true
$weatherDetails.TabStop = $false
$weatherDetails.Cursor = [System.Windows.Forms.Cursors]::Arrow
$weatherDetails.BackColor = $script:Palette.SurfaceAlt
$weatherDetails.ForeColor = $script:Palette.TextSecondary

# AutoGenerateColumns nefungovalo, protože DataGridView neumí odvodit sloupce z pole
# PSCustomObject (nemá reflexí viditelné CLR vlastnosti) - proto sloupce ručně a řádky
# plníme přes Rows.Add, stejně jako $gridUpdates výš v Show-SoftwareWindow.
$forecastGrid = New-Object System.Windows.Forms.DataGridView
$forecastGrid.Dock = 'Fill'
$forecastGrid.ReadOnly = $true
$forecastGrid.AutoGenerateColumns = $false
$forecastGrid.AllowUserToAddRows = $false
$forecastGrid.AllowUserToDeleteRows = $false
$forecastGrid.RowHeadersVisible = $false
$forecastGrid.SelectionMode = 'FullRowSelect'
# BorderStyle None - jinak tabulka měla svůj vlastní 3D okraj navíc k rámečku GroupBoxu kolem
# a vypadalo to jako "box v boxu" se zbytečnou mezerou; takhle splyne s okolní plochou.
$forecastGrid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$forecastGrid.CellBorderStyle = [System.Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
$forecastGrid.ColumnHeadersBorderStyle = [System.Windows.Forms.DataGridViewHeaderBorderStyle]::None
$forecastGrid.BackgroundColor = $script:Palette.GridBack

# SortMode NotSortable - je to statický 3denní přehled v chronologickém pořadí, kliknutím na
# hlavičku by šel řádky přeskládat abecedně podle textu ve sloupci, což pořadí dnů jen rozhodí.
$colFcDate = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colFcDate.Name = 'Date'
$colFcDate.HeaderText = 'Den'
$colFcDate.Width = 90
$colFcDate.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

$colFcCondition = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colFcCondition.Name = 'Condition'
$colFcCondition.HeaderText = 'Stav'
$colFcCondition.AutoSizeMode = 'Fill'
$colFcCondition.MinimumWidth = 110
$colFcCondition.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

$colFcMin = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colFcMin.Name = 'Min'
$colFcMin.HeaderText = 'Min'
$colFcMin.Width = 70
$colFcMin.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

$colFcMax = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colFcMax.Name = 'Max'
$colFcMax.HeaderText = 'Max'
$colFcMax.Width = 70
$colFcMax.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

$colFcRain = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colFcRain.Name = 'RainChance'
$colFcRain.HeaderText = 'Srážky'
$colFcRain.Width = 80
$colFcRain.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

[void]$forecastGrid.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@(
    $colFcDate, $colFcCondition, $colFcMin, $colFcMax, $colFcRain
))

$forecastGrid.DefaultCellStyle.BackColor = $script:Palette.GridBack
$forecastGrid.DefaultCellStyle.ForeColor = $script:Palette.GridText
$forecastGrid.ColumnHeadersDefaultCellStyle.BackColor = $script:Palette.GridHeaderBack
$forecastGrid.ColumnHeadersDefaultCellStyle.ForeColor = $script:Palette.GridHeaderText
$forecastGrid.GridColor = $script:Palette.GridLine

# Je to jen statický přehled k přečtení, ne interaktivní výběr - zvýrazňování vybrané
# buňky/řádku by tu nemělo žádný smysl, proto se výběr po kliknutí hned zruší.
$forecastGrid.DefaultCellStyle.SelectionBackColor = $script:Palette.GridBack
$forecastGrid.DefaultCellStyle.SelectionForeColor = $script:Palette.GridText
$forecastGrid.Add_SelectionChanged({ $forecastGrid.ClearSelection() })

# Panel s ikonami vybraných aplikací - žije ve stejném sloupci jako počasí, pod předpovědí,
# v prostoru, který byl dřív jen prázdný (viz komentář u $forecastGrid výš).
$quickAppsSection = New-Object System.Windows.Forms.Panel
$quickAppsSection.Dock = 'Fill'
$quickAppsSection.BackColor = $script:Palette.SurfaceAlt
$quickAppsSection.Padding = New-Object System.Windows.Forms.Padding(8, 8, 8, 4)

$quickAppsHeaderRow = New-Object System.Windows.Forms.Panel
$quickAppsHeaderRow.Dock = 'Top'
$quickAppsHeaderRow.Height = 28
$quickAppsHeaderRow.BackColor = [System.Drawing.Color]::Transparent

$quickAppsLabel = New-Object System.Windows.Forms.Label
$quickAppsLabel.Text = 'Rychlé spuštění'
$quickAppsLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$quickAppsLabel.ForeColor = $script:Palette.TextSecondary
$quickAppsLabel.BackColor = [System.Drawing.Color]::Transparent
$quickAppsLabel.Dock = 'Left'
$quickAppsLabel.AutoSize = $true
$quickAppsLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$addQuickAppButton = New-Object System.Windows.Forms.Button
$addQuickAppButton.Text = '+ Přidat'
$addQuickAppButton.Dock = 'Right'
$addQuickAppButton.Size = New-Object System.Drawing.Size(90, 26)
$addQuickAppButton.BackColor = $script:Palette.ButtonBack
$addQuickAppButton.ForeColor = $script:Palette.ButtonText

[void]$quickAppsHeaderRow.Controls.Add($quickAppsLabel)
[void]$quickAppsHeaderRow.Controls.Add($addQuickAppButton)

$quickAppsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$quickAppsPanel.Dock = 'Fill'
$quickAppsPanel.BackColor = [System.Drawing.Color]::Transparent
$quickAppsPanel.FlowDirection = 'LeftToRight'
$quickAppsPanel.WrapContents = $true
$quickAppsPanel.AutoScroll = $true

[void]$quickAppsSection.Controls.Add($quickAppsPanel)
[void]$quickAppsSection.Controls.Add($quickAppsHeaderRow)

[void]$weatherLayout.Controls.Add($weatherCurrentPanel, 0, 0)
[void]$weatherLayout.Controls.Add($weatherDetails, 0, 1)
[void]$weatherLayout.Controls.Add($forecastGrid, 0, 2)
[void]$weatherLayout.Controls.Add($quickAppsSection, 0, 3)
[void]$weatherGroup.Controls.Add($weatherLayout)

$newsGroup = New-Object System.Windows.Forms.GroupBox
$newsGroup.Text = 'Zpravodajský kanál'
$newsGroup.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$newsGroup.Dock = 'Fill'
$newsGroup.BackColor = [System.Drawing.Color]::Transparent

$newsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$newsLayout.Dock = 'Fill'
$newsLayout.BackColor = [System.Drawing.Color]::Transparent
$newsLayout.RowCount = 3
$newsLayout.ColumnCount = 1
[void]$newsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$newsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 66)))
[void]$newsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

$newsList = New-Object System.Windows.Forms.ListView
$newsList.Dock = 'Fill'
$newsList.View = 'Details'
$newsList.FullRowSelect = $true
$newsList.GridLines = $true
$newsList.HideSelection = $false
$newsList.MultiSelect = $false
$newsList.Activation = [System.Windows.Forms.ItemActivation]::Standard
$newsList.HotTracking = $false
$newsList.HoverSelection = $false
$newsList.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$newsList.BackColor = $script:Palette.GridBack
$newsList.ForeColor = $script:Palette.GridText
$newsList.Columns.Add('Zdroj', 130) | Out-Null
$newsList.Columns.Add('Titulek', 400) | Out-Null
$newsList.Columns.Add('Publikováno', 130) | Out-Null

$newsPreviewPanel = New-Object System.Windows.Forms.Panel
$newsPreviewPanel.Dock = 'Fill'
$newsPreviewPanel.BackColor = $script:Palette.SurfaceAlt
$newsPreviewPanel.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)

$newsPreviewLabel = New-Object System.Windows.Forms.Label
$newsPreviewLabel.Dock = 'Fill'
$newsPreviewLabel.AutoSize = $false
$newsPreviewLabel.BackColor = [System.Drawing.Color]::Transparent
$newsPreviewLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$newsPreviewLabel.ForeColor = $script:Palette.TextSecondary
$newsPreviewLabel.Text = 'Vyber zprávu pro zobrazení anotace.'

[void]$newsPreviewPanel.Controls.Add($newsPreviewLabel)

$newsCachePath = Join-Path -Path $PSScriptRoot -ChildPath 'NewsCache.json'
$script:AllNewsItems = @()
$script:NewsFilterState = [ordered]@{}
$script:HoveredNewsItem = $null
$isUpdatingNewsFilter = $false
$sourceFilterCheckBoxes = New-Object System.Collections.Generic.List[System.Windows.Forms.CheckBox]

$newsFooterLayout = New-Object System.Windows.Forms.TableLayoutPanel
$newsFooterLayout.Dock = 'Fill'
$newsFooterLayout.BackColor = [System.Drawing.Color]::Transparent
$newsFooterLayout.ColumnCount = 1
$newsFooterLayout.RowCount = 2
[void]$newsFooterLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$newsFooterLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42)))
$newsFooterLayout.AutoSize = $true
$newsFooterLayout.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

$newsFilterSection = New-Object System.Windows.Forms.TableLayoutPanel
$newsFilterSection.Dock = 'Top'
$newsFilterSection.BackColor = [System.Drawing.Color]::Transparent
$newsFilterSection.AutoSize = $true
$newsFilterSection.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$newsFilterSection.ColumnCount = 1
$newsFilterSection.RowCount = 2
[void]$newsFilterSection.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$newsFilterSection.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = 'Filtr zdrojů:'
$filterLabel.AutoSize = $true
$filterLabel.BackColor = [System.Drawing.Color]::Transparent
$filterLabel.ForeColor = $script:Palette.TextSecondary
$filterLabel.Margin = New-Object System.Windows.Forms.Padding(8, 8, 8, 4)

$newsFilterGrid = New-Object System.Windows.Forms.TableLayoutPanel
$newsFilterGrid.Dock = 'Fill'
$newsFilterGrid.BackColor = [System.Drawing.Color]::Transparent
$newsFilterGrid.AutoSize = $true
$newsFilterGrid.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$newsFilterGrid.ColumnCount = 3
$newsFilterGrid.RowCount = 3
$newsFilterGrid.GrowStyle = [System.Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize
[void]$newsFilterGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.34)))
[void]$newsFilterGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
[void]$newsFilterGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
[void]$newsFilterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$newsFilterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$newsFilterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

$allSourcesCheckBox = New-Object System.Windows.Forms.CheckBox
$allSourcesCheckBox.Text = 'ALL'
$allSourcesCheckBox.Checked = $true
$allSourcesCheckBox.AutoSize = $true
$allSourcesCheckBox.BackColor = [System.Drawing.Color]::Transparent
$allSourcesCheckBox.ForeColor = $script:Palette.TextSecondary
$allSourcesCheckBox.Margin = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
$allSourcesCheckBox.Anchor = 'Left'

$newsButtonPanel = New-Object System.Windows.Forms.Panel
$newsButtonPanel.Dock = 'Fill'
$newsButtonPanel.BackColor = [System.Drawing.Color]::Transparent
$newsButtonPanel.Height = 42

$openNewsButton = New-Object System.Windows.Forms.Button
$openNewsButton.Text = 'Otevřít článek'
$openNewsButton.Location = New-Object System.Drawing.Point(10, 6)
$openNewsButton.Size = New-Object System.Drawing.Size(120, 30)
$openNewsButton.BackColor = $script:Palette.ButtonBack
$openNewsButton.ForeColor = $script:Palette.ButtonText

$refreshNewsButton = New-Object System.Windows.Forms.Button
$refreshNewsButton.Text = 'Obnovit zprávy'
$refreshNewsButton.Location = New-Object System.Drawing.Point(140, 6)
$refreshNewsButton.Size = New-Object System.Drawing.Size(130, 30)
$refreshNewsButton.BackColor = $script:Palette.ButtonBack
$refreshNewsButton.ForeColor = $script:Palette.ButtonText

[void]$newsButtonPanel.Controls.Add($openNewsButton)
[void]$newsButtonPanel.Controls.Add($refreshNewsButton)

$filterCells = @()
$filterCells += $allSourcesCheckBox

$configuredSources = @($config.newsFeeds | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
foreach ($sourceName in $configuredSources) {
    $sourceCheckBox = New-Object System.Windows.Forms.CheckBox
    $sourceCheckBox.Text = $sourceName
    $sourceCheckBox.AutoSize = $true
    $sourceCheckBox.BackColor = [System.Drawing.Color]::Transparent
    $sourceCheckBox.ForeColor = $script:Palette.TextSecondary
    $sourceCheckBox.Margin = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
    $sourceCheckBox.Anchor = 'Left'
    [void]$sourceFilterCheckBoxes.Add($sourceCheckBox)
    $filterCells += $sourceCheckBox
}

for ($index = 0; $index -lt $filterCells.Count; $index++) {
    $row = [int]([Math]::Floor($index / 3))
    $col = [int]($index % 3)
    [void]$newsFilterGrid.Controls.Add($filterCells[$index], $col, $row)
}

[void]$newsFilterSection.Controls.Add($filterLabel, 0, 0)
[void]$newsFilterSection.Controls.Add($newsFilterGrid, 0, 1)

[void]$newsFooterLayout.Controls.Add($newsFilterSection, 0, 0)
[void]$newsFooterLayout.Controls.Add($newsButtonPanel, 0, 1)

[void]$newsLayout.Controls.Add($newsList, 0, 0)
[void]$newsLayout.Controls.Add($newsPreviewPanel, 0, 1)
[void]$newsLayout.Controls.Add($newsFooterLayout, 0, 2)
[void]$newsGroup.Controls.Add($newsLayout)

[void]$bodyLayout.Controls.Add($weatherGroup, 0, 0)
[void]$bodyLayout.Controls.Add($newsGroup, 1, 0)

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = 'Bottom'
$bottomPanel.BackColor = [System.Drawing.Color]::Transparent
$bottomPanel.Height = 78

$openSystemButton = New-Object System.Windows.Forms.Button
$openSystemButton.Text = 'Systém'
$openSystemButton.Location = New-Object System.Drawing.Point(2, 38)
$openSystemButton.Size = New-Object System.Drawing.Size(120, 32)
$openSystemButton.BackColor = $script:Palette.ButtonBack
$openSystemButton.ForeColor = $script:Palette.ButtonText

$openSoftwareButton = New-Object System.Windows.Forms.Button
$openSoftwareButton.Text = 'Software'
$openSoftwareButton.Location = New-Object System.Drawing.Point(132, 38)
$openSoftwareButton.Size = New-Object System.Drawing.Size(120, 32)
$openSoftwareButton.BackColor = $script:Palette.ButtonBack
$openSoftwareButton.ForeColor = $script:Palette.ButtonText

$refreshAllButton = New-Object System.Windows.Forms.Button
$refreshAllButton.Text = 'Obnovit dashboard'
$refreshAllButton.Location = New-Object System.Drawing.Point(262, 38)
$refreshAllButton.Size = New-Object System.Drawing.Size(150, 32)
$refreshAllButton.BackColor = $script:Palette.ButtonBack
$refreshAllButton.ForeColor = $script:Palette.ButtonText

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = 'Zavřít'
$closeButton.Anchor = 'Top,Right'
$closeButton.Location = New-Object System.Drawing.Point(960, 38)
$closeButton.Size = New-Object System.Drawing.Size(110, 32)
$closeButton.BackColor = $script:Palette.ButtonBack
$closeButton.ForeColor = $script:Palette.ButtonText

[void]$bottomPanel.Controls.Add($openSystemButton)
[void]$bottomPanel.Controls.Add($openSoftwareButton)
[void]$bottomPanel.Controls.Add($refreshAllButton)
[void]$bottomPanel.Controls.Add($closeButton)

[void]$mainPanel.Controls.Add($bodyLayout)
[void]$mainPanel.Controls.Add($bottomPanel)
[void]$mainPanel.Controls.Add($headerPanel)
[void]$form.Controls.Add($mainPanel)

$saveQuickApps = {
    try {
        $config['quickApps'] = @($script:QuickApps | ForEach-Object {
            [PSCustomObject]@{ name = [string]$_.name; path = [string]$_.path }
        })
        Save-DashboardConfig -Config $config -ConfigPath $script:ActiveConfigPath
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            ("Nepodařilo se uložit konfiguraci rychlého spuštění.`n`n{0}" -f $_.Exception.Message),
            'Rychlé spuštění',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

$quickAppLaunch = {
    param($sender, $e)
    $appInfo = $sender.Tag
    try {
        Start-Process -FilePath ([string]$appInfo.path) | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            ("Nepodařilo se spustit aplikaci {0}.`n`n{1}" -f $appInfo.name, $_.Exception.Message),
            'Rychlé spuštění',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

$renderQuickApps = {
    $quickAppsPanel.Controls.Clear()

    foreach ($quickApp in $script:QuickApps) {
        $appButton = New-Object System.Windows.Forms.Button
        $appButton.Size = New-Object System.Drawing.Size(34, 34)
        $appButton.Margin = New-Object System.Windows.Forms.Padding(2)
        $appButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $appButton.FlatAppearance.BorderSize = 0
        $appButton.Text = ''
        $appButton.Tag = $quickApp
        $appButton.Cursor = [System.Windows.Forms.Cursors]::Hand
        $appButton.BackColor = $script:Palette.ButtonBack
        $appButton.ForeColor = $script:Palette.ButtonText

        try {
            $extractedIcon = [System.Drawing.Icon]::ExtractAssociatedIcon([string]$quickApp.path)
            if ($extractedIcon) {
                $appButton.Image = $extractedIcon.ToBitmap()
                $appButton.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            }
        }
        catch {
            # Ikonu se nepodařilo vytáhnout (např. neexistující cesta) - zobrazíme aspoň zkratku názvu.
            $appName = [string]$quickApp.name
            $appButton.Text = $appName.Substring(0, [Math]::Min(2, $appName.Length))
        }

        $appToolTip = New-Object System.Windows.Forms.ToolTip
        $appToolTip.SetToolTip($appButton, [string]$quickApp.name)

        $appContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
        $removeMenuItem = $appContextMenu.Items.Add('Odebrat')
        $removeMenuItem.Tag = $quickApp
        $removeMenuItem.Add_Click($quickAppRemove)
        $appButton.ContextMenuStrip = $appContextMenu

        $appButton.Add_Click($quickAppLaunch)

        [void]$quickAppsPanel.Controls.Add($appButton)
    }
}

$quickAppRemove = {
    param($sender, $e)
    $appInfo = $sender.Tag
    [void]$script:QuickApps.Remove($appInfo)
    & $saveQuickApps
    & $renderQuickApps
}

$addQuickAppButton.Add_Click({
    $newApp = Show-AddQuickAppDialog
    if ($null -ne $newApp) {
        $script:QuickApps.Add($newApp)
        & $saveQuickApps
        & $renderQuickApps
    }
})

& $renderQuickApps

$openSelectedNewsItem = {
    if ($newsList.SelectedItems.Count -eq 0) {
        return
    }

    $url = [string]$newsList.SelectedItems[0].Tag.Link
    if ([string]::IsNullOrWhiteSpace($url)) {
        return
    }

    Start-Process $url | Out-Null
}

$loadNewsFromCache = {
    if (-not (Test-Path -LiteralPath $newsCachePath)) {
        $script:AllNewsItems = @()
        return $false
    }

    try {
        $raw = Get-Content -LiteralPath $newsCachePath -Raw -Encoding UTF8
        $cached = ConvertFrom-Json -InputObject $raw
        $loadedItems = New-Object System.Collections.Generic.List[object]

        foreach ($entry in @($cached)) {
            if ($null -eq $entry) {
                continue
            }

            $published = $null
            if ($entry.Published) {
                try {
                    $published = Get-Date ([string]$entry.Published)
                }
                catch {
                    $published = $null
                }
            }

            $loadedItems.Add([PSCustomObject]@{
                Source = [string]$entry.Source
                Title = [string]$entry.Title
                Link = [string]$entry.Link
                Published = $published
                Description = [string]$entry.Description
            })
        }

        $script:AllNewsItems = @($loadedItems)
        return ($script:AllNewsItems.Count -gt 0)
    }
    catch {
        $script:AllNewsItems = @()
        return $false
    }
}

$saveNewsToCache = {
    try {
        $toSave = $script:AllNewsItems | ForEach-Object {
            [PSCustomObject]@{
                Source = [string]$_.Source
                Title = [string]$_.Title
                Link = [string]$_.Link
                Published = if ($_.Published) { ([datetime]$_.Published).ToString('o') } else { $null }
                Description = [string]$_.Description
            }
        }

        $json = $toSave | ConvertTo-Json -Depth 3
        Set-Content -LiteralPath $newsCachePath -Value $json -Encoding UTF8
    }
    catch {
        # Zápis cache je best-effort. Při chybě nechceme blokovat dashboard.
    }
}

$renderNewsList = {
    $newsList.BeginUpdate()
    $newsList.Items.Clear()
    $script:HoveredNewsItem = $null
    $newsPreviewLabel.Text = 'Vyber zprávu pro zobrazení anotace.'

    $selectedSources = @($sourceFilterCheckBoxes | Where-Object { $_.Checked } | ForEach-Object { $_.Text })
    $showAllSources = $allSourcesCheckBox.Checked -or $selectedSources.Count -eq 0

    $itemsToRender = if ($showAllSources) {
        $script:AllNewsItems
    }
    else {
        $script:AllNewsItems | Where-Object { $_.Source -in $selectedSources }
    }

    foreach ($item in $itemsToRender) {
        $row = New-Object System.Windows.Forms.ListViewItem([string]$item.Source)
        [void]$row.SubItems.Add([string]$item.Title)
        $timeText = if ($item.Published) { $item.Published.ToString('dd.MM. HH:mm') } else { '-' }
        [void]$row.SubItems.Add($timeText)
        $row.ForeColor = $script:NewsRowTextColor
        $row.Tag = [PSCustomObject]@{ Link = [string]$item.Link; Description = [string]$item.Description }
        [void]$newsList.Items.Add($row)
    }

    $newsList.EndUpdate()

    $sourceWidth = 140
    $timeWidth = 132
    # Rezerva kompenzuje rámeček a vnitřní scrollbar, aby nevznikal horizontální posuvník.
    $titleWidth = $newsList.ClientSize.Width - ($sourceWidth + $timeWidth + 24)
    if ($titleWidth -lt 180) {
        $titleWidth = 180
    }

    $newsList.Columns[0].Width = $sourceWidth
    $newsList.Columns[1].Width = $titleWidth
    $newsList.Columns[2].Width = $timeWidth
}

$refreshNewsFromInternet = {
    $newsLoadError = $null
    try {
        $script:AllNewsItems = @(Get-NewsFeedItems -Feeds $config.newsFeeds -MaxItemsPerFeed 6)
        & $saveNewsToCache
    }
    catch {
        $newsLoadError = $_.Exception.Message
    }

    & $renderNewsList
    return $newsLoadError
}

$applyNewsFilter = {
    param([bool]$changedAll)

    if ($isUpdatingNewsFilter) {
        return
    }

    $isUpdatingNewsFilter = $true
    try {
        if ($changedAll -and $allSourcesCheckBox.Checked) {
            foreach ($cb in $sourceFilterCheckBoxes) {
                $cb.Checked = $false
            }
        }
        else {
            $selectedCount = @($sourceFilterCheckBoxes | Where-Object { $_.Checked }).Count
            if ($selectedCount -gt 0) {
                $allSourcesCheckBox.Checked = $false
            }
            else {
                $allSourcesCheckBox.Checked = $true
            }
        }

        $script:NewsFilterState.Clear()
        $script:NewsFilterState['All'] = [bool]$allSourcesCheckBox.Checked
        $script:NewsFilterState['Selected'] = @($sourceFilterCheckBoxes | Where-Object { $_.Checked } | ForEach-Object { $_.Text })
        & $renderNewsList
        $statusLabel.Text = ('Stav: filtr zpráv aplikován {0}' -f (Get-Date -Format 'HH:mm:ss'))
    }
    finally {
        $isUpdatingNewsFilter = $false
    }
}

$allSourcesCheckBox.Add_CheckedChanged({
    & $applyNewsFilter $true
})

foreach ($sourceCheckBox in $sourceFilterCheckBoxes) {
    $sourceCheckBox.Add_CheckedChanged({
        & $applyNewsFilter $false
    })
}

$newsList.Add_SizeChanged({
    if ($newsList.Columns.Count -ge 3) {
        $sourceWidth = 140
        $timeWidth = 132
        $titleWidth = $newsList.ClientSize.Width - ($sourceWidth + $timeWidth + 24)
        if ($titleWidth -lt 180) {
            $titleWidth = 180
        }

        $newsList.Columns[0].Width = $sourceWidth
        $newsList.Columns[1].Width = $titleWidth
        $newsList.Columns[2].Width = $timeWidth
    }
})

$newsList.Add_MouseMove({
    param($sender, $e)
    $itemUnderCursor = $newsList.GetItemAt($e.X, $e.Y)

    if ($null -ne $script:HoveredNewsItem -and $script:HoveredNewsItem -ne $itemUnderCursor) {
        $script:HoveredNewsItem.ForeColor = $script:NewsRowTextColor
    }

    if ($null -ne $itemUnderCursor) {
        $newsList.Cursor = [System.Windows.Forms.Cursors]::Hand
        $itemUnderCursor.ForeColor = [System.Drawing.Color]::RoyalBlue
        $script:HoveredNewsItem = $itemUnderCursor
    }
    else {
        $newsList.Cursor = [System.Windows.Forms.Cursors]::Default
        $script:HoveredNewsItem = $null
    }
})

$newsList.Add_MouseLeave({
    $newsList.Cursor = [System.Windows.Forms.Cursors]::Default
    if ($null -ne $script:HoveredNewsItem) {
        $script:HoveredNewsItem.ForeColor = $script:NewsRowTextColor
        $script:HoveredNewsItem = $null
    }
})

$newsList.Add_MouseClick({
    param($sender, $e)
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) {
        return
    }

    $item = $newsList.GetItemAt($e.X, $e.Y)
    if ($null -eq $item) {
        return
    }

    # Jednoklik jen vybere položku (zobrazí anotaci v náhledu) - otevření odkazu je na dvojkliku.
    $item.Selected = $true
})

$newsList.Add_DoubleClick({
    & $openSelectedNewsItem
})

$refreshWeatherAndNews = {
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $statusLabel.Text = 'Stav: načítám počasí a zprávy...'
    $weatherLoadError = $null
    $newsLoadError = $null

    try {
        try {
            $snapshot = Get-WeatherSnapshot -LocationName $location.name -Latitude ([double]$location.latitude) -Longitude ([double]$location.longitude)
            $current = $snapshot.Current

            $lblTemp.Text = ('Teplota: {0}' -f $current.Temperature)
            $lblCondition.Text = ('Stav: {0} | Vlhkost: {1} | Oblačnost: {2}' -f $current.Condition, $current.Humidity, $current.CloudCover)
            $lblTime.Text = ('Aktualizace: {0} | Veřejná IP: {1}' -f $current.Time, $snapshot.PublicIp)

            $weatherState = Get-WeatherIconState -TemperatureText $current.Temperature
            $weatherCurrentPanel.Invalidate()

            $weatherDetails.Text = @(
                "Lokalita: $($snapshot.Location)"
                "Pocitová teplota: $($current.Feel)"
                "Rychlost větru: $($current.Wind)"
                "Stanice ČHMÚ: $($snapshot.Chmi.Station)"
                "Teplota ČHMÚ: $($snapshot.Chmi.Temperature)"
                "Čas měření ČHMÚ: $($snapshot.Chmi.LastMeasurement)"
                "Stav ČHMÚ: $($snapshot.Chmi.Status)"
                "Stav online: $($snapshot.Status)"
            ) -join [Environment]::NewLine
            $weatherDetails.SelectionStart = 0
            $weatherDetails.SelectionLength = 0

            $forecastGrid.Rows.Clear()
            foreach ($day in $snapshot.Forecast) {
                $forecastRowIndex = $forecastGrid.Rows.Add()
                $forecastRow = $forecastGrid.Rows[$forecastRowIndex]
                $forecastRow.Cells['Date'].Value = [string]$day.Date
                $forecastRow.Cells['Condition'].Value = [string]$day.Condition
                $forecastRow.Cells['Min'].Value = [string]$day.Min
                $forecastRow.Cells['Max'].Value = [string]$day.Max
                $forecastRow.Cells['RainChance'].Value = [string]$day.RainChance
            }
        }
        catch {
            $weatherLoadError = $_.Exception.Message
        }

        $newsLoadError = & $refreshNewsFromInternet

        if ($null -eq $weatherLoadError -and $null -eq $newsLoadError) {
            $statusLabel.Text = ('Stav: dashboard aktualizován {0}' -f (Get-Date -Format 'HH:mm:ss'))
        }
        elseif ($null -ne $weatherLoadError -and $null -eq $newsLoadError) {
            $statusLabel.Text = ('Stav: chyba počasí ({0}), zprávy načteny' -f $weatherLoadError)
        }
        elseif ($null -eq $weatherLoadError -and $null -ne $newsLoadError) {
            $statusLabel.Text = ('Stav: chyba zpráv ({0}), počasí načteno' -f $newsLoadError)
        }
        else {
            $statusLabel.Text = ('Stav: chyba počasí ({0}) i zpráv ({1})' -f $weatherLoadError, $newsLoadError)
        }
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

$openNewsButton.Add_Click({
    if ($newsList.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Vyber nejdřív článek ze seznamu.', 'Info') | Out-Null
        return
    }

    $url = [string]$newsList.SelectedItems[0].Tag.Link
    if ([string]::IsNullOrWhiteSpace($url)) {
        [System.Windows.Forms.MessageBox]::Show('U této položky není odkaz.', 'Info') | Out-Null
        return
    }

    & $openSelectedNewsItem
})

$newsList.Add_SelectedIndexChanged({
    if ($newsList.SelectedItems.Count -eq 0) {
        $newsPreviewLabel.Text = 'Vyber zprávu pro zobrazení anotace.'
        return
    }

    $description = [string]$newsList.SelectedItems[0].Tag.Description
    $newsPreviewLabel.Text = if ([string]::IsNullOrWhiteSpace($description)) { '(bez anotace)' } else { $description }
})

$refreshNewsAction = {
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $statusLabel.Text = 'Stav: načítám zprávy...'
    try {
        $newsErr = & $refreshNewsFromInternet
        if ($null -eq $newsErr) {
            $statusLabel.Text = ('Stav: zprávy aktualizovány {0}' -f (Get-Date -Format 'HH:mm:ss'))
        }
        else {
            $statusLabel.Text = ('Stav: chyba zpráv - {0}' -f $newsErr)
        }
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

$refreshNewsButton.Add_Click($refreshNewsAction)
$openSystemButton.Add_Click({ Start-Process 'ms-settings:about' })
$openSoftwareButton.Add_Click({ Show-SoftwareWindow })
$refreshAllButton.Add_Click($refreshWeatherAndNews)
$closeButton.Add_Click({ $form.Close() })

# Znovu aplikuje aktuální paletu ($script:Palette) na všechny hlavní ovládací prvky okna -
# volá se jednou při startu a pak znovu při každém přepnutí motivu tlačítkem ☀/☾ v hlavičce.
# Hlavička (modrý gradient nahoře) se záměrně nemění, je to pevný brand prvek v obou motivech.
$applyDashboardTheme = {
    $form.BackColor = $script:Palette.FormBack
    $mainPanel.BackColor = $script:Palette.FormBack

    $weatherGroup.ForeColor = $script:Palette.TextPrimary
    $newsGroup.ForeColor = $script:Palette.TextPrimary

    $weatherCurrentPanel.BackColor = $script:Palette.SurfaceAlt
    $lblTemp.ForeColor = $script:Palette.TextPrimary
    $lblCondition.ForeColor = $script:Palette.TextSecondary
    $lblTime.ForeColor = $script:Palette.TextMuted

    $weatherDetails.BackColor = $script:Palette.SurfaceAlt
    $weatherDetails.ForeColor = $script:Palette.TextSecondary

    $forecastGrid.BackgroundColor = $script:Palette.GridBack
    $forecastGrid.GridColor = $script:Palette.GridLine
    $forecastGrid.DefaultCellStyle.BackColor = $script:Palette.GridBack
    $forecastGrid.DefaultCellStyle.ForeColor = $script:Palette.GridText
    $forecastGrid.DefaultCellStyle.SelectionBackColor = $script:Palette.GridBack
    $forecastGrid.DefaultCellStyle.SelectionForeColor = $script:Palette.GridText
    $forecastGrid.ColumnHeadersDefaultCellStyle.BackColor = $script:Palette.GridHeaderBack
    $forecastGrid.ColumnHeadersDefaultCellStyle.ForeColor = $script:Palette.GridHeaderText
    $forecastGrid.Invalidate()

    $quickAppsSection.BackColor = $script:Palette.SurfaceAlt
    $quickAppsLabel.ForeColor = $script:Palette.TextSecondary
    $addQuickAppButton.BackColor = $script:Palette.ButtonBack
    $addQuickAppButton.ForeColor = $script:Palette.ButtonText

    $newsList.BackColor = $script:Palette.GridBack
    $newsList.ForeColor = $script:Palette.GridText
    $newsPreviewPanel.BackColor = $script:Palette.SurfaceAlt
    $newsPreviewLabel.ForeColor = $script:Palette.TextSecondary
    $filterLabel.ForeColor = $script:Palette.TextSecondary
    $allSourcesCheckBox.ForeColor = $script:Palette.TextSecondary
    foreach ($sourceCheckBox in $sourceFilterCheckBoxes) {
        $sourceCheckBox.ForeColor = $script:Palette.TextSecondary
    }
    $openNewsButton.BackColor = $script:Palette.ButtonBack
    $openNewsButton.ForeColor = $script:Palette.ButtonText
    $refreshNewsButton.BackColor = $script:Palette.ButtonBack
    $refreshNewsButton.ForeColor = $script:Palette.ButtonText

    $openSystemButton.BackColor = $script:Palette.ButtonBack
    $openSystemButton.ForeColor = $script:Palette.ButtonText
    $openSoftwareButton.BackColor = $script:Palette.ButtonBack
    $openSoftwareButton.ForeColor = $script:Palette.ButtonText
    $refreshAllButton.BackColor = $script:Palette.ButtonBack
    $refreshAllButton.ForeColor = $script:Palette.ButtonText
    $closeButton.BackColor = $script:Palette.ButtonBack
    $closeButton.ForeColor = $script:Palette.ButtonText

    # Barva textu položek zpráv se čte v $renderNewsList a hover handlerech ze script-scope
    # proměnné - stačí ji přepsat a seznam překreslit, ať se zpětně obarví i stávající řádky.
    $script:NewsRowTextColor = $script:Palette.GridText
    & $renderNewsList
    & $renderQuickApps
}

& $applyDashboardTheme

$form.Add_Shown({
    $loadedFromCache = & $loadNewsFromCache
    if ($loadedFromCache) {
        & $renderNewsList
        $statusLabel.Text = 'Stav: načtena lokální cache zpráv, aktualizuji online data...'
    }

    & $refreshWeatherAndNews
})

[void]$form.ShowDialog()
