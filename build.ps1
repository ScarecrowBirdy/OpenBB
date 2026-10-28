param(
    [switch]$Bootstrap,
    [switch]$Test,
    [string]$GameDirectory,
    [string]$Compiler
)
$ErrorActionPreference = 'Stop'
if ($GameDirectory) { $GameDirectory = (Resolve-Path -LiteralPath $GameDirectory).Path }
if (!$Compiler) { $Compiler = & (Join-Path $PSScriptRoot 'tools/bootstrap.ps1') -Offline:(!$Bootstrap) }
$version = & $Compiler --version
if ($LASTEXITCODE -ne 0 -or ($version -join "`n") -notmatch 'v2\.111\.0') {
    throw 'This build is pinned to DMD 2.111.0. See README.md.'
}
$bin = Join-Path $PSScriptRoot 'bin'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force $bin,$build | Out-Null
Push-Location $PSScriptRoot
try {
    foreach ($tool in @('unbox','mfbdecoder','m10decoder')) {
        Write-Host "Building $tool"
        & $Compiler '-m64' '-i' '-Isource' '-g' '-O' "-od$build" "-of$(Join-Path $bin ($tool+'.exe'))" "tools/$tool.d"
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $tool" }
    }
    if ($Test) {
        & $Compiler '-m64' '-i' '-Isource' '-g' '-unittest' "-od$build" "-of$(Join-Path $build 'asset-tests.exe')" 'tests/asset_tests.d'
        if ($LASTEXITCODE -ne 0) { throw 'Test build failed.' }
        & (Join-Path $build 'asset-tests.exe')
        if ($LASTEXITCODE -ne 0) { throw 'Unit tests failed.' }
        if ($GameDirectory) {
            & $Compiler '-m64' '-i' '-Isource' '-g' '-O' "-od$build" "-of$(Join-Path $build 'asset-audit.exe')" 'tests/asset_audit.d'
            if ($LASTEXITCODE -ne 0) { throw 'Corpus audit build failed.' }
            python tests/verify_corpus.py --game $GameDirectory
            if ($LASTEXITCODE -ne 0) { throw 'Corpus verification failed.' }
        }
    } elseif ($GameDirectory) { throw '-GameDirectory requires -Test.' }
    Write-Host 'Asset-tool build complete.'
} finally { Pop-Location }
