# cargo-heal installer (binary-only distribution).
# Usage: iwr -useb https://raw.githubusercontent.com/gist-rs/cargo-heal/main/install.ps1 | iex
$ErrorActionPreference = "Stop"

$Repo = "gist-rs/cargo-heal"
$Dest = Join-Path $env:USERPROFILE ".cargo\bin"

if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
    throw "unsupported architecture: $env:PROCESSOR_ARCHITECTURE (only x86_64 windows binaries ship)"
}

$release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
$tag = $release.tag_name
if (-not $tag) { throw "cannot resolve the latest release (none published yet?)" }

$base = "https://github.com/$Repo/releases/download/$tag"
$asset = "cargo-heal-$tag-x86_64-pc-windows-msvc.zip"

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cargo-heal-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    Write-Host "fetching $asset ..."
    Invoke-WebRequest -UseBasicParsing "$base/$asset" -OutFile "$tmp\$asset"
    Invoke-WebRequest -UseBasicParsing "$base/SHA256SUMS" -OutFile "$tmp\SHA256SUMS"

    $line = Select-String -Path "$tmp\SHA256SUMS" -Pattern ([regex]::Escape($asset)) | Select-Object -First 1
    if (-not $line) { throw "$asset not listed in SHA256SUMS" }
    $want = ($line.Line -split '\s+')[0]
    $got = (Get-FileHash -Algorithm SHA256 "$tmp\$asset").Hash.ToLower()
    if ($got -ne $want) { throw "checksum mismatch (want $want, got $got)" }

    Expand-Archive -Path "$tmp\$asset" -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Move-Item -Force (Join-Path $tmp "cargo-heal.exe") (Join-Path $Dest "cargo-heal.exe")
    Write-Host "installed cargo-heal $tag (x86_64-pc-windows-msvc) -> $Dest\cargo-heal.exe"
    if (($env:Path -split ';') -notcontains $Dest) {
        Write-Host "note: $Dest is not on your PATH - add it to use 'cargo heal'"
    }
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
