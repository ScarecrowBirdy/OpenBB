param(
    [Parameter(Mandatory=$true,Position=0)][string]$InputDirectory,
    [Parameter(Mandatory=$true,Position=1)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$inputPath = (Resolve-Path -LiteralPath $InputDirectory).Path
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputPath) { throw 'Choose a new output directory; existing outputs are never overwritten.' }
$files = @(Get-ChildItem -LiteralPath $inputPath -File -Filter '*.BOX' | Sort-Object Name)
if (!$files.Count) { throw 'No BOX archives found.' }
$tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'bin/unbox.exe'
if (!(Test-Path -LiteralPath $tool)) { throw 'Run build.ps1 first.' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
foreach ($file in $files) {
    & $tool $file.FullName (Join-Path $outputPath $file.BaseName)
    if ($LASTEXITCODE -ne 0) { throw "Extraction failed: $($file.Name). Earlier outputs remain." }
}
