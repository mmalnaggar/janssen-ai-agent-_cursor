# Janssen AI - n8n Workflow

n8n workflow blueprint for the Janssen AI customer service system.

## Overview

This workflow processes customer messages from all channels (chat, voice, WhatsApp) through:

1. **Intent Detection** - Classify customer intent
2. **Agent Routing** - Select appropriate agent (sales, support, warranty, complaint, escalation)
3. **Knowledge Retrieval** - Fetch relevant products, prices, policies
4. **Business Rules** - Enforce forbidden actions and policies
5. **Response Generation** - Generate AI response with agent tone
6. **Logging** - Log interaction for analytics and CRM sync

## Workflow Flow

```
Webhook_In
    ↓
Normalize_Input
    ↓
Detect_Intent
    ↓
Load_Agent_Config
    ↓
Check_Escalation ─────→ Escalate_To_Human
    ↓                         ↓
Fetch_Knowledge               │
    ↓                         │
Apply_Business_Rules          │
    ↓                         │
Generate_Response             │
    ↓                         │
Log_Interaction ←─────────────┘
    ↓
Return_Response
```

## Files

| File | Description |
|------|-------------|
| `janssen-ai-blueprint.json` | n8n workflow definition |

## Installation

1. Open n8n
2. Go to **Workflows** → **Import from File**
3. Select `janssen-ai-blueprint.json`
4. Configure credentials and endpoints

## Configuration Required

Before running, replace these placeholders:

| Placeholder | Description |
|-------------|-------------|
| `PLACEHOLDER_POSTGRES_CONNECTION` | PostgreSQL database connection |
| `PLACEHOLDER_OPENAI_API` | OpenAI API credentials |
| `PLACEHOLDER_CRM_WEBHOOK` | CRM integration webhook URL |

## Webhook Endpoint

After activation, the webhook will be available at:

```
https://your-n8n-instance.com/webhook/janssen-ai-incoming
```

### Request Format

```json
{
  "session_id": "session_123",
  "message": "عايز أعرف سعر المرتبة",
  "phone": "+201234567890",
  "channel": "whatsapp",
  "language": "ar"
}
```

### Response Format

```json
{
  "success": true,
  "session_id": "session_123",
  "response_text": "تمام! أي مرتبة بالظبط عايز تعرف سعرها؟",
  "agent_used": "sales",
  "intent_detected": "SALES_PRICE",
  "escalated": false
}
```

## Agent Routing

| Intent | Agent |
|--------|-------|
| SALES_PRICE | sales |
| SALES_RECOMMENDATION | sales |
| DELIVERY | support |
| WARRANTY | warranty |
| COMPLAINT | complaint |
| HUMAN_REQUEST | escalation |
| GENERAL | support |

## Notes

- This is a blueprint - requires configuration before use
- Supports Arabic (Egyptian dialect) and English
- All credentials must be configured in n8n
- Test in development before production deployment
