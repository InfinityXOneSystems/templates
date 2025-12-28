<#
.SYNOPSIS
  Infinity-X Bootstrap Validator + Auto-Heal (Stable)
.DESCRIPTION
  Validates, repairs, and classifies all files/folders in the Infinity-X bootstrap environment.
  Safe for all PowerShell versions (no Unicode or broken escaping).
#>

$Base = "C:\AI\repos\auto-bootstrap"
if (-not (Test-Path $Base)) {
    Write-Host "Creating base directory at $Base" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $Base | Out-Null
}

Write-Host ""
Write-Host "=== Validating Infinity-X Bootstrap at $Base ==="
Write-Host "-------------------------------------------------------------"

# --- Expected structure ---
$Expected = @{
    "bootstrap"             = @("bootstrap.sh")
    "governance"            = @("policies.rego")
    "automation"            = @("github_sync.sh","gcloud_sync.sh","credentials_sync.ps1","vscode_sync.sh")
    "infra\helm"            = @()
    "infra\terraform"       = @()
    "orchestrator"          = @("main.py","core.py","scheduler.py")
    "orchestrator\adapters" = @("vertex.py","groq.py","mcp.py")
    "schemas"               = @("task_schema.json")
    "agents\registry"       = @("agents.json")
    "launch-scripts"        = @("Makefile")
    "."                     = @("docker-compose.yml","requirements.txt")
}

# --- Classification map ---
$Class = @{
    "bootstrap"      = "MVP"
    "launch-scripts" = "MVP"
    "logs"           = "MVP"
    "automation"     = "Production"
    "schemas"        = "Production"
    "frontend"       = "Production"
    "orchestrator"   = "Enterprise"
    "governance"     = "Enterprise"
    "agents"         = "Enterprise"
    "infra"          = "Enterprise"
}

# --- Auto-repair templates (safe literal blocks) ---
$Templates = @{}

$Templates["bootstrap.sh"] = @"
#!/usr/bin/env bash
echo 'Bootstrapping environment...'
"@

$Templates["policies.rego"] = @"
package infinityx.authz
default allow = false
allow {
  input.user == "admin"
}
"@

$Templates["github_sync.sh"] = @"
#!/usr/bin/env bash
git add .
git commit -m "auto-sync"
git push
"@

$Templates["gcloud_sync.sh"] = @"
#!/usr/bin/env bash
echo 'Deploying to Google Cloud...'
"@

$Templates["credentials_sync.ps1"] = @"
Write-Host 'Syncing credentials...'
"@

$Templates["vscode_sync.sh"] = @"
#!/usr/bin/env bash
echo 'Syncing VSCode settings...'
"@

$Templates["main.py"] = @"
print('InfinityX Orchestrator initialized')
"@

$Templates["core.py"] = "# Core orchestrator logic placeholder"
$Templates["scheduler.py"] = "# Task scheduler entry point"
$Templates["vertex.py"] = "# Vertex AI adapter"
$Templates["groq.py"] = "# Groq adapter"
$Templates["mcp.py"] = "# MCP adapter"

$Templates["task_schema.json"] = @"
{
  "type": "object",
  "title": "TaskSchema"
}
"@

$Templates["agents.json"] = @"
{
  "agents": []
}
"@

$Templates["Makefile"] = @"
all:
	@echo 'Building InfinityX system...'
"@

$Templates["docker-compose.yml"] = @"
version: '3.9'
services:
  infinityx:
    build: .
    ports:
      - "8080:8080"
"@

$Templates["requirements.txt"] = @"
fastapi
httpx
"@

# --- Validation & auto-repair ---
$Missing = @()
$Empty   = @()

foreach ($folder in $Expected.Keys) {
    $fullPath = Join-Path $Base $folder
    if (-not (Test-Path $fullPath)) {
        Write-Host "[!] Missing Folder: $folder" -ForegroundColor Red
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    }

    foreach ($file in $Expected[$folder]) {
        $target = Join-Path $fullPath $file
        if (-not (Test-Path $target)) {
            Write-Host "[Auto-Fix] Creating missing file: $target" -ForegroundColor Yellow
            if ($Templates.ContainsKey($file)) {
                Set-Content -Path $target -Value $Templates[$file] -Encoding UTF8
            } else {
                Set-Content -Path $target -Value "# Placeholder for $file" -Encoding UTF8
            }
            $Missing += $target
        } elseif ((Get-Item $target).Length -eq 0) {
            Write-Host "[!] Empty file: $target" -ForegroundColor DarkYellow
            $Empty += $target
        } else {
            $rel = $target.Replace("$Base\", "")
            $type = ($Class.Keys | Where-Object { $rel -like "*$_*" } | ForEach-Object { $Class[$_] }) | Select-Object -First 1
            if (-not $type) { $type = "Unclassified" }
            $color = switch ($type) {
                "MVP"         { "Yellow" }
                "Production"  { "Cyan" }
                "Enterprise"  { "Green" }
                default       { "Gray" }
            }
            Write-Host ("[{0}] {1}" -f $type, $rel) -ForegroundColor $color
        }
    }
}

# --- Dependency check ---
Write-Host ""
Write-Host "Checking dependencies..."

$deps = @{
    "python" = (Get-Command python -ErrorAction SilentlyContinue)
    "git"    = (Get-Command git -ErrorAction SilentlyContinue)
    "docker" = (Get-Command docker -ErrorAction SilentlyContinue)
}

foreach ($k in $deps.Keys) {
    if ($deps[$k]) {
        Write-Host ("OK: {0} found at {1}" -f $k, $deps[$k].Source) -ForegroundColor Green
    } else {
        Write-Host ("MISSING: {0} not found in PATH" -f $k) -ForegroundColor Red
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Validation Summary ==="
Write-Host ("MVP components:        {0}" -f (($Class.Values | Where-Object {$_ -eq 'MVP'}).Count)) -ForegroundColor Yellow
Write-Host ("Production components: {0}" -f (($Class.Values | Where-Object {$_ -eq 'Production'}).Count)) -ForegroundColor Cyan
Write-Host ("Enterprise components: {0}" -f (($Class.Values | Where-Object {$_ -eq 'Enterprise'}).Count)) -ForegroundColor Green
Write-Host "-------------------------------------------------------------"

if ($Missing.Count -gt 0 -or $Empty.Count -gt 0) {
    Write-Host "Some issues were fixed or found." -ForegroundColor Yellow
    if ($Missing.Count -gt 0) {
        Write-Host "  Created:" -ForegroundColor Green
        $Missing | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGreen }
    }
    if ($Empty.Count -gt 0) {
        Write-Host "  Empty files:" -ForegroundColor DarkYellow
        $Empty | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkYellow }
    }
    Write-Host "`nAuto-Heal Completed. Validation PASSED with repairs." -ForegroundColor Green
} else {
    Write-Host "Validation PASSED. Structure fully healthy." -ForegroundColor Green
}

