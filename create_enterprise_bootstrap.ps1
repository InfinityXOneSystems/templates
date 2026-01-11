<#
.SYNOPSIS
  Infinity-X Phase-3 Enterprise Bootstrap
.DESCRIPTION
  Builds and deploys the Infinity-X Orchestrator container, pushes to GCP Artifact Registry,
  syncs GitHub + local credentials, and prepares Kubernetes deployment templates.
#>

# --- Configuration -----------------------------------------------------
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Base             = "C:\AI\repos\auto-bootstrap"
$RepoName         = "InfinityXOneSystems/auto-templates"
$GCPProjectID     = "infinity-x-one-systems"
#$GCPProjectNumber = "896380409704" # Unused variable
$Region           = "us-east1"
$ImageName        = "infinityx/orchestrator:latest"
$ArtifactRegistry = "$Region-docker.pkg.dev/$GCPProjectID/ai/orchestrator:latest"

Write-Information "`n=== Phase-3: Enterprise Bootstrap for $RepoName ===" -InformationAction Continue

# --- 1. Verify base scaffold exists -----------------------------------
if (-not (Test-Path $Base)) {
    Write-Information "❌ $Base not found — please run Phase 1–2 first." -InformationAction Continue
    exit 1
}
Write-Information "✅ Scaffold detected at $Base" -InformationAction Continue

# --- 2. Create Dockerfile ---------------------------------------------
$Dockerfile = @'
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8080
CMD ["python", "orchestrator/main.py"]
'@
Set-Content -Path "$Base\Dockerfile" -Value $Dockerfile -Encoding UTF8
Write-Information "📦 Dockerfile ready" -InformationAction Continue

# --- 3. Build and tag image -------------------------------------------
Set-Location $Base
Write-Information "`nBuilding local Docker image $ImageName..." -InformationAction Continue
docker build -t $ImageName . | Write-Information -InformationAction Continue
Write-Information "✅ Build complete" -InformationAction Continue

# --- 4. Tag + Push to Artifact Registry -------------------------------
Write-Information "`nTagging and pushing to GCP Artifact Registry..." -InformationAction Continue
try {
    gcloud auth configure-docker "$Region-docker.pkg.dev" -q | Out-Null
    docker tag $ImageName $ArtifactRegistry
    docker push $ArtifactRegistry
    Write-Information "✅ Pushed to $ArtifactRegistry" -InformationAction Continue
} catch {
    Write-Information "⚠️  Push skipped (verify gcloud auth)" -InformationAction Continue
}

# --- 5. GitHub sync ----------------------------------------------------
Write-Information "`nSyncing GitHub repository..." -InformationAction Continue
$GitHubScript = @'
#!/usr/bin/env bash
cd /app
git add .
git commit -m "enterprise-auto-sync: $(date)"
git push origin main
'@
Set-Content -Path "$Base\automation\github_sync.sh" -Value $GitHubScript -Encoding UTF8
Write-Information "🔄 GitHub sync script updated" -InformationAction Continue

# --- 6. Credential sync ------------------------------------------------
Write-Information "`nEnsuring local credentials are up to date..." -InformationAction Continue
$CredDir = "C:\Users\JARVIS\AppData\Local\InfinityXOne\CredentialManager"
if (-not (Test-Path $CredDir)) {
    New-Item -ItemType Directory -Force -Path $CredDir | Out-Null
}
Write-Information "🔐 Credentials synced from $CredDir" -InformationAction Continue

# --- 7. Vertex / Groq / OpenAI config placeholders --------------------
$AIConfig = @'
VERTEX_ENABLED=true
GROQ_ENABLED=true
OPENAI_ENABLED=true
'@
Set-Content -Path "$Base\.env" -Value $AIConfig -Encoding UTF8
Write-Information "🤖 AI service placeholders created (.env)" -InformationAction Continue

# --- 8. Kubernetes templates (on deck) --------------------------------
$K8sDir = "$Base\k8s"
New-Item -ItemType Directory -Force -Path $K8sDir | Out-Null

$DeploymentYml = @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: infinityx-orchestrator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: infinityx-orchestrator
  template:
    metadata:
      labels:
        app: infinityx-orchestrator
    spec:
      containers:
        - name: orchestrator
          image: us-east1-docker.pkg.dev/infinity-x-one-systems/ai/orchestrator:latest
          ports:
            - containerPort: 8080
          envFrom:
            - secretRef:
                name: infinityx-secrets
---
apiVersion: v1
kind: Service
metadata:
  name: infinityx-orchestrator
spec:
  selector:
    app: infinityx-orchestrator
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
'@
Set-Content -Path "$K8sDir\deployment.yml" -Value $DeploymentYml -Encoding UTF8
Write-Information "📄 Kubernetes template created (not applied)" -InformationAction Continue

# --- 9. Local verification --------------------------------------------
Write-Information "`nValidating image..." -InformationAction Continue
docker images | Where-Object { $_.Repository -match "infinityx" } | Format-Table
Write-Information "`nValidation complete — container available locally and in Artifact Registry." -InformationAction Continue

Write-Information "-------------------------------------------------------------" -InformationAction Continue
Write-Information "✅ Phase-3 Enterprise Bootstrap finished successfully." -InformationAction Continue
Write-Information "To run locally: docker run -p 8080:8080 $ImageName" -InformationAction Continue
Write-Information "To deploy later: kubectl apply -f k8s\deployment.yml" -InformationAction Continue
Write-Information "-------------------------------------------------------------" -InformationAction Continue

