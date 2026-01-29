# Janssen AI - CRM Logging Documentation

## Overview

This document describes the logging structure for the Janssen AI customer service system.

## Log Tables

### agents_log

Records all AI agent activities for monitoring and analytics.

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| conversation_id | INTEGER | Reference to conversation |
| agent_name | VARCHAR(50) | Agent: sales, support, warranty, complaint, escalation |
| action_type | VARCHAR(100) | Action performed |
| intent_received | VARCHAR(100) | Detected customer intent |
| input_text | TEXT | Customer message |
| output_text | TEXT | AI response |
| data_fetched | TEXT | Data retrieved (JSON) |
| response_time_ms | INTEGER | Processing time |
| success | BOOLEAN | Action success status |
| error_message | TEXT | Error details if failed |
| escalated | BOOLEAN | Was escalation triggered |
| created_at | TIMESTAMP | Log timestamp |

### Action Types

| Action | Description | Agent |
|--------|-------------|-------|
| MESSAGE_ROUTED | Message routed to agent | router |
| PRODUCT_FETCHED | Product info retrieved | sales |
| PRICE_QUOTED | Price provided to customer | sales |
| LEAD_CAPTURED | Sales lead created | sales |
| FAQ_ANSWERED | FAQ response provided | support |
| DELIVERY_INFO | Delivery info provided | support |
| WARRANTY_EXPLAINED | Warranty terms explained | warranty |
| CLAIM_COLLECTED | Warranty claim details collected | warranty |
| COMPLAINT_ACKNOWLEDGED | Complaint received | complaint |
| COMPLAINT_LOGGED | Complaint recorded | complaint |
| ESCALATION_INITIATED | Transfer to human started | escalation |
| TRANSFER_COMPLETED | Human handover complete | escalation |

## CRM Integration Events

### Events Synced to CRM

| Event | Trigger | Priority |
|-------|---------|----------|
| New_Conversation_Created | New session started | Real-time |
| New_Message_Logged | Message exchanged | Near real-time |
| AI_Decision_Logged | Agent action taken | Near real-time |
| Escalation_To_Human | Human transfer | Real-time (critical) |
| Conversation_Closed | Session ended | Deferred |

### Event Payload Structure

```json
{
  "event_type": "AI_DECISION",
  "timestamp": "2024-01-15T10:30:00Z",
  "conversation": {
    "session_id": "session_123",
    "crm_case_id": "CASE-001"
  },
  "decision": {
    "agent_name": "sales",
    "action_type": "PRICE_QUOTED",
    "intent_received": "SALES_PRICE",
    "success": true
  },
  "performance": {
    "response_time_ms": 450
  }
}
```

## Analytics Metrics

### Key Performance Indicators

| Metric | Description | Calculation |
|--------|-------------|-------------|
| AI Resolution Rate | % resolved without human | (total - escalations) / total |
| Avg Response Time | Average AI response time | AVG(response_time_ms) |
| Escalation Rate | % escalated to human | escalations / total |
| Intent Accuracy | Intent detection accuracy | correct_intents / total |

### Agent Performance Query

```sql
SELECT 
    agent_name,
    COUNT(*) as total_actions,
    AVG(response_time_ms) as avg_response_ms,
    SUM(CASE WHEN success THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN escalated THEN 1 ELSE 0 END) as escalations
FROM agents_log
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY agent_name
ORDER BY total_actions DESC;
```

### Intent Distribution Query

```sql
SELECT 
    intent_received,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM agents_log
WHERE intent_received IS NOT NULL
    AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY intent_received
ORDER BY count DESC;
```

## Retention Policy

| Data Type | Retention Period | Archive |
|-----------|-----------------|---------|
| agents_log | 90 days | Yes |
| conversation_messages | 1 year | Yes |
| conversations | 2 years | Yes |
| complaints | 5 years | Yes (legal) |

## Monitoring Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| High Escalation Rate | > 30% in 1 hour | Warning |
| Slow Response Time | > 5s average | Warning |
| Agent Errors | > 5 errors in 10 min | Critical |
| Database Lag | > 60s sync delay | Critical |
