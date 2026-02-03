# Janssen AI

AI-powered customer service agent system for Janssen Mattresses - Egypt.

## Features

- **Multi-Channel Support**: Chat widget, WhatsApp, Voice/IVR
- **Bilingual**: Arabic & English with auto-detection
- **5 Specialized Agents**: Sales, Support, Warranty, Complaint, Escalation
- **OpenAI Integration**: GPT-powered intelligent responses
- **CRM Logging**: Google Sheets integration
- **Analytics Dashboard**: Real-time conversation insights
- **n8n Automation**: Cloud-ready workflows

---

## Quick Start

### 1. Deploy n8n Workflow

```bash
# Import to n8n Cloud
n8n/janssen-ai-full-v2.json
```

### 2. Test the Webhook

```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"بكام المرتبة","channel":"chat"}'
```

### 3. Add Chat Widget to Website

```html
<script>
  window.JANSSEN_WEBHOOK_URL = 'https://YOUR-N8N-URL/webhook/janssen-ai-incoming';
</script>
<link rel="stylesheet" href="widget/styles.css">
<script src="widget/widget.js"></script>
```

---

## Project Structure

```
janssen-ai/
├── widget/                    # Chat Widget
│   ├── widget.js              # Main JavaScript
│   ├── styles.css             # Styles
│   ├── demo.html              # Demo website
│   ├── dashboard.html         # Analytics dashboard
│   └── embed.html             # Embed instructions
│
├── n8n/                       # n8n Workflows
│   ├── janssen-ai-full-v2.json        # Main workflow (recommended)
│   ├── janssen-ai-with-openai.json    # With GPT integration
│   ├── janssen-complete-system.json   # All-in-one + logging
│   ├── janssen-whatsapp-workflow.json # WhatsApp bot
│   ├── janssen-voice-integration.json # Voice/IVR
│   ├── janssen-crm-integration.json   # CRM logger
│   ├── janssen-analytics-dashboard.json # Stats API
│   └── README.md
│
├── docs/                      # Documentation
│   ├── SETUP-GUIDE.md         # Complete setup guide
│   ├── agent-architecture.md
│   └── ...
│
├── backend/                   # Node.js Backend (optional)
│   ├── agents/
│   ├── controllers/
│   ├── routes/
│   └── app.js
│
└── README.md
```

---

## Workflows Overview

| Workflow | Description | Use Case |
|----------|-------------|----------|
| `janssen-ai-full-v2.json` | Multi-agent with routing | Production - keyword matching |
| `janssen-ai-with-openai.json` | With GPT integration | Production - smart responses |
| `janssen-complete-system.json` | All-in-one + CRM logging | Full system |
| `janssen-whatsapp-workflow.json` | WhatsApp bot via Twilio | WhatsApp channel |
| `janssen-voice-integration.json` | Voice/IVR with TwiML | Call center |
| `janssen-crm-integration.json` | Log to Google Sheets | Analytics |
| `janssen-analytics-dashboard.json` | Stats API endpoint | Dashboard |

---

s
## Supported Channels

| Channel | Workflow | Webhook |
|---------|----------|---------|
| Chat Widget | `janssen-ai-full-v2.json` | `/webhook/janssen-ai-incoming` |
| WhatsApp | `janssen-whatsapp-workflow.json` | `/webhook/janssen-whatsapp` |
| Voice/IVR | `janssen-voice-integration.json` | `/webhook/janssen-voice` |
| CRM Log | `janssen-crm-integration.json` | `/webhook/janssen-log` |
| Stats API | `janssen-analytics-dashboard.json` | `/webhook/janssen-stats` |

---

## Agent System

| Agent | Handles | Intents |
|-------|---------|---------|
| **Sales** | Prices, recommendations, products | SALES_PRICE, SALES_REC |
| **Support** | Delivery, store info, FAQs | DELIVERY, STORE_INFO, GENERAL |
| **Warranty** | Warranty info, claims | WARRANTY |
| **Complaint** | Issues, refunds → escalates | COMPLAINT |
| **Escalation** | Human requests, legal threats | HUMAN_REQUEST, LEGAL_THREAT |
| **OpenAI** | Unknown queries | Falls through to GPT |

---

## API Reference

### Request Format

```json
{
  "user_message": "بكام المرتبة",
  "channel": "chat",
  "language": "ar",
  "session_id": "session_123",
  "phone": "+201234567890",
  "metadata": {
    "page": "/products",
    "customer_id": "cust_456"
  }
}
```

### Response Format

```json
{
  "response_type": "text",
  "content": {
    "text": "أسعار المراتب:...",
    "product": { ... }
  },
  "next_action": "await_response",
  "agent_used": "sales",
  "intent": "SALES_PRICE",
  "confidence_score": 0.8,
  "session_id": "session_123",
  "language": "ar",
  "channel": "chat",
  "matched_keywords": ["بكام"]
}
```

---

## Setup Guides

### Chat Widget

1. Open `widget/demo.html` locally
2. Upload `widget.js` + `styles.css` to your server
3. Add embed code to your website

### WhatsApp (Twilio)

1. Create Twilio account
2. Set up WhatsApp Sandbox
3. Import `janssen-whatsapp-workflow.json`
4. Add Twilio credentials
5. Set webhook in Twilio console

### OpenAI

1. Get API key from OpenAI
2. Add credential in n8n
3. Import `janssen-ai-with-openai.json`
4. Select credential in OpenAI node

### Analytics

1. Create Google Sheet with columns: timestamp, session_id, user_message, etc.
2. Add Google Sheets credential in n8n
3. Import `janssen-crm-integration.json`
4. Import `janssen-analytics-dashboard.json`
5. Open `widget/dashboard.html`

---

## Testing

### Test Chat

```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"hello","channel":"chat"}'
```

### Test Arabic

```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"عايز اعرف عن الضمان","channel":"chat"}'
```

### Test WhatsApp

```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-whatsapp" \
  -H "Content-Type: application/json" \
  -d '{"Body":"بكام المرتبة","From":"+201234567890"}'
```

---

## Environment Variables

```bash
# n8n
OPENAI_API_KEY=sk-xxxxx
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=xxxxx
TWILIO_WHATSAPP_NUMBER=+14155238886
CRM_LOG_WEBHOOK=https://your-n8n/webhook/janssen-log

# Widget
JANSSEN_WEBHOOK_URL=https://your-n8n/webhook/janssen-ai-incoming
JANSSEN_STATS_URL=https://your-n8n/webhook/janssen-stats
```

---

## Demo

1. **Chat Widget**: `widget/demo.html`
2. **Dashboard**: `widget/dashboard.html`

```bash
cd widget
python3 -m http.server 8080
# Open http://localhost:8080/demo.html
```

---

## License

Proprietary - Janssen Egypt

---

## Support

For technical issues, refer to `docs/SETUP-GUIDE.md` or contact the development team.
