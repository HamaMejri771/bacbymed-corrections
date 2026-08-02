# ranger_corrections.ps1
# ------------------------------------------------------------------
# ينظّف هيكل مجلّد bacbymed-corrections.
#
#   .\ranger_corrections.ps1        -> محاكاة، ما يبدّل والو
#   .\ranger_corrections.ps1 -Go    -> يبدّل بالفعل
#
# الهيكل المطلوب :  <section>\<matiere>\<annee>_<session>.pdf
# ------------------------------------------------------------------

param([switch]$Go)

$ErrorActionPreference = "Stop"
$racine = "C:\Users\dell\bacbymed-corrections"
Set-Location $racine

$mode = if ($Go) { "MODE REEL" } else { "MODE SIMULATION (rien ne bouge)" }
Write-Host ""
Write-Host ("=" * 66)
Write-Host "  $mode"
Write-Host ("=" * 66)
Write-Host ""

$actions = @()

function Plan($type, $de, $vers) {
    $script:actions += [pscustomobject]@{ Type = $type; De = $de; Vers = $vers }
}

# ── 1. fichier avec " (2)" dans le nom ──────────────────────────────
Get-ChildItem -Recurse -File -Filter "*.pdf" |
    Where-Object { $_.Name -match "\s*\(\d+\)" } |
    ForEach-Object {
        $propre = $_.Name -replace "\s*\(\d+\)", ""
        $propre = $propre -replace "\s+\.pdf$", ".pdf"
        Plan "RENOMMER" $_.FullName (Join-Path $_.DirectoryName $propre)
    }

# ── 2. double extension .pdf.pdf ────────────────────────────────────
Get-ChildItem -Recurse -File -Filter "*.pdf.pdf" | ForEach-Object {
    $propre = $_.Name -replace "\.pdf\.pdf$", ".pdf"
    $cible = Join-Path $_.DirectoryName $propre
    if (Test-Path $cible) {
        Plan "QUARANTAINE" $_.FullName "_a_trier\$($_.Name)"   # doublon
    } else {
        Plan "RENOMMER" $_.FullName $cible
    }
}

# ── 3. dossiers mal nommes ──────────────────────────────────────────
$correctionsDossiers = @{
    "economie_gestion\français" = "economie_gestion\francais"
    "lettres\philosophie"       = "lettre\philo"
    "lettres"                   = "lettre"
}
foreach ($k in $correctionsDossiers.Keys) {
    if (Test-Path $k) { Plan "DOSSIER" $k $correctionsDossiers[$k] }
}

# ── 4. tout ce qui traine a la racine -> _a_trier ───────────────────
Get-ChildItem -File | Where-Object { $_.Extension -in ".pdf", ".html" } |
    ForEach-Object { Plan "QUARANTAINE" $_.FullName "_a_trier\$($_.Name)" }

# ── affichage ───────────────────────────────────────────────────────
if (-not $actions) {
    Write-Host "  Rien a faire, tout est deja propre."
    exit 0
}

$actions | Group-Object Type | ForEach-Object {
    Write-Host ""
    Write-Host "  --- $($_.Name) ($($_.Count)) ---" -ForegroundColor Cyan
    $_.Group | ForEach-Object {
        $de = $_.De.Replace("$racine\", "")
        $vers = $_.Vers.Replace("$racine\", "")
        Write-Host "    $de"
        Write-Host "       -> $vers" -ForegroundColor Green
    }
}

if (-not $Go) {
    Write-Host ""
    Write-Host ("-" * 66)
    Write-Host "  Rien n'a ete fait."
    Write-Host "  Si la liste te convient :  .\ranger_corrections.ps1 -Go"
    Write-Host ("-" * 66)
    exit 0
}

# ── execution ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Execution..." -ForegroundColor Yellow

New-Item -ItemType Directory -Force -Path "_a_trier" | Out-Null

foreach ($a in $actions) {
    try {
        switch ($a.Type) {
            "RENOMMER" {
                Move-Item $a.De $a.Vers -Force
            }
            "QUARANTAINE" {
                $cible = Join-Path $racine $a.Vers
                New-Item -ItemType Directory -Force -Path (Split-Path $cible) | Out-Null
                Move-Item $a.De $cible -Force
            }
            "DOSSIER" {
                $src = Join-Path $racine $a.De
                $dst = Join-Path $racine $a.Vers
                New-Item -ItemType Directory -Force -Path $dst | Out-Null
                Get-ChildItem $src -Force | Move-Item -Destination $dst -Force
                if (-not (Get-ChildItem $src -Force)) { Remove-Item $src -Force }
            }
        }
        Write-Host "    OK  $($a.Type)  $($a.De.Replace("$racine\",''))"
    } catch {
        Write-Host "    ECHEC  $($a.De) : $_" -ForegroundColor Red
    }
}

# nettoyage des dossiers vides
Get-ChildItem -Recurse -Directory |
    Sort-Object { $_.FullName.Length } -Descending |
    Where-Object { -not (Get-ChildItem $_.FullName -Force) } |
    Remove-Item -Force

Write-Host ""
Write-Host ("=" * 66)
Write-Host "  Fini. Structure actuelle :"
Write-Host ("=" * 66)
Get-ChildItem -Recurse -File | ForEach-Object {
    Write-Host "  $($_.FullName.Replace("$racine\",''))"
}
Write-Host ""
Write-Host "  N'oublie pas :  git add -A ; git commit -m 'rangement' ; git push"
Write-Host ""
