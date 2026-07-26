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
Otevře seznam aplikací s dostupnými aktualizacemi a umožní spustit upgrade pro každou z nich.

.OUTPUTS
System.Void
#>
function Show-SoftwareWindow {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Software - aktualizace'
    $form.StartPosition = 'CenterParent'
    $form.Size = New-Object System.Drawing.Size(1120, 720)
    $form.MinimumSize = New-Object System.Drawing.Size(900, 560)

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
    $gridUpdates.BackgroundColor = [System.Drawing.Color]::White

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
    $topPanel.Height = 48

    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = 'Obnovit software'
    $refreshButton.Location = New-Object System.Drawing.Point(12, 10)
    $refreshButton.Size = New-Object System.Drawing.Size(140, 30)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = 'Zavřít'
    $closeButton.Location = New-Object System.Drawing.Point(990, 10)
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $closeButton.Anchor = 'Top,Right'

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = 'Stav: připraveno'
    $statusLabel.Location = New-Object System.Drawing.Point(170, 15)
    $statusLabel.Size = New-Object System.Drawing.Size(760, 22)

    $refreshUpdates = {
        try {
            $statusLabel.Text = 'Stav: načítám dostupné aktualizace...'
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

    [void]$form.Controls.Add($gridUpdates)
    [void]$form.Controls.Add($topPanel)

    $form.Add_Shown({
        $form.ActiveControl = $refreshButton
    })

    & $refreshAction
    [void]$form.ShowDialog()
}

$localConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'DashboardConfig.local.json'
if (Test-Path -LiteralPath $localConfigPath) {
    $config = Get-DashboardConfig -ConfigPath $localConfigPath
}
else {
    $config = Get-DashboardConfig
}
$location = $config.location
$weatherState = 'Unknown'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Můj startup dashboard'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(1260, 780)
$form.MinimumSize = New-Object System.Drawing.Size(1140, 700)
$form.BackColor = [System.Drawing.Color]::FromArgb(242, 246, 251)
$form.AutoScaleMode = 'Dpi'

$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = 'Fill'
$mainPanel.Padding = New-Object System.Windows.Forms.Padding(14)

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

[void]$headerPanel.Controls.Add($titleLabel)
[void]$headerPanel.Controls.Add($subtitleLabel)
[void]$headerPanel.Controls.Add($statusLabel)

$bodyLayout = New-Object System.Windows.Forms.TableLayoutPanel
$bodyLayout.Dock = 'Fill'
$bodyLayout.ColumnCount = 2
$bodyLayout.RowCount = 1
$bodyLayout.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 10)
[void]$bodyLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 44)))
[void]$bodyLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 56)))

$weatherGroup = New-Object System.Windows.Forms.GroupBox
$weatherGroup.Text = ('Počasí a předpověď ({0})' -f $location.name)
$weatherGroup.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$weatherGroup.Dock = 'Fill'

$weatherLayout = New-Object System.Windows.Forms.TableLayoutPanel
$weatherLayout.Dock = 'Fill'
$weatherLayout.RowCount = 3
$weatherLayout.ColumnCount = 1
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 110)))
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 120)))
[void]$weatherLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

$weatherCurrentPanel = New-Object System.Windows.Forms.Panel
$weatherCurrentPanel.Dock = 'Fill'
$weatherCurrentPanel.BackColor = [System.Drawing.Color]::FromArgb(236, 244, 253)

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
$lblTemp.ForeColor = [System.Drawing.Color]::FromArgb(25, 54, 93)
$lblTemp.Location = New-Object System.Drawing.Point(110, 14)
$lblTemp.Size = New-Object System.Drawing.Size(370, 32)

$lblCondition = New-Object System.Windows.Forms.Label
$lblCondition.Text = 'Stav: --'
$lblCondition.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$lblCondition.ForeColor = [System.Drawing.Color]::FromArgb(47, 73, 107)
$lblCondition.Location = New-Object System.Drawing.Point(112, 50)
$lblCondition.Size = New-Object System.Drawing.Size(430, 22)

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Text = 'Aktualizace: --'
$lblTime.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$lblTime.ForeColor = [System.Drawing.Color]::FromArgb(77, 95, 120)
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

$forecastGrid = New-Object System.Windows.Forms.DataGridView
$forecastGrid.Dock = 'Fill'
$forecastGrid.ReadOnly = $true
$forecastGrid.AutoGenerateColumns = $true
$forecastGrid.AllowUserToAddRows = $false
$forecastGrid.AllowUserToDeleteRows = $false
$forecastGrid.SelectionMode = 'FullRowSelect'

[void]$weatherLayout.Controls.Add($weatherCurrentPanel, 0, 0)
[void]$weatherLayout.Controls.Add($weatherDetails, 0, 1)
[void]$weatherLayout.Controls.Add($forecastGrid, 0, 2)
[void]$weatherGroup.Controls.Add($weatherLayout)

$newsGroup = New-Object System.Windows.Forms.GroupBox
$newsGroup.Text = 'Zpravodajský kanál'
$newsGroup.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$newsGroup.Dock = 'Fill'

$newsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$newsLayout.Dock = 'Fill'
$newsLayout.RowCount = 2
$newsLayout.ColumnCount = 1
[void]$newsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
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
$newsList.Columns.Add('Zdroj', 130) | Out-Null
$newsList.Columns.Add('Titulek', 400) | Out-Null
$newsList.Columns.Add('Publikováno', 130) | Out-Null

$newsCachePath = Join-Path -Path $PSScriptRoot -ChildPath 'NewsCache.json'
$script:AllNewsItems = @()
$script:NewsFilterState = [ordered]@{}
$script:HoveredNewsItem = $null
$isUpdatingNewsFilter = $false
$sourceFilterCheckBoxes = New-Object System.Collections.Generic.List[System.Windows.Forms.CheckBox]

