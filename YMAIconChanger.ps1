<#
    .TITLE
        YMA Tools: Folder Icon Changer - Setup Manager v1.0.1 (Cyber Edition)
    .AUTHOR
        Youssef Mahmoud Abdelqeader (Akhdar/Mr. Green)
    .DESCRIPTION
        Manager to Install, Update, or Uninstall the YMAIconChanger tool.
        CYBER UI: Enhanced visual design with ASCII art and hacker aesthetic
#>

# ═══════════════════════════════════════════════════════════════════════════
# 1. INITIALIZATION & ADMIN CHECK
# ═══════════════════════════════════════════════════════════════════════════

$Version         = "1.0.1"
$ProgramName     = "YMA TOOLS: FOLDER ICON CHANGER"
$SystemName      = "YMAIconChanger"
$InstallBase     = "C:\YMATools"
$InstallPath     = Join-Path $InstallBase $SystemName
$ScriptFileName  = "YMAIconChanger.ps1"
$ConfigFileName  = "config.json"
$MenuIconName    = "menu_icon.ico"

$FullScriptPath = Join-Path $InstallPath $ScriptFileName
$FullConfigPath = Join-Path $InstallPath $ConfigFileName
$FullIconPath   = Join-Path $InstallPath $MenuIconName

# Google Drive Link for Custom Branding
$GDriveLink = "https://drive.google.com/file/d/1m6QvhjjaMXIXVivM2k5GVo4rH7RoijWp/view"

# Define Cyber UI Colors
$CyberGreen     = [System.ConsoleColor]::Green
$CyberTeal      = [System.ConsoleColor]::Cyan
$AccentColor    = [System.ConsoleColor]::DarkCyan
$TextWhite      = [System.ConsoleColor]::White
$ErrorColor     = [System.ConsoleColor]::Red
$WarningColor   = [System.ConsoleColor]::Yellow
$DimText        = [System.ConsoleColor]::DarkGray

# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] PRIVILEGE ESCALATION REQUIRED..." -ForegroundColor $WarningColor
    try {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        Exit
    } catch {
        Write-Host "[X] ELEVATION FAILED: $($_.Exception.Message)" -ForegroundColor $ErrorColor
        Read-Host "Press Enter to exit"
        Exit
    }
}

# Load Assemblies for Image Conversion
try {
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "[X] ASSEMBLY LOAD FAILED: $($_.Exception.Message)" -ForegroundColor $ErrorColor
    Read-Host "Press Enter to exit"
    Exit
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

function Write-LogError {
    param([string]$Message, [string]$Exception = "")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] ERROR: $Message"
    if ($Exception) { $logMessage += " | Exception: $Exception" }
    Write-Host $logMessage -ForegroundColor $ErrorColor
    
    $logPath = Join-Path $InstallPath "error.log"
    try {
        $logMessage | Out-File -FilePath $logPath -Append -ErrorAction SilentlyContinue
    } catch {}
}

function Write-LogInfo {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $CyberTeal
}

function Write-CyberHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor $AccentColor
    Write-Host "  ║ " -NoNewline -ForegroundColor $AccentColor
    Write-Host $Title.PadRight(61) -NoNewline -ForegroundColor $CyberTeal
    Write-Host " ║" -ForegroundColor $AccentColor
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor $AccentColor
    Write-Host ""
}

function Ensure-InstallDirectory {
    try {
        if (-not (Test-Path $InstallPath)) {
            New-Item -Path $InstallPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-LogInfo "Installation directory created"
        }
        return $true
    } catch {
        Write-LogError "Could not create directory: $InstallPath" $_.Exception.Message
        return $false
    }
}

function Convert-PngToIco-Installer {
    param([string]$PngPath, [string]$IcoPath, [int]$Size = 256)
    
    if (-not (Test-Path $PngPath)) {
        Write-LogError "PNG file not found: $PngPath"
        return $false
    }
    
    try {
        $sourceImage = [System.Drawing.Image]::FromFile($PngPath)
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($sourceImage, 0, 0, $Size, $Size)
        $graphics.Dispose()
        
        $memoryStream = New-Object System.IO.MemoryStream
        $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $fileStream = [System.IO.File]::Create($IcoPath)
        $binaryWriter = New-Object System.IO.BinaryWriter($fileStream)
        
        $binaryWriter.Write([UInt16]0); $binaryWriter.Write([UInt16]1); $binaryWriter.Write([UInt16]1)
        if ($Size -eq 256) { $binaryWriter.Write([Byte]0); $binaryWriter.Write([Byte]0) } 
        else { $binaryWriter.Write([Byte]$Size); $binaryWriter.Write([Byte]$Size) }
        $binaryWriter.Write([Byte]0); $binaryWriter.Write([Byte]0); $binaryWriter.Write([UInt16]1); $binaryWriter.Write([UInt16]32)
        $binaryWriter.Write([UInt32]$memoryStream.Length); $binaryWriter.Write([UInt32]22)
        
        $memoryStream.Position = 0
        $memoryStream.CopyTo($fileStream)
        
        $binaryWriter.Close(); $fileStream.Close(); $memoryStream.Close()
        $bitmap.Dispose(); $sourceImage.Dispose()
        
        Write-LogInfo "PNG converted to ICO successfully"
        return $true
    } catch {
        Write-LogError "PNG to ICO conversion failed" $_.Exception.Message
        return $false
    }
}

