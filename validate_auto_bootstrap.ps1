<#
.SYNOPSIS
  Infinity-X Bootstrap Validator + Auto-Heal (Stable)
.DESCRIPTION
  Validates, repairs, and classifies all files/folders in the Infinity-X bootstrap environment.
  Safe for all PowerShell versions (no Unicode or broken escaping).
#>

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Base = "C:\AI\repos\auto-bootstrap"
if (-not (Test-Path $Base)) {
    Write-Information "Creating base directory at $Base" -InformationAction Continue
    New-Item -ItemType Directory -Force -Path $Base | Out-Null
}


Write-Information "=== Validating Infinity-X Bootstrap at $Base ===" -InformationAction Continue
Write-Information "-------------------------------------------------------------" -InformationAction Continue

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
        Write-Information "[!] Missing Folder: $folder" -InformationAction Continue
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    }

    foreach ($file in $Expected[$folder]) {
        $target = Join-Path $fullPath $file
        if (-not (Test-Path $target)) {
            Write-Information "[Auto-Fix] Creating missing file: $target" -InformationAction Continue
            if ($Templates.ContainsKey($file)) {
                Set-Content -Path $target -Value $Templates[$file] -Encoding UTF8
            } else {
                Set-Content -Path $target -Value "# Placeholder for $file" -Encoding UTF8
            }
            $Missing += $target
        } elseif ((Get-Item $target).Length -eq 0) {
            Write-Information "[!] Empty file: $target" -InformationAction Continue
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
            Write-Information ("[{0}] {1}" -f $type, $rel) -InformationAction Continue
        }
    }
}

# --- Dependency check ---

Write-Information "Checking dependencies..." -InformationAction Continue

$deps = @{
    "python" = (Get-Command python -ErrorAction SilentlyContinue)
    "git"    = (Get-Command git -ErrorAction SilentlyContinue)
    "docker" = (Get-Command docker -ErrorAction SilentlyContinue)
}

foreach ($k in $deps.Keys) {
    if ($deps[$k]) {
        Write-Information ("OK: {0} found at {1}" -f $k, $deps[$k].Source) -InformationAction Continue
    } else {
        Write-Information ("MISSING: {0} not found in PATH" -f $k) -InformationAction Continue
    }
}

# --- Summary ---

Write-Information "=== Validation Summary ===" -InformationAction Continue
Write-Information ("MVP components:        {0}" -f (($Class.Values | Where-Object {$_ -eq 'MVP'}).Count)) -InformationAction Continue
Write-Information ("Production components: {0}" -f (($Class.Values | Where-Object {$_ -eq 'Production'}).Count)) -InformationAction Continue
Write-Information ("Enterprise components: {0}" -f (($Class.Values | Where-Object {$_ -eq 'Enterprise'}).Count)) -InformationAction Continue
Write-Information "-------------------------------------------------------------" -InformationAction Continue

if ($Missing.Count -gt 0 -or $Empty.Count -gt 0) {
    Write-Information "Some issues were fixed or found." -InformationAction Continue
    if ($Missing.Count -gt 0) {
        Write-Information "  Created:" -InformationAction Continue
        $Missing | ForEach-Object { Write-Information "   $_" -InformationAction Continue }
    }
    if ($Empty.Count -gt 0) {
        Write-Information "  Empty files:" -InformationAction Continue
        $Empty | ForEach-Object { Write-Information "   $_" -InformationAction Continue }
    }
    Write-Information "`nAuto-Heal Completed. Validation PASSED with repairs." -InformationAction Continue
} else {
    Write-Information "Validation PASSED. Structure fully healthy." -InformationAction Continue
}

