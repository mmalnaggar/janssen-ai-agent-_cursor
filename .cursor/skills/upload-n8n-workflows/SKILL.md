name: upload-n8n-workflows
description: Automates uploading Janssen n8n init and workflow JSON files from this repo to an n8n instance using curl and an API key stored in environment variables or provided interactively by the user. Use when the user wants to deploy or update n8n workflows from the project into a running n8n server without hard-coded workflow paths.
---

# Upload n8n Workflows

## Purpose

This skill helps the agent **deploy or update n8n workflows** from this project into a running n8n instance using **curl** and an **API key from environment variables or interactively provided by the user**.

- **Source workflows**:
  - `janssen-ai/n8n/*.json` (main Janssen AI workflows)
  - `janssen-ai/backend/workflows/*.json` (backend flows like webhooks/integrations)
- **Target**: Any reachable n8n instance (cloud or self-hosted).
- **Auth**: n8n API key stored in environment variables.

The agent should use this skill whenever the user mentions **deploying/importing/updating n8n workflows** or **syncing project workflows to n8n via API**.

---

## Assumptions & Conventions

- The project root is the workspace root: `janssen-ai/` is at the top level.
- n8n instance exposes the REST API (standard n8n).
- Environment variables:
  - `N8N_BASE_URL` – base URL of the n8n instance, **without trailing slash**, for example:
    - `https://n8n.example.com`
    - `http://localhost:5678`
  - `N8N_API_KEY` – n8n API key with permissions to manage workflows.
- Workflows are **valid n8n export JSONs** (already in correct format).

If any of these assumptions are wrong or missing, the agent should:
- Explicitly state the assumption.
- Propose what the user needs to configure (e.g., export N8N_BASE_URL).

---

## Mandatory: Credential Check First

**Before doing anything else**, determine whether credentials are available.

### Where to check

- **Credentials file**: `.cursor/skills/upload-n8n-workflows/n8n-credentials.env` (relative to workspace root).
- **Required variables**: the file must define `N8N_BASE_URL` and `N8N_API_KEY` (check variable names only; **never** read or display the API key value).
- **Example file**: `n8n-credentials.env.example` in the same folder shows the required variable names; copy to `n8n-credentials.env` and fill in. The real credentials file is gitignored.

### If credentials EXIST

- **Do not** show the full procedure, list all workflow files, or suggest batch upload commands.
- **Only**:
  1. Ask the user: **"Which workflow do you want to upload?"**
  2. Offer the available options (see workflow list below) so they can choose by name.
  3. Run the upload directly: source the credentials file, then `curl -X POST` with the chosen workflow file. Use the workspace path to the JSON (e.g. `janssen-ai/n8n/<name>.json` or `janssen-ai/backend/workflows/<name>.json`).

**Available workflows** (use these names when asking; paths are relative to `janssen-ai/`):

| User choice | File path (under `janssen-ai/`) |
|-------------|----------------------------------|
| governance-validation-workflow | n8n/governance-validation-workflow.json |
| janssen-ai-blueprint | n8n/janssen-ai-blueprint.json |
| janssen-ai-full-v2 | n8n/janssen-ai-full-v2.json |
| janssen-ai-full | n8n/janssen-ai-full.json |
| janssen-ai-production | n8n/janssen-ai-production.json |
| janssen-ai-with-openai | n8n/janssen-ai-with-openai.json |
| janssen-analytics-dashboard | n8n/janssen-analytics-dashboard.json |
| janssen-complete-system | n8n/janssen-complete-system.json |
| janssen-crm-integration | n8n/janssen-crm-integration.json |
| janssen-unified-workflow | n8n/janssen-unified-workflow.json |
| janssen-voice-integration | n8n/janssen-voice-integration.json |
| janssen-whatsapp-workflow | n8n/janssen-whatsapp-workflow.json |
| avaya.voice.flow | backend/workflows/avaya.voice.flow.json |
| crm.integration.flow | backend/workflows/crm.integration.flow.json |
| n8n.main.workflow | backend/workflows/n8n.main.workflow.json |