$newsFooterLayout = New-Object System.Windows.Forms.TableLayoutPanel
$newsFooterLayout.Dock = 'Fill'
$newsFooterLayout.ColumnCount = 1
$newsFooterLayout.RowCount = 2
[void]$newsFooterLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$newsFooterLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42)))
$newsFooterLayout.AutoSize = $true
$newsFooterLayout.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

$newsFilterSection = New-Object System.Windows.Forms.TableLayoutPanel
$newsFilterSection.Dock = 'Top'
$newsFilterSection.AutoSize = $true
$newsFilterSection.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$newsFilterSection.ColumnCount = 1
$newsFilterSection.RowCount = 2
[void]$newsFilterSection.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$newsFilterSection.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = 'Filtr zdrojů:'
$filterLabel.AutoSize = $true
$filterLabel.Margin = New-Object System.Windows.Forms.Padding(8, 8, 8, 4)

$newsFilterGrid = New-Object System.Windows.Forms.TableLayoutPanel
$newsFilterGrid.Dock = 'Fill'
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
$allSourcesCheckBox.Margin = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
$allSourcesCheckBox.Anchor = 'Left'

$newsButtonPanel = New-Object System.Windows.Forms.Panel
$newsButtonPanel.Dock = 'Fill'
$newsButtonPanel.Height = 42

$openNewsButton = New-Object System.Windows.Forms.Button
$openNewsButton.Text = 'Otevřít článek'
$openNewsButton.Location = New-Object System.Drawing.Point(10, 6)
$openNewsButton.Size = New-Object System.Drawing.Size(120, 30)

$refreshNewsButton = New-Object System.Windows.Forms.Button
$refreshNewsButton.Text = 'Obnovit zprávy'
$refreshNewsButton.Location = New-Object System.Drawing.Point(140, 6)
$refreshNewsButton.Size = New-Object System.Drawing.Size(130, 30)

[void]$newsButtonPanel.Controls.Add($openNewsButton)
[void]$newsButtonPanel.Controls.Add($refreshNewsButton)

$filterCells = @()
$filterCells += $allSourcesCheckBox

$configuredSources = @($config.newsFeeds | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
foreach ($sourceName in $configuredSources) {
    $sourceCheckBox = New-Object System.Windows.Forms.CheckBox
    $sourceCheckBox.Text = $sourceName
    $sourceCheckBox.AutoSize = $true
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
[void]$newsLayout.Controls.Add($newsFooterLayout, 0, 1)
[void]$newsGroup.Controls.Add($newsLayout)

[void]$bodyLayout.Controls.Add($weatherGroup, 0, 0)
[void]$bodyLayout.Controls.Add($newsGroup, 1, 0)

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = 'Bottom'
$bottomPanel.Height = 78

$openSystemButton = New-Object System.Windows.Forms.Button
$openSystemButton.Text = 'Systém'
$openSystemButton.Location = New-Object System.Drawing.Point(2, 38)
$openSystemButton.Size = New-Object System.Drawing.Size(120, 32)

$openSoftwareButton = New-Object System.Windows.Forms.Button
$openSoftwareButton.Text = 'Software'
$openSoftwareButton.Location = New-Object System.Drawing.Point(132, 38)
$openSoftwareButton.Size = New-Object System.Drawing.Size(120, 32)

$refreshAllButton = New-Object System.Windows.Forms.Button
$refreshAllButton.Text = 'Obnovit dashboard'
$refreshAllButton.Location = New-Object System.Drawing.Point(262, 38)
$refreshAllButton.Size = New-Object System.Drawing.Size(150, 32)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = 'Zavřít'
$closeButton.Anchor = 'Top,Right'
$closeButton.Location = New-Object System.Drawing.Point(960, 38)
$closeButton.Size = New-Object System.Drawing.Size(110, 32)

[void]$bottomPanel.Controls.Add($openSystemButton)
[void]$bottomPanel.Controls.Add($openSoftwareButton)
[void]$bottomPanel.Controls.Add($refreshAllButton)
[void]$bottomPanel.Controls.Add($closeButton)

[void]$mainPanel.Controls.Add($bodyLayout)
[void]$mainPanel.Controls.Add($bottomPanel)
[void]$mainPanel.Controls.Add($headerPanel)
[void]$form.Controls.Add($mainPanel)

$openSelectedNewsItem = {
    if ($newsList.SelectedItems.Count -eq 0) {
        return
    }

    $url = [string]$newsList.SelectedItems[0].Tag
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
        $row.ForeColor = [System.Drawing.Color]::Black
        $row.Tag = [string]$item.Link
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
        $script:HoveredNewsItem.ForeColor = [System.Drawing.Color]::Black
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
        $script:HoveredNewsItem.ForeColor = [System.Drawing.Color]::Black
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

    $item.Selected = $true
    & $openSelectedNewsItem
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

            $forecastGrid.DataSource = $snapshot.Forecast
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

    $url = [string]$newsList.SelectedItems[0].Tag
    if ([string]::IsNullOrWhiteSpace($url)) {
        [System.Windows.Forms.MessageBox]::Show('U této položky není odkaz.', 'Info') | Out-Null
        return
    }

    & $openSelectedNewsItem
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

$form.Add_Shown({
    $loadedFromCache = & $loadNewsFromCache
    if ($loadedFromCache) {
        & $renderNewsList
        $statusLabel.Text = 'Stav: načtena lokální cache zpráv, aktualizuji online data...'
    }

    & $refreshWeatherAndNews
})

[void]$form.ShowDialog()
