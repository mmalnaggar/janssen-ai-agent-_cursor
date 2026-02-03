# Janssen AI - n8n Installation Guide

Step-by-step guide to install and configure the Janssen AI system on n8n.
 
 
---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [n8n Cloud Setup](#2-n8n-cloud-setup)
3. [Import Main Workflow](#3-import-main-workflow)
4. [Activate Workflow](#4-activate-workflow)
5. [Test the Webhook](#5-test-the-webhook)
6. [Add Chat Widget to Website](#6-add-chat-widget-to-website)
7. [Optional: Add WhatsApp](#7-optional-add-whatsapp)
8. [Optional: Add OpenAI](#8-optional-add-openai)
9. [Optional: Add CRM Logging](#9-optional-add-crm-logging)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

Before starting, you need:

- [ ] n8n Cloud account OR self-hosted n8n
- [ ] The workflow files from `janssen-ai/n8n/` folder
- [ ] A website to embed the chat widget (optional for testing)

### Files You'll Need

| File | Purpose |
|------|---------|
| `janssen-ai-full-v2.json` | Main AI workflow (required) |
| `janssen-whatsapp-workflow.json` | WhatsApp (optional) |
| `janssen-voice-integration.json` | Voice/IVR (optional) |
| `janssen-crm-integration.json` | CRM logging (optional) |

---

## 2. n8n Cloud Setup

### Step 2.1: Create Account

1. Go to **https://n8n.io**
2. Click **"Get Started Free"**
3. Sign up with email or Google
4. Verify your email

### Step 2.2: Access Your Instance

1. After signup, you'll get a URL like:
   ```
   https://your-name.app.n8n.cloud
   ```
2. Bookmark this URL
3. Log in to your dashboard

---

## 3. Import Main Workflow

### Step 3.1: Open Workflows

1. In n8n, click **"Workflows"** in the left sidebar
2. Click **"Add Workflow"** or the **"+"** button

### Step 3.2: Import from File

1. Click the **three dots menu (⋮)** in the top right
2. Select **"Import from File"**
3. Choose the file: `janssen-ai-full-v2.json`
4. Click **"Open"**

### Step 3.3: Verify Import

You should see a workflow with these nodes:

```
1_Webhook → 2_Normalize → 3_Detect_Intent → 4_Router
                                               ↓
              ┌──────┬──────┬──────┬──────┬──────┐
              ↓      ↓      ↓      ↓      ↓      ↓
           Sales  Support Warranty Complaint Escalation Fallback
              ↓      ↓      ↓      ↓      ↓      ↓
           Format Format Format  Format Format   ↓
              ↓      ↓      ↓      ↓      ↓      ↓
           Respond Respond Respond Respond Respond Respond
```

### Step 3.4: Save Workflow

1. Click **"Save"** button (top right)
2. Or press **Ctrl+S** / **Cmd+S**

---

## 4. Activate Workflow

### Step 4.1: Activate

1. Find the **toggle switch** in the top right corner
2. Click it to turn it **ON** (orange/active)
3. You should see: "Workflow activated"

### Step 4.2: Get Webhook URL

1. Click on the **"1_Webhook"** node
2. Look for **"Production URL"**:
   ```
   https://your-name.app.n8n.cloud/webhook/janssen-ai-incoming
   ```
3. **Copy this URL** - you'll need it for the widget

> ⚠️ **Important**: Use the "Production URL", NOT the "Test URL"

---

## 5. Test the Webhook

### Step 5.1: Test with curl

Open Terminal and run:

```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"بكام المرتبة","channel":"chat"}'
```

Replace `YOUR-N8N-URL` with your actual n8n URL.

### Step 5.2: Expected Response

```json
{
  "response_type": "text",
  "content": {
    "text": "أسعار المراتب:..."
  },
  "agent_used": "sales",
  "intent": "SALES_PRICE",
  "language": "ar"
}
```

### Step 5.3: Test English

```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"how much is the mattress","channel":"chat"}'
```

### Step 5.4: Verify in n8n

1. Go to **"Executions"** in left sidebar
2. You should see your test executions
3. Click on one to see the data flow

---

## 6. Add Chat Widget to Website

### Step 6.1: Upload Widget Files

Upload these files to your web server:
- `widget/widget.js`
- `widget/styles.css`

### Step 6.2: Add to Website HTML

Add this code before `</body>` on your website:

```html
<!-- Janssen AI Chat Widget -->
<script>
  window.JANSSEN_WEBHOOK_URL = 'https://YOUR-N8N-URL/webhook/janssen-ai-incoming';
</script>
<link rel="stylesheet" href="/path/to/styles.css">
<script src="/path/to/widget.js"></script>
```

### Step 6.3: Replace URL

Change `YOUR-N8N-URL` to your actual n8n webhook URL.

### Step 6.4: Test Locally First

```bash
cd janssen-ai/widget
python3 -m http.server 8080
```

Open: http://localhost:8080/demo.html

---

## 7. Optional: Add WhatsApp

### Step 7.1: Create Twilio Account

1. Go to **https://www.twilio.com/try-twilio**
2. Sign up and verify phone
3. Get your **Account SID** and **Auth Token**

### Step 7.2: Set Up WhatsApp Sandbox

1. In Twilio Console, go to:
   **Messaging → Try it out → Send a WhatsApp message**
2. Follow instructions to join sandbox
3. Note the sandbox number

### Step 7.3: Import WhatsApp Workflow

1. In n8n, import `janssen-whatsapp-workflow.json`
2. Click on **"5_Send_WhatsApp"** node
3. Add credentials:
   - Type: **HTTP Basic Auth**
   - Username: Your Twilio **Account SID**
   - Password: Your Twilio **Auth Token**

### Step 7.4: Set Twilio Webhook

1. In Twilio Console:
   **Messaging → Settings → WhatsApp Sandbox Settings**
2. Set "When a message comes in" to:
   ```
   https://YOUR-N8N-URL/webhook/janssen-whatsapp
   ```
3. Method: **POST**

### Step 7.5: Activate and Test

1. Activate the workflow in n8n
2. Send a WhatsApp message to your sandbox number
3. Check n8n executions

---

## 8. Optional: Add OpenAI

### Step 8.1: Get OpenAI API Key

1. Go to **https://platform.openai.com/api-keys**
2. Create new secret key
3. Copy and save it

### Step 8.2: Add Credential in n8n

1. Go to **Settings → Credentials**
2. Click **"Add Credential"**
3. Search for **"OpenAI"**
4. Paste your API key
5. Save

### Step 8.3: Import OpenAI Workflow

1. Import `janssen-ai-with-openai.json`
2. Click on **"5_OpenAI_Chat"** node
3. Select your OpenAI credential

### Step 8.4: Activate

1. Deactivate the basic workflow (janssen-ai-full-v2)
2. Activate the OpenAI workflow

---

## 9. Optional: Add CRM Logging

### Step 9.1: Create Google Sheet

Create a new Google Sheet with these columns:

| timestamp | session_id | phone | channel | language | user_message | bot_response | intent | agent_used | confidence | escalated |

### Step 9.2: Add Google Credential

1. In n8n, go to **Settings → Credentials**
2. Add **"Google Sheets OAuth2 API"**
3. Follow the authentication flow

### Step 9.3: Import CRM Workflow

1. Import `janssen-crm-integration.json`
2. Click on **"3_Save_To_Sheets"** node
3. Select your Google credential
4. Enter your Sheet ID (from the URL)
5. Select the sheet name

### Step 9.4: Connect to Main Workflow

In your main workflow, add an HTTP Request node at the end:
- Method: POST
- URL: `https://YOUR-N8N-URL/webhook/janssen-log`
- Body: The conversation data

---

## 10. Troubleshooting

### Problem: 404 Not Found

**Cause**: Workflow not activated

**Fix**:
1. Open the workflow
2. Click the toggle to activate
3. Check the URL is correct (Production, not Test)

---

### Problem: Empty Response

**Cause**: Response node configuration issue

**Fix**:
1. Click on the Respond node
2. Ensure "Respond With" is set to "All Incoming Items"
3. Save and test again

---

### Problem: Intent Not Detected

**Cause**: Message not matching keywords

**Fix**:
1. Check the message contains keywords
2. Arabic messages should include Arabic text
3. Check the Detect_Intent node logic

---

### Problem: CORS Error (Widget)

**Cause**: Browser blocking cross-origin request

**Fix**:
1. In n8n webhook node settings, enable CORS
2. Or add these headers to the response

---

### Problem: WhatsApp Not Responding

**Cause**: Twilio credentials or webhook issue

**Fix**:
1. Verify Twilio credentials are correct
2. Check webhook URL in Twilio console
3. Check n8n executions for errors

---

## Quick Reference

### Webhook URLs

| Purpose | Path |
|---------|------|
| Chat | `/webhook/janssen-ai-incoming` |
| WhatsApp | `/webhook/janssen-whatsapp` |
| Voice | `/webhook/janssen-voice` |
| CRM Log | `/webhook/janssen-log` |
| Stats | `/webhook/janssen-stats` |

### Test Commands

```bash
# Arabic Price
curl -X POST "URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"بكام المرتبة","channel":"chat"}'

# English Delivery
curl -X POST "URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"how long is delivery","channel":"chat"}'

# Warranty
curl -X POST "URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"عايز اعرف عن الضمان","channel":"chat"}'
```

---

## Support

If you encounter issues:

1. Check n8n Executions for error details
2. Verify all credentials are correct
3. Test with curl before using the widget
4. Check the workflow is activated

---

## Next Steps

After completing this guide:

1. ✅ Main workflow active
2. ✅ Widget on website
3. ⬜ Add WhatsApp (optional)
4. ⬜ Add OpenAI (optional)
5. ⬜ Add CRM logging (optional)
6. ⬜ Set up analytics dashboard
