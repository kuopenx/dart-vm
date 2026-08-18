#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$Owner = "kuopenx"
$Repo = "dart-vm"
$BinDir = Join-Path $env:LOCALAPPDATA "dart-vm"

switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $Arch = "amd64" }
    default { throw "No released binary for windows/$($env:PROCESSOR_ARCHITECTURE)" }
}

$ZipName = "dart-vm-windows-$Arch.zip"
$ReleaseRoot = "https://github.com/$Owner/$Repo/releases/latest/download"
$TmpDir = Join-Path $env:TEMP "dart-vm-install-$([guid]::NewGuid())"

try {
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
    $ZipPath = Join-Path $TmpDir $ZipName
    $ChecksumsPath = Join-Path $TmpDir "checksums.txt"

    Write-Host "Downloading $ZipName..."
    Invoke-WebRequest "$ReleaseRoot/$ZipName" -OutFile $ZipPath -UseBasicParsing
    Invoke-WebRequest "$ReleaseRoot/checksums.txt" -OutFile $ChecksumsPath -UseBasicParsing

    $ChecksumLine = Get-Content $ChecksumsPath |
        Where-Object { $_ -match "\s+$([regex]::Escape($ZipName))$" } |
        Select-Object -First 1
    if (-not $ChecksumLine) {
        throw "No checksum found for $ZipName"
    }

    $Expected = ($ChecksumLine.Trim() -split '\s+')[0].ToLowerInvariant()
    $Actual = (Get-FileHash $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Actual -ne $Expected) {
        throw "Checksum mismatch: expected $Expected, got $Actual"
    }

    $ExtractDir = Join-Path $TmpDir "extract"
    Expand-Archive $ZipPath -DestinationPath $ExtractDir -Force
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    Copy-Item (Join-Path $ExtractDir "dart-vm.exe") (Join-Path $BinDir "dart-vm.exe") -Force

    Write-Host "Installed dart-vm to $BinDir\dart-vm.exe"
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$BinDir*") {
        Write-Host "Add $BinDir to your user PATH."
    }
}
finally {
    if (Test-Path $TmpDir) {
        Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
