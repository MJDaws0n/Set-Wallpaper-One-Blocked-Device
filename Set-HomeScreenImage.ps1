param(
    [string]$Path,
    [string]$InitialPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Select-ImageFile {
    param(
        [string]$StartPath
    )

    if ([Threading.Thread]::CurrentThread.ApartmentState -ne [Threading.ApartmentState]::STA) {
        $argumentList = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-STA',
            '-File', "`"$PSCommandPath`""
        )

        if ($StartPath) {
            $argumentList += @('-InitialPath', "`"$StartPath`"")
        }

        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -Wait -PassThru
        exit $process.ExitCode
    }

    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose a home screen image'
    $dialog.Filter = 'Image files|*.bmp;*.dib;*.gif;*.jpg;*.jpeg;*.jpe;*.jfif;*.png|All files|*.*'
    $dialog.Multiselect = $false

    if ($StartPath) {
        if (Test-Path -LiteralPath $StartPath -PathType Container) {
            $dialog.InitialDirectory = $StartPath
        }
        elseif (Test-Path -LiteralPath $StartPath -PathType Leaf) {
            $dialog.InitialDirectory = Split-Path -Path $StartPath -Parent
            $dialog.FileName = Split-Path -Path $StartPath -Leaf
        }
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }

    throw 'No image was selected.'
}

function Set-HomeScreenImage {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Image not found: $SourcePath"
    }

    Add-Type -AssemblyName System.Drawing

    $localThemeDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes'
    $roamingThemeDirectory = Join-Path $env:APPDATA 'Microsoft\Windows\Themes'
    $null = New-Item -ItemType Directory -Path $localThemeDirectory -Force
    $null = New-Item -ItemType Directory -Path $roamingThemeDirectory -Force

    $themeWallpaperPath = Join-Path $localThemeDirectory '67Wallpaper.bmp'
    $cachedWallpaperPath = Join-Path $localThemeDirectory '67Wallpaper.jpg'
    $themeFilePath = Join-Path $localThemeDirectory '67Custom.theme'
    $themeCachePath = Join-Path $roamingThemeDirectory 'TranscodedWallpaper'
    $cachedFilesDirectory = Join-Path $roamingThemeDirectory 'CachedFiles'
    $null = New-Item -ItemType Directory -Path $cachedFilesDirectory -Force

    $image = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap $image.Width, $image.Height
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.DrawImage($image, 0, 0, $image.Width, $image.Height)
            }
            finally {
                $graphics.Dispose()
            }

            $bitmap.Save($themeWallpaperPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
            $bitmap.Save($cachedWallpaperPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        $image.Dispose()
    }

    Copy-Item -LiteralPath $themeWallpaperPath -Destination $themeCachePath -Force
    Get-ChildItem -LiteralPath $cachedFilesDirectory -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $cachedWallpaperPath -Destination (Join-Path $cachedFilesDirectory 'CachedImage_1920_1080_POS0.jpg') -Force

    $policy = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
    if ($policy -and $policy.Wallpaper) {
        $policyWallpaperPath = [Environment]::ExpandEnvironmentVariables($policy.Wallpaper)
        $policyWallpaperDirectory = Split-Path -Path $policyWallpaperPath -Parent
        if ($policyWallpaperDirectory) {
            $null = New-Item -ItemType Directory -Path $policyWallpaperDirectory -Force
        }

        Copy-Item -LiteralPath $themeWallpaperPath -Destination $policyWallpaperPath -Force
    }

    $themeContent = @"
[Theme]
DisplayName=67 Custom
SetLogonBackground=0

[Control Panel\Desktop]
Wallpaper=$themeWallpaperPath
TileWallpaper=0
WallpaperStyle=10
Pattern=

[VisualStyles]
Path=%ResourceDir%\Themes\Aero\Aero.msstyles
ColorStyle=NormalColor
Size=NormalSize
AutoColorization=0
ColorizationColor=0XC4680081
SystemMode=Dark
AppMode=Dark

[MasterThemeSelector]
MTSM=RJSPBS
"@

    Set-Content -LiteralPath $themeFilePath -Value $themeContent -Encoding Unicode
    Start-Process -FilePath $themeFilePath
    Start-Sleep -Milliseconds 1500
    Start-Process -FilePath 'rundll32.exe' -ArgumentList 'user32.dll,UpdatePerUserSystemParameters 1, True' -WindowStyle Hidden -Wait
    $explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
    foreach ($explorerProcess in $explorerProcesses) {
        Stop-Process -Id $explorerProcess.Id -Force
    }
    Start-Sleep -Seconds 1
    Start-Process -FilePath 'explorer.exe'
    Write-Output "Home screen image applied via theme file: $themeFilePath"
}

if (-not $Path) {
    $Path = Select-ImageFile -StartPath $InitialPath
}

Set-HomeScreenImage -SourcePath $Path
