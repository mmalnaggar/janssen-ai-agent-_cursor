# Janssen AI - Analytics Dashboard Readiness Guide

> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Database:** PostgreSQL (analytics_events)  
> **SQL File:** `backend/db/dashboard_views.sql`

---

## Table of Contents

1. [Overview](#1-overview)
2. [View Definitions](#2-view-definitions)
   - [2.1 system_health_view](#21-system_health_view)
   - [2.2 sales_kpi_view](#22-sales_kpi_view)
   - [2.3 complaints_kpi_view](#23-complaints_kpi_view)
   - [2.4 escalation_heatmap_view](#24-escalation_heatmap_view)
   - [2.5 ai_quality_view](#25-ai_quality_view)
3. [Dashboard Mapping](#3-dashboard-mapping)
4. [Example Queries](#4-example-queries)
5. [Recommended Charts](#5-recommended-charts)
6. [Refresh Strategy](#6-refresh-strategy)
7. [Performance Optimization](#7-performance-optimization)

---

## 1. Overview

### Purpose

This document describes the SQL views created for analytics dashboard visualization. These views are:

- **Read-Only**: SELECT-only views, no data modification capabilities
- **Pre-Computed**: Leverage existing precomputed fields from `analytics_events`
- **Optimized**: Use existing indexes for fast aggregation
- **Dashboard-Ready**: Column names and types optimized for Metabase/Grafana

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  n8n Workflow                                                           │
│       │                                                                 │
│       ▼                                                                 │
│  Analytics_Event_Mirror ──► analytics_events (table)                    │
│                                    │                                    │
│                                    ▼                                    │
│                           ┌────────────────────┐                        │
│                           │   SQL VIEWS        │                        │
│                           │                    │                        │
│                           │ • system_health    │                        │
│                           │ • sales_kpi        │                        │
│                           │ • complaints_kpi   │                        │
│                           │ • escalation_heat  │                        │
│                           │ • ai_quality       │                        │
│                           └────────────────────┘                        │
│                                    │                                    │
│                                    ▼                                    │
│                     ┌──────────────────────────────┐                    │
│                     │   DASHBOARD TOOLS            │                    │
│                     │   • Metabase                 │                    │
│                     │   • Grafana                  │                    │
│                     │   • Custom BI                │                    │
│                     └──────────────────────────────┘                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Pre-Computed Fields Used

| Field | Description | Usage |
|-------|-------------|-------|
| `date` | YYYY-MM-DD | Daily aggregation |
| `hour` | 0-23 | Hourly patterns |
| `day_of_week` | 0-6 (Sun-Sat) | Weekly patterns |
| `confidence_bucket` | very_high/high/medium/low/very_low | AI quality buckets |
| `urgency_score` | 0-100 | Priority scoring |
| `is_business_hours` | Boolean | Business vs after-hours |
| `agg_key_daily` | date_agent | Fast GROUP BY |
| `agg_key_channel` | date_channel | Fast GROUP BY |

---

## 2. View Definitions

### 2.1 system_health_view

**Purpose:** Real-time system health monitoring for operations dashboard

**Dashboard Usage:**
- `[JTECH] System Health Dashboard`
- Executive Summary KPI Cards

**Key Metrics:**

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `events_today` | Total events today | N/A |
| `escalation_rate_today` | % escalations | > 20% = Warning |
| `avg_confidence_today` | AI confidence | < 0.6 = Warning |
| `system_status` | Health status | CRITICAL/WARNING/HEALTHY |

**Recommended Charts:**

| Chart Type | Metric(s) | Notes |
|------------|-----------|-------|
| KPI Cards | events_today, leads_today | Show with delta vs yesterday |
| Gauge | escalation_rate_today | Red > 20%, Yellow > 15% |
| Status Indicator | system_status | Color-coded health |
| Comparison Bar | *_today vs *_yesterday | Side-by-side comparison |

**Refresh Strategy:** Real-time or 1-minute cache

---

### 2.2 sales_kpi_view

**Purpose:** Daily sales lead tracking and conversion metrics

**Dashboard Usage:**
- `[JOPS] Leads Pipeline`
- `[JANA] Channel Performance`
- `[JEXEC] Weekly KPI Report`

**Key Metrics:**

| Metric | Description | Target |
|--------|-------------|--------|
| `leads` | Lead count per day | > 50/day |
| `lead_rate_percent` | Leads / Total events | > 15% |
| `avg_lead_confidence` | AI confidence on leads | > 0.75 |
| `lead_to_complaint_ratio` | Leads / Complaints | > 5:1 |

**Recommended Charts:**

| Chart Type | Metric(s) | Notes |
|------------|-----------|-------|
| Line Chart | leads over time | With 7-day moving average |
| Stacked Bar | leads_chat, leads_voice, leads_whatsapp | Channel breakdown |
| Combo Chart | leads + lead_rate_percent | Bars + Line |
| Pie/Donut | Channel distribution | For snapshots |
| Table | All metrics | With conditional formatting |

**Refresh Strategy:** 5-minute cache (operations), 1-hour cache (analytics)

---

### 2.3 complaints_kpi_view

**Purpose:** Complaint tracking, categorization, and resolution monitoring

**Dashboard Usage:**
- `[JOPS] Complaints Monitor`
- `[JANA] Complaints Analytics`
- `[JOPS] Daily Operations Overview`

**Key Metrics:**

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `complaints` | Complaint count per day | > 20/day = Review |
| `complaint_rate_percent` | Complaints / Total events | > 10% = Warning |
| `avg_complaint_urgency` | Average urgency score | > 60 = Alert |
| `complaint_escalation_rate` | % complaints escalated | > 30% = Warning |
| `critical_complaints` | Urgency >= 80 | Any = Immediate action |

**Recommended Charts:**

| Chart Type | Metric(s) | Notes |
|------------|-----------|-------|
| Area Chart | complaints over time | Show trend |
| Stacked Bar | complaints by channel | Identify problem channels |
| Gauge | complaint_escalation_rate | Red > 30% |
| Table | critical_complaints | With drill-down |
| Dual Axis Line | complaints + avg_urgency | Correlation view |

**Refresh Strategy:** 5-minute cache (operations)

---

### 2.4 escalation_heatmap_view

**Purpose:** Time-based escalation patterns for staffing optimization

**Dashboard Usage:**
- `[JANA] Escalation Tracker`
- `[JOPS] Daily Operations Overview`
- `[JEXEC] Executive Summary`

**Key Metrics:**

| Metric | Description | Usage |
|--------|-------------|-------|
| `day_of_week` + `hour` | Time coordinates | Heatmap axes |
| `escalation_count` | Escalations per cell | Heatmap value |
| `escalation_rate_percent` | % escalated | Alternative value |
| `avg_confidence_before_escalation` | AI confidence | Quality indicator |

**Recommended Charts:**

| Chart Type | Metric(s) | Notes |
|------------|-----------|-------|
| **Heatmap** | escalation_count | Primary view |
| Pivot Table | day_name x hour | With values |
| Grouped Bar | escalation_count by hour | Single day analysis |
| Donut | Business hours vs After hours | Distribution |

**Heatmap Configuration:**

```
        │ 09 │ 10 │ 11 │ 12 │ 13 │ 14 │ 15 │ 16 │ 17 │
────────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
Sunday  │  2 │  4 │  5 │  8 │  6 │  7 │  5 │  4 │  3 │
Monday  │  5 │  8 │ 12 │ 15 │ 11 │ 13 │ 10 │  7 │  5 │
Tuesday │  4 │  7 │ 10 │ 12 │  9 │ 11 │  8 │  6 │  4 │
...
────────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
Color Scale: Green (low) → Yellow → Red (high)
```

**Refresh Strategy:** 1-hour cache (patterns don't change rapidly)

---

### 2.5 ai_quality_view

**Purpose:** AI confidence and performance metrics by channel and agent

**Dashboard Usage:**
- `[JANA] Confidence Analysis`
- `[JTECH] AI Performance`
- `[JANA] Channel Performance`

**Key Metrics:**

| Metric | Description | Target |
|--------|-------------|--------|
| `avg_confidence` | Average AI confidence | > 0.75 |
| `high_confidence_percent` | % with confidence >= 0.8 | > 60% |
| `low_confidence_percent` | % with confidence < 0.5 | < 10% |
| `ai_quality_score` | Composite score (0-100) | > 75 |
| `escalation_rate_percent` | % escalated per segment | < 15% |

**AI Quality Score Formula:**

```
ai_quality_score = 
    (avg_confidence * 40) +
    ((1 - escalation_rate) * 30) +
    (high_confidence_percent * 30)
```

**Recommended Charts:**

| Chart Type | Metric(s) | Notes |
|------------|-----------|-------|
| Grouped Bar | avg_confidence by channel | Compare channels |
| Box Plot | confidence distribution | Statistical view |
| Line Chart | avg_confidence over time | With 7-day MA |
| Table | All metrics by agent | Performance comparison |
| Histogram | confidence_bucket distribution | Quality distribution |
| Gauge | ai_quality_score | Composite health |

**Refresh Strategy:** 1-hour cache (analytics dashboards)

---

## 3. Dashboard Mapping

### View to Dashboard Mapping

| View | Primary Dashboard | Secondary Dashboards |
|------|-------------------|---------------------|
| `system_health_view` | [JTECH] System Health | [JEXEC] Executive Summary |
| `sales_kpi_view` | [JOPS] Leads Pipeline | [JANA] Channel Performance |
| `complaints_kpi_view` | [JOPS] Complaints Monitor | [JOPS] Daily Operations |
| `escalation_heatmap_view` | [JANA] Escalation Tracker | [JOPS] Daily Operations |
| `ai_quality_view` | [JANA] Confidence Analysis | [JTECH] AI Performance |

### Dashboard Collection Structure

```
Janssen AI Ops/
├── 📊 [JEXEC] Executive Summary
│   └── Uses: system_health_view, daily_summary_view
│
├── 📈 Operations/
│   ├── [JOPS] Daily Operations Overview
│   │   └── Uses: system_health_view, complaints_kpi_view, escalation_heatmap_view
│   ├── [JOPS] Leads Pipeline
│   │   └── Uses: sales_kpi_view
│   └── [JOPS] Complaints Monitor
│       └── Uses: complaints_kpi_view
│
├── 📉 Analytics/
│   ├── [JANA] Confidence Analysis
│   │   └── Uses: ai_quality_view
│   ├── [JANA] Channel Performance
│   │   └── Uses: ai_quality_view, sales_kpi_view
│   └── [JANA] Escalation Tracker
│       └── Uses: escalation_heatmap_view
│
└── 🔧 Technical/
    ├── [JTECH] System Health
    │   └── Uses: system_health_view
    └── [JTECH] AI Performance
        └── Uses: ai_quality_view
```

---

## 4. Example Queries

### 4.1 Leads Per Day

```sql
-- Basic leads per day with 7-day moving average
SELECT 
    date,
    leads,
    lead_rate_percent,
    AVG(leads) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS leads_7d_avg
FROM sales_kpi_view
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date;
```

**Use Case:** Line chart showing lead trends with smoothing

---

### 4.2 Escalation Rate Trend

```sql
-- Daily escalation rate from complaints view
SELECT 
    date,
    complaints,
    escalated_complaints,
    complaint_escalation_rate
FROM complaints_kpi_view
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date;
```

**Use Case:** Track escalation trends, identify spikes

---

### 4.3 Channel Confidence Comparison

```sql
-- Compare AI confidence across channels
SELECT 
    channel,
    ROUND(AVG(avg_confidence), 3) AS overall_avg_confidence,
    SUM(total_events) AS total_interactions,
    ROUND(AVG(escalation_rate_percent), 2) AS avg_escalation_rate
FROM ai_quality_view
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY channel
ORDER BY overall_avg_confidence DESC;
```

**Use Case:** Grouped bar chart, identify weak channels

---

### 4.4 Urgency Distribution

```sql
-- Urgency level breakdown
SELECT 
    urgency_level,
    SUM(event_count) AS total_events,
    ROUND(SUM(event_count) * 100.0 / SUM(SUM(event_count)) OVER (), 2) AS percentage
FROM urgency_distribution_view
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY urgency_level, urgency_order
ORDER BY urgency_order;
```

**Use Case:** Pie chart showing priority distribution

---

### 4.5 Heatmap Data

```sql
-- Escalation heatmap for staffing
SELECT 
    day_name,
    hour,
    escalation_count,
    escalation_rate_percent
FROM escalation_heatmap_view
WHERE escalation_count > 0
ORDER BY day_of_week, hour;
```

**Use Case:** Heatmap visualization for staffing optimization

---

### 4.6 System Status Check

```sql
-- Quick system health check
SELECT 
    snapshot_time,
    events_today,
    leads_today,
    escalation_rate_today,
    avg_confidence_today,
    system_status
FROM system_health_view;
```

**Use Case:** KPI cards and status indicators

---

## 5. Recommended Charts

### Chart Type Reference

| KPI | Recommended Chart | X-Axis | Y-Axis | Color |
|-----|-------------------|--------|--------|-------|
| Leads per day | Line Chart | Date | Lead Count | `#4CAF50` |
| Leads by channel | Stacked Bar | Date | Count | Channel colors |
| Complaint trend | Area Chart | Date | Count | `#F44336` |
| Escalation rate | Line + Goal | Date | % | Red/Green |
| Escalation heatmap | Heatmap | Hour | Day | Green→Red |
| Confidence by agent | Grouped Bar | Agent | Confidence | Channel colors |
| Urgency distribution | Pie/Donut | Level | Count | Priority colors |
| System status | Gauge/Card | N/A | Value | Status colors |

### Color Palette

| Element | Hex Code | Usage |
|---------|----------|-------|
| Leads/Positive | `#4CAF50` | Green |
| Complaints/Negative | `#F44336` | Red |
| Escalations/Warning | `#FF9800` | Orange |
| Chat Channel | `#2196F3` | Blue |
| Voice Channel | `#9C27B0` | Purple |
| WhatsApp Channel | `#25D366` | WhatsApp Green |
| High Confidence | `#4CAF50` | Green |
| Low Confidence | `#F44336` | Red |

---

## 6. Refresh Strategy

### Cache Configuration

| View | Cache Duration | Auto-Refresh | Rationale |
|------|----------------|--------------|-----------|
| `system_health_view` | 1 minute | Every 1 min | Real-time monitoring |
| `sales_kpi_view` | 5 minutes | Every 5 min | Operational tracking |
| `complaints_kpi_view` | 5 minutes | Every 5 min | Operational tracking |
| `escalation_heatmap_view` | 1 hour | Every 1 hour | Patterns are stable |
| `ai_quality_view` | 1 hour | Every 1 hour | Analytics review |
| `daily_summary_view` | 1 hour | Every 1 hour | Trend analysis |

### Metabase Configuration

```yaml
# Per-Question Settings
[JOPS] queries: cache_ttl: 300    # 5 minutes
[JANA] queries: cache_ttl: 3600   # 1 hour
[JTECH] queries: cache_ttl: 60    # 1 minute
[JEXEC] queries: cache_ttl: 3600  # 1 hour
```

### Grafana Configuration

```yaml
# Dashboard Settings
[JTECH] System Health:
  refresh: 1m
  
[JOPS] Operations:
  refresh: 5m
  
[JANA] Analytics:
  refresh: 1h
```

---

## 7. Performance Optimization

### Index Utilization

All views are designed to leverage existing indexes:

| View | Primary Indexes Used |
|------|---------------------|
| `system_health_view` | `idx_analytics_date`, `idx_analytics_timestamp` |
| `sales_kpi_view` | `idx_analytics_date_event_type`, `idx_analytics_leads_only` |
| `complaints_kpi_view` | `idx_analytics_date_event_type`, `idx_analytics_complaints_only` |
| `escalation_heatmap_view` | `idx_analytics_escalation_heatmap`, `idx_analytics_escalations_only` |
| `ai_quality_view` | `idx_analytics_channel_confidence`, `idx_analytics_date_agent` |

### Query Performance Tips

1. **Date Range Filters**: Always filter by date range first
   ```sql
   WHERE date >= CURRENT_DATE - INTERVAL '30 days'
   ```

2. **Avoid SELECT ***: Only select needed columns
   ```sql
   SELECT date, leads, lead_rate_percent  -- Good
   SELECT *  -- Avoid in production
   ```

3. **Use Materialized Views**: For heavy aggregations, consider:
   ```sql
   -- Already exists in analytics_schema.sql
   REFRESH MATERIALIZED VIEW mv_analytics_daily;
   ```

4. **Pre-aggregated Keys**: Use `agg_key_*` columns when possible
   ```sql
   GROUP BY agg_key_daily  -- Faster than GROUP BY date, agent_used
   ```

### Monitoring Query Performance

```sql
-- Check slow queries
SELECT 
    query,
    calls,
    mean_time,
    total_time
FROM pg_stat_statements
WHERE query LIKE '%analytics_events%'
ORDER BY mean_time DESC
LIMIT 10;
```

---

## Appendix A: Quick Reference

### KPI Definitions

| KPI | Formula | Target | View |
|-----|---------|--------|------|
| Lead Rate | leads / total_events | > 15% | sales_kpi_view |
| Escalation Rate | escalations / total_events | < 15% | complaints_kpi_view |
| Avg Confidence | AVG(confidence) | > 0.75 | ai_quality_view |
| Complaint Ratio | complaints / leads | < 20% | daily_summary_view |
| AI Quality Score | Composite formula | > 75 | ai_quality_view |

### Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Escalation Rate | > 15% | > 25% |
| Avg Confidence | < 0.70 | < 0.50 |
| Complaint Rate | > 8% | > 15% |
| System Status | WARNING | CRITICAL |

---

## Appendix B: Database Grants

```sql
-- Read-only access for dashboard tools
GRANT SELECT ON system_health_view TO metabase_readonly;
GRANT SELECT ON sales_kpi_view TO metabase_readonly;
GRANT SELECT ON complaints_kpi_view TO metabase_readonly;
GRANT SELECT ON escalation_heatmap_view TO metabase_readonly;
GRANT SELECT ON ai_quality_view TO metabase_readonly;
GRANT SELECT ON daily_summary_view TO metabase_readonly;
GRANT SELECT ON urgency_distribution_view TO metabase_readonly;
```

---

## Appendix C: Troubleshooting

| Issue | Solution |
|-------|----------|
| View returns no data | Check date range, verify analytics_events has data |
| Slow query performance | Check indexes, reduce date range, use materialized view |
| Permission denied | Verify metabase_readonly has SELECT grants |
| Missing columns | Re-run dashboard_views.sql to update views |
| Stale data | Refresh Metabase cache or reduce cache TTL |

---

*Document maintained by Janssen AI Ops Team*  
*SQL Views: `backend/db/dashboard_views.sql`*