Example upload command once the user picks a workflow (e.g. `janssen-whatsapp-workflow`):

```bash
cd "WORKSPACE_ROOT/janssen-ai"
source "../.cursor/skills/upload-n8n-workflows/n8n-credentials.env"
curl -sS -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @n8n/janssen-whatsapp-workflow.json \
  "$N8N_BASE_URL/rest/workflows"
```

(Replace the path with the chosen workflow file. Use the table above to map the user's choice to the path under `janssen-ai/`. `WORKSPACE_ROOT` is the workspace root—the directory that contains both `janssen-ai/` and `.cursor/`.)

### If credentials do NOT exist

- **Do** go through the credential flow:
  1. Ask the user for:
     - **N8N_BASE_URL** (n8n instance URL, no trailing slash).
     - **N8N_API_KEY** (from n8n: Settings → Personal Access Tokens).
  2. Suggest they copy `n8n-credentials.env.example` to `n8n-credentials.env` in the same folder and fill in:
     - `N8N_BASE_URL="https://YOUR-N8N-URL"` (no trailing slash)
     - `N8N_API_KEY="YOUR_API_KEY"` (from n8n: Settings → Personal Access Tokens)
  3. Remind them that `n8n-credentials.env` is gitignored and must never be committed.
  4. Tell them to re-run the skill once the file is in place; then the agent will only ask for the workflow name and upload.
- Do **not** paste or log the API key; only refer to the env file and variable names.

---

## n8n API Basics (for this skill)

Use n8n's REST endpoints with the `X-N8N-API-KEY` header:

```bash
curl -sS \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$N8N_BASE_URL/rest/workflows"
```

Key patterns:

- **List workflows** (for existence checks):

```bash
curl -sS \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$N8N_BASE_URL/rest/workflows"
```

- **Create/import a workflow** (generic pattern; exact shape may vary by n8n version – keep user informed):

```bash
curl -sS -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"path/to/workflow.json" \
  "$N8N_BASE_URL/rest/workflows"
```

If this endpoint or payload shape fails, the agent should:
- Show the error response.
- Suggest checking the current n8n API docs for the user's version.

---

## Standard Workflow Upload Procedure

When the user asks to upload/init Janssen workflows to n8n:

1. **Check credentials** (see "Mandatory: Credential Check First" above).  
   - If the credentials file exists and has both `N8N_BASE_URL` and `N8N_API_KEY`: ask only for the **workflow name**, then upload that workflow directly.  
   - If not: run the credential flow (ask for URL and API key, suggest creating the env file), then stop; tell the user to run the skill again after adding credentials.

2. **When credentials exist**: ask "Which workflow do you want to upload?" and use the workflow list in the Mandatory section. Map the user's choice to the correct path (e.g. `n8n/janssen-whatsapp-workflow.json`) and run the upload command with the credentials file sourced.

3. **Optional – list or batch**: only if the user explicitly asks to "list existing workflows" or "upload all workflows", use the list endpoint or the batch loop below. Do not offer these by default when credentials exist.

### Batch upload (only when user explicitly requests it)

Run from workspace root so that `janssen-ai` and `.cursor` are in scope:

```bash
cd janssen-ai
source "../.cursor/skills/upload-n8n-workflows/n8n-credentials.env"
for file in n8n/*.json backend/workflows/*.json; do
  [ -f "$file" ] || continue
  echo "Uploading $file ..."
  curl -sS -X POST \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$file" \
    "$N8N_BASE_URL/rest/workflows"
  echo ""
done
```

### Activating Workflows

If the n8n version supports activation via API, suggest:

```bash
curl -sS -X PATCH \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"active": true}' \
  "$N8N_BASE_URL/rest/workflows/WORKFLOW_ID"
```

Where `WORKFLOW_ID` is taken from the list endpoint.

If this fails, instruct the user to:
- Activate workflows via the n8n UI as a fallback.

---

## Error Handling & Troubleshooting

When curl requests fail, the agent should:

1. **Show the HTTP status and body** to the user.  
2. Interpret common issues:
   - `401` / `403`: likely API key issue or missing permissions.
   - `404`: wrong base URL, path, or n8n version mismatch.
   - `4xx` with JSON validation error: workflow JSON might be incompatible with this n8n version.
3. Suggest corrective actions:
   - Re-check `N8N_BASE_URL` and `N8N_API_KEY`.
   - Confirm the user's n8n version and consult that version's API docs.
   - Re-export or simplify the workflow in n8n UI if necessary.

---

## How the Agent Should Respond

When the user asks to **upload/init/sync workflows**:

1. **Check credentials first**: look for `.cursor/skills/upload-n8n-workflows/n8n-credentials.env` and confirm it defines `N8N_BASE_URL` and `N8N_API_KEY` (variable names only; never read or display the key).
2. **If credentials exist**: ask only **"Which workflow do you want to upload?"** and offer the workflow list; then run the upload (source env + curl) for the chosen file. Do not show the full procedure, list endpoint, or batch commands unless the user explicitly asks.
3. **If credentials do not exist**: ask for `N8N_BASE_URL` and `N8N_API_KEY`, suggest creating the env file, and stop; do not show upload commands until credentials are in place.
4. **Never** print or log API keys; always use the env file and `$N8N_API_KEY` in commands.
5. **Security**: `n8n-credentials.env` is listed in `.cursor/skills/upload-n8n-workflows/.gitignore`; remind users not to commit it.

---

## Examples

### Example 1 – Credentials exist: upload one workflow

User: "Upload workflows to n8n."
Agent:

1. Checks for `.cursor/skills/upload-n8n-workflows/n8n-credentials.env` and finds `N8N_BASE_URL` and `N8N_API_KEY`.
2. Asks: **"Which workflow do you want to upload? For example: janssen-whatsapp-workflow, janssen-ai-full-v2, janssen-unified-workflow, crm.integration.flow, etc."**
3. User: "janssen-whatsapp-workflow."
4. Agent runs (or proposes) the upload using the credentials file and `n8n/janssen-whatsapp-workflow.json`.

### Example 2 – Credentials missing

User: "Upload workflows to n8n."
Agent:

1. Checks for the credentials file; it is missing or does not define both variables.
2. Asks for **N8N_BASE_URL** and **N8N_API_KEY**, and suggests creating `.cursor/skills/upload-n8n-workflows/n8n-credentials.env` with those two lines.
3. Tells the user to add the file and run the skill again; then the agent will only ask for the workflow name and upload.

### Example 3 – User explicitly asks for all workflows

User: "Upload all Janssen workflows to n8n."
Agent: If credentials exist, asks to confirm "all" (or runs the batch loop). If credentials are missing, runs the credential flow first.

---

## Implemented test script

A script in this folder implements the skill and can be run locally to test:

- **Path**: `.cursor/skills/upload-n8n-workflows/upload-workflow.sh`
- **Usage**:
  - `bash upload-workflow.sh` — test connection (GET /rest/workflows). Requires valid `n8n-credentials.env`.
  - `bash upload-workflow.sh <workflow-name>` — upload one workflow (e.g. `janssen-ai-production`, `janssen-whatsapp-workflow`).
- **Behavior**:
  1. Checks that `n8n-credentials.env` exists and defines `N8N_BASE_URL` and `N8N_API_KEY`.
  2. Rejects placeholder values (`your-n8n-instance.com` / `your_n8n_api_key_here`).
  3. With no argument: calls n8n API to list workflows (connection test).
  4. With workflow name: maps name to file under `janssen-ai/` and POSTs to `$N8N_BASE_URL/rest/workflows`.

Run from workspace root or from the skill folder. The script resolves the workspace root and `janssen-ai` path automatically.
