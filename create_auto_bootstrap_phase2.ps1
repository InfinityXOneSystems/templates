<#
.SYNOPSIS
    Infinity-X Phase 2 Expansion — Orchestrator / Automation Kernel
.DESCRIPTION
    Builds the orchestrator service, GPT adapter layer, scheduler,
    and agent registry inside Phase 1 auto-bootstrap folder.
#>

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Base = "C:\AI\repos\auto-bootstrap"
if (-not (Test-Path $Base)) {
    Write-Information "❌ Phase 1 folder not found at $Base" -InformationAction Continue
    exit
}

Write-Information "🚀 Expanding Phase 2 structure in $Base ..." -InformationAction Continue

# Create folders
$Dirs = @("orchestrator","orchestrator\adapters","schemas","agents\registry")
foreach ($d in $Dirs) { New-Item -ItemType Directory -Force -Path (Join-Path $Base $d) | Out-Null }

# Main FastAPI entry
@"
from fastapi import FastAPI, Request
import asyncio
from orchestrator import core

app = FastAPI(title="Infinity-X Orchestrator", version="2.0")
app.include_router(core.router)

@app.on_event("startup")
async def startup(): print("✅ Orchestrator Phase 2 active")

@app.get("/health")
def health(): return {"status":"ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
"@ | Set-Content -Path "$Base/orchestrator/main.py" -Encoding UTF8

# Core router
@"
from fastapi import APIRouter
from orchestrator import scheduler
from orchestrator.adapters import vertex, groq, mcp

router = APIRouter()

@router.post("/execute")
async def execute(task: dict):
    model = task.get("model","vertex")
    handler = {"vertex": vertex, "groq": groq, "mcp": mcp}.get(model, vertex)
    return {"result": handler.run(task)}

@router.post("/schedule")
async def schedule_task(task: dict):
    job_id = scheduler.enqueue(task)
    return {"scheduled": job_id}
"@ | Set-Content -Path "$Base/orchestrator/core.py" -Encoding UTF8

# Scheduler
@"
import uuid, asyncio
_tasks = {}

def enqueue(task):
    job_id = str(uuid.uuid4())
    _tasks[job_id] = task
    asyncio.create_task(run(task))
    return job_id

async def run(task):
    await asyncio.sleep(0.1)
    print(f"🧠 Executed task: {task}")
"@ | Set-Content -Path "$Base/orchestrator/scheduler.py" -Encoding UTF8

# Adapters (Vertex/Groq/MCP)
$Adapters = @{
  "vertex.py" = "def run(task): return {'engine':'vertex','ok':True}"
  "groq.py"   = "def run(task): return {'engine':'groq','ok':True}"
  "mcp.py"    = "def run(task): return {'engine':'mcp','ok':True}"
}
foreach ($k in $Adapters.Keys) { $Adapters[$k] | Set-Content -Path "$Base/orchestrator/adapters/$k" -Encoding UTF8 }

# Agent registry
@"
[
  {"name":"infrastructure","entry":"agents/infrastructure/main.py"},
  {"name":"analytics","entry":"agents/analytics/main.py"},
  {"name":"crawler","entry":"agents/crawler/main.py"},
  {"name":"security","entry":"agents/security/main.py"},
  {"name":"governance","entry":"agents/governance/main.py"}
]
"@ | Set-Content -Path "$Base/agents/registry/agents.json" -Encoding UTF8

# Task schema
@"
{
  "\$schema":"http://json-schema.org/draft-07/schema#",
  "title":"AutomationTask",
  "type":"object",
  "properties":{
    "id":{"type":"string"},
    "agent":{"type":"string"},
    "model":{"type":"string"},
    "payload":{"type":"object"}
  },
  "required":["agent","model"]
}
"@ | Set-Content -Path "$Base/schemas/task_schema.json" -Encoding UTF8

# Python requirements
@"
fastapi
uvicorn
pydantic
"@ | Set-Content -Path "$Base/requirements.txt" -Encoding UTF8

Write-Information "`n✅ Phase 2 Orchestrator / Automation Kernel scaffold created." -InformationAction Continue
Write-Information "  Next: cd $Base and docker build -t infinityx/orchestrator ." -InformationAction Continue
