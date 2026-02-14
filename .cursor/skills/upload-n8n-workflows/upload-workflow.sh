#!/usr/bin/env bash
# Implements the upload-n8n-workflows skill: credential check then upload one workflow.
# Usage: ./upload-workflow.sh [workflow-name]
#   If workflow-name is omitted, tests connection by listing workflows (GET).
#   Workflow names: janssen-ai-production, janssen-whatsapp-workflow, janssen-crm-integration, etc.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Workspace root = parent of .cursor (skill lives in .cursor/skills/...)
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CREDENTIALS_FILE="$SCRIPT_DIR/n8n-credentials.env"
JANSSEN_AI="$WORKSPACE_ROOT/janssen-ai"

# Map user choice to path under janssen-ai/
get_workflow_path() {
  case "$1" in
    governance-validation-workflow)  echo "n8n/governance-validation-workflow.json" ;;
    janssen-ai-blueprint)            echo "n8n/janssen-ai-blueprint.json" ;;
    janssen-ai-full-v2)               echo "n8n/janssen-ai-full-v2.json" ;;
    janssen-ai-full)                  echo "n8n/janssen-ai-full.json" ;;
    janssen-ai-production)           echo "n8n/janssen-ai-production.json" ;;
    janssen-ai-with-openai)           echo "n8n/janssen-ai-with-openai.json" ;;
    janssen-analytics-dashboard)     echo "n8n/janssen-analytics-dashboard.json" ;;
    janssen-complete-system)         echo "n8n/janssen-complete-system.json" ;;
    janssen-crm-integration)         echo "n8n/janssen-crm-integration.json" ;;
    janssen-unified-workflow)        echo "n8n/janssen-unified-workflow.json" ;;
    janssen-voice-integration)       echo "n8n/janssen-voice-integration.json" ;;
    janssen-whatsapp-workflow)       echo "n8n/janssen-whatsapp-workflow.json" ;;
    avaya.voice.flow)                echo "backend/workflows/avaya.voice.flow.json" ;;
    crm.integration.flow)            echo "backend/workflows/crm.integration.flow.json" ;;
    n8n.main.workflow)               echo "backend/workflows/n8n.main.workflow.json" ;;
    *) echo "" ;;
  esac
}

# --- Mandatory: credential check ---
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
  echo "Missing credentials file: $CREDENTIALS_FILE"
  echo "Copy n8n-credentials.env.example to n8n-credentials.env and set N8N_BASE_URL and N8N_API_KEY."
  exit 1
fi

# shellcheck source=.
source "$CREDENTIALS_FILE"

if [[ -z "${N8N_BASE_URL:-}" ]] || [[ -z "${N8N_API_KEY:-}" ]]; then
  echo "Credentials file must define N8N_BASE_URL and N8N_API_KEY."
  exit 1
fi

# Strip trailing slash from base URL
N8N_BASE_URL="${N8N_BASE_URL%/}"

if [[ "$N8N_BASE_URL" == "https://your-n8n-instance.com" ]] || [[ "$N8N_API_KEY" == "your_n8n_api_key_here" ]]; then
  echo "Replace placeholder values in n8n-credentials.env with your real n8n URL and API key."
  exit 1
fi

if [[ ! -d "$JANSSEN_AI" ]]; then
  echo "Janssen-ai directory not found: $JANSSEN_AI"
  exit 1
fi

WORKFLOW_NAME="${1:-}"

# Detect API path: n8n uses /api/v1/workflows (newer) or /rest/workflows (older)
if [[ -z "$WORKFLOW_NAME" ]]; then
  for API_PATH in "/api/v1/workflows" "/rest/workflows"; do
    echo "Testing connection (GET $API_PATH)..."
    HTTP_CODE=$(curl -sS -o /tmp/n8n-list.json -w "%{http_code}" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      "$N8N_BASE_URL$API_PATH")
    if [[ "$HTTP_CODE" == "200" ]]; then
      echo "OK (200). Workflows: $(jq -r 'if type=="array" then length else "object" end' /tmp/n8n-list.json 2>/dev/null || cat /tmp/n8n-list.json | head -c 200)"
      exit 0
    fi
  done
  echo "Connection test failed: HTTP $HTTP_CODE (tried /api/v1/workflows and /rest/workflows)"
  cat /tmp/n8n-list.json 2>/dev/null | head -c 500
  exit 1
fi

REL_PATH="$(get_workflow_path "$WORKFLOW_NAME")"
if [[ -z "$REL_PATH" ]]; then
  echo "Unknown workflow: $WORKFLOW_NAME"
  echo "Examples: janssen-ai-production, janssen-whatsapp-workflow, janssen-crm-integration"
  exit 1
fi

ABSPATH="$JANSSEN_AI/$REL_PATH"
if [[ ! -f "$ABSPATH" ]]; then
  echo "Workflow file not found: $ABSPATH"
  exit 1
fi

# Use same path that worked for GET (default /api/v1/workflows)
N8N_WORKFLOWS_PATH="${N8N_WORKFLOWS_PATH:-/api/v1/workflows}"
echo "Uploading $WORKFLOW_NAME from $REL_PATH ..."
HTTP_CODE=$(curl -sS -o /tmp/n8n-upload.json -w "%{http_code}" -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$ABSPATH" \
  "$N8N_BASE_URL$N8N_WORKFLOWS_PATH")

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "Upload OK (HTTP $HTTP_CODE)."
  jq -r '.id // .name // .' /tmp/n8n-upload.json 2>/dev/null || cat /tmp/n8n-upload.json
  exit 0
else
  echo "Upload failed: HTTP $HTTP_CODE"
  cat /tmp/n8n-upload.json 2>/dev/null
  exit 1
fi
