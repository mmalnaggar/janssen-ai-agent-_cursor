# Janssen AI Ops - Metabase Dashboard Guide

> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Database:** PostgreSQL (analytics_events) + MySQL (JanssenCRM)

---

## Table of Contents

1. [Dashboard Naming Conventions](#1-dashboard-naming-conventions)
2. [Read-Only Access Rules](#2-read-only-access-rules)
3. [SQL Queries & Chart Recommendations](#3-sql-queries--chart-recommendations)
   - [3.1 Leads Analytics](#31-leads-analytics)
   - [3.2 Complaints Analytics](#32-complaints-analytics)
   - [3.3 Escalations Analytics](#33-escalations-analytics)
   - [3.4 Confidence Analytics](#34-confidence-analytics)
   - [3.5 Media Analytics](#35-media-analytics)
4. [Dashboard Layouts](#4-dashboard-layouts)
5. [Refresh & Caching](#5-refresh--caching)

---

## 1. Dashboard Naming Conventions

### Collection Structure

```
Janssen AI Ops/
├── 📊 Executive Summary
├── 📈 Operations/
│   ├── [JOPS] Daily Operations Overview
│   ├── [JOPS] Leads Pipeline
│   ├── [JOPS] Complaints Monitor
│   └── [JOPS] Escalation Tracker
├── 📉 Analytics/
│   ├── [JANA] Confidence Analysis
│   ├── [JANA] Channel Performance
│   ├── [JANA] Agent Workload
│   └── [JANA] Media Attachments
└── 🔧 Technical/
    ├── [JTECH] System Health
    └── [JTECH] Error Rates
```

### Naming Convention Rules

| Prefix | Category | Example |
|--------|----------|---------|
| `[JOPS]` | Operations | `[JOPS] Daily Leads Summary` |
| `[JANA]` | Analytics | `[JANA] Confidence Trends` |
| `[JTECH]` | Technical | `[JTECH] API Response Times` |
| `[JEXEC]` | Executive | `[JEXEC] Weekly KPI Report` |

### Question (Query) Naming

```
[Category] Metric - Dimension - Timeframe
```

**Examples:**
- `[JOPS] Leads - By Channel - Daily`
- `[JANA] Confidence - By Agent - Weekly`
- `[JOPS] Escalations - Heatmap - Hourly`

---

## 2. Read-Only Access Rules

### User Groups & Permissions

| Group | Collections | Data Access | Actions |
|-------|-------------|-------------|---------|
| `janssen-ai-viewers` | All dashboards | Read-only | View, Export CSV |
| `janssen-ai-analysts` | Analytics, Operations | Read-only + Native Query | View, Export, Create Questions |
| `janssen-ai-admins` | All | Full access | All + Edit Dashboards |
| `janssen-crm-ops` | Operations only | Read-only | View, Export |

### Database Connection Setup

```yaml
# Metabase Admin > Databases > Add Database

# Analytics Database (PostgreSQL)
database_name: "Janssen AI Analytics"
type: postgresql
host: ${ANALYTICS_DB_HOST}
port: 5432
database: janssen_analytics
username: metabase_readonly
ssl: required

# CRM Database (MySQL) - Read Replica
database_name: "JanssenCRM (Read-Only)"
type: mysql
host: ${CRM_READ_REPLICA_HOST}
port: 3306
database: janssencrm
username: metabase_readonly
ssl: required
```

### SQL User Permissions (PostgreSQL)

```sql
-- Create read-only user for Metabase
CREATE USER metabase_readonly WITH PASSWORD '${SECURE_PASSWORD}';

-- Grant read-only access to analytics schema
GRANT CONNECT ON DATABASE janssen_analytics TO metabase_readonly;
GRANT USAGE ON SCHEMA public TO metabase_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO metabase_readonly;

-- Explicitly deny write operations
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM metabase_readonly;
```

### SQL User Permissions (MySQL - JanssenCRM)

```sql
-- Create read-only user for Metabase (use read replica)
CREATE USER 'metabase_readonly'@'%' IDENTIFIED BY '${SECURE_PASSWORD}';

-- Grant read-only access
GRANT SELECT ON janssencrm.* TO 'metabase_readonly'@'%';

-- Explicitly deny write operations
REVOKE INSERT, UPDATE, DELETE ON janssencrm.* FROM 'metabase_readonly'@'%';

FLUSH PRIVILEGES;
```

### Row-Level Security (Optional)

```sql
-- If multi-company access control is needed
CREATE POLICY company_isolation ON analytics_events
    FOR SELECT
    USING (company_id = current_setting('app.current_company_id')::int);
```

---

## 3. SQL Queries & Chart Recommendations

### 3.1 Leads Analytics

#### 3.1.1 Leads Per Day (Trend)

**Query Name:** `[JOPS] Leads - Daily Count - 30 Days`

```sql
-- Leads created per day (last 30 days)
SELECT 
    date AS "Date",
    COUNT(*) AS "Leads"
FROM analytics_events
WHERE event_type = 'LEAD_CREATED'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Line Chart |
| **X-Axis** | Date |
| **Y-Axis** | Leads |
| **Goal Line** | Daily target (e.g., 50) |
| **Color** | `#4CAF50` (green) |

---

#### 3.1.2 Leads by Channel

**Query Name:** `[JANA] Leads - By Channel - Weekly`

```sql
-- Leads by channel (weekly breakdown)
SELECT 
    DATE_TRUNC('week', timestamp) AS "Week",
    channel AS "Channel",
    COUNT(*) AS "Leads"
FROM analytics_events
WHERE event_type = 'LEAD_CREATED'
  AND timestamp >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', timestamp), channel
ORDER BY "Week" ASC, "Leads" DESC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Stacked Bar Chart |
| **X-Axis** | Week |
| **Y-Axis** | Leads |
| **Stack By** | Channel |
| **Colors** | chat: `#2196F3`, voice: `#FF9800`, whatsapp: `#25D366` |

---

#### 3.1.3 Lead Conversion Proxy

**Query Name:** `[JANA] Lead Conversion Proxy - Daily`

```sql
-- Lead conversion proxy (leads / total interactions)
SELECT 
    date AS "Date",
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads",
    COUNT(*) AS "Total Interactions",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0),
        2
    ) AS "Conversion Rate %"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Combo Chart (Bar + Line) |
| **Bars** | Leads, Total Interactions |
| **Line** | Conversion Rate % |
| **Secondary Y-Axis** | Conversion Rate % |

---

#### 3.1.4 Leads by Agent Performance

**Query Name:** `[JANA] Leads - By Agent - Monthly`

```sql
-- Leads generated by each AI agent
SELECT 
    agent_used AS "Agent",
    COUNT(*) AS "Leads Generated",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    COUNT(*) FILTER (WHERE confidence >= 0.8) AS "High Confidence Leads"
FROM analytics_events
WHERE event_type = 'LEAD_CREATED'
  AND date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY agent_used
ORDER BY "Leads Generated" DESC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Table with Conditional Formatting |
| **Highlight** | High Confidence Leads > 70% → Green |
| **Mini Bar** | Leads Generated column |

---

### 3.2 Complaints Analytics

#### 3.2.1 Complaints Daily Trend

**Query Name:** `[JOPS] Complaints - Daily Count - 30 Days`

```sql
-- Complaints logged per day
SELECT 
    date AS "Date",
    COUNT(*) AS "Complaints",
    COUNT(*) FILTER (WHERE confidence < 0.5) AS "Low Confidence",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalated"
FROM analytics_events
WHERE event_type = 'COMPLAINT_LOGGED'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Area Chart |
| **X-Axis** | Date |
| **Y-Axis** | Complaints |
| **Color** | `#F44336` (red) |
| **Show Trend Line** | Yes |

---

#### 3.2.2 Complaints vs Sales Ratio

**Query Name:** `[JANA] Complaints vs Leads - Daily Ratio`

```sql
-- Complaints to Leads ratio (health indicator)
SELECT 
    date AS "Date",
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads",
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS "Complaints",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
        NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
        2
    ) AS "Complaint Ratio %"
FROM analytics_events
WHERE event_type IN ('LEAD_CREATED', 'COMPLAINT_LOGGED')
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Line Chart (Dual Axis) |
| **Left Y-Axis** | Leads (green), Complaints (red) |
| **Right Y-Axis** | Complaint Ratio % |
| **Alert Threshold** | Ratio > 20% → Warning |

---

#### 3.2.3 Complaints by Channel

**Query Name:** `[JANA] Complaints - By Channel - Breakdown`

```sql
-- Complaint distribution by channel
SELECT 
    channel AS "Channel",
    COUNT(*) AS "Total Complaints",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS "Percentage",
    ROUND(AVG(CASE WHEN escalated THEN 1 ELSE 0 END) * 100, 2) AS "Escalation Rate %"
FROM analytics_events
WHERE event_type = 'COMPLAINT_LOGGED'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY channel
ORDER BY "Total Complaints" DESC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Pie Chart / Donut Chart |
| **Labels** | Channel + Percentage |
| **Colors** | chat: `#2196F3`, voice: `#FF9800`, whatsapp: `#25D366` |

---

#### 3.2.4 Complaints with Media Attachments

**Query Name:** `[JANA] Complaints - Media Attachment Rate`

```sql
-- Complaints with media (WhatsApp images/videos)
-- Note: Requires JanssenCRM MySQL connection
SELECT 
    DATE(t.created_at) AS "Date",
    COUNT(DISTINCT t.id) AS "Total Complaint Tickets",
    COUNT(DISTINCT tm.id) AS "Tickets with Media",
    ROUND(
        100.0 * COUNT(DISTINCT tm.ticket_id) / NULLIF(COUNT(DISTINCT t.id), 0),
        2
    ) AS "Media Attachment Rate %"
FROM tickets t
LEFT JOIN ticket_media tm ON t.id = tm.ticket_id
WHERE t.category_id = 1  -- Complaints category
  AND t.created_at >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY DATE(t.created_at)
ORDER BY "Date" ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Bar Chart with Percentage Line |
| **Bars** | Total Tickets, Tickets with Media |
| **Line** | Media Attachment Rate % |

---

### 3.3 Escalations Analytics

#### 3.3.1 Escalation Rate Trend

**Query Name:** `[JOPS] Escalation Rate - Daily Trend`

```sql
-- Daily escalation rate
SELECT 
    date AS "Date",
    COUNT(*) AS "Total Events",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Line Chart with Goal |
| **Metric** | Escalation Rate % |
| **Goal Line** | Target < 15% |
| **Color** | Below goal: `#4CAF50`, Above: `#F44336` |

---

#### 3.3.2 Escalation Heatmap (Hour x Day)

**Query Name:** `[JANA] Escalations - Heatmap - Hourly`

```sql
-- Escalation heatmap by hour and day of week
SELECT 
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS "Day",
    hour AS "Hour",
    COUNT(*) AS "Escalations"
FROM analytics_events
WHERE escalated = TRUE
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY day_of_week, hour
ORDER BY day_of_week, hour;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Heatmap / Pivot Table |
| **Rows** | Day of Week |
| **Columns** | Hour (0-23) |
| **Values** | Escalations (color intensity) |
| **Color Scale** | Green (low) → Yellow → Red (high) |

---

#### 3.3.3 Escalation Reasons Breakdown

**Query Name:** `[JANA] Escalations - By Reason - Distribution`

```sql
-- Escalation reasons (from JanssenCRM)
SELECT 
    COALESCE(t.escalation_reason, 'Not Specified') AS "Reason",
    COUNT(*) AS "Count",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS "Percentage"
FROM tickets t
WHERE t.escalated_by_ai = 1
  AND t.created_at >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY t.escalation_reason
ORDER BY "Count" DESC
LIMIT 10;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Horizontal Bar Chart |
| **Bars** | Reason |
| **Values** | Count |
| **Sort** | Descending by Count |

---

#### 3.3.4 Business Hours vs After-Hours Escalations

**Query Name:** `[JANA] Escalations - Business Hours Comparison`

```sql
-- Escalations during vs outside business hours
SELECT 
    CASE 
        WHEN is_business_hours THEN 'Business Hours (9AM-6PM)'
        ELSE 'After Hours'
    END AS "Time Period",
    COUNT(*) AS "Escalations",
    ROUND(AVG(confidence), 3) AS "Avg Confidence Before Escalation"
FROM analytics_events
WHERE escalated = TRUE
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY is_business_hours;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Donut Chart |
| **Center Label** | Total Escalations |
| **Segments** | Business Hours, After Hours |

---

### 3.4 Confidence Analytics

#### 3.4.1 Average Confidence by Agent

**Query Name:** `[JANA] Confidence - By Agent - Summary`

```sql
-- Confidence metrics per AI agent
SELECT 
    agent_used AS "Agent",
    COUNT(*) AS "Interactions",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    ROUND(MIN(confidence), 3) AS "Min Confidence",
    ROUND(MAX(confidence), 3) AS "Max Confidence",
    ROUND(STDDEV(confidence), 3) AS "Std Dev",
    COUNT(*) FILTER (WHERE confidence >= 0.8) AS "High Confidence (≥0.8)",
    COUNT(*) FILTER (WHERE confidence < 0.5) AS "Low Confidence (<0.5)"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
  AND confidence IS NOT NULL
GROUP BY agent_used
ORDER BY "Avg Confidence" DESC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Table with Sparklines |
| **Conditional Formatting** | Avg < 0.6 → Red, ≥ 0.8 → Green |
| **Mini Chart** | Distribution sparkline per agent |

---

#### 3.4.2 Confidence Trend Over Time

**Query Name:** `[JANA] Confidence - Daily Trend`

```sql
-- Daily average confidence with moving average
SELECT 
    date AS "Date",
    ROUND(AVG(confidence), 3) AS "Daily Avg Confidence",
    ROUND(
        AVG(AVG(confidence)) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
        3
    ) AS "7-Day Moving Avg"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '60 days'
  AND confidence IS NOT NULL
GROUP BY date
ORDER BY date ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Line Chart |
| **Lines** | Daily Avg (thin), 7-Day Moving Avg (thick) |
| **Reference Line** | Target confidence (e.g., 0.75) |
| **Y-Axis Range** | 0 to 1 |

---

#### 3.4.3 Confidence Bucket Distribution

**Query Name:** `[JANA] Confidence - Bucket Distribution`

```sql
-- Confidence distribution by buckets
SELECT 
    confidence_bucket AS "Confidence Range",
    COUNT(*) AS "Interactions",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS "Percentage"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
  AND confidence_bucket IS NOT NULL
GROUP BY confidence_bucket
ORDER BY confidence_bucket;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Histogram / Bar Chart |
| **X-Axis** | Confidence Range |
| **Y-Axis** | Interactions |
| **Colors** | Gradient from red (low) to green (high) |

---

#### 3.4.4 Confidence by Channel

**Query Name:** `[JANA] Confidence - Channel Comparison`

```sql
-- Confidence comparison across channels
SELECT 
    channel AS "Channel",
    agent_used AS "Agent",
    COUNT(*) AS "Interactions",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY confidence), 3) AS "Median"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
  AND confidence IS NOT NULL
GROUP BY channel, agent_used
ORDER BY channel, "Avg Confidence" DESC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Grouped Bar Chart |
| **Groups** | Channel |
| **Bars** | Agent |
| **Values** | Avg Confidence |

---

#### 3.4.5 Low Confidence Alert List

**Query Name:** `[JOPS] Low Confidence - Alert List`

```sql
-- Recent low confidence interactions for review
SELECT 
    session_id AS "Session ID",
    timestamp AS "Time",
    agent_used AS "Agent",
    channel AS "Channel",
    ROUND(confidence, 3) AS "Confidence",
    event_type AS "Event Type",
    escalated AS "Escalated"
FROM analytics_events
WHERE confidence < 0.5
  AND date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY timestamp DESC
LIMIT 100;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Table |
| **Row Link** | Link to session details |
| **Conditional Formatting** | Confidence < 0.3 → Red highlight |
| **Filters** | Agent, Channel, Date Range |

---

### 3.5 Media Analytics

#### 3.5.1 Media Attachment Overview

**Query Name:** `[JANA] Media - Attachment Overview`

```sql
-- Media attachment statistics (JanssenCRM)
SELECT 
    media_type AS "Media Type",
    COUNT(*) AS "Files",
    ROUND(AVG(file_size) / 1024, 2) AS "Avg Size (KB)",
    COUNT(DISTINCT ticket_id) AS "Unique Tickets"
FROM ticket_media
WHERE created_at >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY media_type
ORDER BY "Files" DESC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Pie Chart + Summary Cards |
| **Cards** | Total Files, Unique Tickets, Avg Size |

---

#### 3.5.2 Media by Channel

**Query Name:** `[JANA] Media - By Channel - Weekly`

```sql
-- Media uploads by channel over time
SELECT 
    DATE(tm.created_at) AS "Date",
    t.channel AS "Channel",
    COUNT(*) AS "Media Files"
FROM ticket_media tm
JOIN tickets t ON tm.ticket_id = t.id
WHERE tm.created_at >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY DATE(tm.created_at), t.channel
ORDER BY "Date" ASC;
```

| Property | Recommendation |
|----------|----------------|
| **Chart Type** | Stacked Area Chart |
| **X-Axis** | Date |
| **Y-Axis** | Media Files |
| **Stack By** | Channel |

---

## 4. Dashboard Layouts

### 4.1 Executive Summary Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  [JEXEC] Janssen AI Ops - Executive Summary                     │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   TODAY'S       │   ESCALATION    │   AVG CONFIDENCE            │
│   LEADS: 47     │   RATE: 12.3%   │   0.78                      │
│   ▲ +12%        │   ▼ -2.1%       │   ▲ +0.03                   │
├─────────────────┴─────────────────┴─────────────────────────────┤
│                                                                 │
│   [LINE CHART] Leads vs Complaints - 30 Day Trend               │
│                                                                 │
├─────────────────────────────────┬───────────────────────────────┤
│                                 │                               │
│   [PIE] Channel Distribution    │   [BAR] Agent Performance     │
│                                 │                               │
├─────────────────────────────────┴───────────────────────────────┤
│                                                                 │
│   [HEATMAP] Escalation Heatmap - Hour x Day                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Operations Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  [JOPS] Daily Operations Overview                               │
├────────────┬────────────┬────────────┬────────────┬─────────────┤
│  LEADS     │ COMPLAINTS │ ESCALATIONS│ SESSIONS   │ MEDIA FILES │
│  47        │ 12         │ 8          │ 312        │ 23          │
├────────────┴────────────┴────────────┴────────────┴─────────────┤
│                                                                 │
│   [AREA CHART] Event Volume - Last 24 Hours                     │
│                                                                 │
├─────────────────────────────────┬───────────────────────────────┤
│                                 │                               │
│   [TABLE] Recent Escalations    │   [TABLE] Low Confidence      │
│   (Last 10)                     │   Alerts (Top 10)             │
│                                 │                               │
├─────────────────────────────────┴───────────────────────────────┤
│                                                                 │
│   [BAR] Hourly Distribution - Today                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Refresh & Caching

### Recommended Cache Settings

| Dashboard Type | Cache Duration | Auto-Refresh |
|----------------|----------------|--------------|
| Executive Summary | 1 hour | Every 1 hour |
| Operations | 5 minutes | Every 5 minutes |
| Analytics | 1 hour | Every 1 hour |
| Technical | 1 minute | Every 1 minute |

### Metabase Cache Configuration

```yaml
# Admin > Settings > Caching

# Question-level caching
question_cache_ttl: 3600  # 1 hour default

# Dashboard-level caching
dashboard_cache_ttl: 300  # 5 minutes for operations

# Database-level caching
database_cache_ttl: 60    # 1 minute minimum
```

### Manual Refresh SQL (for Materialized Views)

```sql
-- If using materialized views for heavy queries
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_kpi_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_agent_performance;
```

---

## Appendix A: Quick Reference Card

### KPI Definitions

| KPI | Formula | Target |
|-----|---------|--------|
| **Lead Conversion Proxy** | Leads / Total Events | > 15% |
| **Escalation Rate** | Escalations / Total Events | < 15% |
| **Avg Confidence** | AVG(confidence) | > 0.75 |
| **Complaint Ratio** | Complaints / Leads | < 20% |
| **Media Attachment Rate** | Tickets with Media / Total Tickets | - |

### Color Palette

| Element | Hex Code | Usage |
|---------|----------|-------|
| Leads | `#4CAF50` | Green for positive metrics |
| Complaints | `#F44336` | Red for negative metrics |
| Escalations | `#FF9800` | Orange for warnings |
| Chat | `#2196F3` | Blue for chat channel |
| Voice | `#9C27B0` | Purple for voice channel |
| WhatsApp | `#25D366` | WhatsApp brand green |

---

## Appendix B: Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Permission denied" on query | Verify metabase_readonly has SELECT grants |
| Slow dashboard load | Add indexes, enable caching, use materialized views |
| Missing data | Check n8n workflow is running, verify analytics_events inserts |
| Wrong timezone | Set `SET timezone = 'Africa/Cairo';` in connection |

### Support Contact

For dashboard issues, contact: `ai-ops@janssen.com`

---

*Document maintained by Janssen AI Ops Team*
