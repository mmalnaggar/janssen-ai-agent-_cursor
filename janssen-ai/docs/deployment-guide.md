# Janssen AI - Deployment Guide

## Overview

This guide covers deploying the Janssen AI customer service system across all components.

## System Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Backend API | Node.js + Express | Message processing |
| Workflow Engine | n8n | Orchestration |
| Database | PostgreSQL | Data storage |
| Chat Widget | JavaScript | Web chat interface |
| Voice Flow | Avaya IP Office | Voice calls |

## Prerequisites

- Node.js 18+ installed
- PostgreSQL 14+ database
- n8n instance (self-hosted or cloud)
- Domain with SSL certificate
- WhatsApp Business API access (optional)

---

## Step 1: Database Setup

### 1.1 Create Database

```bash
createdb janssen_ai
```

### 1.2 Run Schema

```bash
psql -d janssen_ai -f crm/schema.sql
```

### 1.3 Verify Tables

```sql
\dt
```

Expected tables:
- products
- prices
- delivery_rules
- warranty_policies
- conversations
- conversation_messages
- leads
- complaints
- agents_log

---

## Step 2: Backend API Deployment

### 2.1 Install Dependencies

```bash
cd backend
npm install
```

### 2.2 Configure Environment

Create `.env` file:

```env
PORT=3000
NODE_ENV=production
DATABASE_URL=postgres://user:pass@localhost:5432/janssen_ai
N8N_WEBHOOK_URL=https://your-n8n.com/webhook/janssen-ai
```

### 2.3 Start Server

```bash
npm start
```

### 2.4 Verify Health

```bash
curl http://localhost:3000/health
```

---

## Step 3: n8n Workflow Deployment

### 3.1 Import Workflow

1. Open n8n dashboard
2. Go to **Workflows** → **Import**
3. Select `n8n/janssen-ai-blueprint.json`

### 3.2 Configure Credentials

Set up these credentials in n8n:

| Credential | Type | Purpose |
|------------|------|---------|
| PostgreSQL | Database | Data access |
| OpenAI | API Key | LLM responses |
| HTTP Header | API | Backend calls |

### 3.3 Update Placeholders

Replace in workflow nodes:
- `PLACEHOLDER_POSTGRES_CONNECTION`
- `PLACEHOLDER_OPENAI_API`
- `PLACEHOLDER_BACKEND_URL`

### 3.4 Activate Workflow

Click **Activate** to enable webhook.

### 3.5 Note Webhook URL

Copy the webhook URL:
```
https://your-n8n.com/webhook/janssen-ai-incoming
```

---

## Step 4: Widget Deployment

### 4.1 Shopify Installation

Upload files to theme assets:
- `widget/widget.js`
- `widget/styles.css`

Add to `theme.liquid`:

```html
<!-- Before </head> -->
<link rel="stylesheet" href="{{ 'styles.css' | asset_url }}">

<!-- Before </body> -->
<script src="{{ 'widget.js' | asset_url }}" defer></script>
```

### 4.2 Configure Backend URL

Edit `widget.js`:

```javascript
const BACKEND = {
  endpoint: 'https://your-n8n.com/webhook/janssen-ai-incoming',
  timeout: 8000
};
```

### 4.3 Verify Widget

1. Visit store frontend
2. Look for chat toggle button (bottom-right)
3. Click to open chat
4. Send test message

---

## Step 5: Voice Flow (Avaya)

### 5.1 Import Flow

1. Open Avaya IP Office Manager
2. Import `flows/voice-agent-flow.json` configuration
3. Configure hunt groups

### 5.2 Configure Endpoints

Update in Avaya config:
- ASR Provider endpoint
- TTS Provider endpoint
- Backend webhook URL

### 5.3 Test Voice Flow

1. Call Janssen service number
2. Listen for Arabic IVR menu
3. Test each option

---

## Step 6: WhatsApp Integration

### 6.1 WhatsApp Business API

1. Set up WhatsApp Business Account
2. Configure webhook URL to n8n
3. Set message templates

### 6.2 Webhook Configuration

Point WhatsApp webhook to:
```
https://your-n8n.com/webhook/janssen-whatsapp
```

---

## Environment Configuration

### Production `.env`

```env
# Server
PORT=3000
NODE_ENV=production

# Database
DATABASE_URL=postgres://user:pass@db.example.com:5432/janssen_ai

# n8n
N8N_WEBHOOK_URL=https://n8n.example.com/webhook/janssen-ai

# OpenAI (optional)
OPENAI_API_KEY=sk-...

# WhatsApp (optional)
WHATSAPP_TOKEN=...
WHATSAPP_PHONE_ID=...
```

---

## Monitoring

### Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | API health check |
| `GET /api/agents` | List loaded agents |

### Log Monitoring

```sql
-- Recent agent actions
SELECT * FROM agents_log 
ORDER BY created_at DESC 
LIMIT 100;

-- Escalation rate
SELECT 
    COUNT(*) FILTER (WHERE escalated) as escalated,
    COUNT(*) as total,
    ROUND(COUNT(*) FILTER (WHERE escalated) * 100.0 / COUNT(*), 2) as rate
FROM agents_log
WHERE created_at >= NOW() - INTERVAL '24 hours';
```

---

## Troubleshooting

### Widget Not Appearing

1. Check browser console for errors
2. Verify CSS/JS files loaded
3. Check for JavaScript conflicts

### n8n Webhook Not Responding

1. Verify workflow is active
2. Check webhook URL is correct
3. Review n8n execution logs

### Database Connection Errors

1. Verify DATABASE_URL format
2. Check PostgreSQL is running
3. Verify network access

### Voice Flow Not Working

1. Check Avaya hunt group config
2. Verify ASR/TTS endpoints
3. Review call logs

---

## Security Checklist

- [ ] SSL certificates installed
- [ ] Database credentials secured
- [ ] API keys not in code
- [ ] CORS configured properly
- [ ] Rate limiting enabled
- [ ] Input validation active
- [ ] Logs don't contain PII
- [ ] Webhook signatures verified

---

## Rollback Procedure

1. Stop current deployment
2. Restore previous code version
3. Rollback database if needed
4. Restart services
5. Verify functionality

---

## Support

For deployment issues:
- Review logs in `agents_log` table
- Check n8n execution history
- Contact Janssen IT team
