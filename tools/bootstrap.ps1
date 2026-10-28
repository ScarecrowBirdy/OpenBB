param([switch]$Offline)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = '2.111.0'
$sha = '6A37075BA547D25B9B836023B25A878827EF0234F8A9243C6058AD1F63036A15'
$cache = Join-Path $root '.tools'
$install = Join-Path $cache "dmd-$version"
$compiler = Join-Path $install 'dmd2/windows/bin64/dmd.exe'
if (Test-Path -LiteralPath $compiler) { return $compiler }
$archive = Join-Path $cache "dmd.$version.windows.zip"
New-Item -ItemType Directory -Force $cache | Out-Null
if (!(Test-Path -LiteralPath $archive)) {
    if ($Offline) { throw 'Pinned compiler is not cached. Run build.ps1 -Bootstrap with network access once.' }
    Invoke-WebRequest -Uri "https://downloads.dlang.org/releases/2025/dmd.$version.windows.zip" -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $sha) {
    throw "Compiler archive SHA256 mismatch: $archive"
}
Expand-Archive -LiteralPath $archive -DestinationPath $install -Force
if (!(Test-Path -LiteralPath $compiler)) { throw 'Compiler extraction failed.' }
return $compiler
