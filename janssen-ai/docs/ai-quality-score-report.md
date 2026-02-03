# Janssen AI - Quality Score Report

> **Document Type:** Periodic Report Template  
> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Frequency:** Weekly (Monday) & Monthly (1st of month)  
> **Distribution:** CEO, COO, CTO, Operations Directors

---

## Table of Contents

1. [Report Overview](#1-report-overview)
2. [AI Quality Score Formula](#2-ai-quality-score-formula)
3. [Weekly & Monthly Scorecard](#3-weekly--monthly-scorecard)
4. [KPI Comparison Table](#4-kpi-comparison-table)
5. [Weakest Agent Identification](#5-weakest-agent-identification)
6. [Top Escalation Reasons](#6-top-escalation-reasons)
7. [Channel Risk Analysis](#7-channel-risk-analysis)
8. [Executive Recommendations](#8-executive-recommendations)
9. [Report Generation Guide](#9-report-generation-guide)

---

## 1. Report Overview

### Purpose

The AI Quality Score Report provides leadership with a **comprehensive assessment** of AI system performance, identifying areas of excellence and opportunities for improvement. This report is designed to:

- Summarize AI performance in executive-friendly terms
- Compare current period against previous period
- Highlight risks requiring immediate attention
- Provide actionable recommendations

### Report Cadence

| Report Type | Generated | Covers | Delivered To |
|-------------|-----------|--------|--------------|
| **Weekly** | Monday 8:00 AM | Previous 7 days | Operations Team, Directors |
| **Monthly** | 1st of month | Previous calendar month | C-Suite, Board |

### Key Sections at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│                 AI QUALITY SCORE: 76/100                    │
│                      Status: GOOD                           │
├─────────────────────────────────────────────────────────────┤
│  This Week    │  Last Week    │  Change                     │
│  Resolution: 84%  Resolution: 82%   ▲ +2%                   │
│  Escalation: 16%  Escalation: 18%   ▼ -2% (improved)        │
│  Leads: 312       Leads: 287        ▲ +8.7%                 │
└─────────────────────────────────────────────────────────────┤
│  ⚠️ ATTENTION: Voice channel shows elevated escalation      │
│  📈 POSITIVE: WhatsApp lead conversion up 15%               │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. AI Quality Score Formula

### Definition

The **AI Quality Score** is a composite metric (0-100) that measures the overall effectiveness and reliability of the AI system across multiple dimensions.

### Formula

```
AI Quality Score = 
    (Resolution Score × 0.30) +
    (Confidence Score × 0.25) +
    (Lead Efficiency Score × 0.20) +
    (Customer Satisfaction Proxy × 0.15) +
    (Consistency Score × 0.10)
```

### Component Definitions

| Component | Weight | Formula | Max Score |
|-----------|--------|---------|-----------|
| **Resolution Score** | 30% | `Resolution Rate` (0-100) | 100 |
| **Confidence Score** | 25% | `Avg Confidence × 100` | 100 |
| **Lead Efficiency Score** | 20% | `Min(Lead Rate × 5, 100)` | 100 |
| **Customer Satisfaction Proxy** | 15% | `100 - Min(Complaint Ratio, 100)` | 100 |
| **Consistency Score** | 10% | `100 - (Std Dev of Daily Resolution × 10)` | 100 |

### Score Interpretation

| Score | Grade | Status | Executive Summary |
|-------|-------|--------|-------------------|
| 90-100 | A+ | Excellent | AI is performing exceptionally. Maintain current approach. |
| 80-89 | A | Very Good | Strong performance with minor optimization opportunities. |
| 70-79 | B | Good | Solid performance. Review identified weak areas. |
| 60-69 | C | Fair | Acceptable but requires attention to specific issues. |
| 50-59 | D | Below Average | Multiple areas need improvement. Action plan required. |
| 0-49 | F | Critical | Significant issues present. Immediate intervention needed. |

---

### 2.1 AI Quality Score Query

**Query Name:** `[REPORT] AI Quality Score - Full Calculation`

```sql
-- AI Quality Score: Complete Calculation with All Components
WITH base_metrics AS (
    SELECT 
        -- Resolution metrics
        COUNT(*) AS total_interactions,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved_count,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) AS resolution_rate,
        
        -- Confidence metrics
        ROUND(AVG(confidence), 4) AS avg_confidence,
        ROUND(STDDEV(confidence), 4) AS stddev_confidence,
        
        -- Lead metrics
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS lead_count,
        ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) AS lead_rate,
        
        -- Complaint metrics
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaint_count,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
            NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
            2
        ) AS complaint_ratio
        
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'  -- Change to '1 month' for monthly
),
daily_consistency AS (
    SELECT 
        ROUND(STDDEV(daily_resolution), 2) AS resolution_stddev
    FROM (
        SELECT 
            date,
            100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0) AS daily_resolution
        FROM analytics_events
        WHERE date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY date
    ) daily
),
component_scores AS (
    SELECT 
        -- Resolution Score (0-100)
        ROUND(bm.resolution_rate, 2) AS resolution_score,
        
        -- Confidence Score (0-100)
        ROUND(bm.avg_confidence * 100, 2) AS confidence_score,
        
        -- Lead Efficiency Score (0-100, capped)
        ROUND(LEAST(bm.lead_rate * 5, 100), 2) AS lead_efficiency_score,
        
        -- Customer Satisfaction Proxy (0-100)
        ROUND(GREATEST(100 - COALESCE(bm.complaint_ratio, 0), 0), 2) AS satisfaction_score,
        
        -- Consistency Score (0-100)
        ROUND(GREATEST(100 - COALESCE(dc.resolution_stddev * 10, 0), 0), 2) AS consistency_score,
        
        -- Raw metrics for reference
        bm.*
    FROM base_metrics bm, daily_consistency dc
)
SELECT 
    -- Component Scores
    resolution_score AS "Resolution Score",
    confidence_score AS "Confidence Score",
    lead_efficiency_score AS "Lead Efficiency Score",
    satisfaction_score AS "Satisfaction Score",
    consistency_score AS "Consistency Score",
    
    -- Final AI Quality Score
    ROUND(
        (resolution_score * 0.30) +
        (confidence_score * 0.25) +
        (lead_efficiency_score * 0.20) +
        (satisfaction_score * 0.15) +
        (consistency_score * 0.10),
        1
    ) AS "AI Quality Score",
    
    -- Grade
    CASE 
        WHEN (
            (resolution_score * 0.30) +
            (confidence_score * 0.25) +
            (lead_efficiency_score * 0.20) +
            (satisfaction_score * 0.15) +
            (consistency_score * 0.10)
        ) >= 90 THEN 'A+'
        WHEN (
            (resolution_score * 0.30) +
            (confidence_score * 0.25) +
            (lead_efficiency_score * 0.20) +
            (satisfaction_score * 0.15) +
            (consistency_score * 0.10)
        ) >= 80 THEN 'A'
        WHEN (
            (resolution_score * 0.30) +
            (confidence_score * 0.25) +
            (lead_efficiency_score * 0.20) +
            (satisfaction_score * 0.15) +
            (consistency_score * 0.10)
        ) >= 70 THEN 'B'
        WHEN (
            (resolution_score * 0.30) +
            (confidence_score * 0.25) +
            (lead_efficiency_score * 0.20) +
            (satisfaction_score * 0.15) +
            (consistency_score * 0.10)
        ) >= 60 THEN 'C'
        WHEN (
            (resolution_score * 0.30) +
            (confidence_score * 0.25) +
            (lead_efficiency_score * 0.20) +
            (satisfaction_score * 0.15) +
            (consistency_score * 0.10)
        ) >= 50 THEN 'D'
        ELSE 'F'
    END AS "Grade",
    
    -- Raw metrics
    total_interactions AS "Total Interactions",
    lead_count AS "Leads Generated",
    complaint_count AS "Complaints Logged"
    
FROM component_scores;
```

### 2.2 Score Component Visualization

| Chart Type | **Radar Chart** (Spider Chart) |
|------------|--------------------------------|
| Axes | Resolution, Confidence, Lead Efficiency, Satisfaction, Consistency |
| Values | Component scores (0-100) |
| Comparison | Current period vs Previous period |
| Colors | Current: Blue, Previous: Gray |

---

## 3. Weekly & Monthly Scorecard

### 3.1 Scorecard Header

**Query Name:** `[REPORT] Scorecard - Header Summary`

```sql
-- Scorecard Header: Key Numbers at a Glance
SELECT 
    -- Period info
    CURRENT_DATE - INTERVAL '7 days' AS "Period Start",
    CURRENT_DATE - INTERVAL '1 day' AS "Period End",
    '7 days' AS "Duration",
    
    -- Volume
    COUNT(*) AS "Total Interactions",
    COUNT(DISTINCT session_id) AS "Unique Sessions",
    
    -- Key Rates
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 1) 
        AS "AI Resolution Rate %",
    ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 1) 
        AS "Escalation Rate %",
    
    -- Outcomes
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS "Leads Generated",
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS "Complaints Handled",
    COUNT(*) FILTER (WHERE event_type = 'ESCALATION') AS "Escalations",
    
    -- Quality
    ROUND(AVG(confidence), 3) AS "Avg AI Confidence"
    
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '7 days';
```

### 3.2 Weekly Report Template

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    JANSSEN AI - WEEKLY QUALITY REPORT                  ║
║                    Week of: January 22-28, 2026                        ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║                    ┌─────────────────────────┐                         ║
║                    │   AI QUALITY SCORE      │                         ║
║                    │                         │                         ║
║                    │         76 / 100        │                         ║
║                    │       Grade: B          │                         ║
║                    │      Status: GOOD       │                         ║
║                    └─────────────────────────┘                         ║
║                                                                        ║
╠═══════════════════════════════════════════════════════════════════════╣
║  QUICK STATS                                                           ║
║  ─────────────────────────────────────────────────────────────────────║
║  Total Interactions:  3,247        Leads Generated:     312           ║
║  AI Resolution Rate:  84.2%        Complaints Handled:  89            ║
║  Escalation Rate:     15.8%        Avg Confidence:      0.78          ║
╠═══════════════════════════════════════════════════════════════════════╣
║  WEEK-OVER-WEEK COMPARISON                                             ║
║  ─────────────────────────────────────────────────────────────────────║
║  Metric              This Week    Last Week    Change                  ║
║  ─────────────────────────────────────────────────────────────────────║
║  Resolution Rate     84.2%        82.1%        ▲ +2.1%  [IMPROVED]    ║
║  Escalation Rate     15.8%        17.9%        ▼ -2.1%  [IMPROVED]    ║
║  Leads Generated     312          287          ▲ +8.7%  [IMPROVED]    ║
║  Complaints          89           102          ▼ -12.7% [IMPROVED]    ║
║  Avg Confidence      0.78         0.76         ▲ +2.6%  [IMPROVED]    ║
╠═══════════════════════════════════════════════════════════════════════╣
║  ⚠️  ATTENTION REQUIRED                                                ║
║  ─────────────────────────────────────────────────────────────────────║
║  • Voice channel escalation rate at 22% (target: <15%)                ║
║  • Support agent confidence dropped to 0.68 (target: >0.75)           ║
╠═══════════════════════════════════════════════════════════════════════╣
║  ✅ HIGHLIGHTS                                                         ║
║  ─────────────────────────────────────────────────────────────────────║
║  • WhatsApp lead conversion improved 15% week-over-week               ║
║  • Chat resolution rate reached all-time high of 89%                  ║
║  • Complaint ratio decreased from 35% to 28%                          ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### 3.3 Monthly Scorecard Query

**Query Name:** `[REPORT] Monthly Scorecard - Full Summary`

```sql
-- Monthly Scorecard: Comprehensive Summary
WITH this_month AS (
    SELECT 
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved,
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        AVG(confidence) AS avg_confidence
    FROM analytics_events
    WHERE date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month'
      AND date < DATE_TRUNC('month', CURRENT_DATE)
),
last_month AS (
    SELECT 
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved,
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        AVG(confidence) AS avg_confidence
    FROM analytics_events
    WHERE date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '2 months'
      AND date < DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month'
)
SELECT 
    -- Period
    TO_CHAR(DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month', 'Month YYYY') AS "Report Period",
    
    -- This Month
    tm.total AS "This Month: Interactions",
    ROUND(100.0 * tm.resolved / NULLIF(tm.total, 0), 1) AS "This Month: Resolution %",
    tm.leads AS "This Month: Leads",
    tm.complaints AS "This Month: Complaints",
    ROUND(tm.avg_confidence, 3) AS "This Month: Confidence",
    
    -- Last Month
    lm.total AS "Last Month: Interactions",
    ROUND(100.0 * lm.resolved / NULLIF(lm.total, 0), 1) AS "Last Month: Resolution %",
    lm.leads AS "Last Month: Leads",
    lm.complaints AS "Last Month: Complaints",
    ROUND(lm.avg_confidence, 3) AS "Last Month: Confidence",
    
    -- Changes
    ROUND(100.0 * (tm.total - lm.total) / NULLIF(lm.total, 0), 1) AS "Volume Change %",
    ROUND(
        (100.0 * tm.resolved / NULLIF(tm.total, 0)) - 
        (100.0 * lm.resolved / NULLIF(lm.total, 0)),
        1
    ) AS "Resolution Change pp",
    ROUND(100.0 * (tm.leads - lm.leads) / NULLIF(lm.leads, 0), 1) AS "Leads Change %"
    
FROM this_month tm, last_month lm;
```

---

## 4. KPI Comparison Table

### 4.1 This Week vs Last Week

**Query Name:** `[REPORT] KPI Comparison - Week over Week`

```sql
-- KPI Comparison: This Week vs Last Week
WITH this_week AS (
    SELECT 
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved,
        COUNT(*) FILTER (WHERE escalated = TRUE) AS escalated,
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        AVG(confidence) AS avg_confidence,
        COUNT(*) FILTER (WHERE confidence >= 0.8) AS high_confidence
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'
),
last_week AS (
    SELECT 
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = FALSE) AS resolved,
        COUNT(*) FILTER (WHERE escalated = TRUE) AS escalated,
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        AVG(confidence) AS avg_confidence,
        COUNT(*) FILTER (WHERE confidence >= 0.8) AS high_confidence
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '14 days'
      AND date < CURRENT_DATE - INTERVAL '7 days'
)
SELECT 
    'Total Interactions' AS "Metric",
    tw.total AS "This Week",
    lw.total AS "Last Week",
    tw.total - lw.total AS "Change",
    ROUND(100.0 * (tw.total - lw.total) / NULLIF(lw.total, 0), 1) AS "Change %",
    CASE WHEN tw.total >= lw.total THEN '▲' ELSE '▼' END AS "Trend"
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Resolution Rate',
    ROUND(100.0 * tw.resolved / NULLIF(tw.total, 0), 1),
    ROUND(100.0 * lw.resolved / NULLIF(lw.total, 0), 1),
    NULL,
    ROUND(
        (100.0 * tw.resolved / NULLIF(tw.total, 0)) - 
        (100.0 * lw.resolved / NULLIF(lw.total, 0)),
        1
    ),
    CASE 
        WHEN (100.0 * tw.resolved / NULLIF(tw.total, 0)) >= 
             (100.0 * lw.resolved / NULLIF(lw.total, 0)) 
        THEN '▲' ELSE '▼' 
    END
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Escalation Rate',
    ROUND(100.0 * tw.escalated / NULLIF(tw.total, 0), 1),
    ROUND(100.0 * lw.escalated / NULLIF(lw.total, 0), 1),
    NULL,
    ROUND(
        (100.0 * tw.escalated / NULLIF(tw.total, 0)) - 
        (100.0 * lw.escalated / NULLIF(lw.total, 0)),
        1
    ),
    CASE 
        WHEN (100.0 * tw.escalated / NULLIF(tw.total, 0)) <= 
             (100.0 * lw.escalated / NULLIF(lw.total, 0)) 
        THEN '▲' ELSE '▼'  -- Lower is better
    END
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Leads Generated',
    tw.leads,
    lw.leads,
    tw.leads - lw.leads,
    ROUND(100.0 * (tw.leads - lw.leads) / NULLIF(lw.leads, 0), 1),
    CASE WHEN tw.leads >= lw.leads THEN '▲' ELSE '▼' END
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Complaints Logged',
    tw.complaints,
    lw.complaints,
    tw.complaints - lw.complaints,
    ROUND(100.0 * (tw.complaints - lw.complaints) / NULLIF(lw.complaints, 0), 1),
    CASE WHEN tw.complaints <= lw.complaints THEN '▲' ELSE '▼' END  -- Lower is better
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'Avg Confidence',
    ROUND(tw.avg_confidence, 3),
    ROUND(lw.avg_confidence, 3),
    NULL,
    ROUND((tw.avg_confidence - lw.avg_confidence) * 100, 1),
    CASE WHEN tw.avg_confidence >= lw.avg_confidence THEN '▲' ELSE '▼' END
FROM this_week tw, last_week lw

UNION ALL

SELECT 
    'High Confidence Rate',
    ROUND(100.0 * tw.high_confidence / NULLIF(tw.total, 0), 1),
    ROUND(100.0 * lw.high_confidence / NULLIF(lw.total, 0), 1),
    NULL,
    ROUND(
        (100.0 * tw.high_confidence / NULLIF(tw.total, 0)) - 
        (100.0 * lw.high_confidence / NULLIF(lw.total, 0)),
        1
    ),
    CASE 
        WHEN (100.0 * tw.high_confidence / NULLIF(tw.total, 0)) >= 
             (100.0 * lw.high_confidence / NULLIF(lw.total, 0)) 
        THEN '▲' ELSE '▼' 
    END
FROM this_week tw, last_week lw;
```

### KPI Comparison Table Format

| Metric | This Week | Last Week | Change | Trend | Status |
|--------|-----------|-----------|--------|-------|--------|
| Total Interactions | 3,247 | 2,986 | +261 (+8.7%) | ▲ | Good |
| Resolution Rate | 84.2% | 82.1% | +2.1pp | ▲ | Improved |
| Escalation Rate | 15.8% | 17.9% | -2.1pp | ▲ | Improved |
| Leads Generated | 312 | 287 | +25 (+8.7%) | ▲ | Good |
| Complaints | 89 | 102 | -13 (-12.7%) | ▲ | Improved |
| Avg Confidence | 0.78 | 0.76 | +0.02 | ▲ | Improved |

| Chart Type | **Comparison Table with Conditional Formatting** |
|------------|--------------------------------------------------|
| Format | Green for improvements, Red for declines |
| Trend Icons | ▲ (up/better), ▼ (down/worse) |
| Highlight | Best/worst performers |

---

## 5. Weakest Agent Identification

### 5.1 Agent Performance Ranking

**Query Name:** `[REPORT] Weakest Agent - Performance Ranking`

```sql
-- Agent Performance Ranking (Identify Weakest)
WITH agent_metrics AS (
    SELECT 
        agent_used AS agent,
        COUNT(*) AS total_interactions,
        
        -- Core metrics
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) 
            AS resolution_rate,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) 
            AS escalation_rate,
        ROUND(AVG(confidence), 3) AS avg_confidence,
        
        -- Lead performance
        ROUND(100.0 * COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') / NULLIF(COUNT(*), 0), 2) 
            AS lead_rate,
            
        -- Complaint handling
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints_handled,
        
        -- Quality indicators
        COUNT(*) FILTER (WHERE confidence < 0.5) AS low_confidence_count,
        ROUND(100.0 * COUNT(*) FILTER (WHERE confidence < 0.5) / NULLIF(COUNT(*), 0), 2) 
            AS low_confidence_rate
            
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY agent_used
    HAVING COUNT(*) >= 50  -- Minimum sample size for statistical relevance
),
agent_scores AS (
    SELECT 
        agent,
        total_interactions,
        resolution_rate,
        escalation_rate,
        avg_confidence,
        lead_rate,
        low_confidence_rate,
        
        -- Calculate Agent Quality Score
        ROUND(
            (resolution_rate * 0.35) +
            (avg_confidence * 100 * 0.30) +
            (LEAST(lead_rate * 5, 100) * 0.20) +
            ((100 - low_confidence_rate) * 0.15),
            1
        ) AS agent_quality_score
        
    FROM agent_metrics
)
SELECT 
    agent AS "Agent",
    total_interactions AS "Interactions",
    resolution_rate AS "Resolution %",
    escalation_rate AS "Escalation %",
    avg_confidence AS "Confidence",
    lead_rate AS "Lead Rate %",
    low_confidence_rate AS "Low Conf %",
    agent_quality_score AS "Quality Score",
    
    -- Ranking
    RANK() OVER (ORDER BY agent_quality_score DESC) AS "Rank",
    
    -- Status
    CASE 
        WHEN agent_quality_score >= 80 THEN 'Strong'
        WHEN agent_quality_score >= 65 THEN 'Adequate'
        WHEN agent_quality_score >= 50 THEN 'Needs Improvement'
        ELSE 'Critical'
    END AS "Status",
    
    -- Primary Issue (for lowest performers)
    CASE 
        WHEN resolution_rate < 75 THEN 'Low Resolution Rate'
        WHEN avg_confidence < 0.65 THEN 'Low Confidence'
        WHEN escalation_rate > 25 THEN 'High Escalation'
        WHEN low_confidence_rate > 20 THEN 'Inconsistent Performance'
        ELSE 'Review Needed'
    END AS "Primary Issue"
    
FROM agent_scores
ORDER BY agent_quality_score ASC  -- Weakest first
LIMIT 10;
```

### 5.2 Weakest Agent Summary

**Query Name:** `[REPORT] Weakest Agent - Executive Summary`

```sql
-- Weakest Agent: Executive Summary
WITH agent_scores AS (
    SELECT 
        agent_used AS agent,
        COUNT(*) AS interactions,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 1) AS resolution,
        ROUND(AVG(confidence), 3) AS confidence,
        ROUND(
            (100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0) * 0.5) +
            (AVG(confidence) * 100 * 0.5),
            1
        ) AS score
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY agent_used
    HAVING COUNT(*) >= 50
)
SELECT 
    agent AS "Weakest Agent",
    interactions AS "Sample Size",
    resolution || '%' AS "Resolution Rate",
    confidence AS "Avg Confidence",
    score AS "Quality Score",
    
    -- Impact assessment
    ROUND(
        (SELECT AVG(s2.resolution) FROM agent_scores s2) - resolution,
        1
    ) || ' pp below average' AS "Resolution Gap",
    
    -- Recommendation
    CASE 
        WHEN resolution < 70 AND confidence < 0.6 THEN 'URGENT: Review agent training and intent model'
        WHEN resolution < 75 THEN 'ACTION: Focus on improving resolution handling'
        WHEN confidence < 0.65 THEN 'ACTION: Review confidence calibration'
        ELSE 'MONITOR: Track performance over next week'
    END AS "Recommendation"
    
FROM agent_scores
ORDER BY score ASC
LIMIT 1;
```

### Weakest Agent Report Section

```
╔═══════════════════════════════════════════════════════════════════════╗
║  WEAKEST AGENT IDENTIFICATION                                          ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Agent Requiring Attention: SUPPORT                                    ║
║  ─────────────────────────────────────────────────────────────────────║
║                                                                        ║
║  Quality Score:    58/100 (Below Average)                              ║
║  Resolution Rate:  71.2% (8.3pp below average)                         ║
║  Avg Confidence:   0.68 (below 0.75 target)                            ║
║  Escalation Rate:  28.8% (13.0pp above target)                         ║
║  Sample Size:      487 interactions                                    ║
║                                                                        ║
║  Primary Issue:    High Escalation Rate                                ║
║  Secondary Issue:  Low Confidence Scores                               ║
║                                                                        ║
║  RECOMMENDATION:                                                       ║
║  Review support agent's intent recognition model. Consider             ║
║  additional training data for common support queries. Analyze          ║
║  escalation patterns to identify specific weak points.                 ║
║                                                                        ║
╚═══════════════════════════════════════════════════════════════════════╝
```

| Chart Type | **Horizontal Bar Chart** |
|------------|--------------------------|
| Y-Axis | Agent names |
| X-Axis | Quality Score (0-100) |
| Color | Red for lowest, gradient to green |
| Highlight | Lowest performer emphasized |

---

## 6. Top Escalation Reasons

### 6.1 Escalation Reasons Analysis

**Query Name:** `[REPORT] Escalation Reasons - Top 10`

```sql
-- Top Escalation Reasons
-- Note: This query infers reasons from event patterns since escalation_reason
-- may not always be populated in analytics_events

WITH escalation_patterns AS (
    SELECT 
        -- Infer reason from context
        CASE 
            WHEN confidence < 0.3 THEN 'Very Low AI Confidence'
            WHEN confidence < 0.5 THEN 'Low AI Confidence'
            WHEN agent_used = 'complaint' THEN 'Complaint Handling Request'
            WHEN agent_used = 'escalation' THEN 'Customer Requested Agent'
            WHEN event_type = 'NO_CRM_EVENT' AND confidence < 0.6 THEN 'Intent Not Recognized'
            WHEN hour NOT BETWEEN 9 AND 17 THEN 'After-Hours Complexity'
            WHEN channel = 'voice' AND confidence < 0.7 THEN 'Voice Recognition Issues'
            ELSE 'General Escalation'
        END AS inferred_reason,
        
        agent_used,
        channel,
        confidence,
        hour,
        date
        
    FROM analytics_events
    WHERE escalated = TRUE
      AND date >= CURRENT_DATE - INTERVAL '7 days'
)
SELECT 
    inferred_reason AS "Escalation Reason",
    COUNT(*) AS "Count",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS "% of Escalations",
    
    -- Channel breakdown
    COUNT(*) FILTER (WHERE channel = 'chat') AS "Chat",
    COUNT(*) FILTER (WHERE channel = 'voice') AS "Voice",
    COUNT(*) FILTER (WHERE channel = 'whatsapp') AS "WhatsApp",
    
    -- Avg confidence for this reason
    ROUND(AVG(confidence), 3) AS "Avg Confidence",
    
    -- Trend (compare to previous period would require additional CTE)
    'See trend chart' AS "Trend"
    
FROM escalation_patterns
GROUP BY inferred_reason
ORDER BY COUNT(*) DESC
LIMIT 10;
```

### 6.2 Escalation Reason Trends

**Query Name:** `[REPORT] Escalation Reasons - Weekly Trend`

```sql
-- Escalation Reason Trends Over Time
WITH weekly_reasons AS (
    SELECT 
        DATE_TRUNC('week', date)::DATE AS week,
        CASE 
            WHEN confidence < 0.5 THEN 'Low Confidence'
            WHEN agent_used = 'complaint' THEN 'Complaint Related'
            WHEN event_type = 'NO_CRM_EVENT' THEN 'Intent Not Recognized'
            ELSE 'Other'
        END AS reason_category,
        COUNT(*) AS count
    FROM analytics_events
    WHERE escalated = TRUE
      AND date >= CURRENT_DATE - INTERVAL '4 weeks'
    GROUP BY DATE_TRUNC('week', date), reason_category
)
SELECT 
    week AS "Week",
    SUM(count) FILTER (WHERE reason_category = 'Low Confidence') AS "Low Confidence",
    SUM(count) FILTER (WHERE reason_category = 'Complaint Related') AS "Complaint Related",
    SUM(count) FILTER (WHERE reason_category = 'Intent Not Recognized') AS "Intent Issues",
    SUM(count) FILTER (WHERE reason_category = 'Other') AS "Other",
    SUM(count) AS "Total"
FROM weekly_reasons
GROUP BY week
ORDER BY week ASC;
```

### Escalation Reasons Report Section

```
╔═══════════════════════════════════════════════════════════════════════╗
║  TOP ESCALATION REASONS                                                ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Rank │ Reason                      │ Count │ Share │ Trend           ║
║  ─────┼─────────────────────────────┼───────┼───────┼─────────────────║
║   1   │ Low AI Confidence           │  156  │ 31.2% │ ▼ Improving     ║
║   2   │ Customer Requested Agent    │  127  │ 25.4% │ ─ Stable        ║
║   3   │ Complaint Handling Request  │   89  │ 17.8% │ ▲ Increasing    ║
║   4   │ Intent Not Recognized       │   67  │ 13.4% │ ▼ Improving     ║
║   5   │ Voice Recognition Issues    │   34  │  6.8% │ ─ Stable        ║
║   6   │ After-Hours Complexity      │   27  │  5.4% │ ─ Stable        ║
║                                                                        ║
║  KEY INSIGHT:                                                          ║
║  "Low AI Confidence" remains the top reason but is improving.          ║
║  "Complaint Handling" escalations increased 12% - investigate.         ║
║                                                                        ║
╚═══════════════════════════════════════════════════════════════════════╝
```

| Chart Type | **Horizontal Stacked Bar Chart** |
|------------|----------------------------------|
| Y-Axis | Escalation Reason |
| X-Axis | Count |
| Stacks | By Channel (Chat, Voice, WhatsApp) |
| Sort | Descending by total count |

---

## 7. Channel Risk Analysis

### 7.1 Channel Risk Assessment

**Query Name:** `[REPORT] Channel Risk - Assessment Matrix`

```sql
-- Channel Risk Analysis
WITH channel_metrics AS (
    SELECT 
        channel,
        COUNT(*) AS total_interactions,
        
        -- Performance metrics
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) 
            AS resolution_rate,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) 
            AS escalation_rate,
        ROUND(AVG(confidence), 3) AS avg_confidence,
        
        -- Volume trend (compare to previous week)
        COUNT(*) AS this_week_volume
        
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY channel
),
previous_metrics AS (
    SELECT 
        channel,
        COUNT(*) AS last_week_volume,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) 
            AS last_week_escalation
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '14 days'
      AND date < CURRENT_DATE - INTERVAL '7 days'
    GROUP BY channel
),
risk_assessment AS (
    SELECT 
        cm.channel,
        cm.total_interactions,
        cm.resolution_rate,
        cm.escalation_rate,
        cm.avg_confidence,
        
        -- Volume change
        ROUND(100.0 * (cm.this_week_volume - COALESCE(pm.last_week_volume, 0)) / 
              NULLIF(pm.last_week_volume, 0), 1) AS volume_change_pct,
        
        -- Escalation trend
        cm.escalation_rate - COALESCE(pm.last_week_escalation, cm.escalation_rate) AS escalation_trend,
        
        -- Calculate Risk Score (0-100, higher = more risk)
        ROUND(
            (CASE WHEN cm.escalation_rate > 25 THEN 40 
                  WHEN cm.escalation_rate > 20 THEN 30
                  WHEN cm.escalation_rate > 15 THEN 20
                  ELSE 10 END) +
            (CASE WHEN cm.avg_confidence < 0.6 THEN 30
                  WHEN cm.avg_confidence < 0.7 THEN 20
                  WHEN cm.avg_confidence < 0.75 THEN 10
                  ELSE 0 END) +
            (CASE WHEN cm.escalation_rate > COALESCE(pm.last_week_escalation, 0) THEN 20
                  ELSE 0 END) +
            (CASE WHEN cm.resolution_rate < 75 THEN 10
                  ELSE 0 END),
            0
        ) AS risk_score
        
    FROM channel_metrics cm
    LEFT JOIN previous_metrics pm ON cm.channel = pm.channel
)
SELECT 
    INITCAP(channel) AS "Channel",
    total_interactions AS "Volume",
    resolution_rate || '%' AS "Resolution",
    escalation_rate || '%' AS "Escalation",
    avg_confidence AS "Confidence",
    
    CASE 
        WHEN volume_change_pct > 0 THEN '+' || volume_change_pct || '%'
        ELSE volume_change_pct || '%'
    END AS "Volume Trend",
    
    CASE 
        WHEN escalation_trend > 2 THEN '⚠️ +' || ROUND(escalation_trend, 1) || 'pp'
        WHEN escalation_trend < -2 THEN '✅ ' || ROUND(escalation_trend, 1) || 'pp'
        ELSE '─ Stable'
    END AS "Escalation Trend",
    
    risk_score AS "Risk Score",
    
    CASE 
        WHEN risk_score >= 60 THEN '🔴 HIGH RISK'
        WHEN risk_score >= 40 THEN '🟡 MODERATE'
        WHEN risk_score >= 20 THEN '🟢 LOW RISK'
        ELSE '✅ HEALTHY'
    END AS "Risk Level",
    
    -- Primary Risk Factor
    CASE 
        WHEN escalation_rate > 25 THEN 'High Escalation Rate'
        WHEN avg_confidence < 0.65 THEN 'Low Confidence'
        WHEN escalation_rate > COALESCE((SELECT last_week_escalation FROM previous_metrics WHERE channel = risk_assessment.channel), 0) + 3 
            THEN 'Escalation Increasing'
        WHEN resolution_rate < 75 THEN 'Low Resolution'
        ELSE 'No Major Issues'
    END AS "Primary Risk"
    
FROM risk_assessment
ORDER BY risk_score DESC;
```

### 7.2 Channel Risk Summary

**Query Name:** `[REPORT] Channel Risk - Summary Card`

```sql
-- Channel Risk Summary for Executive Report
SELECT 
    -- Highest risk channel
    (SELECT INITCAP(channel) 
     FROM (
         SELECT channel,
                (CASE WHEN 100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0) > 20 THEN 30 ELSE 0 END +
                 CASE WHEN AVG(confidence) < 0.7 THEN 20 ELSE 0 END) AS risk
         FROM analytics_events
         WHERE date >= CURRENT_DATE - INTERVAL '7 days'
         GROUP BY channel
     ) x ORDER BY risk DESC LIMIT 1
    ) AS "Highest Risk Channel",
    
    -- Channel with best performance
    (SELECT INITCAP(channel) 
     FROM (
         SELECT channel,
                100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0) AS resolution
         FROM analytics_events
         WHERE date >= CURRENT_DATE - INTERVAL '7 days'
         GROUP BY channel
     ) x ORDER BY resolution DESC LIMIT 1
    ) AS "Best Performing Channel",
    
    -- Overall channel health
    CASE 
        WHEN (SELECT AVG(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0)) 
              FROM analytics_events 
              WHERE date >= CURRENT_DATE - INTERVAL '7 days' 
              GROUP BY channel) > 20 THEN 'Attention Needed'
        ELSE 'Healthy'
    END AS "Overall Channel Health";
```

### Channel Risk Report Section

```
╔═══════════════════════════════════════════════════════════════════════╗
║  CHANNEL RISK ANALYSIS                                                 ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Channel    │ Volume │ Resolution │ Escalation │ Risk   │ Status      ║
║  ───────────┼────────┼────────────┼────────────┼────────┼─────────────║
║  Voice      │  892   │   78.1%    │   21.9%    │  55    │ 🟡 MODERATE ║
║  Chat       │ 1,847  │   86.4%    │   13.6%    │  20    │ 🟢 LOW RISK ║
║  WhatsApp   │  508   │   89.2%    │   10.8%    │  15    │ ✅ HEALTHY  ║
║                                                                        ║
║  ⚠️  RISK ALERT: Voice Channel                                         ║
║  ─────────────────────────────────────────────────────────────────────║
║  Primary Risk: Escalation rate (21.9%) exceeds 15% target              ║
║  Trend: Escalation increased 3.2pp from last week                      ║
║  Impact: 196 customers required human escalation                       ║
║                                                                        ║
║  RECOMMENDED ACTION:                                                   ║
║  1. Review voice-specific intent recognition accuracy                  ║
║  2. Analyze peak escalation hours (see heatmap)                        ║
║  3. Consider additional voice agent training data                      ║
║                                                                        ║
╚═══════════════════════════════════════════════════════════════════════╝
```

| Chart Type | **Risk Matrix / Quadrant Chart** |
|------------|----------------------------------|
| X-Axis | Volume (low to high) |
| Y-Axis | Risk Score (low to high) |
| Bubbles | Channel (size = escalation count) |
| Quadrants | Monitor, Watch, Manage, Critical |

---

## 8. Executive Recommendations

### 8.1 Automated Recommendations Query

**Query Name:** `[REPORT] Executive Recommendations - Auto-Generated`

```sql
-- Generate Executive Recommendations Based on Data
WITH metrics AS (
    SELECT 
        -- Overall metrics
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 1) AS resolution_rate,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 1) AS escalation_rate,
        ROUND(AVG(confidence), 3) AS avg_confidence,
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        
        -- By channel
        ROUND(100.0 * COUNT(*) FILTER (WHERE channel = 'voice' AND escalated = TRUE) / 
              NULLIF(COUNT(*) FILTER (WHERE channel = 'voice'), 0), 1) AS voice_escalation,
        ROUND(100.0 * COUNT(*) FILTER (WHERE channel = 'chat' AND escalated = TRUE) / 
              NULLIF(COUNT(*) FILTER (WHERE channel = 'chat'), 0), 1) AS chat_escalation,
              
        -- By time
        ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_business_hours AND escalated = TRUE) / 
              NULLIF(COUNT(*) FILTER (WHERE NOT is_business_hours), 0), 1) AS afterhours_escalation
              
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'
),
recommendations AS (
    SELECT 
        1 AS priority,
        'CRITICAL' AS severity,
        'Escalation Rate Above Target' AS issue,
        'Overall escalation rate of ' || escalation_rate || '% exceeds 15% target' AS detail,
        'Review AI training data and escalation rules' AS action
    FROM metrics WHERE escalation_rate > 20
    
    UNION ALL
    
    SELECT 
        2,
        'HIGH',
        'Voice Channel Performance',
        'Voice escalation at ' || voice_escalation || '%, significantly above chat (' || chat_escalation || '%)',
        'Investigate voice recognition accuracy and consider voice-specific improvements'
    FROM metrics WHERE voice_escalation > chat_escalation + 5
    
    UNION ALL
    
    SELECT 
        3,
        'MEDIUM',
        'AI Confidence Below Target',
        'Average confidence at ' || avg_confidence || ', below 0.75 target',
        'Review intent classification model and expand training data'
    FROM metrics WHERE avg_confidence < 0.75
    
    UNION ALL
    
    SELECT 
        4,
        'MEDIUM',
        'After-Hours Escalation Elevated',
        'After-hours escalation rate at ' || afterhours_escalation || '%',
        'Consider expanding after-hours AI capabilities or staffing'
    FROM metrics WHERE afterhours_escalation > 25
    
    UNION ALL
    
    SELECT 
        5,
        'LOW',
        'Complaint to Lead Ratio',
        complaints || ' complaints vs ' || leads || ' leads this week',
        'Monitor complaint trends and customer feedback'
    FROM metrics WHERE complaints::FLOAT / NULLIF(leads, 0) > 0.25
    
    UNION ALL
    
    SELECT 
        10,
        'POSITIVE',
        'Strong Performance Areas',
        'Resolution rate at ' || resolution_rate || '% - meeting targets',
        'Maintain current approach and document best practices'
    FROM metrics WHERE resolution_rate >= 80
)
SELECT 
    priority AS "#",
    severity AS "Severity",
    issue AS "Issue",
    detail AS "Details",
    action AS "Recommended Action"
FROM recommendations
ORDER BY 
    CASE severity 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        WHEN 'LOW' THEN 4 
        ELSE 5 
    END,
    priority
LIMIT 6;
```

### Executive Recommendations Section

```
╔═══════════════════════════════════════════════════════════════════════╗
║  EXECUTIVE RECOMMENDATIONS                                             ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  🔴 CRITICAL ACTIONS (This Week)                                       ║
║  ─────────────────────────────────────────────────────────────────────║
║                                                                        ║
║  1. Voice Channel Escalation                                           ║
║     Issue: Voice escalation rate (21.9%) significantly exceeds target  ║
║     Impact: ~200 customers/week require human intervention             ║
║     Action: Commission voice AI accuracy audit within 5 business days  ║
║     Owner: CTO / AI Team                                               ║
║                                                                        ║
║  ─────────────────────────────────────────────────────────────────────║
║  🟡 HIGH PRIORITY (Next 2 Weeks)                                       ║
║  ─────────────────────────────────────────────────────────────────────║
║                                                                        ║
║  2. Support Agent Performance                                          ║
║     Issue: Support agent quality score 58/100 (lowest performer)       ║
║     Impact: Contributing 40% of total escalations                      ║
║     Action: Review support intent model; expand FAQ training data      ║
║     Owner: AI Team / Product                                           ║
║                                                                        ║
║  3. After-Hours Coverage                                               ║
║     Issue: After-hours escalation rate 28% vs 14% during business hrs  ║
║     Impact: Customer experience degraded outside 9AM-6PM               ║
║     Action: Evaluate 24/7 human backup staffing ROI                    ║
║     Owner: COO / Operations                                            ║
║                                                                        ║
║  ─────────────────────────────────────────────────────────────────────║
║  ✅ POSITIVE HIGHLIGHTS                                                ║
║  ─────────────────────────────────────────────────────────────────────║
║                                                                        ║
║  • WhatsApp channel achieving 89% resolution rate (best performer)     ║
║  • Lead generation up 8.7% week-over-week                              ║
║  • Complaint ratio improved from 35% to 28%                            ║
║  • Chat confidence score reached 0.81 (above target)                   ║
║                                                                        ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Recommendation Priority Matrix

| Severity | Response Time | Escalation To |
|----------|---------------|---------------|
| 🔴 CRITICAL | Within 48 hours | CEO, CTO |
| 🟡 HIGH | Within 1 week | CTO, COO |
| 🟠 MEDIUM | Within 2 weeks | Directors |
| 🟢 LOW | Next sprint | Team Leads |
| ✅ POSITIVE | Celebrate | All Teams |

---

## 9. Report Generation Guide

### 9.1 Metabase Report Setup

1. **Create Dashboard:** `[REPORT] AI Quality Score - Weekly`
2. **Add Questions:** Each SQL query as a saved question
3. **Configure Subscriptions:**
   ```
   Recipients: ceo@janssen.com, coo@janssen.com, cto@janssen.com
   Schedule: Weekly on Monday at 8:00 AM
   Format: PDF attachment + inline preview
   ```

### 9.2 PDF Export Settings

```yaml
report_settings:
  paper_size: A4
  orientation: portrait
  margins: 1 inch
  header: "Janssen AI - Quality Score Report"
  footer: "Confidential - For Internal Use Only"
  logo: /assets/janssen-logo.png
  
sections:
  - ai_quality_score_summary
  - kpi_comparison_table
  - weakest_agent_card
  - escalation_reasons_chart
  - channel_risk_matrix
  - executive_recommendations
```

### 9.3 Email Template

```html
Subject: [Janssen AI] Weekly Quality Report - Score: {{score}}/100 ({{grade}})

Hi Team,

Please find attached the AI Quality Score Report for the week of {{week_start}} - {{week_end}}.

QUICK SUMMARY:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AI Quality Score:     {{score}}/100 ({{grade}})
Resolution Rate:      {{resolution_rate}}% ({{resolution_trend}})
Escalation Rate:      {{escalation_rate}}% ({{escalation_trend}})
Leads Generated:      {{leads}} ({{leads_trend}})

TOP PRIORITY:
{{#if critical_issues}}
🔴 {{critical_issue_summary}}
{{else}}
✅ No critical issues this week
{{/if}}

Full report attached as PDF.

Best regards,
Janssen AI Operations
```

### 9.4 Scheduling Queries

```sql
-- Query to generate report metadata
SELECT 
    CURRENT_DATE AS report_date,
    CURRENT_DATE - INTERVAL '7 days' AS period_start,
    CURRENT_DATE - INTERVAL '1 day' AS period_end,
    'Weekly' AS report_type,
    (SELECT ROUND(/* AI Quality Score calculation */, 1)) AS quality_score,
    (SELECT /* Grade calculation */) AS grade;
```

---

## Appendix A: Quick Reference

### KPI Targets

| KPI | Target | Warning | Critical |
|-----|--------|---------|----------|
| AI Quality Score | ≥75 | 60-74 | <60 |
| Resolution Rate | ≥85% | 75-84% | <75% |
| Escalation Rate | ≤15% | 15-20% | >20% |
| Avg Confidence | ≥0.75 | 0.65-0.74 | <0.65 |
| Lead Rate | ≥10% | 5-9% | <5% |
| Complaint Ratio | ≤20% | 20-35% | >35% |

### Report Distribution

| Report | Frequency | Recipients |
|--------|-----------|------------|
| Weekly Quality Report | Monday 8 AM | Ops Team, Directors |
| Monthly Quality Report | 1st of month | C-Suite |
| Critical Alert | Immediate | CEO, CTO, COO |

### Glossary

| Term | Definition |
|------|------------|
| **Resolution Rate** | % of interactions handled without human escalation |
| **Escalation Rate** | % of interactions requiring human agent |
| **Confidence** | AI's certainty in its response (0-1 scale) |
| **Lead Rate** | % of interactions resulting in sales lead |
| **Complaint Ratio** | Complaints per 100 leads generated |
| **Risk Score** | Composite metric indicating channel health (0-100) |

---

*Report Template Version 1.0.0*  
*Janssen AI Operations Team*  
*Contact: ai-ops@janssen.com*
