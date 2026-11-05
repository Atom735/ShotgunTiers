<#
.SYNOPSIS
  Build Factorio Mod Portal zip packages from mod folders in this repo.

.EXAMPLE
  .\scripts\pack-mod.ps1 -ModDir atmos_shotgun_tiers

.EXAMPLE
  .\scripts\pack-mod.ps1 -All
#>
[CmdletBinding(DefaultParameterSetName = "One")]
param(
  [Parameter(ParameterSetName = "One", Position = 0)]
  [string]$ModDir,

  [Parameter(ParameterSetName = "All")]
  [switch]$All,

  [string]$OutDir = "dist",

  [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
  $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
  $RepoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

$ExcludeDirNames = @(
  ".git", ".cursor", ".vs", ".idea", "dist", "__pycache__", "node_modules"
)
$ExcludeFileNames = @(
  "Thumbs.db", ".DS_Store", "desktop.ini"
)
$ExcludeFileRegex = @(
  '^README.*\.md$',
  '^changelog_RU\.txt$',
  '^\.gitignore$',
  '^\.gitattributes$',
  '.*\.zip$',
  '.*\.psd$',
  '.*\.blend$',
  '.*\.tmp$'
)

function Test-ExcludedRelativePath {
  param([string]$RelativePath)

  $parts = $RelativePath -split '[\\/]'
  foreach ($part in $parts) {
    if ($ExcludeDirNames -contains $part) { return $true }
  }

  $fileName = $parts[-1]
  if ($ExcludeFileNames -contains $fileName) { return $true }

  foreach ($pattern in $ExcludeFileRegex) {
    if ($fileName -match $pattern) { return $true }
  }

  return $false
}

function Get-InfoJson {
  param([string]$ModPath)

  $infoPath = Join-Path $ModPath "info.json"
  if (-not (Test-Path -LiteralPath $infoPath)) {
    throw "Missing info.json in: $ModPath"
  }

  $info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $info.name -or -not $info.version) {
    throw "info.json must contain name and version: $infoPath"
  }
  if ($info.version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid version '$($info.version)' in $infoPath (expected X.Y.Z)"
  }
  return $info
}

function New-ModZip {
  param([string]$ModPath)

  $ModPath = (Resolve-Path -LiteralPath $ModPath).Path
  $info = Get-InfoJson -ModPath $ModPath
  $packageId = "{0}_{1}" -f $info.name, $info.version

  $outRoot = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir
  } else {
    Join-Path $RepoRoot $OutDir
  }
  New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

  $zipPath = Join-Path $outRoot ($packageId + ".zip")
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem

  $zip = [System.IO.Compression.ZipFile]::Open(
    $zipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
  )

  try {
    $files = Get-ChildItem -LiteralPath $ModPath -Recurse -File
    $count = 0
    foreach ($file in $files) {
      $rel = $file.FullName.Substring($ModPath.Length).TrimStart("\", "/")
      if (Test-ExcludedRelativePath -RelativePath $rel) { continue }

      $entryName = ($packageId + "/" + ($rel -replace "\\", "/"))
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip,
        $file.FullName,
        $entryName,
        [System.IO.Compression.CompressionLevel]::Optimal
      )
      $count++
    }

    if ($count -eq 0) {
      throw "No files packed from $ModPath (everything excluded?)"
    }
  }
  finally {
    $zip.Dispose()
  }

  Write-Host "Packed $count files -> $zipPath"
  Write-Host "  name=$($info.name) version=$($info.version) factorio_version=$($info.factorio_version)"
  return $zipPath
}

function Get-ModDirectories {
  Get-ChildItem -LiteralPath $RepoRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "info.json") } |
    Where-Object { $_.Name -notin @(".cursor", "scripts", "dist") }
}

Push-Location $RepoRoot
try {
  if ($All) {
    $mods = @(Get-ModDirectories)
    if ($mods.Count -eq 0) {
      throw "No mod folders with info.json found under $RepoRoot"
    }
    foreach ($mod in $mods) {
      New-ModZip -ModPath $mod.FullName | Out-Null
    }
  }
  else {
    if (-not $ModDir) {
      throw "Specify -ModDir <folder> or -All"
    }
    $path = if ([System.IO.Path]::IsPathRooted($ModDir)) {
      $ModDir
    } else {
      Join-Path $RepoRoot $ModDir
    }
    if (-not (Test-Path -LiteralPath $path)) {
      throw "Mod directory not found: $path"
    }
    New-ModZip -ModPath $path | Out-Null
  }
}
finally {
  Pop-Location
}