function Download-GoogleDriveImage {
    param([string]$Url, [string]$DestinationPath)
    
    try {
        if ($Url -match '/d/([a-zA-Z0-9_-]+)') {
            $fileId = $matches[1]
            $directUrl = "https://drive.google.com/uc?export=download&id=$fileId"
            $tempFile = [System.IO.Path]::GetTempFileName()
            
            Write-Host "[>] Downloading from Google Drive..." -ForegroundColor $CyberTeal
            Invoke-WebRequest -Uri $directUrl -OutFile $tempFile -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            
            if ((Get-Item $tempFile).Length -eq 0) {
                throw "Downloaded file is empty"
            }
            
            Move-Item -Path $tempFile -Destination $DestinationPath -Force
            Write-LogInfo "Image downloaded successfully"
            return $true
        }
        Write-LogError "Invalid Google Drive URL format"
        return $false
    } catch {
        Write-LogError "Failed to download Google Drive image" $_.Exception.Message
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. CONFIGURATION LOGIC (ENHANCED)
# ═══════════════════════════════════════════════════════════════════════════

function Get-DefaultConfig {
    try {
        $downloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    } catch {
        $downloadsPath = Join-Path $env:USERPROFILE "Downloads"
        Write-LogError "Could not detect Downloads folder, using default: $downloadsPath"
    }
    
    return [pscustomobject]@{
        IconStoragePath     = "C:\CustomIcons"
        DownloadsFolder     = $downloadsPath
        DeletePngBehavior   = "delete"
        MonitorTimeoutSec   = 300
        IconDownloadWebsite = "https://www.flaticon.com/search?word="
        OpenBrowserNoSearch = $false
    }
}

function Get-YMAConfig {
    $null = Ensure-InstallDirectory

    if (-not (Test-Path $FullConfigPath)) {
        try {
            $defaultConfig = Get-DefaultConfig
            $defaultConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $FullConfigPath -Encoding UTF8 -Force
            Write-LogInfo "Created default configuration file"
            return $defaultConfig
        } catch {
            Write-LogError "Failed to create default config" $_.Exception.Message
            return (Get-DefaultConfig)
        }
    }
    
    try {
        $config = Get-Content -Path $FullConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
        
        $defaultConfig = Get-DefaultConfig
        $updated = $false
        
        foreach ($prop in $defaultConfig.PSObject.Properties) {
            if (-not ($config.PSObject.Properties.Name -contains $prop.Name)) {
                $config | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
                $updated = $true
                Write-LogInfo "Added missing config property: $($prop.Name)"
            }
        }
        
        if ($updated) {
            $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $FullConfigPath -Encoding UTF8 -Force
        }
        
        return $config
    } catch {
        Write-LogError "Failed to load config, using defaults" $_.Exception.Message
        return (Get-DefaultConfig)
    }
}

function Set-YMAConfig {
    param([pscustomobject]$ConfigObject)
    
    $null = Ensure-InstallDirectory
    
    try {
        $ConfigObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $FullConfigPath -Encoding UTF8 -Force
        Write-LogInfo "Configuration saved successfully"
        return $true
    } catch {
        Write-LogError "Could not save config" $_.Exception.Message
        return $false 
    }
}

function Configure-YMAIconChanger {
    Clear-Host
    
    $asciiConfig = @'

   ██████\   ██████\  ██\   ██\ ████████\ ██████\  ██████\  
  ██  __██\ ██  __██\ ███\  ██ |██  _____|\_██  _|██  __██\ 
  ██ /  \__|██ /  ██ |████\ ██ |██ |        ██ |  ██ /  \__|
  ██ |      ██ |  ██ |██ ██\██ |█████\      ██ |  ██ |████\ 
  ██ |      ██ |  ██ |██ \████ |██  __|     ██ |  ██ |\_██ |
  ██ |  ██\ ██ |  ██ |██ |\███ |██ |        ██ |  ██ |  ██ |
  \██████  | ██████  |██ | \██ |██ |      ██████\ \██████  |
   \______/  \______/ \__|  \__|\__|      \______| \______/ 

'@
    
    Write-Host $asciiConfig -ForegroundColor $CyberGreen
    Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor $AccentColor
    Write-Host "   CONFIGURATION PANEL" -ForegroundColor $CyberTeal
    Write-Host "   v$Version" -ForegroundColor $DimText
    Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor $AccentColor

    $currentConfig = Get-YMAConfig
    $tempConfig = $currentConfig | ConvertTo-Json -Depth 5 | ConvertFrom-Json 

    while ($true) {
        Write-Host ""
        Write-Host "  ┌─[ " -NoNewline -ForegroundColor $AccentColor
        Write-Host "CURRENT SETTINGS" -NoNewline -ForegroundColor $CyberTeal
        Write-Host " ]" -ForegroundColor $AccentColor
        Write-Host "  │" -ForegroundColor $AccentColor
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[1] Icon Storage    : " -NoNewline -ForegroundColor $TextWhite
        Write-Host "$($tempConfig.IconStoragePath)" -ForegroundColor $DimText
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[2] Downloads Path  : " -NoNewline -ForegroundColor $TextWhite
        Write-Host "$($tempConfig.DownloadsFolder)" -ForegroundColor $DimText
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[3] PNG Cleanup     : " -NoNewline -ForegroundColor $TextWhite
        Write-Host "$($tempConfig.DeletePngBehavior)" -ForegroundColor $DimText
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[4] Timeout         : " -NoNewline -ForegroundColor $TextWhite
        Write-Host "$($tempConfig.MonitorTimeoutSec)s" -ForegroundColor $DimText
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[5] Download Site   : " -NoNewline -ForegroundColor $TextWhite
        Write-Host "$($tempConfig.IconDownloadWebsite)" -ForegroundColor $DimText
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[6] Browser Behavior: " -NoNewline -ForegroundColor $TextWhite
        $browserMode = if ($tempConfig.OpenBrowserNoSearch) { "Open Without Search" } else { "Open With Search" }
        Write-Host "$browserMode" -ForegroundColor $DimText
        Write-Host "  │" -ForegroundColor $AccentColor
        Write-Host "  └─────────────────────────────────────────────────────" -ForegroundColor $AccentColor
        Write-Host ""
        Write-Host "  [S] " -NoNewline -ForegroundColor $CyberGreen
        Write-Host "SAVE & EXIT  " -NoNewline -ForegroundColor $TextWhite
        Write-Host "[B] " -NoNewline -ForegroundColor $ErrorColor
        Write-Host "BACK TO MENU" -ForegroundColor $TextWhite
        Write-Host ""
        Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal

        $choice = Read-Host
        Clear-Host 
        Write-Host $asciiConfig -ForegroundColor $CyberGreen
        Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor $AccentColor

        switch ($choice.ToUpper()) {
            '1' {
                Write-Host ""
                Write-Host "  [CURRENT] $($tempConfig.IconStoragePath)" -ForegroundColor $DimText
                Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                $newPath = Read-Host
                if ($newPath) {
                    try {
                        $parentPath = Split-Path $newPath -Parent
                        if ($parentPath -and (Test-Path $parentPath -PathType Container)) {
                            New-Item -Path $newPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                            $tempConfig.IconStoragePath = $newPath
                            Write-Host "  [✓] Path updated" -ForegroundColor $CyberGreen
                        } else {
                            Write-Host "  [X] Invalid path" -ForegroundColor $ErrorColor
                        }
                    } catch {
                        Write-Host "  [X] Error: $($_.Exception.Message)" -ForegroundColor $ErrorColor
                    }
                }
                Start-Sleep -Seconds 1
            }
            '2' {
                Write-Host ""
                Write-Host "  [CURRENT] $($tempConfig.DownloadsFolder)" -ForegroundColor $DimText
                Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                $newPath = Read-Host
                if ($newPath -and (Test-Path $newPath -PathType Container)) {
                    $tempConfig.DownloadsFolder = $newPath
                    Write-Host "  [✓] Path updated" -ForegroundColor $CyberGreen
                } else {
                    Write-Host "  [X] Invalid path" -ForegroundColor $ErrorColor
                }
                Start-Sleep -Seconds 1
            }
            '3' {
                Write-Host ""
                Write-Host "  [CURRENT] $($tempConfig.DeletePngBehavior)" -ForegroundColor $DimText
                Write-Host "  [OPTIONS] Ask / Keep / Delete" -ForegroundColor $CyberTeal
                Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                $behavior = Read-Host
                if ($behavior -match '^(Ask|Keep|Delete)$') {
                    $tempConfig.DeletePngBehavior = $behavior
                    Write-Host "  [✓] Behavior updated" -ForegroundColor $CyberGreen
                } else {
                    Write-Host "  [X] Invalid input" -ForegroundColor $ErrorColor
                }
                Start-Sleep -Seconds 1
            }
            '4' {
                Write-Host ""
                Write-Host "  [CURRENT] $($tempConfig.MonitorTimeoutSec) seconds" -ForegroundColor $DimText
                Write-Host "  [RANGE] 30-600 seconds" -ForegroundColor $CyberTeal
                Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                $timeout = Read-Host
                try {
                    $timeoutNum = [int]$timeout
                    if ($timeoutNum -ge 30 -and $timeoutNum -le 600) {
                        $tempConfig.MonitorTimeoutSec = $timeoutNum
                        Write-Host "  [✓] Timeout updated" -ForegroundColor $CyberGreen
                    } else {
                        Write-Host "  [X] Must be 30-600" -ForegroundColor $ErrorColor
                    }
                } catch {
                    Write-Host "  [X] Invalid number" -ForegroundColor $ErrorColor
                }
                Start-Sleep -Seconds 1
            }
            '5' {
                Write-Host ""
                Write-Host "  [CURRENT] $($tempConfig.IconDownloadWebsite)" -ForegroundColor $DimText
                Write-Host ""
                Write-Host "  ┌─[ AVAILABLE SITES ]" -ForegroundColor $AccentColor
                Write-Host "  ├──> [1] Flaticon" -ForegroundColor $CyberTeal
                Write-Host "  ├──> [2] Icons8" -ForegroundColor $CyberTeal
                Write-Host "  ├──> [3] Iconscout" -ForegroundColor $CyberTeal
                Write-Host "  ├──> [4] Iconfinder" -ForegroundColor $CyberTeal
                Write-Host "  └──> [5] Custom URL" -ForegroundColor $CyberTeal
                Write-Host ""
                Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                $websiteChoice = Read-Host
                
                switch ($websiteChoice) {
                    '1' { $tempConfig.IconDownloadWebsite = "https://www.flaticon.com/search?word=" }
                    '2' { $tempConfig.IconDownloadWebsite = "https://icons8.com/icons/set/" }
                    '3' { $tempConfig.IconDownloadWebsite = "https://iconscout.com/icons/" }
                    '4' { $tempConfig.IconDownloadWebsite = "https://www.iconfinder.com/search?q=" }
                    '5' { 
                        Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                        $customUrl = Read-Host
                        if ($customUrl -match '^https?://') {
                            $tempConfig.IconDownloadWebsite = $customUrl
                            Write-Host "  [✓] Custom URL set" -ForegroundColor $CyberGreen
                        } else {
                            Write-Host "  [X] Invalid URL" -ForegroundColor $ErrorColor
                        }
                    }
                    default { Write-Host "  [X] Invalid selection" -ForegroundColor $ErrorColor }
                }
                Start-Sleep -Seconds 1
            }
            '6' {
                Write-Host ""
                Write-Host "  [CURRENT] " -NoNewline -ForegroundColor $DimText
                if ($tempConfig.OpenBrowserNoSearch) {
                    Write-Host "Open Without Search" -ForegroundColor $DimText
                } else {
                    Write-Host "Open With Search" -ForegroundColor $DimText
                }
                Write-Host ""
                Write-Host "  Toggle browser behavior? (Y/N)" -ForegroundColor $CyberTeal
                Write-Host "  > " -NoNewline -ForegroundColor $CyberTeal
                $toggle = Read-Host
                if ($toggle -match '^[Yy]') {
                    $tempConfig.OpenBrowserNoSearch = -not $tempConfig.OpenBrowserNoSearch
                    Write-Host "  [✓] Browser behavior toggled" -ForegroundColor $CyberGreen
                }
                Start-Sleep -Seconds 1
            }
            'S' {
                if (Set-YMAConfig -ConfigObject $tempConfig) { 
                    Write-Host ""
                    Write-Host "  [✓] CONFIGURATION SAVED" -ForegroundColor $CyberGreen
                    Start-Sleep -Seconds 1.5
                }
                return
            }
            'B' { return }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# 4. THE PAYLOAD (Worker Script) - ENHANCED
# ═══════════════════════════════════════════════════════════════════════════

$YMAIconChangerPayload = @'
#Requires -Version 5.1

param(
    [Parameter(Mandatory=$false)][string]$Keyword,
    [Parameter(Mandatory=$false)][string]$FolderPath
)

$FullConfigPath = "C:\YMATools\YMAIconChanger\config.json"

function Write-EngineError {
    param([string]$Message, [string]$Exception = "")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] ERROR: $Message"
    if ($Exception) { $logMessage += " | $Exception" }
    Write-Host "`n$logMessage" -ForegroundColor Red
    
    $logPath = "C:\YMATools\YMAIconChanger\engine_error.log"
    try {
        $logMessage | Out-File -FilePath $logPath -Append -ErrorAction SilentlyContinue
    } catch {}
}

function Get-ConfigLocal {
    if (Test-Path $FullConfigPath) {
        try { 
            return (Get-Content -Path $FullConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json) 
        } catch {
            Write-EngineError "Failed to parse config file" $_.Exception.Message
            return $null
        }
    }
    return $null
}

$config = Get-ConfigLocal
if (-not $config) {
    Write-Host "[!] Using default configuration" -ForegroundColor Yellow
    try {
        $defaultDownloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    } catch {
        $defaultDownloads = Join-Path $env:USERPROFILE "Downloads"
    }
    
    $config = [pscustomobject]@{
        IconStoragePath     = "C:\CustomIcons"
        DownloadsFolder     = $defaultDownloads
        DeletePngBehavior   = "delete"
        MonitorTimeoutSec   = 300
        IconDownloadWebsite = "https://www.flaticon.com/search?word="
        OpenBrowserNoSearch = $false
    }
}

$IconStoragePath    = $config.IconStoragePath
$DownloadsFolder    = $config.DownloadsFolder
$DeletePngBehavior  = $config.DeletePngBehavior
$MonitorTimeout     = $config.MonitorTimeoutSec
$IconDownloadSite   = $config.IconDownloadWebsite
$OpenBrowserNoSearch = $config.OpenBrowserNoSearch
$IconSize           = 256

function Convert-PngToIco {
    param([string]$PngPath, [string]$IcoPath, [int]$Size = 256)
    
    if (-not (Test-Path $PngPath)) {
        Write-EngineError "Source PNG not found: $PngPath"
        return $false
    }
    
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        Write-Host "`n[>] Converting PNG to ICO..." -ForegroundColor Cyan
        
        $sourceImage = [System.Drawing.Image]::FromFile($PngPath)
        if (-not $sourceImage) {
            throw "Failed to load image from file"
        }
        
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($sourceImage, 0, 0, $Size, $Size)
        $graphics.Dispose()
        
        $memoryStream = New-Object System.IO.MemoryStream
        $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $fileStream = [System.IO.File]::Create($IcoPath)
        $binaryWriter = New-Object System.IO.BinaryWriter($fileStream)
        
        $binaryWriter.Write([UInt16]0); $binaryWriter.Write([UInt16]1); $binaryWriter.Write([UInt16]1)
        if ($Size -eq 256) { $binaryWriter.Write([Byte]0); $binaryWriter.Write([Byte]0) } 
        else { $binaryWriter.Write([Byte]$Size); $binaryWriter.Write([Byte]$Size) }
        $binaryWriter.Write([Byte]0); $binaryWriter.Write([Byte]0); $binaryWriter.Write([UInt16]1); $binaryWriter.Write([UInt16]32)
        $binaryWriter.Write([UInt32]$memoryStream.Length); $binaryWriter.Write([UInt32]22)
        
        $memoryStream.Position = 0
        $memoryStream.CopyTo($fileStream)
        
        $binaryWriter.Close(); $fileStream.Close(); $memoryStream.Close()
        $bitmap.Dispose(); $sourceImage.Dispose()
        
        Write-Host "[✓] Conversion complete" -ForegroundColor Green
        return $true
    } catch {
        Write-EngineError "Conversion failed" $_.Exception.Message
        return $false
    }
}

function Set-FolderIcon {
    param([string]$FolderPath, [string]$IconPath)
    
    if (-not (Test-Path $FolderPath -PathType Container)) {
        Write-EngineError "Target folder not found: $FolderPath"
        return $false
    }
    
    if (-not (Test-Path $IconPath)) {
        Write-EngineError "Icon file not found: $IconPath"
        return $false
    }
    
    try {
        Write-Host "`n[>] Applying icon..." -ForegroundColor Cyan
        $desktopIniPath = Join-Path $FolderPath "desktop.ini"
        
        # 1. Clean up existing desktop.ini
        if (Test-Path $desktopIniPath -ErrorAction SilentlyContinue) {
            attrib -h -s -r "$desktopIniPath" 2>$null
            Remove-Item -Path $desktopIniPath -Force -ErrorAction SilentlyContinue
        }

        # 2. Create the new ini content
        $iniContent = "[.ShellClassInfo]`r`nIconResource=$IconPath,0`r`n[ViewState]`r`nMode=`r`nVid=`r`nFolderType=Generic"
        
        # Use a small retry loop for writing the file in case of locks
        $written = $false
        for ($i = 1; $i -le 3; $i++) {
            try {
                [System.IO.File]::WriteAllText($desktopIniPath, $iniContent, [System.Text.Encoding]::Unicode)
                $written = $true
                break
            } catch {
                Start-Sleep -Milliseconds 500
            }
        }

        if (-not $written) { throw "Could not write desktop.ini (file locked by another process)" }

        # 3. Set required attributes
        attrib +h +s "$desktopIniPath"
        attrib +r "$FolderPath" # The 'Read-only' flag on a FOLDER tells Windows to process desktop.ini

        # 4. "Nudge" the folder - wrapped in try/catch so it doesn't crash the script if locked
        try {
            (Get-Item -Path $FolderPath -Force).LastWriteTime = Get-Date
        } catch {
            # If this fails, it's okay. The icon will still apply after the shell refresh.
            Write-Host " [i] Note: Could not update folder timestamp (minor), continuing..." -ForegroundColor Gray
        }

        # 5. Notify the System of the change (Shell Refresh)
        $code = @"
            [DllImport("Shell32.dll")] 
            private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
            public static void Refresh() { 
                SHChangeNotify(0x08000000, 0x1000, IntPtr.Zero, IntPtr.Zero); 
            }
"@
        if (-not ([System.Management.Automation.PSTypeName]'Win32.Win32Refresh').Type) {
            Add-Type -MemberDefinition $code -Name Win32Refresh -Namespace Win32 -ErrorAction SilentlyContinue
        }
        [Win32.Win32Refresh]::Refresh()

        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Start-Process explorer.exe

        Write-Host "[✓] Icon applied successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-EngineError "Failed to apply folder icon" $_.Exception.Message
        return $false
    }
}

function Start-YMAIconChanger {
    param([string]$SearchKeyword, [string]$TargetFolder)

    $banner = "
  
          ██╗   ██╗███╗   ███╗ █████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗          
          ╚██╗ ██╔╝████╗ ████║██╔══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝          
           ╚████╔╝ ██╔████╔██║███████║       ██║   ██║   ██║██║   ██║██║     ███████╗          
            ╚██╔╝  ██║╚██╔╝██║██╔══██║       ██║   ██║   ██║██║   ██║██║     ╚════██║          
             ██║   ██║ ╚═╝ ██║██║  ██║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║          
             ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝          
                                                                                               
  ██╗ ██████╗ ██████╗ ███╗   ██╗     ██████╗██╗  ██╗ █████╗ ███╗   ██╗ ██████╗ ███████╗██████╗ 
  ██║██╔════╝██╔═══██╗████╗  ██║    ██╔════╝██║  ██║██╔══██╗████╗  ██║██╔════╝ ██╔════╝██╔══██╗
  ██║██║     ██║   ██║██╔██╗ ██║    ██║     ███████║███████║██╔██╗ ██║██║  ███╗█████╗  ██████╔╝
  ██║██║     ██║   ██║██║╚██╗██║    ██║     ██╔══██║██╔══██║██║╚██╗██║██║   ██║██╔══╝  ██╔══██╗
  ██║╚██████╗╚██████╔╝██║ ╚████║    ╚██████╗██║  ██║██║  ██║██║ ╚████║╚██████╔╝███████╗██║  ██║
  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
                                                                                               
"

    Write-Host $banner -ForegroundColor green
    Write-Host "  ═════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    if (-not (Test-Path $IconStoragePath)) { 
        try {
            New-Item -Path $IconStoragePath -ItemType Directory -Force -ErrorAction Stop | Out-Null 
            Write-Host "  [i] Icon storage created: $IconStoragePath" -ForegroundColor Cyan
        } catch {
            Write-EngineError "Failed to create icon storage directory" $_.Exception.Message
            return
        }
    }
    
    if(-not $OpenBrowserNoSearch){
        if (-not $SearchKeyword) { 
            Write-Host "`n  > Enter keyword: " -NoNewline -ForegroundColor Cyan
            $SearchKeyword = Read-Host
            if (-not $SearchKeyword) {
                Write-Host "  [X] No keyword provided" -ForegroundColor Red
                return
            }
        }
    }else{
        Write-Host "  [i] Opening icon download site without search" -ForegroundColor Cyan
    }
    
    if (-not (Test-Path $DownloadsFolder -PathType Container)) {
        Write-EngineError "Downloads folder not found: $DownloadsFolder"
        return
    }

    try {
        $beforeFiles = Get-ChildItem -Path $DownloadsFolder -Filter "*.png" -File -ErrorAction Stop | Select-Object -ExpandProperty FullName
    } catch {
        Write-EngineError "Failed to scan downloads folder" $_.Exception.Message
        return
    }
    
    try {
        if ($OpenBrowserNoSearch) {
            $searchUrl = $IconDownloadSite
        } else {
            $searchUrl = "$IconDownloadSite$([uri]::EscapeDataString($SearchKeyword))"
        }
        Start-Process $searchUrl -ErrorAction Stop
        Write-Host "  [>] Browser opened: $searchUrl" -ForegroundColor Cyan
    } catch {
        Write-EngineError "Failed to open browser" $_.Exception.Message
        return
    }

    Write-Host "`n  [~] Monitoring downloads: $DownloadsFolder" -ForegroundColor Yellow
    Write-Host "  [~] Timeout: $MonitorTimeout seconds" -ForegroundColor Yellow
    Write-Host "  [~] Press Ctrl+C to cancel`n" -ForegroundColor DarkGray
    
    $startTime = Get-Date
    $newPngFile = $null
    $dotCount = 0

    while (((Get-Date) - $startTime).TotalSeconds -lt $MonitorTimeout) {
        Start-Sleep -Milliseconds 500
        
        $dotCount = ($dotCount + 1) % 4
        $dots = "." * $dotCount + " " * (3 - $dotCount)
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        Write-Host "`r  [~] Scanning$dots ($elapsed/$MonitorTimeout sec)" -NoNewline -ForegroundColor Yellow
        
        try {
            $currentFiles = Get-ChildItem -Path $DownloadsFolder -Filter "*.png" -File -ErrorAction Stop | Select-Object -ExpandProperty FullName
            $newFiles = $currentFiles | Where-Object { $_ -notin $beforeFiles }
            
            if ($newFiles) {
                $newPngFile = Get-ChildItem -Path $DownloadsFolder -Filter "*.png" -File -ErrorAction Stop | 
                              Where-Object { $_.FullName -in $newFiles } | 
                              Sort-Object LastWriteTime -Descending | 
                              Select-Object -First 1
                
                Start-Sleep -Seconds 1.5
                
                try {
                    $fileStream = [System.IO.File]::Open($newPngFile.FullName, 'Open', 'Read', 'None')
                    $fileStream.Close()
                    Write-Host "`n  [✓] PNG detected: $($newPngFile.Name)" -ForegroundColor Green
                    break
                } catch {
                    Write-Host "`n  [i] Still downloading..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        } catch {
            Write-EngineError "Error during file monitoring" $_.Exception.Message
        }
    }
    
    Write-Host ""

    if ($newPngFile) {
        try {
            $iconBaseName = [System.IO.Path]::GetFileNameWithoutExtension($newPngFile.Name) -replace '[^\w\-]', '_'
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $iconFullPath = Join-Path $IconStoragePath "${iconBaseName}_${timestamp}.ico"

            Write-Host "  [>] Processing: $($newPngFile.Name)" -ForegroundColor Cyan
            
            if (Convert-PngToIco -PngPath $newPngFile.FullName -IcoPath $iconFullPath -Size $IconSize) {
                Write-Host "  [✓] Icon saved: $iconFullPath" -ForegroundColor Green
                
                if ($TargetFolder) {
                    if (Set-FolderIcon -FolderPath $TargetFolder -IconPath $iconFullPath) {
                        Write-Host "`n  ╔════════════════════════════════════════════════╗" -ForegroundColor Green
                        Write-Host "  ║       FOLDER ICON UPDATED SUCCESSFULLY!        ║" -ForegroundColor Green
                        Write-Host "  ╚════════════════════════════════════════════════╝" -ForegroundColor Green
                    } else {
                        Write-Host "`n  [!] Icon created but not applied" -ForegroundColor Yellow
                    }
                }

                switch ($DeletePngBehavior) {
                    "Ask" {
                        Write-Host "`n  [?] Delete original PNG? (Y/N): " -NoNewline -ForegroundColor Yellow
                        $response = Read-Host
                        if ($response -match '^[Yy]') {
                            try {
                                Remove-Item -Path $newPngFile.FullName -Force -ErrorAction Stop
                                Write-Host "  [✓] PNG deleted" -ForegroundColor Green
                            } catch {
                                Write-EngineError "Failed to delete PNG file" $_.Exception.Message
                            }
                        } else {
                            Write-Host "  [i] PNG kept" -ForegroundColor DarkGray
                        }
                    }
                    "Delete" {
                        try {
                            Remove-Item -Path $newPngFile.FullName -Force -ErrorAction Stop
                            Write-Host "`n  [✓] PNG auto-deleted" -ForegroundColor Green
                        } catch {
                            Write-EngineError "Failed to auto-delete PNG file" $_.Exception.Message
                        }
                    }
                    "Keep" {
                        Write-Host "`n  [i] PNG kept (auto-keep enabled)" -ForegroundColor DarkGray
                    }
                }
            } else {
                Write-Host "  [X] Conversion failed" -ForegroundColor Red
            }
        } catch {
            Write-EngineError "Error processing downloaded file" $_.Exception.Message
        }
    } else {
        Write-Host "  [X] Timeout: No PNG detected in $MonitorTimeout seconds" -ForegroundColor Red
        Write-Host "  [i] Ensure PNG was saved to: $DownloadsFolder" -ForegroundColor Yellow
    }
}

try {
    Start-YMAIconChanger -SearchKeyword $Keyword -TargetFolder $FolderPath
    
    if ($FolderPath) {
        Write-Host "`n  Press any key to exit..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} catch {
    Write-EngineError "Critical error in Icon Engine" $_.Exception.Message
    Write-Host "`n  Press any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
'@

# ═══════════════════════════════════════════════════════════════════════════
# 5. INSTALLATION LOGIC (ENHANCED)
# ═══════════════════════════════════════════════════════════════════════════

function Install-YMAIconChanger {
    Clear-Host
    Write-CyberHeader "INSTALLATION SEQUENCE INITIATED"

    Write-Host "  [1/5] " -NoNewline -ForegroundColor $DimText
    Write-Host "Creating installation directory..." -ForegroundColor $TextWhite
    if (-not (Ensure-InstallDirectory)) {
        Write-Host "  [X] Installation aborted" -ForegroundColor $ErrorColor
        Read-Host "Press Enter to return"
        return
    }
    Write-Host "        ✓ $InstallPath" -ForegroundColor $CyberGreen

    Write-Host "  [2/5] " -NoNewline -ForegroundColor $DimText
    Write-Host "Deploying script payload..." -ForegroundColor $TextWhite
    try {
        $YMAIconChangerPayload | Out-File -FilePath $FullScriptPath -Encoding UTF8 -Force -ErrorAction Stop
        Write-Host "        ✓ $ScriptFileName" -ForegroundColor $CyberGreen
    } catch {
        Write-LogError "Failed to write script file" $_.Exception.Message
        Read-Host "Press Enter to return"
        return
    }

    Write-Host "  [3/5] " -NoNewline -ForegroundColor $DimText
    Write-Host "Initializing configuration..." -ForegroundColor $TextWhite
    try {
        $config = Get-YMAConfig
        Write-Host "        ✓ $ConfigFileName" -ForegroundColor $CyberGreen
    } catch {
        Write-LogError "Failed to create configuration" $_.Exception.Message
        Read-Host "Press Enter to return"
        return
    }

    Write-Host "  [4/5] " -NoNewline -ForegroundColor $DimText
    Write-Host "Setting up custom icon..." -ForegroundColor $TextWhite
    $tempIconPng = Join-Path $env:TEMP "yma_temp_icon.png"
    $iconDownloadSuccess = Download-GoogleDriveImage -Url $GDriveLink -DestinationPath $tempIconPng
    
    $finalIconValue = "imageres.dll,-109" 
    
    if ($iconDownloadSuccess) {
        $conversionResult = Convert-PngToIco-Installer -PngPath $tempIconPng -IcoPath $FullIconPath -Size 64
        
        if ($conversionResult) {
            Write-Host "        ✓ Custom icon applied" -ForegroundColor $CyberGreen
            $finalIconValue = $FullIconPath
        } else {
            Write-Host "        ! Using default icon" -ForegroundColor $WarningColor
        }
        
        try {
            Remove-Item -Path $tempIconPng -Force -ErrorAction SilentlyContinue
        } catch {}
    } else {
        Write-Host "        ! Using default icon" -ForegroundColor $WarningColor
    }

    Write-Host "  [5/5] " -NoNewline -ForegroundColor $DimText
    Write-Host "Integrating with context menu..." -ForegroundColor $TextWhite
    try {
        $MenuTitle = "Change Folder Icon (YMA)"
        
        $RegPathFolder = "Registry::HKEY_CLASSES_ROOT\Directory\shell\YMAIconChanger"
        New-Item -Path $RegPathFolder -Force -ErrorAction Stop | Out-Null
        Set-ItemProperty -Path $RegPathFolder -Name "(Default)" -Value $MenuTitle -ErrorAction Stop
        Set-ItemProperty -Path $RegPathFolder -Name "Icon" -Value $finalIconValue -ErrorAction Stop
        Set-ItemProperty -Path $RegPathFolder -Name "Position" -Value "Bottom" -ErrorAction Stop
        
        $RegCommandFolder = "$RegPathFolder\command"
        New-Item -Path $RegCommandFolder -Force -ErrorAction Stop | Out-Null
        Set-ItemProperty -Path $RegCommandFolder -Name "(Default)" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$FullScriptPath`" -FolderPath `"%1`"" 

        $RegPathBg = "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\YMAIconChanger"
        New-Item -Path $RegPathBg -Force -ErrorAction Stop | Out-NULL
        Set-ItemProperty -Path $RegPathBg -Name "(Default)" -Value $MenuTitle -ErrorAction Stop
        Set-ItemProperty -Path $RegPathBg -Name "Icon" -Value $finalIconValue -ErrorAction Stop
        Set-ItemProperty -Path $RegPathBg -Name "Position" -Value "Bottom" -ErrorAction Stop
        
        $RegCommandBg = "$RegPathBg\command"
        New-Item -Path $RegCommandBg -Force -ErrorAction Stop | Out-NULL
        Set-ItemProperty -Path $RegCommandBg -Name "(Default)" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$FullScriptPath`" -FolderPath `"%V`""

        Write-Host "        ✓ Registry entries created" -ForegroundColor $CyberGreen
    } catch {
        Write-LogError "Failed to create registry entries" $_.Exception.Message
        Read-Host "Press Enter to return"
        return
    }

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor $CyberGreen
    Write-Host "  ║       INSTALLATION COMPLETED SUCCESSFULLY!             ║" -ForegroundColor $CyberGreen
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor $CyberGreen
    Write-Host ""
    Write-Host "  Right-click any folder to access YMA Icon Changer!" -ForegroundColor $TextWhite
    Write-Host ""
    Read-Host "Press Enter to return"
}

function Uninstall-YMAIconChanger {
    Clear-Host
    Write-CyberHeader "UNINSTALL SEQUENCE"
    
    Write-Host "  [!] " -NoNewline -ForegroundColor $ErrorColor
    Write-Host "Confirm uninstallation? (Y/N): " -NoNewline -ForegroundColor $TextWhite
    $confirm = Read-Host
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "`n  [i] Operation cancelled" -ForegroundColor $DimText
        Start-Sleep -Seconds 1
        return
    }
    
    Write-Host ""

    Write-Host "  [1/2] " -NoNewline -ForegroundColor $DimText
    Write-Host "Removing context menu entries..." -ForegroundColor $TextWhite
    try {
        Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\Directory\shell\YMAIconChanger" -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\YMAIconChanger" -Recurse -ErrorAction SilentlyContinue
        Write-Host "        ✓ Registry cleaned" -ForegroundColor $CyberGreen
    } catch {
        Write-LogError "Failed to remove some registry entries" $_.Exception.Message
    }

    Write-Host "  [2/2] " -NoNewline -ForegroundColor $DimText
    Write-Host "Removing installation files..." -ForegroundColor $TextWhite
    if (Test-Path $InstallPath) {
        try {
            Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop
            Write-Host "        ✓ Files removed" -ForegroundColor $CyberGreen
        } catch {
            Write-LogError "Failed to remove installation directory" $_.Exception.Message
            Write-Host "        ! Some files may remain" -ForegroundColor $WarningColor
        }
    } else {
        Write-Host "        ✓ No files to remove" -ForegroundColor $CyberGreen
    }

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor $CyberGreen
    Write-Host "  ║      UNINSTALLATION COMPLETED SUCCESSFULLY             ║" -ForegroundColor $CyberGreen
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor $CyberGreen
    Write-Host ""
    Read-Host "Press Enter to return"
}

# ═══════════════════════════════════════════════════════════════════════════
# 6. MAIN MENU (CYBER REDESIGN)
# ═══════════════════════════════════════════════════════════════════════════

function Show-MainMenu {
    while ($true) {
        Clear-Host
        
        $asciiLogo = @'
          
  ██\     ██\ ██\      ██\  ██████\        ████████\  ██████\   ██████\  ██\       ██████\  
  \██\   ██  |███\    ███ |██  __██\       \__██  __|██  __██\ ██  __██\ ██ |     ██  __██\ 
   \██\ ██  / ████\  ████ |██ /  ██ |         ██ |   ██ /  ██ |██ /  ██ |██ |     ██ /  \__|
    \████  /  ██\██\██ ██ |████████ |         ██ |   ██ |  ██ |██ |  ██ |██ |     \██████\  
     \██  /   ██ \███  ██ |██  __██ |         ██ |   ██ |  ██ |██ |  ██ |██ |      \____██\ 
      ██ |    ██ |\█  /██ |██ |  ██ |         ██ |   ██ |  ██ |██ |  ██ |██ |     ██\   ██ |
      ██ |    ██ | \_/ ██ |██ |  ██ |         ██ |    ██████  | ██████  |████████\\██████  |
      \__|    \__|     \__|\__|  \__|         \__|    \______/  \______/ \________|\______/ 
  
'@
        
        Write-Host $asciiLogo -ForegroundColor $CyberGreen
        Write-Host "    ════════════════════════════════════════════════════════════════" -ForegroundColor $AccentColor
        Write-Host "     FOLDER ICON CHANGER INSTALLER" -ForegroundColor $CyberTeal
        Write-Host "     v$Version | By Youssef M. A." -ForegroundColor $DimText
        Write-Host "    ════════════════════════════════════════════════════════════════" -ForegroundColor $AccentColor
        Write-Host ""
        
        $isInstalled = Test-Path $FullScriptPath
        Write-Host "    ┌─[ " -NoNewline -ForegroundColor $AccentColor
        Write-Host "SYSTEM STATUS" -NoNewline -ForegroundColor $CyberTeal
        Write-Host " ]" -ForegroundColor $AccentColor
        Write-Host "    │" -ForegroundColor $AccentColor
        Write-Host "    ├──> Status: " -NoNewline -ForegroundColor $AccentColor
        
        if ($isInstalled) {
            Write-Host "ACTIVE" -ForegroundColor $CyberGreen
            try {
                $config = Get-YMAConfig
                Write-Host "    ├──> Timeout: " -NoNewline -ForegroundColor $AccentColor
                Write-Host "$($config.MonitorTimeoutSec)s" -ForegroundColor $DimText
                Write-Host "    ├──> PNG CleanUp: " -NoNewline -ForegroundColor $AccentColor
                Write-Host "$($config.DeletePngBehavior)s" -ForegroundColor $DimText
                Write-Host "    ├──> Browser: " -NoNewline -ForegroundColor $AccentColor
                if ($config.OpenBrowserNoSearch) {
                    Write-Host "No Search Mode" -ForegroundColor $DimText
                } else {
                    Write-Host "Search Mode" -ForegroundColor $DimText
                }
                $siteName = ($config.IconDownloadWebsite -split '//')[1] -split '/' | Select-Object -First 1
                Write-Host "    └──> Site: " -NoNewline -ForegroundColor $AccentColor
                Write-Host "$siteName" -ForegroundColor $DimText
            } catch {}
        } else {
            Write-Host "NOT INSTALLED" -ForegroundColor $ErrorColor
            Write-Host "    └──> Install required" -ForegroundColor $DimText
        }
        
        Write-Host ""
        Write-Host "    ┌─[ " -NoNewline -ForegroundColor $AccentColor
        Write-Host "MAIN MENU" -NoNewline -ForegroundColor $CyberTeal
        Write-Host " ]" -ForegroundColor $AccentColor
        Write-Host "    │" -ForegroundColor $AccentColor
        Write-Host "    ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[1] Install / Repair System" -ForegroundColor $TextWhite
        Write-Host "    ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[2] Uninstall System" -ForegroundColor $TextWhite
        Write-Host "    ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[3] Configuration Panel" -ForegroundColor $TextWhite
        Write-Host "    ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[4] System Information" -ForegroundColor $TextWhite
        Write-Host "    ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[5] Open Icon Download Site" -ForegroundColor $TextWhite
        Write-Host "    └──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "[Q] Quit" -ForegroundColor $DimText
        Write-Host ""
        Write-Host "    > " -NoNewline -ForegroundColor $CyberTeal
        
        $choice = Read-Host
        
        switch ($choice.ToUpper()) {
            '1' { Install-YMAIconChanger }
            '2' { Uninstall-YMAIconChanger }
            '3' { 
                if ($isInstalled) {
                    Configure-YMAIconChanger 
                } else {
                    Write-Host "`n    [X] Install required first" -ForegroundColor $ErrorColor
                    Start-Sleep -Seconds 1.5
                }
            }
            '4' { Show-InstallationInfo }
            '5' {
                try {
                    if ($isInstalled) {
                        $config = Get-YMAConfig
                        $baseUrl = $config.IconDownloadWebsite -replace '\?.*', ''
                        Start-Process $baseUrl -ErrorAction Stop
                        Write-Host "`n    [✓] Browser opened: $baseUrl" -ForegroundColor $CyberGreen
                    } else {
                        Start-Process "https://www.flaticon.com" -ErrorAction Stop
                        Write-Host "`n    [✓] Browser opened (default site)" -ForegroundColor $CyberGreen
                    }
                    Start-Sleep -Seconds 1.5
                } catch {
                    Write-Host "`n    [X] Failed to open browser: $($_.Exception.Message)" -ForegroundColor $ErrorColor
                    Start-Sleep -Seconds 1.5
                }
            }
            'Q' { 
                Clear-Host
                Write-Host "`n    [✓] Shutdown complete" -ForegroundColor $CyberGreen
                Write-Host "    Thank you for using YMA Tools`n" -ForegroundColor $CyberTeal
                Start-Sleep -Seconds 1
                Exit 
            }
            default {
                Write-Host "`n    [X] Invalid selection" -ForegroundColor $ErrorColor
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-InstallationInfo {
    Clear-Host
    Write-CyberHeader "SYSTEM INFORMATION"
    
    Write-Host "  ┌─[ INSTALLATION PATH ]" -ForegroundColor $AccentColor
    Write-Host "  └──> $InstallPath" -ForegroundColor $DimText
    Write-Host ""
    
    Write-Host "  ┌─[ FILES ]" -ForegroundColor $AccentColor
    if (Test-Path $FullScriptPath) {
        $fileInfo = Get-Item $FullScriptPath
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "✓ $ScriptFileName " -NoNewline -ForegroundColor $CyberGreen
        Write-Host "($([math]::Round($fileInfo.Length/1KB, 2)) KB)" -ForegroundColor $DimText
    } else {
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "✗ $ScriptFileName (Not found)" -ForegroundColor $ErrorColor
    }
    
    if (Test-Path $FullConfigPath) {
        $fileInfo = Get-Item $FullConfigPath
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "✓ $ConfigFileName " -NoNewline -ForegroundColor $CyberGreen
        Write-Host "($([math]::Round($fileInfo.Length/1KB, 2)) KB)" -ForegroundColor $DimText
    } else {
        Write-Host "  ├──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "✗ $ConfigFileName (Not found)" -ForegroundColor $ErrorColor
    }
    
    if (Test-Path $FullIconPath) {
        $fileInfo = Get-Item $FullIconPath
        Write-Host "  └──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "✓ $MenuIconName " -NoNewline -ForegroundColor $CyberGreen
        Write-Host "($([math]::Round($fileInfo.Length/1KB, 2)) KB)" -ForegroundColor $DimText
    } else {
        Write-Host "  └──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "⚠ $MenuIconName (Using default)" -ForegroundColor $WarningColor
    }
    
    Write-Host ""
    Write-Host "  ┌─[ REGISTRY ENTRIES ]" -ForegroundColor $AccentColor
    
    $regPaths = @(
        "Registry::HKEY_CLASSES_ROOT\Directory\shell\YMAIconChanger",
        "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\YMAIconChanger"
    )
    
    $regIndex = 0
    foreach ($regPath in $regPaths) {
        $regIndex++
        $shortPath = $regPath.Replace('Registry::HKEY_CLASSES_ROOT\', 'HKCR\')
        $prefix = if ($regIndex -lt $regPaths.Count) { "├──>" } else { "└──>" }
        
        if (Test-Path $regPath) {
            Write-Host "  $prefix " -NoNewline -ForegroundColor $AccentColor
            Write-Host "✓ $shortPath" -ForegroundColor $CyberGreen
        } else {
            Write-Host "  $prefix " -NoNewline -ForegroundColor $AccentColor
            Write-Host "✗ $shortPath" -ForegroundColor $ErrorColor
        }
    }
    
    Write-Host ""
    Write-Host "  ┌─[ CONFIGURATION ]" -ForegroundColor $AccentColor
    try {
        $config = Get-YMAConfig
        Write-Host "  ├──> Icon Storage    : " -NoNewline -ForegroundColor $AccentColor
        Write-Host "$($config.IconStoragePath)" -ForegroundColor $DimText
        Write-Host "  ├──> Downloads Path  : " -NoNewline -ForegroundColor $AccentColor
        Write-Host "$($config.DownloadsFolder)" -ForegroundColor $DimText
        Write-Host "  ├──> PNG Cleanup     : " -NoNewline -ForegroundColor $AccentColor
        Write-Host "$($config.DeletePngBehavior)" -ForegroundColor $DimText
        Write-Host "  ├──> Monitor Timeout : " -NoNewline -ForegroundColor $AccentColor
        Write-Host "$($config.MonitorTimeoutSec) seconds" -ForegroundColor $DimText
        Write-Host "  ├──> Download Site   : " -NoNewline -ForegroundColor $AccentColor
        $siteName = ($config.IconDownloadWebsite -split '//')[1] -split '/' | Select-Object -First 1
        Write-Host "$siteName" -ForegroundColor $DimText
        Write-Host "  └──> Browser Mode    : " -NoNewline -ForegroundColor $AccentColor
        if ($config.OpenBrowserNoSearch) {
            Write-Host "No Search (Direct)" -ForegroundColor $DimText
        } else {
            Write-Host "Search Mode (With Keyword)" -ForegroundColor $DimText
        }
    } catch {
        Write-Host "  └──> " -NoNewline -ForegroundColor $AccentColor
        Write-Host "✗ Unable to load configuration" -ForegroundColor $ErrorColor
    }
    
    Write-Host ""
    Write-Host "  ┌─[ SYSTEM INFO ]" -ForegroundColor $AccentColor
    Write-Host "  ├──> PowerShell    : " -NoNewline -ForegroundColor $AccentColor
    Write-Host "v$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" -ForegroundColor $DimText
    Write-Host "  ├──> OS Version    : " -NoNewline -ForegroundColor $AccentColor
    Write-Host "$([System.Environment]::OSVersion.Version)" -ForegroundColor $DimText
    Write-Host "  ├──> Admin Rights  : " -NoNewline -ForegroundColor $AccentColor
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if ($isAdmin) {
        Write-Host "✓ Granted" -ForegroundColor $CyberGreen
    } else {
        Write-Host "✗ Denied" -ForegroundColor $ErrorColor
    }
    Write-Host "  └──> Manager Version: " -NoNewline -ForegroundColor $AccentColor
    Write-Host "v$Version" -ForegroundColor $DimText
    
    Write-Host ""
    Write-Host "  ┌─[ AUTHOR ]" -ForegroundColor $AccentColor
    Write-Host "  ├──> Name     : " -NoNewline -ForegroundColor $AccentColor
    Write-Host "Youssef Mahmoud Abdelqeader" -ForegroundColor $DimText
    Write-Host "  ├──> Alias    : " -NoNewline -ForegroundColor $AccentColor
    Write-Host "Akhdar / Mr.Green" -ForegroundColor $DimText
    Write-Host "  └──> Project  : " -NoNewline -ForegroundColor $AccentColor
    Write-Host "YMA Tools Suite" -ForegroundColor $DimText
    
    Write-Host ""
    Read-Host "Press Enter to return"
}



# ═══════════════════════════════════════════════════════════════════════════
# 7. SCRIPT ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════

Show-MainMenu