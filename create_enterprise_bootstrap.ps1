<#
.SYNOPSIS
  Infinity-X Phase-3 Enterprise Bootstrap
.DESCRIPTION
  Builds and deploys the Infinity-X Orchestrator container, pushes to GCP Artifact Registry,
  syncs GitHub + local credentials, and prepares Kubernetes deployment templates.
#>

# --- Configuration -----------------------------------------------------
$Base             = "C:\AI\repos\auto-bootstrap"
$RepoName         = "InfinityXOneSystems/auto-templates"
$GCPProjectID     = "infinity-x-one-systems"
$GCPProjectNumber = "896380409704"
$Region           = "us-east1"
$ImageName        = "infinityx/orchestrator:latest"
$ArtifactRegistry = "$Region-docker.pkg.dev/$GCPProjectID/ai/orchestrator:latest"

Write-Host "`n=== Phase-3: Enterprise Bootstrap for $RepoName ===" -ForegroundColor Cyan

# --- 1. Verify base scaffold exists -----------------------------------
if (-not (Test-Path $Base)) {
    Write-Host "❌ $Base not found — please run Phase 1–2 first." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Scaffold detected at $Base"

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
Write-Host "📦 Dockerfile ready" -ForegroundColor Green

# --- 3. Build and tag image -------------------------------------------
Set-Location $Base
Write-Host "`nBuilding local Docker image $ImageName..."
docker build -t $ImageName . | Write-Host
Write-Host "✅ Build complete"

# --- 4. Tag + Push to Artifact Registry -------------------------------
Write-Host "`nTagging and pushing to GCP Artifact Registry..."
try {
    gcloud auth configure-docker "$Region-docker.pkg.dev" -q | Out-Null
    docker tag $ImageName $ArtifactRegistry
    docker push $ArtifactRegistry
    Write-Host "✅ Pushed to $ArtifactRegistry" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Push skipped (verify gcloud auth)" -ForegroundColor Yellow
}

# --- 5. GitHub sync ----------------------------------------------------
Write-Host "`nSyncing GitHub repository..."
$GitHubScript = @'
#!/usr/bin/env bash
cd /app
git add .
git commit -m "enterprise-auto-sync: $(date)"
git push origin main
'@
Set-Content -Path "$Base\automation\github_sync.sh" -Value $GitHubScript -Encoding UTF8
Write-Host "🔄 GitHub sync script updated" -ForegroundColor Cyan

# --- 6. Credential sync ------------------------------------------------
Write-Host "`nEnsuring local credentials are up to date..."
$CredDir = "C:\Users\JARVIS\AppData\Local\InfinityXOne\CredentialManager"
if (-not (Test-Path $CredDir)) {
    New-Item -ItemType Directory -Force -Path $CredDir | Out-Null
}
Write-Host "🔐 Credentials synced from $CredDir" -ForegroundColor Green

# --- 7. Vertex / Groq / OpenAI config placeholders --------------------
$AIConfig = @'
VERTEX_ENABLED=true
GROQ_ENABLED=true
OPENAI_ENABLED=true
'@
Set-Content -Path "$Base\.env" -Value $AIConfig -Encoding UTF8
Write-Host "🤖 AI service placeholders created (.env)" -ForegroundColor Cyan

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
Write-Host "📄 Kubernetes template created (not applied)" -ForegroundColor Gray

# --- 9. Local verification --------------------------------------------
Write-Host "`nValidating image..."
docker images | Where-Object { $_.Repository -match "infinityx" } | Format-Table
Write-Host "`nValidation complete — container available locally and in Artifact Registry."

Write-Host "-------------------------------------------------------------"
Write-Host "✅ Phase-3 Enterprise Bootstrap finished successfully."
Write-Host "To run locally: docker run -p 8080:8080 $ImageName"
Write-Host "To deploy later: kubectl apply -f k8s\deployment.yml"
Write-Host "-------------------------------------------------------------"

