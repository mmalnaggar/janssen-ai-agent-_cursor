# Janssen AI - n8n Workflows

## Available Workflows

| File | Description | Nodes | Use Case |
|------|-------------|-------|----------|
| `janssen-ai-full-v2.json` | Full multi-agent | 17 | Production - keyword matching |
| `janssen-ai-with-openai.json` | With GPT integration | 22 | Production - smart responses |
| `janssen-whatsapp-workflow.json` | WhatsApp bot | 6 | WhatsApp channel |
| `janssen-ai-production.json` | Simple 3-node | 3 | Quick deploy/testing |

---

## Quick Start

### 1. Import Workflow
1. Open n8n
2. Go to Workflows → Import from File
3. Select `janssen-ai-full-v2.json`
4. Click **Activate** (toggle in top-right)

### 2. Test
```bash
curl -X POST "https://YOUR-N8N-URL/webhook/janssen-ai-incoming" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"بكام المرتبة","channel":"chat"}'
```

---

## Workflow Architectures

### Basic (janssen-ai-full-v2.json)
```
Webhook → Normalize → Detect_Intent → Router
                                        ↓
         ┌──────┬──────┬──────┬──────┬──────┐
         ↓      ↓      ↓      ↓      ↓      ↓
       Sales  Support Warranty Complaint Escalation Fallback
         ↓      ↓      ↓      ↓      ↓      ↓
       Format Format Format  Format Format   ↓
         ↓      ↓      ↓      ↓      ↓      ↓
       Respond Respond Respond Respond Respond Respond
```

### With OpenAI (janssen-ai-with-openai.json)
```
Webhook → Normalize → Detect_Intent → Router
                                        ↓
         ┌────────┬──────┬──────┬──────┬──────┐
         ↓        ↓      ↓      ↓      ↓      ↓
       OpenAI   Sales  Support Warranty etc...
         ↓        ↓      ↓      ↓      ↓
       Format  Format Format Format Format
         ↓        ↓      ↓      ↓      ↓
      Respond  Respond Respond Respond Respond
```

### WhatsApp (janssen-whatsapp-workflow.json)
```
WhatsApp_Trigger → Parse → Detect_Intent → Generate → Send_WhatsApp → Respond
```

---

## Webhook Endpoints

| Workflow | Path | Method |
|----------|------|--------|
| Chat Widget | `/webhook/janssen-ai-incoming` | POST |
| WhatsApp | `/webhook/janssen-whatsapp` | POST |

---

## Request Format

```json
{
  "user_message": "بكام المرتبة",
  "channel": "chat",
  "language": "ar",
  "session_id": "optional_session_id"
}
```

## Response Format

```json
{
  "response_type": "text",
  "content": {
    "text": "أسعار المراتب:..."
  },
  "next_action": "await_response",
  "agent_used": "sales",
  "intent": "SALES_PRICE",
  "confidence_score": 0.8,
  "language": "ar",
  "matched_keywords": ["بكام"]
}
```

---

## Supported Agents

| Agent | Handles |
|-------|---------|
| `sales` | Prices, recommendations, products |
| `support` | Delivery, store info, general |
| `warranty` | Warranty info, claims |
| `complaint` | Issues, refunds → escalates |
| `escalation` | Human requests, legal threats |
| `openai` | Unknown/general queries (with OpenAI) |

---

## Supported Intents

| Intent | Trigger Keywords (AR) | Trigger Keywords (EN) |
|--------|----------------------|----------------------|
| SALES_PRICE | سعر, بكام, عروض | price, cost, discount |
| SALES_REC | اشتري, مرتبة, انصحني | buy, mattress, recommend |
| DELIVERY | توصيل, شحن | delivery, shipping |
| STORE_INFO | فرع, عنوان | store, address, branch |
| WARRANTY | ضمان, تصليح | warranty, repair |
| COMPLAINT | شكوى, مشكلة, زعلان | complaint, problem, angry |
| HUMAN_REQUEST | موظف, خدمة عملاء | human, manager |
| LEGAL_THREAT | محامي, قانون, فيسبوك | lawyer, legal, facebook |

---

## Setup OpenAI

1. Add OpenAI credential in n8n (Settings → Credentials)
2. Import `janssen-ai-with-openai.json`
3. Select your credential in the OpenAI node
4. Activate workflow

---

## Setup WhatsApp (Twilio)

1. Create Twilio account
2. Add HTTP Basic Auth credential in n8n:
   - Username: Account SID
   - Password: Auth Token
3. Import `janssen-whatsapp-workflow.json`
4. Set webhook in Twilio console
5. Activate workflow

---

## Troubleshooting

### Empty Response
- Check `responseMode: "responseNode"` in webhook
- Check `respondWith: "allIncomingItems"` in respond node

### 404 Not Found
- Workflow not activated
- Wrong webhook path

### Intent Not Detected
- Check message includes keywords
- Verify `input.body.user_message` access pattern

---

## Files Reference

```
n8n/
├── janssen-ai-full-v2.json        # Main production workflow
├── janssen-ai-with-openai.json    # With GPT integration
├── janssen-whatsapp-workflow.json # WhatsApp bot
├── janssen-ai-production.json     # Simple 3-node
├── janssen-ai-blueprint.json      # Original blueprint
└── README.md                      # This file
```
