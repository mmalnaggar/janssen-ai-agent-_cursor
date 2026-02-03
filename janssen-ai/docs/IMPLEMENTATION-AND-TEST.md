# Janssen AI – Full Implementation & Test (n8n on Render)

You run **n8n on Render** and will create the **API keys**. This guide gets the whole system running and tests it with you step by step.

---

## Start here (minimal path)

1. **You:** Confirm n8n is running on Render and note the base URL (e.g. `https://n8n-xxx.onrender.com`).
2. **You:** In n8n → Import **`n8n/janssen-ai-production.json`** → Save → turn **Active** ON.
3. **Test:** Either:
   - **Browser:** Open `widget/test.html` (after starting a local server in `widget/`), set the webhook URL to `https://YOUR-N8N-URL/webhook/janssen-ai-incoming`, click "Send to webhook".
   - **Terminal:** `./scripts/test-webhook.sh https://YOUR-N8N-URL.onrender.com`
4. **Widget:** In `widget/demo.html` set `window.JANSSEN_WEBHOOK_URL` to the same webhook URL, then open `http://localhost:8080/demo.html` and use the chat.

No API keys are required for this path.

---

## What You Need Ready

| Item | Who | Notes |
|------|-----|--------|
| n8n live on Render | You | e.g. `https://your-n8n.onrender.com` |
| OpenAI API key (optional) | You | Only if you want GPT replies for unknown questions |
| Twilio SID + Auth Token (optional) | You | Only if you want WhatsApp bot |
| Google Sheets (optional) | You | Only if you want Analytics dashboard or CRM log |

**To start:** only n8n on Render is required. No API keys needed for basic chat.

---

## Step 1: Your n8n Base URL

1. Open your n8n instance on Render (e.g. `https://your-n8n.onrender.com`).
2. Note the **exact base URL** (no trailing slash).  
   Example: `https://n8n-2-7fw9.onrender.com`

**Chat webhook will be:**  
`<YOUR_BASE_URL>/webhook/janssen-ai-incoming`

---

## Step 2: Import the Main Chat Workflow (No Keys Required)

We’ll use the **3-node production workflow** first (no OpenAI, no Twilio).

1. In n8n: **Workflows** → **Import from File** (or Add workflow → Import).
2. Choose: **`janssen-ai/n8n/janssen-ai-production.json`**
3. Open the new workflow.
4. **Save** (Ctrl/Cmd+S).
5. Turn **Active** ON (top right).

**Test the webhook:**

- In the workflow, open the **Webhook_In** node and copy the **Production URL** (or use your base URL + path).
- It should look like:  
  `https://your-n8n.onrender.com/webhook/janssen-ai-incoming`

**Quick curl test (replace with your URL):**

```bash
curl -X POST "https://YOUR-N8N-URL.onrender.com/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"بكام المرتبة","channel":"chat","language":"ar"}'
```

You should get a JSON response with `response_type`, `content.text`, and Arabic text about prices.

---

## Step 3: Point the Widget to Your Webhook

1. Open **`janssen-ai/widget/demo.html`** in an editor.
2. Find the line:
   ```html
   window.JANSSEN_WEBHOOK_URL = 'https://n8n-2-7fw9.onrender.com/webhook/janssen-ai-incoming';
   ```
3. Replace the URL with **your** webhook URL from Step 2.
4. Save the file.

Same for **`widget/embed.html`** if you use it on another site: set `window.JANSSEN_WEBHOOK_URL` to your webhook URL.

---

## Step 4: Run the Widget Locally and Test

1. In a terminal:
   ```bash
   cd janssen-ai/widget
   python3 -m http.server 8080
   ```
2. In the browser open: **http://localhost:8080/demo.html**
3. Click the chat button and send:
   - **بكام المرتبة** (Arabic price)
   - **What are your prices?** (English)
   - **توصيل فين** (delivery)
   - **ضمان** (warranty)
   - **عايز اتكلم مع حد** (request human – should lock input after reply)

If you see replies and the last one locks the chat, the **core system is implemented and working**.

---

## Step 5 (Optional): OpenAI for Smarter Replies

