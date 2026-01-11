# ============================================================
# INFINITY XOS — UNIVERSAL FAANG SYSTEM VALIDATOR
# AUTO-HEAL • SMOKE TEST • ALERTING • GRACEFUL FAIL
# ============================================================

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"
$RESULTS = @()
$ORCH_URL = "https://orchestrator-896380409704.us-east1.run.app"

function Log($system,$status,$detail) {
  $entry = @{
    system=$system
    status=$status
    detail=$detail
    time=(Get-Date).ToString("o")
  }
  $RESULTS += $entry
}

function Smoke-Test {
  try {
    Invoke-RestMethod "$ORCH_URL/health" -TimeoutSec 10 | Out-Null
    Log -system "SmokeTest" -status "PASS" -detail "Orchestrator reachable"
  } catch {
    Log -system "SmokeTest" -status "FAIL" -detail "Orchestrator unreachable"
  }
}

function Validate-Orchestrator {
  try {
    Invoke-RestMethod "$ORCH_URL/heartbeat" -Method POST -TimeoutSec 10 | Out-Null
    Log -system "Orchestrator" -status "PASS" -detail "Heartbeat executed"
  } catch {
    Log -system "Orchestrator" -status "FAIL" -detail "Heartbeat failed"
  }
}

function Validate-GitHub {
  try {
    gh auth status | Out-Null
    Log -system "GitHub" -status "PASS" -detail "gh authenticated"
  } catch {
    Log -system "GitHub" -status "FAIL" -detail "gh auth failure"
  }
}

function Validate-GCP {
  try {
    gcloud run services list --region us-east1 | Out-Null
    Log -system "GCP" -status "PASS" -detail "Cloud Run accessible"
  } catch {
    Log -system "GCP" -status "FAIL" -detail "GCP access failure"
  }
}

function Auto-Heal {
  param($failure)
  try {
    Invoke-RestMethod "$ORCH_URL/auto-heal" `
      -Method POST `
      -Body ($failure | ConvertTo-Json) `
      -ContentType "application/json"
  } catch {}
}

# ---- EXECUTION ----
Smoke-Test
Validate-Orchestrator
Validate-GitHub
Validate-GCP

$RESULTS | ConvertTo-Json -Depth 4 |
  Out-File "latest_validation.json" -Force

$FAILS = $RESULTS | Where-Object {$_.status -eq "FAIL"}
if ($FAILS.Count -gt 0) {
  Auto-Heal $FAILS
}
