# ============================================================
# INFINITY XOS — UNIVERSAL FAANG SYSTEM VALIDATOR
# AUTO-HEAL • SMOKE TEST • ALERTING • GRACEFUL FAIL
# ============================================================

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
    Log "SmokeTest" "PASS" "Orchestrator reachable"
  } catch {
    Log "SmokeTest" "FAIL" "Orchestrator unreachable"
  }
}

function Validate-Orchestrator {
  try {
    Invoke-RestMethod "$ORCH_URL/heartbeat" -Method POST -TimeoutSec 10 | Out-Null
    Log "Orchestrator" "PASS" "Heartbeat executed"
  } catch {
    Log "Orchestrator" "FAIL" "Heartbeat failed"
  }
}

function Validate-GitHub {
  try {
    gh auth status | Out-Null
    Log "GitHub" "PASS" "gh authenticated"
  } catch {
    Log "GitHub" "FAIL" "gh auth failure"
  }
}

function Validate-GCP {
  try {
    gcloud run services list --region us-east1 | Out-Null
    Log "GCP" "PASS" "Cloud Run accessible"
  } catch {
    Log "GCP" "FAIL" "GCP access failure"
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
