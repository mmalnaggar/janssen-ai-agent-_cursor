# Janssen AI Ops - Voice Analytics KPIs

> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Channel Focus:** Voice (Avaya IVR Integration)  
> **Database:** PostgreSQL (analytics_events)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Voice vs Chat Resolution Rate](#2-voice-vs-chat-resolution-rate)
3. [Voice Escalation Rate by Hour](#3-voice-escalation-rate-by-hour)
4. [Voice Confidence Bucket Distribution](#4-voice-confidence-bucket-distribution)
5. [Failed Intents on Voice Channel](#5-failed-intents-on-voice-channel)
6. [Business Hours vs Off-Hours Comparison](#6-business-hours-vs-off-hours-comparison)
7. [Dashboard Layout](#7-dashboard-layout)
8. [Alerting Thresholds](#8-alerting-thresholds)

---

## 1. Overview

### Purpose

This document defines Voice-specific KPIs for monitoring the Janssen AI voice channel (Avaya IVR integration). All analytics are **read-only** and do not affect the live system.

### Data Source

```sql
-- All queries use the analytics_events table
-- Filter: channel = 'voice'
SELECT * FROM analytics_events WHERE channel = 'voice';
```

### Voice Channel Characteristics

| Aspect | Voice | Chat | WhatsApp |
|--------|-------|------|----------|
| Response Time Expectation | Immediate | < 30s | < 5 min |
| Escalation Tolerance | Lower | Medium | Higher |
| Confidence Threshold | Higher (0.7+) | Standard (0.5+) | Standard (0.5+) |
| Business Hours Dependency | High | Medium | Low |

---

## 2. Voice vs Chat Resolution Rate

### Definition

**Resolution Rate** = Interactions resolved by AI without escalation / Total interactions

A higher resolution rate indicates effective AI handling without human intervention.

### 2.1 Overall Resolution Rate Comparison

**Query Name:** `[JANA-VOICE] Resolution Rate - Voice vs Chat`

```sql
-- Resolution rate comparison: Voice vs Chat
SELECT 
    channel AS "Channel",
    COUNT(*) AS "Total Interactions",
    COUNT(*) FILTER (WHERE escalated = FALSE) AS "Resolved by AI",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalated",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Resolution Rate %"
FROM analytics_events
WHERE channel IN ('voice', 'chat')
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY channel
ORDER BY "Resolution Rate %" DESC;
```

| Widget Type | **Comparison Bar Chart** |
|-------------|--------------------------|
| X-Axis | Channel |
| Y-Axis | Resolution Rate % |
| Colors | Voice: `#9C27B0`, Chat: `#2196F3` |
| Reference Line | Target: 85% |
| Size | Medium (1/3 width) |

---

### 2.2 Daily Resolution Rate Trend

**Query Name:** `[JANA-VOICE] Resolution Rate - Daily Trend`

```sql
-- Daily resolution rate trend: Voice vs Chat
SELECT 
    date AS "Date",
    
    -- Voice metrics
    COUNT(*) FILTER (WHERE channel = 'voice') AS "Voice Total",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE channel = 'voice' AND escalated = FALSE) / 
        NULLIF(COUNT(*) FILTER (WHERE channel = 'voice'), 0),
        2
    ) AS "Voice Resolution %",
    
    -- Chat metrics
    COUNT(*) FILTER (WHERE channel = 'chat') AS "Chat Total",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE channel = 'chat' AND escalated = FALSE) / 
        NULLIF(COUNT(*) FILTER (WHERE channel = 'chat'), 0),
        2
    ) AS "Chat Resolution %"
    
FROM analytics_events
WHERE channel IN ('voice', 'chat')
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Widget Type | **Dual Line Chart** |
|-------------|---------------------|
| X-Axis | Date |
| Lines | Voice Resolution %, Chat Resolution % |
| Colors | Voice: `#9C27B0`, Chat: `#2196F3` |
| Y-Axis Range | 0% - 100% |
| Goal Line | 85% |
| Size | Large (full width) |

---

### 2.3 Resolution Rate by Agent (Voice Only)

**Query Name:** `[JANA-VOICE] Resolution Rate - By Agent`

```sql
-- Resolution rate by AI agent (voice channel only)
SELECT 
    agent_used AS "Agent",
    COUNT(*) AS "Total Calls",
    COUNT(*) FILTER (WHERE escalated = FALSE) AS "Resolved",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalated",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Resolution Rate %",
    ROUND(AVG(confidence), 3) AS "Avg Confidence"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY agent_used
ORDER BY "Resolution Rate %" DESC;
```

| Widget Type | **Table with Conditional Formatting** |
|-------------|---------------------------------------|
| Columns | Agent, Total Calls, Resolution Rate %, Avg Confidence |
| Highlight | Resolution < 70% → Red, ≥ 85% → Green |
| Mini Bar | Total Calls column |
| Size | Medium (1/2 width) |

---

## 3. Voice Escalation Rate by Hour

### Definition

**Escalation Rate** = Escalated calls / Total calls per hour

Identifies peak escalation times to optimize staffing and AI training.

### 3.1 Hourly Escalation Heatmap

**Query Name:** `[JANA-VOICE] Escalation - Hourly Heatmap`

```sql
-- Voice escalation heatmap by hour and day of week
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
    day_of_week AS "Day_Num",  -- For sorting
    hour AS "Hour",
    COUNT(*) AS "Total Calls",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY day_of_week, hour
ORDER BY day_of_week, hour;
```

| Widget Type | **Heatmap** |
|-------------|-------------|
| Rows | Day of Week (ordered Sun-Sat) |
| Columns | Hour (0-23) |
| Values | Escalation Rate % |
| Color Scale | Green (0%) → Yellow (15%) → Red (30%+) |
| Size | Large (full width) |

---

### 3.2 Hourly Escalation Trend (Today)

**Query Name:** `[JOPS-VOICE] Escalation - Today Hourly`

```sql
-- Today's hourly escalation trend (voice only)
SELECT 
    hour AS "Hour",
    COUNT(*) AS "Total Calls",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date = CURRENT_DATE
GROUP BY hour
ORDER BY hour ASC;
```

| Widget Type | **Bar Chart with Line Overlay** |
|-------------|----------------------------------|
| X-Axis | Hour (0-23) |
| Bars | Total Calls |
| Line | Escalation Rate % |
| Secondary Y-Axis | Escalation Rate % |
| Alert Zone | Highlight hours where rate > 20% |
| Size | Medium (1/2 width) |

---

### 3.3 Peak Escalation Hours Summary

**Query Name:** `[JANA-VOICE] Escalation - Peak Hours`

```sql
-- Top 5 peak escalation hours (voice channel)
SELECT 
    hour AS "Hour",
    TO_CHAR(MAKE_TIME(hour, 0, 0), 'HH12:MI AM') AS "Time",
    COUNT(*) AS "Total Calls",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %",
    ROUND(AVG(confidence) FILTER (WHERE escalated = TRUE), 3) AS "Avg Confidence at Escalation"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY hour
HAVING COUNT(*) >= 10  -- Minimum sample size
ORDER BY "Escalation Rate %" DESC
LIMIT 5;
```

| Widget Type | **Ranked Table** |
|-------------|------------------|
| Columns | Time, Total Calls, Escalation Rate %, Avg Confidence |
| Sort | Escalation Rate % DESC |
| Highlight | Top row (worst hour) in red |
| Size | Small (1/4 width) |

---

## 4. Voice Confidence Bucket Distribution

### Definition

Distribution of AI confidence scores across predefined buckets for voice interactions.

### 4.1 Confidence Bucket Histogram

**Query Name:** `[JANA-VOICE] Confidence - Bucket Distribution`

```sql
-- Voice confidence bucket distribution
SELECT 
    confidence_bucket AS "Confidence Range",
    COUNT(*) AS "Call Count",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS "Percentage",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalated",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
  AND confidence_bucket IS NOT NULL
GROUP BY confidence_bucket
ORDER BY confidence_bucket;
```

| Widget Type | **Histogram / Bar Chart** |
|-------------|---------------------------|
| X-Axis | Confidence Range |
| Y-Axis | Call Count |
| Color Gradient | Red (0-0.3) → Yellow (0.3-0.7) → Green (0.7-1.0) |
| Annotations | Show escalation rate per bucket |
| Size | Medium (1/2 width) |

---

### 4.2 Voice vs Chat Confidence Comparison

**Query Name:** `[JANA-VOICE] Confidence - Channel Comparison`

```sql
-- Confidence distribution: Voice vs Chat
SELECT 
    channel AS "Channel",
    confidence_bucket AS "Confidence Range",
    COUNT(*) AS "Interactions",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY channel), 2) AS "% of Channel"
FROM analytics_events
WHERE channel IN ('voice', 'chat')
  AND date >= CURRENT_DATE - INTERVAL '30 days'
  AND confidence_bucket IS NOT NULL
GROUP BY channel, confidence_bucket
ORDER BY channel, confidence_bucket;
```

| Widget Type | **Grouped Bar Chart** |
|-------------|------------------------|
| X-Axis | Confidence Range |
| Groups | Channel (Voice, Chat) |
| Y-Axis | % of Channel |
| Colors | Voice: `#9C27B0`, Chat: `#2196F3` |
| Size | Medium (1/2 width) |

---

### 4.3 Low Confidence Voice Calls (Detail)

**Query Name:** `[JOPS-VOICE] Low Confidence - Alert List`

```sql
-- Voice calls with low confidence (for review)
SELECT 
    session_id AS "Session ID",
    timestamp AS "Time",
    agent_used AS "Agent",
    ROUND(confidence, 3) AS "Confidence",
    event_type AS "Event Type",
    escalated AS "Escalated",
    CASE 
        WHEN confidence < 0.3 THEN 'Critical'
        WHEN confidence < 0.5 THEN 'Warning'
        ELSE 'Monitor'
    END AS "Severity"
FROM analytics_events
WHERE channel = 'voice'
  AND confidence < 0.7  -- Voice threshold is higher
  AND date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY confidence ASC, timestamp DESC
LIMIT 50;
```

| Widget Type | **Table with Row Actions** |
|-------------|----------------------------|
| Columns | Time, Agent, Confidence, Severity, Escalated |
| Conditional Formatting | Severity Critical → Red row |
| Filter | Date range, Agent |
| Size | Large (full width) |

---

### 4.4 Confidence Trend Over Time (Voice)

**Query Name:** `[JANA-VOICE] Confidence - Weekly Trend`

```sql
-- Weekly average confidence trend (voice)
SELECT 
    DATE_TRUNC('week', timestamp)::DATE AS "Week",
    COUNT(*) AS "Total Calls",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY confidence), 3) AS "25th Percentile",
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY confidence), 3) AS "Median",
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY confidence), 3) AS "75th Percentile"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '12 weeks'
  AND confidence IS NOT NULL
GROUP BY DATE_TRUNC('week', timestamp)
ORDER BY "Week" ASC;
```

| Widget Type | **Box Plot / Range Chart** |
|-------------|----------------------------|
| X-Axis | Week |
| Values | 25th, Median, 75th percentile |
| Line | Avg Confidence |
| Reference | Target: 0.75 |
| Size | Large (full width) |

---

## 5. Failed Intents on Voice Channel

### Definition

**Failed Intent** = Interaction where AI could not determine user intent or confidence was below threshold.

### 5.1 Failed Intent Rate (Voice)

**Query Name:** `[JANA-VOICE] Failed Intents - Daily Rate`

```sql
-- Daily failed intent rate (voice channel)
-- Failed = NO_CRM_EVENT with low confidence OR escalated due to intent failure
SELECT 
    date AS "Date",
    COUNT(*) AS "Total Calls",
    COUNT(*) FILTER (
        WHERE event_type = 'NO_CRM_EVENT' 
          AND confidence < 0.5
    ) AS "Failed Intents",
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE event_type = 'NO_CRM_EVENT' 
              AND confidence < 0.5
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS "Failed Intent Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY date
ORDER BY date ASC;
```

| Widget Type | **Area Chart** |
|-------------|----------------|
| X-Axis | Date |
| Y-Axis | Failed Intent Rate % |
| Fill Color | `#F44336` (red) with transparency |
| Reference Line | Acceptable: < 10% |
| Size | Medium (1/2 width) |

---

### 5.2 Failed Intents by Agent

**Query Name:** `[JANA-VOICE] Failed Intents - By Agent`

```sql
-- Failed intents breakdown by AI agent (voice)
SELECT 
    agent_used AS "Agent",
    COUNT(*) AS "Total Handled",
    COUNT(*) FILTER (
        WHERE event_type = 'NO_CRM_EVENT' 
          AND confidence < 0.5
    ) AS "Failed Intents",
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE event_type = 'NO_CRM_EVENT' 
              AND confidence < 0.5
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS "Failure Rate %",
    ROUND(
        AVG(confidence) FILTER (
            WHERE event_type = 'NO_CRM_EVENT'
        ),
        3
    ) AS "Avg Confidence on Failures"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY agent_used
ORDER BY "Failure Rate %" DESC;
```

| Widget Type | **Horizontal Bar Chart** |
|-------------|--------------------------|
| Y-Axis | Agent |
| X-Axis | Failure Rate % |
| Color | Gradient by failure rate |
| Labels | Show failure count |
| Size | Small (1/3 width) |

---

### 5.3 Common Failure Patterns

**Query Name:** `[JANA-VOICE] Failed Intents - Pattern Analysis`

```sql
-- Analyze patterns in failed voice intents
SELECT 
    hour AS "Hour",
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS "Day",
    COUNT(*) FILTER (
        WHERE event_type = 'NO_CRM_EVENT' 
          AND confidence < 0.5
    ) AS "Failed Intents",
    COUNT(*) AS "Total Calls",
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE event_type = 'NO_CRM_EVENT' 
              AND confidence < 0.5
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS "Failure Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY hour, day_of_week
HAVING COUNT(*) >= 5  -- Minimum sample
ORDER BY "Failure Rate %" DESC
LIMIT 10;
```

| Widget Type | **Table with Heatmap Column** |
|-------------|-------------------------------|
| Columns | Day, Hour, Failed Intents, Failure Rate % |
| Heatmap | Failure Rate % column |
| Sort | Failure Rate % DESC |
| Size | Medium (1/2 width) |

---

## 6. Business Hours vs Off-Hours Comparison

### Definition

- **Business Hours:** 9:00 AM - 6:00 PM (configurable)
- **Off-Hours:** All other times
- **Weekend:** Saturday and Sunday

### 6.1 Business vs Off-Hours Summary

**Query Name:** `[JANA-VOICE] Business Hours - Summary`

```sql
-- Voice performance: Business hours vs Off-hours
SELECT 
    CASE 
        WHEN is_business_hours THEN 'Business Hours (9AM-6PM)'
        ELSE 'Off-Hours'
    END AS "Time Period",
    COUNT(*) AS "Total Calls",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS "% of Volume",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    COUNT(*) FILTER (WHERE escalated = TRUE) AS "Escalations",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Resolution Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY is_business_hours
ORDER BY is_business_hours DESC;
```

| Widget Type | **Comparison Cards + Donut** |
|-------------|------------------------------|
| Card 1 | Business Hours: Resolution Rate, Escalation Rate |
| Card 2 | Off-Hours: Resolution Rate, Escalation Rate |
| Donut | Volume distribution |
| Colors | Business: `#4CAF50`, Off-Hours: `#607D8B` |
| Size | Medium (1/2 width) |

---

### 6.2 Weekday vs Weekend Performance

**Query Name:** `[JANA-VOICE] Weekend - Performance Comparison`

```sql
-- Voice performance: Weekday vs Weekend
SELECT 
    CASE 
        WHEN is_weekend THEN 'Weekend'
        ELSE 'Weekday'
    END AS "Period",
    COUNT(*) AS "Total Calls",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0),
        2
    ) AS "Lead Rate %",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / NULLIF(COUNT(*), 0),
        2
    ) AS "Complaint Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY is_weekend
ORDER BY is_weekend;
```

| Widget Type | **Side-by-Side Comparison** |
|-------------|------------------------------|
| Layout | Two columns: Weekday | Weekend |
| Metrics | Escalation Rate, Lead Rate, Complaint Rate |
| Highlight | Better performing period in green |
| Size | Medium (1/2 width) |

---

### 6.3 Hourly Pattern: Business vs Off-Hours

**Query Name:** `[JANA-VOICE] Business Hours - Hourly Breakdown`

```sql
-- Hourly breakdown with business hours flag (voice)
SELECT 
    hour AS "Hour",
    TO_CHAR(MAKE_TIME(hour, 0, 0), 'HH12:MI AM') AS "Time",
    CASE 
        WHEN hour >= 9 AND hour < 18 THEN 'Business'
        ELSE 'Off-Hours'
    END AS "Period",
    COUNT(*) AS "Calls",
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0),
        2
    ) AS "Escalation Rate %"
FROM analytics_events
WHERE channel = 'voice'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY hour
ORDER BY hour ASC;
```

| Widget Type | **Bar Chart with Background Zones** |
|-------------|-------------------------------------|
| X-Axis | Hour (0-23) |
| Y-Axis | Calls |
| Background | Green zone for business hours (9-18) |
| Line Overlay | Escalation Rate % |
| Size | Large (full width) |

---

### 6.4 Off-Hours Escalation Detail

**Query Name:** `[JOPS-VOICE] Off-Hours - Escalation List`

```sql
-- Recent off-hours escalations (for staffing decisions)
SELECT 
    session_id AS "Session ID",
    timestamp AS "Time",
    agent_used AS "Agent",
    ROUND(confidence, 3) AS "Confidence",
    event_type AS "Event Type",
    EXTRACT(DOW FROM timestamp) AS "Day of Week",
    CASE 
        WHEN EXTRACT(DOW FROM timestamp) IN (0, 6) THEN 'Weekend'
        ELSE 'Weeknight'
    END AS "Period Type"
FROM analytics_events
WHERE channel = 'voice'
  AND escalated = TRUE
  AND is_business_hours = FALSE
  AND date >= CURRENT_DATE - INTERVAL '14 days'
ORDER BY timestamp DESC
LIMIT 50;
```

| Widget Type | **Detailed Table** |
|-------------|---------------------|
| Columns | Time, Agent, Confidence, Period Type |
| Filter | Date range, Agent |
| Export | CSV enabled |
| Size | Large (full width) |

---

## 7. Dashboard Layout

### Voice Analytics Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│  [JANA-VOICE] Janssen AI - Voice Channel Analytics                      │
├──────────────────────┬──────────────────────┬───────────────────────────┤
│   VOICE CALLS        │   RESOLUTION RATE    │   AVG CONFIDENCE          │
│   TODAY: 156         │   82.3%              │   0.74                    │
│   ▲ +8% vs yesterday │   ▼ -1.2% vs target  │   ▲ +0.02 vs last week    │
├──────────────────────┴──────────────────────┴───────────────────────────┤
│                                                                         │
│   [LINE CHART] Voice vs Chat Resolution Rate - 30 Day Trend             │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   [HEATMAP] Voice Escalation Rate by Hour × Day of Week                 │
│                                                                         │
├──────────────────────────────────┬──────────────────────────────────────┤
│                                  │                                      │
│   [HISTOGRAM] Confidence         │   [BAR] Failed Intents by Agent      │
│   Bucket Distribution            │                                      │
│                                  │                                      │
├──────────────────────────────────┼──────────────────────────────────────┤
│                                  │                                      │
│   [DONUT] Business Hours vs      │   [TABLE] Peak Escalation Hours      │
│   Off-Hours Volume               │   (Top 5)                            │
│                                  │                                      │
├──────────────────────────────────┴──────────────────────────────────────┤
│                                                                         │
│   [TABLE] Low Confidence Voice Calls - Last 7 Days (Alert List)         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Dashboard Naming

| Dashboard | Name |
|-----------|------|
| Main Voice Analytics | `[JANA-VOICE] Voice Channel Analytics` |
| Operations View | `[JOPS-VOICE] Voice Operations Monitor` |
| Executive Summary | `[JEXEC-VOICE] Voice Channel KPI Summary` |

---

## 8. Alerting Thresholds

### Recommended Alert Rules

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Voice Resolution Rate | < 80% | < 70% | Review agent training |
| Voice Escalation Rate | > 18% | > 25% | Check staffing levels |
| Avg Voice Confidence | < 0.70 | < 0.60 | Investigate intent models |
| Failed Intent Rate | > 8% | > 15% | Update voice prompts |
| Off-Hours Escalation Rate | > 25% | > 40% | Consider after-hours staffing |

### Metabase Alert Configuration

```yaml
# Example alert for Voice Escalation Rate
alert_name: "Voice Escalation Rate Critical"
question: "[JANA-VOICE] Escalation Rate - Daily Trend"
condition: 
  column: "Escalation Rate %"
  operator: ">"
  value: 25
frequency: "hourly"
recipients:
  - ai-ops@janssen.com
  - voice-team@janssen.com
channels:
  - email
  - slack (#janssen-ai-alerts)
```

---

## Appendix A: Query Dependencies

All queries require:
- `analytics_events` table with `channel` column populated
- `is_business_hours` computed field (or computation in query)
- `is_weekend` computed field (or computation in query)
- `confidence_bucket` computed field

### Field Computation (if not pre-computed)

```sql
-- Add to query if fields are not in table
SELECT 
    *,
    -- Compute business hours
    CASE WHEN EXTRACT(HOUR FROM timestamp) >= 9 
          AND EXTRACT(HOUR FROM timestamp) < 18 
         THEN TRUE ELSE FALSE 
    END AS is_business_hours,
    
    -- Compute weekend
    CASE WHEN EXTRACT(DOW FROM timestamp) IN (0, 6) 
         THEN TRUE ELSE FALSE 
    END AS is_weekend,
    
    -- Compute confidence bucket
    CASE 
        WHEN confidence < 0.3 THEN '0.0-0.3'
        WHEN confidence < 0.5 THEN '0.3-0.5'
        WHEN confidence < 0.7 THEN '0.5-0.7'
        WHEN confidence < 0.9 THEN '0.7-0.9'
        ELSE '0.9-1.0'
    END AS confidence_bucket
FROM analytics_events
WHERE channel = 'voice';
```

---

## Appendix B: Quick Reference

### KPI Targets for Voice Channel

| KPI | Target | Formula |
|-----|--------|---------|
| Resolution Rate | ≥ 85% | (Total - Escalated) / Total |
| Escalation Rate | ≤ 15% | Escalated / Total |
| Avg Confidence | ≥ 0.75 | AVG(confidence) |
| Failed Intent Rate | ≤ 10% | Low conf NO_CRM_EVENT / Total |
| Business Hours Volume | ≥ 70% | BH calls / Total calls |

### Color Palette (Voice)

| Element | Hex Code |
|---------|----------|
| Voice Primary | `#9C27B0` (Purple) |
| Voice Secondary | `#7B1FA2` |
| Chat Comparison | `#2196F3` (Blue) |
| Good/Target | `#4CAF50` (Green) |
| Warning | `#FF9800` (Orange) |
| Critical | `#F44336` (Red) |
| Off-Hours | `#607D8B` (Gray) |

---

*Document maintained by Janssen AI Ops Team*
