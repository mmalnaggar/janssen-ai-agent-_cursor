# Janssen AI - Complete Setup Guide

## Overview

This guide covers setting up the complete Janssen AI system:
1. **Chat Widget** - Website integration
2. **WhatsApp Bot** - Via Twilio
3. **OpenAI Integration** - GPT-powered responses
4. **n8n Workflows** - Backend automation

---

## 1. Chat Widget Setup

### Files Location
```
janssen-ai/widget/
├── widget.js      # Main JavaScript
├── styles.css     # Styles
├── demo.html      # Demo page
└── embed.html     # Embed instructions
```

### Quick Start
```bash
cd janssen-ai/widget
python3 -m http.server 8080
# Open http://localhost:8080/demo.html
```

### Production Embed
Add to your website before `</body>`:

```html
<script>
  window.JANSSEN_WEBHOOK_URL = 'https://YOUR-N8N-URL/webhook/janssen-ai-incoming';
</script>
<link rel="stylesheet" href="https://your-cdn.com/widget/styles.css">
<script src="https://your-cdn.com/widget/widget.js"></script>
```

### JavaScript API
```javascript
// Open chat
JanssenChat.open();

// Close chat
JanssenChat.close();

// Toggle
JanssenChat.toggle();

// Set language
JanssenChat.setLanguage('ar'); // or 'en'

// Send message programmatically
JanssenChat.sendMessage('مرحبا');

// Check if escalated
JanssenChat.isLocked();
```

---

## 2. WhatsApp Bot Setup (Twilio)

### Prerequisites
- Twilio account (https://twilio.com)
- WhatsApp Business approved number

### Step 1: Create Twilio Account
1. Go to https://www.twilio.com/try-twilio
2. Sign up and verify your phone
3. Get your Account SID and Auth Token from Console

### Step 2: Set Up WhatsApp Sandbox (Testing)
1. Go to Twilio Console → Messaging → Try it out → Send a WhatsApp message
2. Follow instructions to join sandbox
3. Note the sandbox number (e.g., +1 415 523 8886)

### Step 3: Configure n8n
1. Import `n8n/janssen-whatsapp-workflow.json`
2. Add HTTP Basic Auth credential:
   - Username: Your Twilio Account SID
   - Password: Your Twilio Auth Token
3. Set environment variables in n8n:
   ```
   TWILIO_ACCOUNT_SID=ACxxxxxxxxx
   TWILIO_AUTH_TOKEN=your_auth_token
   TWILIO_WHATSAPP_NUMBER=+14155238886
   ```

### Step 4: Set Webhook in Twilio
1. Go to Twilio Console → Messaging → Settings → WhatsApp Sandbox Settings
2. Set "When a message comes in" to:
   ```
   https://YOUR-N8N-URL/webhook/janssen-whatsapp
   ```
3. Method: POST

### Step 5: Activate Workflow
1. Open the workflow in n8n
2. Click the toggle to activate
3. Test by sending a WhatsApp message to your sandbox number

### Production WhatsApp
For production, you need:
1. WhatsApp Business API approval
2. Verified business number
3. Message templates for outbound messages

---

## 3. OpenAI Integration Setup

### Prerequisites
- OpenAI API account (https://platform.openai.com)
- API key with credits

### Step 1: Get OpenAI API Key
1. Go to https://platform.openai.com/api-keys
2. Create new secret key
3. Copy and save securely

### Step 2: Add Credential in n8n
1. Go to n8n → Credentials → Add Credential
2. Search for "OpenAI"
3. Paste your API key
4. Save and note the credential ID

### Step 3: Import Workflow
1. Import `n8n/janssen-ai-with-openai.json`
2. Open the `5_OpenAI_Chat` node
3. Select your OpenAI credential

### Step 4: Configure System Prompt
The default system prompt includes Janssen company info. Edit in the node:

```
You are Janssen AI, a helpful customer service assistant for Janssen Mattresses in Egypt.

Company Info:
- Janssen makes premium mattresses since 1955
- 10-year warranty on all products
- Prices: Orthopedic (12,500 EGP), Memory Foam (15,000 EGP), Super Soft (10,000 EGP)
- Delivery: Cairo 2-3 days, Alexandria 3-5 days, Others 5-7 days
- Free delivery over 5,000 EGP
- Branches: Nasr City (Abbas El-Akkad), Mohandessin (Arab League St)
- Hours: 9 AM - 9 PM

Rules:
- Respond in the same language as the user (Arabic or English)
- Be helpful, friendly, and professional
- For complaints or legal issues, suggest connecting to human support
- Keep responses concise (2-3 sentences max)
```

### Step 5: Activate and Test
1. Activate the workflow
2. Test via chat widget or curl:
   ```bash
   curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
     -H "Content-Type: application/json" \
     -d '{"user_message":"what mattress do you recommend for back pain?","channel":"chat"}'
   ```

---

## 4. n8n Workflow Files

| File | Description | Use Case |
|------|-------------|----------|
| `janssen-ai-full-v2.json` | Basic multi-agent (no AI) | Production - keyword matching |
| `janssen-ai-with-openai.json` | With GPT integration | Production - smart responses |
| `janssen-whatsapp-workflow.json` | WhatsApp bot | WhatsApp channel |
| `janssen-ai-production.json` | Simple 3-node | Quick deploy |

---

## 5. Environment Variables

### n8n Cloud
Set in Settings → Variables:

```
OPENAI_API_KEY=sk-xxxxx
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=xxxxx
TWILIO_WHATSAPP_NUMBER=+14155238886
WHATSAPP_API_URL=https://api.twilio.com/2010-04-01/Accounts/ACxxxxx/Messages.json
```

### Self-hosted n8n
Add to `.env` file:
```bash
OPENAI_API_KEY=sk-xxxxx
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=xxxxx
TWILIO_WHATSAPP_NUMBER=+14155238886
```

---

## 6. Testing Checklist

### Chat Widget
- [ ] Widget appears on page
- [ ] Arabic messages work
- [ ] English messages work
- [ ] Product cards display
- [ ] Escalation locks input

### WhatsApp
- [ ] Webhook receives messages
- [ ] Bot responds in correct language
- [ ] Prices/info are accurate

### OpenAI
- [ ] GPT responses are natural
- [ ] Falls back to keyword agents for known intents
- [ ] Handles unknown queries gracefully

---

## 7. Troubleshooting

### Widget not appearing
- Check console for JavaScript errors
- Verify webhook URL is correct
- Ensure n8n workflow is active

### Empty responses
- Check n8n execution logs
- Verify `responseMode: "responseNode"` in webhook
- Check `respondWith: "allIncomingItems"` in respond node

### WhatsApp not responding
- Verify Twilio credentials
- Check webhook URL in Twilio console
- Ensure workflow is activated

### OpenAI errors
- Verify API key is valid
- Check credit balance
- Review rate limits

---

## 8. Support

For issues with:
- **n8n**: https://community.n8n.io
- **Twilio**: https://support.twilio.com
- **OpenAI**: https://help.openai.com

---

## Quick Reference

### Webhook URLs
```
Chat:     /webhook/janssen-ai-incoming
WhatsApp: /webhook/janssen-whatsapp
```

### Response Format
```json
{
  "response_type": "text",
  "content": { "text": "Response message" },
  "next_action": "await_response",
  "agent_used": "sales",
  "intent": "SALES_PRICE",
  "language": "ar"
}
```

### Supported Intents
- SALES_PRICE, SALES_REC
- DELIVERY, STORE_INFO
- WARRANTY
- COMPLAINT
- HUMAN_REQUEST, LEGAL_THREAT
- GENERAL
