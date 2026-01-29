# Janssen AI Ops - Executive Dashboard

> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Audience:** CEO, C-Suite, Senior Leadership  
> **Refresh Rate:** Every 1 hour (configurable)

---

## Table of Contents

1. [Dashboard Overview](#1-dashboard-overview)
2. [Core KPIs](#2-core-kpis)
3. [Leads vs Complaints Trend](#3-leads-vs-complaints-trend)
4. [Escalation Heatmap](#4-escalation-heatmap)
5. [Channel Performance Comparison](#5-channel-performance-comparison)
6. [AI Health Index](#6-ai-health-index)
7. [Dashboard Layout](#7-dashboard-layout)
8. [Implementation Guide](#8-implementation-guide)

---

## 1. Dashboard Overview

### Purpose

The Executive Dashboard provides a **single-pane-of-glass** view of Janssen AI's operational health and business impact. Designed for C-level executives who need to:

- Monitor AI effectiveness at a glance
- Identify trends requiring attention
- Make data-driven staffing and investment decisions
- Track customer experience quality

### Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Simplicity** | Maximum 6 widgets visible at once |
| **Actionability** | Every metric links to recommended action |
| **Comparability** | Show trends vs targets and historical data |
| **Accessibility** | Color-blind friendly, mobile responsive |

### Data Freshness

| Metric Type | Update Frequency |
|-------------|------------------|
| Summary Cards | Every 1 hour |
| Trend Charts | Every 1 hour |
| Heatmaps | Every 4 hours |
| AI Health Index | Every 1 hour |

---

## 2. Core KPIs

### 2.1 AI Resolution Rate

**Definition:** Percentage of customer interactions successfully handled by AI without human escalation.

**Business Impact:** Higher resolution rate = lower operational cost + faster customer service.

**Query Name:** `[JEXEC] KPI - AI Resolution Rate`

```sql
-- AI Resolution Rate (Last 30 Days vs Previous 30 Days)
WITH current_period AS (
    SELECT 
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
),
previous_period AS (
    SELECT 
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '60 days'
      AND date < CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    ROUND(100.0 * c.resolved / NULLIF(c.total, 0), 1) AS "Resolution Rate %",
    c.total AS "Total Interactions",
    c.resolved AS "Resolved by AI",
    ROUND(100.0 * p.resolved / NULLIF(p.total, 0), 1) AS "Previous Period %",
    ROUND(
        100.0 * c.resolved / NULLIF(c.total, 0) - 
        100.0 * p.resolved / NULLIF(p.total, 0),
        1
    ) AS "Change %"
FROM current_period c, previous_period p;
```

| Widget | **Big Number Card** |
|--------|---------------------|
| Primary Value | Resolution Rate % |
| Subtitle | "vs X% last period" |
| Trend Arrow | ▲ Green if improved, ▼ Red if declined |
| Target | 85% |
| Color | Green ≥85%, Yellow 70-84%, Red <70% |

---

### 2.2 Escalation Rate

**Definition:** Percentage of interactions requiring human agent intervention.

**Business Impact:** Lower escalation = better AI training + reduced staffing needs.

**Query Name:** `[JEXEC] KPI - Escalation Rate`

```sql
-- Escalation Rate with Trend
WITH daily_rates AS (
    SELECT 
        date,
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) AS rate
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY date
)
SELECT 
    ROUND(AVG(rate), 1) AS "Avg Escalation Rate %",
    SUM(escalations) AS "Total Escalations",
    SUM(total) AS "Total Interactions",
    ROUND(MIN(rate), 1) AS "Best Day %",
    ROUND(MAX(rate), 1) AS "Worst Day %",
    ROUND(
        (LAST_VALUE(rate) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) -
         FIRST_VALUE(rate) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)),
        1
    ) AS "30-Day Trend"
FROM daily_rates;
```

| Widget | **Big Number Card with Sparkline** |
|--------|-------------------------------------|
| Primary Value | Escalation Rate % |
| Sparkline | 30-day trend (mini line chart) |
| Target | ≤15% |
| Color | Green ≤15%, Yellow 15-25%, Red >25% |

---

### 2.3 Lead Rate

**Definition:** Percentage of interactions resulting in a qualified sales lead.

**Business Impact:** Direct revenue indicator from AI interactions.

**Query Name:** `[JEXEC] KPI - Lead Conversion Rate`

```sql
-- Lead Conversion Rate
SELECT 
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads Generated",
    COUNT(*) AS "Total Interactions",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0),
        2
    ) AS "Lead Rate %",
    
    -- By Channel Breakdown
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED' AND channel = 'chat') / 
          NULLIF(COUNT(*) FILTER (WHERE channel = 'chat'), 0), 2) AS "Chat Lead Rate %",
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED' AND channel = 'voice') / 
          NULLIF(COUNT(*) FILTER (WHERE channel = 'voice'), 0), 2) AS "Voice Lead Rate %",
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED' AND channel = 'whatsapp') / 
          NULLIF(COUNT(*) FILTER (WHERE channel = 'whatsapp'), 0), 2) AS "WhatsApp Lead Rate %"
          
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days';
```

| Widget | **Big Number Card with Breakdown** |
|--------|-------------------------------------|
| Primary Value | Leads Generated (count) |
| Secondary | Lead Rate % |
| Mini Chart | Channel breakdown (small pie) |
| Target | ≥10% |
| Color | Green ≥10%, Yellow 5-9%, Red <5% |

---

### 2.4 Complaint Ratio

**Definition:** Ratio of complaints to total positive outcomes (leads).

**Business Impact:** Customer satisfaction indicator; high ratio signals product/service issues.

**Query Name:** `[JEXEC] KPI - Complaint to Lead Ratio`

```sql
-- Complaint to Lead Ratio
SELECT 
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS "Complaints",
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
        NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
        1
    ) AS "Complaint Ratio %",
    
    -- Trend indicator
    CASE 
        WHEN COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') * 1.0 / 
             NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0) > 0.3 
        THEN 'HIGH - Action Required'
        WHEN COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') * 1.0 / 
             NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0) > 0.15 
        THEN 'MODERATE - Monitor'
        ELSE 'HEALTHY'
    END AS "Status"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days';
```

| Widget | **Big Number Card with Status** |
|--------|----------------------------------|
| Primary Value | Complaint Ratio % |
| Status Badge | HEALTHY / MODERATE / HIGH |
| Target | ≤15% |
| Color | Green ≤15%, Yellow 15-30%, Red >30% |

---

### 2.5 Combined KPI Summary Query

**Query Name:** `[JEXEC] All Core KPIs - Summary`

```sql
-- Executive Summary: All 4 Core KPIs in One Query
SELECT 
    -- Resolution Rate
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 1) 
        AS "AI Resolution Rate %",
    
    -- Escalation Rate
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 1) 
        AS "Escalation Rate %",
    
    -- Lead Rate
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) 
        AS "Lead Rate %",
    
    -- Complaint Ratio
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
        NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
        1
    ) AS "Complaint Ratio %",
    
    -- Totals
    COUNT(*) AS "Total Interactions",
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads",
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS "Complaints",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days';
```

---

## 3. Leads vs Complaints Trend

### 3.1 7-Day Trend Chart

**Query Name:** `[JEXEC] Trend - Leads vs Complaints (7 Days)`

```sql
-- Leads vs Complaints: Last 7 Days
SELECT 
    date AS "Date",
    TO_CHAR(date, 'Dy, Mon DD') AS "Day",
    
    -- Counts
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads",
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS "Complaints",
    COUNT(*) AS "Total Interactions",
    
    -- Rates
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) 
        AS "Lead Rate %",
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / NULLIF(COUNT(*), 0), 2) 
        AS "Complaint Rate %",
    
    -- Ratio
    ROUND(
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED')::NUMERIC / 
        NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
        2
    ) AS "Complaint:Lead Ratio"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date ASC;
```

| Widget | **Dual-Axis Line Chart** |
|--------|---------------------------|
| X-Axis | Date (last 7 days) |
| Left Y-Axis | Count (Leads, Complaints) |
| Right Y-Axis | Ratio |
| Lines | Leads (Green), Complaints (Red), Ratio (Gray dashed) |
| Size | Large (full width) |
| Interactions | Hover for daily details |

---

### 3.2 Week-over-Week Comparison

**Query Name:** `[JEXEC] Trend - Week over Week`

```sql
-- Week-over-Week Comparison
WITH this_week AS (
    SELECT 
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        COUNT(*) AS total
    FROM analytics_events
    WHERE date >= DATE_TRUNC('week', CURRENT_DATE)
),
last_week AS (
    SELECT 
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        COUNT(*) AS total
    FROM analytics_events
    WHERE date >= DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '7 days'
      AND date < DATE_TRUNC('week', CURRENT_DATE)
)
SELECT 
    tw.leads AS "This Week Leads",
    lw.leads AS "Last Week Leads",
    ROUND(100.0 * (tw.leads - lw.leads) / NULLIF(lw.leads, 0), 1) AS "Leads Change %",
    
    tw.complaints AS "This Week Complaints",
    lw.complaints AS "Last Week Complaints",
    ROUND(100.0 * (tw.complaints - lw.complaints) / NULLIF(lw.complaints, 0), 1) AS "Complaints Change %",
    
    CASE 
        WHEN tw.leads > lw.leads AND tw.complaints <= lw.complaints THEN '✅ Improving'
        WHEN tw.leads < lw.leads AND tw.complaints > lw.complaints THEN '⚠️ Declining'
        ELSE '➡️ Mixed'
    END AS "Overall Trend"
FROM this_week tw, last_week lw;
```

| Widget | **Comparison Cards** |
|--------|----------------------|
| Layout | Side-by-side: This Week | Last Week |
| Metrics | Leads, Complaints, Change % |
| Trend Indicator | Arrow + percentage |
| Size | Medium (1/2 width) |

---

## 4. Escalation Heatmap

### 4.1 Hour × Day Heatmap

**Query Name:** `[JEXEC] Heatmap - Escalations by Hour and Day`

```sql
-- Escalation Heatmap: Hour × Day of Week
SELECT 
    CASE day_of_week
        WHEN 0 THEN '7-Sun'
        WHEN 1 THEN '1-Mon'
        WHEN 2 THEN '2-Tue'
        WHEN 3 THEN '3-Wed'
        WHEN 4 THEN '4-Thu'
        WHEN 5 THEN '5-Fri'
        WHEN 6 THEN '6-Sat'
    END AS "Day",
    hour AS "Hour",
    COUNT(*) AS "Total",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        1
    ) AS "Escalation Rate %"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY day_of_week, hour
ORDER BY day_of_week, hour;
```

| Widget | **Heatmap** |
|--------|-------------|
| Rows | Day of Week (Mon-Sun) |
| Columns | Hour (0-23, or 6AM-10PM for readability) |
| Values | Escalation Rate % |
| Color Scale | Green (0-10%) → Yellow (10-20%) → Red (20%+) |
| Size | Large (full width) |
| Tooltip | "Monday 2PM: 18% escalation rate (45 of 250 calls)" |

---

### 4.2 Simplified Pivot Table

**Query Name:** `[JEXEC] Heatmap - Pivoted View`

```sql
-- Pivoted Escalation Rates (Business Hours Focus: 8AM-8PM)
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
    
    -- Morning (8AM-12PM)
    ROUND(100.0 * COUNT(*) FILTER (WHERE hour BETWEEN 8 AND 11 AND escalated) / 
          NULLIF(COUNT(*) FILTER (WHERE hour BETWEEN 8 AND 11), 0), 1) AS "Morning %",
    
    -- Afternoon (12PM-5PM)
    ROUND(100.0 * COUNT(*) FILTER (WHERE hour BETWEEN 12 AND 16 AND escalated) / 
          NULLIF(COUNT(*) FILTER (WHERE hour BETWEEN 12 AND 16), 0), 1) AS "Afternoon %",
    
    -- Evening (5PM-8PM)
    ROUND(100.0 * COUNT(*) FILTER (WHERE hour BETWEEN 17 AND 20 AND escalated) / 
          NULLIF(COUNT(*) FILTER (WHERE hour BETWEEN 17 AND 20), 0), 1) AS "Evening %",
    
    -- Daily Average
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated) / NULLIF(COUNT(*), 0), 1) AS "Daily Avg %"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY day_of_week
ORDER BY day_of_week;
```

| Widget | **Table with Conditional Formatting** |
|--------|----------------------------------------|
| Columns | Day, Morning %, Afternoon %, Evening %, Daily Avg % |
| Cell Colors | Green ≤15%, Yellow 15-25%, Red >25% |
| Highlight | Worst time slot per day |
| Size | Medium (1/2 width) |

---

## 5. Channel Performance Comparison

### 5.1 Channel Overview

**Query Name:** `[JEXEC] Channels - Performance Comparison`

```sql
-- Channel Performance Comparison
SELECT 
    INITCAP(channel) AS "Channel",
    COUNT(*) AS "Interactions",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS "Volume Share %",
    
    -- Core Metrics
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 1) 
        AS "Resolution Rate %",
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 1) 
        AS "Escalation Rate %",
    ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) 
        AS "Lead Rate %",
    
    -- Quality Metrics
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    ROUND(100.0 * COUNT(*) FILTER (WHERE confidence >= 0.8) / NULLIF(COUNT(*), 0), 1) 
        AS "High Confidence %"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY channel
ORDER BY "Interactions" DESC;
```

| Widget | **Grouped Bar Chart + Table** |
|--------|-------------------------------|
| Chart Type | Grouped horizontal bars |
| Metrics | Resolution %, Lead %, Escalation % |
| Groups | Chat, Voice, WhatsApp |
| Colors | Chat: `#2196F3`, Voice: `#9C27B0`, WhatsApp: `#25D366` |
| Size | Large (full width) |

---

### 5.2 Channel Trend (7 Days)

**Query Name:** `[JEXEC] Channels - 7 Day Volume Trend`

```sql
-- Channel Volume Trend: Last 7 Days
SELECT 
    date AS "Date",
    COUNT(*) FILTER (WHERE channel = 'chat') AS "Chat",
    COUNT(*) FILTER (WHERE channel = 'voice') AS "Voice",
    COUNT(*) FILTER (WHERE channel = 'whatsapp') AS "WhatsApp",
    COUNT(*) AS "Total"
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date ASC;
```

| Widget | **Stacked Area Chart** |
|--------|-------------------------|
| X-Axis | Date |
| Y-Axis | Interaction Count |
| Stack | Chat, Voice, WhatsApp |
| Colors | Chat: `#2196F3`, Voice: `#9C27B0`, WhatsApp: `#25D366` |
| Size | Medium (1/2 width) |

---

### 5.3 Best/Worst Channel Indicators

**Query Name:** `[JEXEC] Channels - Best & Worst Performers`

```sql
-- Channel Performance Ranking
WITH channel_metrics AS (
    SELECT 
        channel,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 1) AS resolution_rate,
        ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) AS lead_rate,
        ROUND(AVG(confidence), 3) AS avg_confidence
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY channel
)
SELECT 
    'Best Resolution' AS "Metric",
    (SELECT INITCAP(channel) FROM channel_metrics ORDER BY resolution_rate DESC LIMIT 1) AS "Channel",
    (SELECT resolution_rate FROM channel_metrics ORDER BY resolution_rate DESC LIMIT 1)::TEXT || '%' AS "Value"
UNION ALL
SELECT 
    'Best Lead Rate',
    (SELECT INITCAP(channel) FROM channel_metrics ORDER BY lead_rate DESC LIMIT 1),
    (SELECT lead_rate FROM channel_metrics ORDER BY lead_rate DESC LIMIT 1)::TEXT || '%'
UNION ALL
SELECT 
    'Highest Confidence',
    (SELECT INITCAP(channel) FROM channel_metrics ORDER BY avg_confidence DESC LIMIT 1),
    (SELECT avg_confidence FROM channel_metrics ORDER BY avg_confidence DESC LIMIT 1)::TEXT
UNION ALL
SELECT 
    'Needs Attention',
    (SELECT INITCAP(channel) FROM channel_metrics ORDER BY resolution_rate ASC LIMIT 1),
    (SELECT resolution_rate FROM channel_metrics ORDER BY resolution_rate ASC LIMIT 1)::TEXT || '% resolution';
```

| Widget | **Status Cards** |
|--------|------------------|
| Layout | 4 small cards in a row |
| Content | Best Resolution, Best Lead Rate, Highest Confidence, Needs Attention |
| Icons | Trophy, Target, Star, Warning |
| Size | Small (1/4 width each) |

---

## 6. AI Health Index

### 6.1 Formula Definition

The **AI Health Index** is a composite score (0-100) that provides a single metric for overall AI system performance.

#### Formula

```
AI Health Index = (
    (Resolution Rate × 0.35) +
    ((100 - Escalation Rate) × 0.25) +
    (Lead Rate × 10 × 0.20) +
    ((100 - Complaint Ratio) × 0.10) +
    (Avg Confidence × 100 × 0.10)
)
```

#### Component Weights

| Component | Weight | Rationale |
|-----------|--------|-----------|
| Resolution Rate | 35% | Primary indicator of AI effectiveness |
| Inverse Escalation Rate | 25% | Operational efficiency |
| Lead Rate (×10) | 20% | Business value generation |
| Inverse Complaint Ratio | 10% | Customer satisfaction |
| Avg Confidence (×100) | 10% | AI model quality |

#### Score Interpretation

| Score Range | Status | Color | Action |
|-------------|--------|-------|--------|
| 90-100 | Excellent | 🟢 Green | Maintain & optimize |
| 75-89 | Good | 🟢 Light Green | Minor improvements |
| 60-74 | Fair | 🟡 Yellow | Review & enhance |
| 40-59 | Poor | 🟠 Orange | Urgent attention needed |
| 0-39 | Critical | 🔴 Red | Immediate intervention |

---

### 6.2 AI Health Index Query

**Query Name:** `[JEXEC] AI Health Index - Current`

```sql
-- AI Health Index Calculation
WITH metrics AS (
    SELECT 
        -- Resolution Rate (0-100)
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) 
            AS resolution_rate,
        
        -- Escalation Rate (0-100)
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) 
            AS escalation_rate,
        
        -- Lead Rate (typically 5-20%, multiply by 10 to normalize)
        ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) 
            AS lead_rate,
        
        -- Complaint Ratio (complaints per 100 leads)
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
            NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
            2
        ) AS complaint_ratio,
        
        -- Avg Confidence (0-1, multiply by 100)
        ROUND(AVG(confidence), 4) AS avg_confidence,
        
        -- Totals for reference
        COUNT(*) AS total_interactions
        
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    -- Component Scores
    resolution_rate AS "Resolution Rate %",
    escalation_rate AS "Escalation Rate %",
    lead_rate AS "Lead Rate %",
    COALESCE(complaint_ratio, 0) AS "Complaint Ratio %",
    ROUND(avg_confidence * 100, 1) AS "Confidence %",
    
    -- AI Health Index Calculation
    ROUND(
        (resolution_rate * 0.35) +
        ((100 - escalation_rate) * 0.25) +
        (LEAST(lead_rate * 10, 100) * 0.20) +  -- Cap at 100
        (GREATEST(100 - COALESCE(complaint_ratio, 0), 0) * 0.10) +  -- Floor at 0
        (avg_confidence * 100 * 0.10),
        1
    ) AS "AI Health Index",
    
    -- Status
    CASE 
        WHEN (
            (resolution_rate * 0.35) +
            ((100 - escalation_rate) * 0.25) +
            (LEAST(lead_rate * 10, 100) * 0.20) +
            (GREATEST(100 - COALESCE(complaint_ratio, 0), 0) * 0.10) +
            (avg_confidence * 100 * 0.10)
        ) >= 90 THEN 'EXCELLENT'
        WHEN (
            (resolution_rate * 0.35) +
            ((100 - escalation_rate) * 0.25) +
            (LEAST(lead_rate * 10, 100) * 0.20) +
            (GREATEST(100 - COALESCE(complaint_ratio, 0), 0) * 0.10) +
            (avg_confidence * 100 * 0.10)
        ) >= 75 THEN 'GOOD'
        WHEN (
            (resolution_rate * 0.35) +
            ((100 - escalation_rate) * 0.25) +
            (LEAST(lead_rate * 10, 100) * 0.20) +
            (GREATEST(100 - COALESCE(complaint_ratio, 0), 0) * 0.10) +
            (avg_confidence * 100 * 0.10)
        ) >= 60 THEN 'FAIR'
        WHEN (
            (resolution_rate * 0.35) +
            ((100 - escalation_rate) * 0.25) +
            (LEAST(lead_rate * 10, 100) * 0.20) +
            (GREATEST(100 - COALESCE(complaint_ratio, 0), 0) * 0.10) +
            (avg_confidence * 100 * 0.10)
        ) >= 40 THEN 'POOR'
        ELSE 'CRITICAL'
    END AS "Status",
    
    total_interactions AS "Sample Size"
    
FROM metrics;
```

---

### 6.3 AI Health Index Trend

**Query Name:** `[JEXEC] AI Health Index - 30 Day Trend`

```sql
-- AI Health Index: Daily Trend (Last 30 Days)
SELECT 
    date AS "Date",
    
    -- Calculate daily health index
    ROUND(
        (ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) * 0.35) +
        ((100 - ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2)) * 0.25) +
        (LEAST(ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) * 10, 100) * 0.20) +
        (GREATEST(100 - COALESCE(
            ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
                  NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0), 2
            ), 0), 0) * 0.10) +
        (COALESCE(AVG(confidence), 0.5) * 100 * 0.10),
        1
    ) AS "Health Index",
    
    COUNT(*) AS "Interactions"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Widget | **Gauge + Trend Line** |
|--------|-------------------------|
| Primary | Large gauge (0-100) with current score |
| Secondary | 30-day sparkline below gauge |
| Zones | Green (75+), Yellow (60-74), Orange (40-59), Red (<40) |
| Size | Medium (1/3 width) |

---

### 6.4 Health Index Component Breakdown

**Query Name:** `[JEXEC] AI Health Index - Component Breakdown`

```sql
-- AI Health Index: Component Contribution
WITH metrics AS (
    SELECT 
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) AS resolution_rate,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) AS escalation_rate,
        ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) AS lead_rate,
        COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
                       NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0), 2), 0) AS complaint_ratio,
        ROUND(AVG(confidence), 4) AS avg_confidence
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    'Resolution Rate' AS "Component",
    resolution_rate AS "Raw Value",
    0.35 AS "Weight",
    ROUND(resolution_rate * 0.35, 2) AS "Contribution"
FROM metrics
UNION ALL
SELECT 
    'Inverse Escalation',
    (100 - escalation_rate),
    0.25,
    ROUND((100 - escalation_rate) * 0.25, 2)
FROM metrics
UNION ALL
SELECT 
    'Lead Rate (×10)',
    LEAST(lead_rate * 10, 100),
    0.20,
    ROUND(LEAST(lead_rate * 10, 100) * 0.20, 2)
FROM metrics
UNION ALL
SELECT 
    'Inverse Complaint Ratio',
    GREATEST(100 - complaint_ratio, 0),
    0.10,
    ROUND(GREATEST(100 - complaint_ratio, 0) * 0.10, 2)
FROM metrics
UNION ALL
SELECT 
    'Avg Confidence (×100)',
    ROUND(avg_confidence * 100, 2),
    0.10,
    ROUND(avg_confidence * 100 * 0.10, 2)
FROM metrics;
```

| Widget | **Stacked Bar or Waterfall Chart** |
|--------|-------------------------------------|
| Type | Horizontal stacked bar showing contribution |
| Components | 5 segments with weights |
| Total | Sum = AI Health Index |
| Size | Medium (1/2 width) |

---

## 7. Dashboard Layout

### Executive Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    JANSSEN AI - EXECUTIVE DASHBOARD                         │
│                    Last updated: Jan 29, 2026 10:00 AM                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │   AI HEALTH │  │ RESOLUTION  │  │ ESCALATION  │  │    LEADS    │       │
│   │     INDEX   │  │    RATE     │  │    RATE     │  │   (30 days) │       │
│   │             │  │             │  │             │  │             │       │
│   │     78      │  │   84.2%     │  │   15.8%     │  │    1,247    │       │
│   │    GOOD     │  │   ▲ +2.1%   │  │   ▼ -1.3%   │  │   ▲ +8.5%   │       │
│   │   [GAUGE]   │  │  [SPARKLINE]│  │  [SPARKLINE]│  │  [MINI PIE] │       │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   LEADS vs COMPLAINTS - 7 Day Trend                                         │
│   ┌─────────────────────────────────────────────────────────────────┐       │
│   │                                                                 │       │
│   │   [DUAL-AXIS LINE CHART]                                        │       │
│   │   Leads (green line) | Complaints (red line) | Ratio (dashed)   │       │
│   │                                                                 │       │
│   └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
├────────────────────────────────────┬────────────────────────────────────────┤
│                                    │                                        │
│   ESCALATION HEATMAP               │   CHANNEL PERFORMANCE                  │
│   ┌────────────────────────────┐   │   ┌────────────────────────────────┐   │
│   │                            │   │   │                                │   │
│   │   [HEATMAP: Hour × Day]    │   │   │   [GROUPED BAR CHART]          │   │
│   │   Color: Green → Red       │   │   │   Chat | Voice | WhatsApp      │   │
│   │                            │   │   │                                │   │
│   └────────────────────────────┘   │   └────────────────────────────────┘   │
│                                    │                                        │
├────────────────────────────────────┴────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│   │ 🏆 BEST      │  │ 🎯 BEST     │  │ ⭐ HIGHEST  │  │ ⚠️ NEEDS     │   │
│   │ RESOLUTION   │  │ LEAD RATE   │  │ CONFIDENCE  │  │ ATTENTION    │   │
│   │              │  │             │  │             │  │              │   │
│   │ WhatsApp     │  │ Chat        │  │ Chat        │  │ Voice        │   │
│   │ 89.2%        │  │ 12.4%       │  │ 0.812       │  │ 78.1%        │   │
│   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Mobile Layout (Responsive)

```
┌───────────────────────┐
│   JANSSEN AI          │
│   EXECUTIVE DASHBOARD │
├───────────────────────┤
│  ┌─────────────────┐  │
│  │  AI HEALTH: 78  │  │
│  │     [GAUGE]     │  │
│  └─────────────────┘  │
├───────────────────────┤
│ Resolution │ Escalation│
│   84.2%    │   15.8%   │
│   ▲ +2.1%  │   ▼ -1.3% │
├───────────────────────┤
│    Leads   │ Complaint │
│    1,247   │   Ratio   │
│   ▲ +8.5%  │   18.2%   │
├───────────────────────┤
│                       │
│  [7-DAY TREND CHART]  │
│                       │
├───────────────────────┤
│                       │
│  [CHANNEL BARS]       │
│                       │
└───────────────────────┘
```

---

## 8. Implementation Guide

### Metabase Setup

1. **Create Collection:**
   ```
   Janssen AI Ops / Executive
   ```

2. **Create Questions (Queries):**
   - Save each SQL query as a saved question
   - Use naming convention: `[JEXEC] Metric Name`

3. **Create Dashboard:**
   - Name: `[JEXEC] Executive Dashboard`
   - Add saved questions as cards
   - Configure card sizes per layout above

4. **Set Filters:**
   ```
   - Date Range (default: Last 30 Days)
   - Channel (default: All)
   ```

5. **Configure Refresh:**
   ```
   Auto-refresh: 1 hour
   Cache: Enabled
   ```

### Access Control

| Role | Access Level |
|------|--------------|
| CEO / C-Suite | Full dashboard view |
| Directors | Full dashboard view |
| Managers | View only (no export) |
| Analysts | View + Export |

### Alerting

| Alert | Condition | Recipients |
|-------|-----------|------------|
| Health Index Drop | Index < 60 | CEO, CTO, COO |
| High Escalation | Rate > 25% | COO, Ops Director |
| Lead Decline | Week-over-week < -20% | CEO, Sales Director |

---

## Appendix: Quick Reference

### Target Benchmarks

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| AI Resolution Rate | ≥85% | 70-84% | <70% |
| Escalation Rate | ≤15% | 15-25% | >25% |
| Lead Rate | ≥10% | 5-9% | <5% |
| Complaint Ratio | ≤15% | 15-30% | >30% |
| AI Health Index | ≥75 | 60-74 | <60 |

### Color Palette

| Status | Hex Code |
|--------|----------|
| Excellent | `#4CAF50` |
| Good | `#8BC34A` |
| Fair | `#FFC107` |
| Poor | `#FF9800` |
| Critical | `#F44336` |

### Channel Colors

| Channel | Hex Code |
|---------|----------|
| Chat | `#2196F3` |
| Voice | `#9C27B0` |
| WhatsApp | `#25D366` |

---

*Document maintained by Janssen AI Ops Team*  
*For questions: ai-ops@janssen.com*
