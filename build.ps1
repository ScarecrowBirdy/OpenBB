param(
    [switch]$Bootstrap,
    [switch]$Test,
    [string]$GameDirectory,
    [string]$Compiler,
    [ValidateSet('all','assets','unbox','mfbdecoder','m10decoder','headless-demo')]
    [string]$Target = 'all'
)
$ErrorActionPreference = 'Stop'
if ($Test -and $Target -ne 'all') { throw '-Test requires -Target all (the default).' }
if ($GameDirectory -and !$Test) { throw '-GameDirectory requires -Test.' }
if ($Compiler) { $Compiler = (Resolve-Path -LiteralPath $Compiler).Path }
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
    $sources = [ordered]@{
        'unbox' = 'tools/unbox.d'
        'mfbdecoder' = 'tools/mfbdecoder.d'
        'm10decoder' = 'tools/m10decoder.d'
        'headless-demo' = 'examples/headless/main.d'
    }
    $targets = if ($Target -eq 'all') { @($sources.Keys) } elseif ($Target -eq 'assets') {
        @('unbox','mfbdecoder','m10decoder')
    } else { @($Target) }
    foreach ($tool in $targets) {
        Write-Host "Building $tool"
        & $Compiler '-m64' '-i' '-Isource' '-g' '-O' "-od$build" "-of$(Join-Path $bin ($tool+'.exe'))" $sources[$tool]
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $tool" }
    }
    if ($Test) {
        foreach ($suite in @('asset','world','cli')) {
            & $Compiler '-m64' '-i' '-Isource' '-g' '-unittest' "-od$build" "-of$(Join-Path $build ($suite+'-tests.exe'))" "tests/${suite}_tests.d"
            if ($LASTEXITCODE -ne 0) { throw "Test build failed: $suite" }
            & (Join-Path $build ($suite+'-tests.exe'))
            if ($LASTEXITCODE -ne 0) { throw "Tests failed: $suite" }
        }
        if ($GameDirectory) {
            & $Compiler '-m64' '-i' '-Isource' '-g' '-O' "-od$build" "-of$(Join-Path $build 'asset-audit.exe')" 'tests/asset_audit.d'
            if ($LASTEXITCODE -ne 0) { throw 'Corpus audit build failed.' }
            python tests/verify_corpus.py --game $GameDirectory
            if ($LASTEXITCODE -ne 0) { throw 'Corpus verification failed.' }
        }
    }
    Write-Host 'OpenBB build complete.'
} finally { Pop-Location }