**You create:** OpenAI API key from https://platform.openai.com/api-keys

1. In n8n: **Settings** (or Credentials) → **Credentials** → **Add credential** → **OpenAI API**.
2. Paste your API key, name it (e.g. “Janssen OpenAI”), Save.
3. **Import** workflow: **`janssen-ai/n8n/janssen-ai-with-openai.json`**.
4. Open the **5_OpenAI_Chat** node → select your OpenAI credential.
5. **Deactivate** the old production workflow (so only one responds to the same webhook).
6. **Activate** the new “Janssen_AI_With_OpenAI” workflow.
7. Test again from the widget (e.g. “What mattress for back pain?”).

---

## Step 6 (Optional): WhatsApp Bot (Twilio)

**You create:** Twilio Account SID + Auth Token (and WhatsApp sandbox number).

1. In n8n: **Add credential** → **HTTP Basic Auth**  
   - Username: Twilio Account SID  
   - Password: Twilio Auth Token  
   Name it e.g. “Twilio Auth”.
2. Import **`janssen-ai/n8n/janssen-whatsapp-workflow.json`**.
3. In the **5_Send_WhatsApp** node: set credential to “Twilio Auth”.
4. In n8n **Variables** (or env): set  
   `TWILIO_WHATSAPP_NUMBER` = your Twilio WhatsApp number (e.g. +14155238886).
5. In Twilio Console: set “When a message comes in” to:  
   `https://YOUR-N8N-URL.onrender.com/webhook/janssen-whatsapp`  
   Method: POST.
6. Activate the WhatsApp workflow and send a WhatsApp message to your sandbox to test.

---

## Step 7 (Optional): Analytics Dashboard

- **Option A – No backend:** Use **`widget/dashboard.html`** as-is; it can show **demo data** if the stats API is not set.
- **Option B – Real stats:**  
  - You create a Google Sheet and OAuth (or service account) for Sheets.  
  - Import **`janssen-ai/n8n/janssen-analytics-dashboard.json`**, configure the Google Sheets node and sheet ID.  
  - In **`widget/dashboard.html`** set:
    ```javascript
    window.JANSSEN_STATS_URL = 'https://YOUR-N8N-URL.onrender.com/webhook/janssen-stats';
    ```
  - Activate the workflow and open the dashboard page.

---

## API Keys Checklist (You Are Responsible)

| Key | Where to create | Where to set in n8n |
|-----|------------------|---------------------|
| OpenAI API key | platform.openai.com/api-keys | Credentials → OpenAI API (for With_OpenAI workflow) |
| Twilio Account SID | twilio.com console | HTTP Basic Auth credential (Username) |
| Twilio Auth Token | twilio.com console | HTTP Basic Auth credential (Password) |
| Google Sheets | sheets.google.com + OAuth | Credentials → Google Sheets (Analytics/CRM workflows) |

---

## Troubleshooting

- **Widget shows “حصلت مشكلة” / “Something went wrong”**  
  - Check browser console (F12).  
  - Confirm webhook URL in `demo.html` is exactly your Render n8n URL + `/webhook/janssen-ai-incoming`.  
  - Confirm the correct workflow is **Active** in n8n.

- **curl returns 404**  
  - Path must be `/webhook/janssen-ai-incoming`.  
  - Only one workflow should be active for that path (either production or with-openai).

- **Render n8n sleeps**  
  - First request after idle can be slow; retry once.  
  - Consider upgrading Render plan if you need no cold starts.

---

## Quick Reference

- **Chat webhook:** `POST /webhook/janssen-ai-incoming`  
  Body: `{"user_message":"...", "channel":"chat", "language":"ar"|"en"}`
- **Widget config:** `window.JANSSEN_WEBHOOK_URL = 'https://...'`
- **Dashboard stats (optional):** `GET /webhook/janssen-stats`  
  Set `window.JANSSEN_STATS_URL` in `dashboard.html` if you use the analytics workflow.

Once Step 1–4 work, the system is implemented and we can refine tests (e.g. more intents, handover, or optional OpenAI/WhatsApp) together.
