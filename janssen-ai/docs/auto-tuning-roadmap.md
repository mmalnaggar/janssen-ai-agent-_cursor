# Janssen AI - Auto-Tuning System Roadmap

> **Document Type:** Technical Roadmap & Design Specification  
> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Status:** Design Phase  
> **Owner:** AI Engineering Team

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Performance Degradation Detection](#3-performance-degradation-detection)
4. [Threshold Definitions](#4-threshold-definitions)
5. [Decision Matrix](#5-decision-matrix)
6. [Recommendation Schema](#6-recommendation-schema)
7. [Apply Modes](#7-apply-modes)
8. [n8n Workflow Design](#8-n8n-workflow-design)
9. [Example Tuning Events](#9-example-tuning-events)
10. [Governance & Safety Rules](#10-governance--safety-rules)
11. [Implementation Phases](#11-implementation-phases)

---

## 1. Executive Summary

### Purpose

The Auto-Tuning System continuously monitors AI performance through `analytics_events` and generates actionable recommendations when degradation is detected. This enables proactive optimization without manual monitoring.

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Non-Invasive** | Never directly modifies agents or flows |
| **Observable** | All decisions logged and auditable |
| **Gradual** | Recommendations escalate from manual → semi-auto → auto |
| **Safe** | Multiple safeguards prevent harmful changes |
| **Data-Driven** | All decisions based on statistical evidence |

### System Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AUTO-TUNING SYSTEM                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │   DETECT     │───▶│   ANALYZE    │───▶│  RECOMMEND   │              │
│  │  Degradation │    │   Signals    │    │   Actions    │              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│         │                   │                   │                       │
│         ▼                   ▼                   ▼                       │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │ analytics_   │    │  Decision    │    │    Apply     │              │
│  │ events table │    │   Matrix     │    │    Mode      │              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│                                                │                        │
│                           ┌────────────────────┼────────────────────┐   │
│                           ▼                    ▼                    ▼   │
│                      ┌────────┐          ┌──────────┐         ┌──────┐ │
│                      │ MANUAL │          │SEMI-AUTO │         │ AUTO │ │
│                      │ Review │          │ Approve  │         │ Apply│ │
│                      └────────┘          └──────────┘         └──────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. System Architecture

### Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │ analytics_events│  │ tuning_signals  │  │ tuning_actions  │         │
│  │ (existing)      │  │ (new table)     │  │ (new table)     │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
├─────────────────────────────────────────────────────────────────────────┤
│                           PROCESSING LAYER                              │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                    n8n WORKFLOW                              │       │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │       │
│  │  │ Schedule │─▶│ Detect   │─▶│ Evaluate │─▶│ Generate │    │       │
│  │  │ Trigger  │  │ Signals  │  │ Matrix   │  │ Recommend│    │       │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │       │
│  │                                                │             │       │
│  │                                                ▼             │       │
│  │                                         ┌──────────┐        │       │
│  │                                         │  Route   │        │       │
│  │                                         │  Action  │        │       │
│  │                                         └──────────┘        │       │
│  └─────────────────────────────────────────────────────────────┘       │
├─────────────────────────────────────────────────────────────────────────┤
│                           OUTPUT LAYER                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐            │
│  │ Dashboard │  │   Email   │  │   Slack   │  │   Ticket  │            │
│  │  Alert    │  │   Alert   │  │   Alert   │  │  Creation │            │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘            │
└─────────────────────────────────────────────────────────────────────────┘
```

### New Database Tables

```sql
-- ============================================================================
-- TUNING SIGNALS TABLE
-- Stores detected performance degradation signals
-- ============================================================================

CREATE TABLE IF NOT EXISTS tuning_signals (
    id SERIAL PRIMARY KEY,
    
    -- Signal identification
    signal_id UUID DEFAULT gen_random_uuid(),
    signal_type VARCHAR(50) NOT NULL,
    signal_category VARCHAR(30) NOT NULL,
    
    -- Detection context
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detection_window_start TIMESTAMP NOT NULL,
    detection_window_end TIMESTAMP NOT NULL,
    
    -- Affected scope
    affected_agent VARCHAR(30) NULL,
    affected_channel VARCHAR(20) NULL,
    affected_event_type VARCHAR(30) NULL,
    
    -- Signal metrics
    current_value DECIMAL(10,4) NOT NULL,
    baseline_value DECIMAL(10,4) NOT NULL,
    threshold_value DECIMAL(10,4) NOT NULL,
    deviation_pct DECIMAL(10,2) NOT NULL,
    
    -- Severity assessment
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    confidence_score DECIMAL(5,4) NOT NULL,
    sample_size INT NOT NULL,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'DETECTED' CHECK (status IN ('DETECTED', 'ACKNOWLEDGED', 'ACTIONED', 'RESOLVED', 'IGNORED')),
    
    -- Metadata
    raw_data JSONB NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_tuning_signals_type (signal_type),
    INDEX idx_tuning_signals_severity (severity),
    INDEX idx_tuning_signals_status (status),
    INDEX idx_tuning_signals_detected (detected_at)
);

-- ============================================================================
-- TUNING ACTIONS TABLE
-- Stores generated recommendations and their lifecycle
-- ============================================================================

CREATE TABLE IF NOT EXISTS tuning_actions (
    id SERIAL PRIMARY KEY,
    
    -- Action identification
    action_id UUID DEFAULT gen_random_uuid(),
    signal_id UUID NOT NULL,
    
    -- Action details
    action_type VARCHAR(50) NOT NULL,
    action_category VARCHAR(30) NOT NULL,
    priority INT NOT NULL CHECK (priority BETWEEN 1 AND 5),
    
    -- Recommendation
    recommendation_title VARCHAR(200) NOT NULL,
    recommendation_detail TEXT NOT NULL,
    recommendation_json JSONB NOT NULL,
    
    -- Apply mode
    apply_mode VARCHAR(20) NOT NULL CHECK (apply_mode IN ('MANUAL', 'SEMI_AUTO', 'AUTO')),
    requires_approval BOOLEAN DEFAULT TRUE,
    
    -- Approval workflow
    approved_by VARCHAR(100) NULL,
    approved_at TIMESTAMP NULL,
    approval_notes TEXT NULL,
    
    -- Execution
    executed_at TIMESTAMP NULL,
    execution_result VARCHAR(20) NULL CHECK (execution_result IN ('SUCCESS', 'FAILED', 'PARTIAL', 'ROLLED_BACK')),
    execution_details JSONB NULL,
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXECUTING', 'COMPLETED', 'FAILED', 'ROLLED_BACK')),
    
    -- Safety
    rollback_available BOOLEAN DEFAULT TRUE,
    rollback_executed BOOLEAN DEFAULT FALSE,
    rollback_at TIMESTAMP NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    
    -- Foreign key
    CONSTRAINT fk_tuning_action_signal FOREIGN KEY (signal_id) REFERENCES tuning_signals(signal_id),
    
    -- Indexes
    INDEX idx_tuning_actions_signal (signal_id),
    INDEX idx_tuning_actions_status (status),
    INDEX idx_tuning_actions_mode (apply_mode),
    INDEX idx_tuning_actions_priority (priority)
);

-- ============================================================================
-- TUNING AUDIT LOG
-- Immutable audit trail for all tuning activities
-- ============================================================================

CREATE TABLE IF NOT EXISTS tuning_audit_log (
    id SERIAL PRIMARY KEY,
    
    -- Reference
    action_id UUID NOT NULL,
    signal_id UUID NOT NULL,
    
    -- Event
    event_type VARCHAR(50) NOT NULL,
    event_detail TEXT NOT NULL,
    event_data JSONB NULL,
    
    -- Actor
    actor_type VARCHAR(20) NOT NULL CHECK (actor_type IN ('SYSTEM', 'USER', 'APPROVAL_FLOW')),
    actor_id VARCHAR(100) NULL,
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Index
    INDEX idx_tuning_audit_action (action_id),
    INDEX idx_tuning_audit_time (created_at)
);
```

---

## 3. Performance Degradation Detection

### 3.1 Detection Signals

| Signal ID | Signal Type | Description | Detection Frequency |
|-----------|-------------|-------------|---------------------|
| `SIG_001` | Confidence Drop | Avg confidence below threshold | Hourly |
| `SIG_002` | Escalation Spike | Escalation rate exceeds threshold | Hourly |
| `SIG_003` | Resolution Decline | Resolution rate drops | Every 4 hours |
| `SIG_004` | Complaint Surge | Complaint ratio increases | Daily |
| `SIG_005` | Agent Degradation | Single agent performance drop | Every 4 hours |
| `SIG_006` | Channel Anomaly | Channel-specific issues | Hourly |
| `SIG_007` | Time-Based Pattern | Recurring degradation patterns | Daily |
| `SIG_008` | Volume Anomaly | Unexpected traffic patterns | Hourly |

### 3.2 Detection Queries

#### SIG_001: Confidence Drop Detection

```sql
-- Detect confidence degradation
-- Compares current hour vs 7-day baseline for same hour

WITH current_metrics AS (
    SELECT 
        agent_used,
        channel,
        AVG(confidence) AS current_confidence,
        COUNT(*) AS sample_size
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '1 hour'
    GROUP BY agent_used, channel
    HAVING COUNT(*) >= 20  -- Minimum sample size
),
baseline_metrics AS (
    SELECT 
        agent_used,
        channel,
        AVG(confidence) AS baseline_confidence,
        STDDEV(confidence) AS baseline_stddev
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '7 days'
      AND timestamp < NOW() - INTERVAL '1 hour'
      AND EXTRACT(HOUR FROM timestamp) = EXTRACT(HOUR FROM NOW())
    GROUP BY agent_used, channel
)
SELECT 
    'SIG_001' AS signal_type,
    'CONFIDENCE_DROP' AS signal_category,
    cm.agent_used AS affected_agent,
    cm.channel AS affected_channel,
    cm.current_confidence AS current_value,
    bm.baseline_confidence AS baseline_value,
    CASE 
        WHEN cm.agent_used = 'sales' THEN 0.70
        WHEN cm.channel = 'voice' THEN 0.70
        ELSE 0.65
    END AS threshold_value,
    ROUND(((bm.baseline_confidence - cm.current_confidence) / bm.baseline_confidence) * 100, 2) AS deviation_pct,
    cm.sample_size,
    
    -- Severity calculation
    CASE 
        WHEN cm.current_confidence < 0.50 THEN 'CRITICAL'
        WHEN cm.current_confidence < 0.60 THEN 'HIGH'
        WHEN cm.current_confidence < 0.70 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    
    -- Confidence in detection (based on sample size and deviation)
    LEAST(1.0, (cm.sample_size / 100.0) * 
          (ABS(bm.baseline_confidence - cm.current_confidence) / COALESCE(bm.baseline_stddev, 0.1))) AS confidence_score
    
FROM current_metrics cm
JOIN baseline_metrics bm ON cm.agent_used = bm.agent_used AND cm.channel = bm.channel
WHERE cm.current_confidence < bm.baseline_confidence - (2 * COALESCE(bm.baseline_stddev, 0.05))
   OR cm.current_confidence < CASE 
        WHEN cm.agent_used = 'sales' THEN 0.70
        WHEN cm.channel = 'voice' THEN 0.70
        ELSE 0.65
      END;
```

#### SIG_002: Escalation Spike Detection

```sql
-- Detect escalation rate spikes
-- Uses statistical outlier detection

WITH hourly_escalation AS (
    SELECT 
        DATE_TRUNC('hour', timestamp) AS hour,
        agent_used,
        channel,
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE escalated = TRUE) AS escalated,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) AS escalation_rate
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '7 days'
    GROUP BY DATE_TRUNC('hour', timestamp), agent_used, channel
    HAVING COUNT(*) >= 10
),
baseline_stats AS (
    SELECT 
        agent_used,
        channel,
        AVG(escalation_rate) AS avg_rate,
        STDDEV(escalation_rate) AS stddev_rate,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY escalation_rate) AS p95_rate
    FROM hourly_escalation
    WHERE hour < NOW() - INTERVAL '1 hour'
    GROUP BY agent_used, channel
),
current_hour AS (
    SELECT 
        agent_used,
        channel,
        escalation_rate,
        total AS sample_size
    FROM hourly_escalation
    WHERE hour = DATE_TRUNC('hour', NOW())
)
SELECT 
    'SIG_002' AS signal_type,
    'ESCALATION_SPIKE' AS signal_category,
    ch.agent_used AS affected_agent,
    ch.channel AS affected_channel,
    ch.escalation_rate AS current_value,
    bs.avg_rate AS baseline_value,
    15.0 AS threshold_value,  -- 15% target
    ROUND(((ch.escalation_rate - bs.avg_rate) / NULLIF(bs.avg_rate, 0)) * 100, 2) AS deviation_pct,
    ch.sample_size,
    
    CASE 
        WHEN ch.escalation_rate > 30 THEN 'CRITICAL'
        WHEN ch.escalation_rate > 25 THEN 'HIGH'
        WHEN ch.escalation_rate > 20 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    
    LEAST(1.0, (ch.sample_size / 50.0) * 
          ((ch.escalation_rate - bs.avg_rate) / COALESCE(bs.stddev_rate, 5))) AS confidence_score
    
FROM current_hour ch
JOIN baseline_stats bs ON ch.agent_used = bs.agent_used AND ch.channel = bs.channel
WHERE ch.escalation_rate > bs.avg_rate + (2 * COALESCE(bs.stddev_rate, 5))
   OR ch.escalation_rate > 20;  -- Absolute threshold
```

#### SIG_003: Resolution Rate Decline

```sql
-- Detect resolution rate decline over 4-hour window

WITH window_metrics AS (
    SELECT 
        agent_used,
        channel,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) AS resolution_rate,
        COUNT(*) AS sample_size
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '4 hours'
    GROUP BY agent_used, channel
    HAVING COUNT(*) >= 50
),
baseline_metrics AS (
    SELECT 
        agent_used,
        channel,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) AS baseline_resolution
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '7 days'
      AND timestamp < NOW() - INTERVAL '4 hours'
    GROUP BY agent_used, channel
)
SELECT 
    'SIG_003' AS signal_type,
    'RESOLUTION_DECLINE' AS signal_category,
    wm.agent_used AS affected_agent,
    wm.channel AS affected_channel,
    wm.resolution_rate AS current_value,
    bm.baseline_resolution AS baseline_value,
    80.0 AS threshold_value,
    ROUND(((bm.baseline_resolution - wm.resolution_rate) / NULLIF(bm.baseline_resolution, 0)) * 100, 2) AS deviation_pct,
    wm.sample_size,
    
    CASE 
        WHEN wm.resolution_rate < 70 THEN 'CRITICAL'
        WHEN wm.resolution_rate < 75 THEN 'HIGH'
        WHEN wm.resolution_rate < 80 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    
    LEAST(1.0, wm.sample_size / 100.0) AS confidence_score
    
FROM window_metrics wm
JOIN baseline_metrics bm ON wm.agent_used = bm.agent_used AND wm.channel = bm.channel
WHERE wm.resolution_rate < bm.baseline_resolution - 5  -- 5pp decline
   OR wm.resolution_rate < 80;  -- Absolute threshold
```

#### SIG_004: Complaint Surge Detection

```sql
-- Detect complaint ratio surge (daily check)

WITH daily_complaints AS (
    SELECT 
        date,
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') / 
            NULLIF(COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED'), 0),
            2
        ) AS complaint_ratio
    FROM analytics_events
    WHERE date >= CURRENT_DATE - INTERVAL '14 days'
    GROUP BY date
),
baseline AS (
    SELECT 
        AVG(complaint_ratio) AS avg_ratio,
        STDDEV(complaint_ratio) AS stddev_ratio
    FROM daily_complaints
    WHERE date < CURRENT_DATE
),
today AS (
    SELECT complaint_ratio, complaints, leads
    FROM daily_complaints
    WHERE date = CURRENT_DATE - INTERVAL '1 day'  -- Yesterday (complete day)
)
SELECT 
    'SIG_004' AS signal_type,
    'COMPLAINT_SURGE' AS signal_category,
    NULL AS affected_agent,
    NULL AS affected_channel,
    t.complaint_ratio AS current_value,
    b.avg_ratio AS baseline_value,
    25.0 AS threshold_value,
    ROUND(((t.complaint_ratio - b.avg_ratio) / NULLIF(b.avg_ratio, 0)) * 100, 2) AS deviation_pct,
    t.complaints + t.leads AS sample_size,
    
    CASE 
        WHEN t.complaint_ratio > 50 THEN 'CRITICAL'
        WHEN t.complaint_ratio > 35 THEN 'HIGH'
        WHEN t.complaint_ratio > 25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    
    LEAST(1.0, (t.complaints + t.leads) / 200.0) AS confidence_score
    
FROM today t, baseline b
WHERE t.complaint_ratio > b.avg_ratio + (2 * COALESCE(b.stddev_ratio, 10))
   OR t.complaint_ratio > 30;
```

#### SIG_005: Agent-Specific Degradation

```sql
-- Detect degradation in a specific agent compared to peers

WITH agent_metrics AS (
    SELECT 
        agent_used,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = FALSE) / NULLIF(COUNT(*), 0), 2) AS resolution_rate,
        ROUND(AVG(confidence), 3) AS avg_confidence,
        COUNT(*) AS sample_size
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '4 hours'
    GROUP BY agent_used
    HAVING COUNT(*) >= 30
),
peer_average AS (
    SELECT 
        AVG(resolution_rate) AS avg_resolution,
        AVG(avg_confidence) AS avg_confidence
    FROM agent_metrics
)
SELECT 
    'SIG_005' AS signal_type,
    'AGENT_DEGRADATION' AS signal_category,
    am.agent_used AS affected_agent,
    NULL AS affected_channel,
    am.resolution_rate AS current_value,
    pa.avg_resolution AS baseline_value,
    pa.avg_resolution - 10 AS threshold_value,  -- 10pp below peer average
    ROUND(((pa.avg_resolution - am.resolution_rate) / NULLIF(pa.avg_resolution, 0)) * 100, 2) AS deviation_pct,
    am.sample_size,
    
    CASE 
        WHEN am.resolution_rate < pa.avg_resolution - 15 THEN 'HIGH'
        WHEN am.resolution_rate < pa.avg_resolution - 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS severity,
    
    LEAST(1.0, am.sample_size / 50.0) AS confidence_score
    
FROM agent_metrics am, peer_average pa
WHERE am.resolution_rate < pa.avg_resolution - 10
   OR am.avg_confidence < pa.avg_confidence - 0.1;
```

#### SIG_006: Channel Anomaly Detection

```sql
-- Detect channel-specific anomalies

WITH channel_hourly AS (
    SELECT 
        channel,
        DATE_TRUNC('hour', timestamp) AS hour,
        COUNT(*) AS volume,
        ROUND(100.0 * COUNT(*) FILTER (WHERE escalated = TRUE) / NULLIF(COUNT(*), 0), 2) AS escalation_rate,
        ROUND(AVG(confidence), 3) AS avg_confidence
    FROM analytics_events
    WHERE timestamp >= NOW() - INTERVAL '24 hours'
    GROUP BY channel, DATE_TRUNC('hour', timestamp)
),
channel_baseline AS (
    SELECT 
        channel,
        AVG(escalation_rate) AS baseline_escalation,
        STDDEV(escalation_rate) AS stddev_escalation,
        AVG(avg_confidence) AS baseline_confidence
    FROM channel_hourly
    WHERE hour < NOW() - INTERVAL '1 hour'
    GROUP BY channel
),
current_hour AS (
    SELECT * FROM channel_hourly
    WHERE hour = DATE_TRUNC('hour', NOW())
)
SELECT 
    'SIG_006' AS signal_type,
    'CHANNEL_ANOMALY' AS signal_category,
    NULL AS affected_agent,
    ch.channel AS affected_channel,
    ch.escalation_rate AS current_value,
    cb.baseline_escalation AS baseline_value,
    cb.baseline_escalation + (2 * COALESCE(cb.stddev_escalation, 5)) AS threshold_value,
    ROUND(((ch.escalation_rate - cb.baseline_escalation) / NULLIF(cb.baseline_escalation, 0)) * 100, 2) AS deviation_pct,
    ch.volume AS sample_size,
    
    CASE 
        WHEN ch.escalation_rate > cb.baseline_escalation + (3 * COALESCE(cb.stddev_escalation, 5)) THEN 'CRITICAL'
        WHEN ch.escalation_rate > cb.baseline_escalation + (2 * COALESCE(cb.stddev_escalation, 5)) THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS severity,
    
    LEAST(1.0, ch.volume / 30.0) AS confidence_score
    
FROM current_hour ch
JOIN channel_baseline cb ON ch.channel = cb.channel
WHERE ch.escalation_rate > cb.baseline_escalation + (2 * COALESCE(cb.stddev_escalation, 5))
   OR ch.avg_confidence < cb.baseline_confidence - 0.1;
```

---

## 4. Threshold Definitions

### 4.1 Global Thresholds

```json
{
  "thresholds": {
    "confidence": {
      "critical": 0.50,
      "high": 0.60,
      "medium": 0.70,
      "target": 0.75,
      "description": "AI confidence score boundaries"
    },
    "escalation_rate": {
      "critical": 30,
      "high": 25,
      "medium": 20,
      "target": 15,
      "unit": "percentage",
      "description": "Percentage of interactions requiring human escalation"
    },
    "resolution_rate": {
      "critical": 70,
      "high": 75,
      "medium": 80,
      "target": 85,
      "unit": "percentage",
      "description": "Percentage of interactions resolved by AI"
    },
    "complaint_ratio": {
      "critical": 50,
      "high": 35,
      "medium": 25,
      "target": 20,
      "unit": "percentage",
      "description": "Complaints per 100 leads"
    }
  }
}
```

### 4.2 Agent-Specific Thresholds

```json
{
  "agent_thresholds": {
    "sales": {
      "confidence_target": 0.75,
      "escalation_max": 12,
      "lead_rate_min": 15,
      "notes": "Sales agent has higher confidence expectations"
    },
    "support": {
      "confidence_target": 0.70,
      "escalation_max": 18,
      "resolution_min": 80,
      "notes": "Support handles complex queries, slightly higher escalation allowed"
    },
    "complaint": {
      "confidence_target": 0.70,
      "escalation_max": 25,
      "resolution_min": 75,
      "notes": "Complaints often require human review"
    },
    "escalation": {
      "confidence_target": 0.65,
      "escalation_max": 40,
      "notes": "Escalation agent intentionally routes to humans"
    }
  }
}
```

### 4.3 Channel-Specific Thresholds

```json
{
  "channel_thresholds": {
    "chat": {
      "confidence_target": 0.75,
      "escalation_max": 15,
      "response_expectation": "immediate",
      "notes": "Chat has highest AI performance expectations"
    },
    "voice": {
      "confidence_target": 0.70,
      "escalation_max": 20,
      "response_expectation": "immediate",
      "notes": "Voice recognition adds complexity; slightly lower thresholds"
    },
    "whatsapp": {
      "confidence_target": 0.75,
      "escalation_max": 12,
      "response_expectation": "within_minutes",
      "notes": "WhatsApp users expect fast, accurate responses"
    }
  }
}
```

### 4.4 Time-Based Threshold Adjustments

```json
{
  "time_adjustments": {
    "business_hours": {
      "hours": "09:00-18:00",
      "days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      "threshold_modifier": 1.0,
      "notes": "Standard thresholds apply"
    },
    "after_hours": {
      "hours": "18:00-09:00",
      "threshold_modifier": 1.15,
      "notes": "15% relaxed thresholds after hours"
    },
    "weekends": {
      "days": ["Saturday", "Sunday"],
      "threshold_modifier": 1.20,
      "notes": "20% relaxed thresholds on weekends"
    }
  }
}
```

---

## 5. Decision Matrix

### 5.1 Signal → Recommendation Mapping

```json
{
  "decision_matrix": [
    {
      "signal_type": "SIG_001",
      "signal_name": "CONFIDENCE_DROP",
      "severity": "CRITICAL",
      "recommendations": [
        {
          "action_type": "ALERT_IMMEDIATE",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Send immediate alert to AI team"
        },
        {
          "action_type": "REVIEW_INTENT_MODEL",
          "priority": 2,
          "apply_mode": "MANUAL",
          "description": "Review intent classification accuracy"
        },
        {
          "action_type": "INCREASE_FALLBACK_RATE",
          "priority": 3,
          "apply_mode": "SEMI_AUTO",
          "description": "Temporarily lower confidence threshold for escalation"
        }
      ]
    },
    {
      "signal_type": "SIG_001",
      "signal_name": "CONFIDENCE_DROP",
      "severity": "HIGH",
      "recommendations": [
        {
          "action_type": "ALERT_TEAM",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Notify AI team via Slack"
        },
        {
          "action_type": "SCHEDULE_REVIEW",
          "priority": 2,
          "apply_mode": "SEMI_AUTO",
          "description": "Schedule model review within 24 hours"
        }
      ]
    },
    {
      "signal_type": "SIG_002",
      "signal_name": "ESCALATION_SPIKE",
      "severity": "CRITICAL",
      "recommendations": [
        {
          "action_type": "ALERT_IMMEDIATE",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Alert operations team immediately"
        },
        {
          "action_type": "SCALE_HUMAN_AGENTS",
          "priority": 2,
          "apply_mode": "SEMI_AUTO",
          "description": "Recommend increasing human agent coverage"
        },
        {
          "action_type": "ANALYZE_ESCALATION_REASONS",
          "priority": 3,
          "apply_mode": "MANUAL",
          "description": "Deep dive into escalation patterns"
        }
      ]
    },
    {
      "signal_type": "SIG_002",
      "signal_name": "ESCALATION_SPIKE",
      "severity": "HIGH",
      "recommendations": [
        {
          "action_type": "ALERT_TEAM",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Notify operations team"
        },
        {
          "action_type": "GENERATE_ESCALATION_REPORT",
          "priority": 2,
          "apply_mode": "AUTO",
          "description": "Generate detailed escalation analysis"
        }
      ]
    },
    {
      "signal_type": "SIG_003",
      "signal_name": "RESOLUTION_DECLINE",
      "severity": "HIGH",
      "recommendations": [
        {
          "action_type": "ALERT_TEAM",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Notify AI team"
        },
        {
          "action_type": "COMPARE_AGENT_PERFORMANCE",
          "priority": 2,
          "apply_mode": "AUTO",
          "description": "Generate agent comparison report"
        },
        {
          "action_type": "REVIEW_TRAINING_DATA",
          "priority": 3,
          "apply_mode": "MANUAL",
          "description": "Review recent training data quality"
        }
      ]
    },
    {
      "signal_type": "SIG_004",
      "signal_name": "COMPLAINT_SURGE",
      "severity": "HIGH",
      "recommendations": [
        {
          "action_type": "ALERT_MANAGEMENT",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Alert senior management"
        },
        {
          "action_type": "ANALYZE_COMPLAINT_PATTERNS",
          "priority": 2,
          "apply_mode": "AUTO",
          "description": "Generate complaint pattern analysis"
        },
        {
          "action_type": "PRODUCT_TEAM_NOTIFICATION",
          "priority": 3,
          "apply_mode": "SEMI_AUTO",
          "description": "Notify product team of potential issues"
        }
      ]
    },
    {
      "signal_type": "SIG_005",
      "signal_name": "AGENT_DEGRADATION",
      "severity": "HIGH",
      "recommendations": [
        {
          "action_type": "ISOLATE_AGENT_ANALYSIS",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Generate agent-specific performance report"
        },
        {
          "action_type": "COMPARE_HISTORICAL",
          "priority": 2,
          "apply_mode": "AUTO",
          "description": "Compare current vs historical agent performance"
        },
        {
          "action_type": "RECOMMEND_RETRAINING",
          "priority": 3,
          "apply_mode": "MANUAL",
          "description": "Evaluate need for agent retraining"
        }
      ]
    },
    {
      "signal_type": "SIG_006",
      "signal_name": "CHANNEL_ANOMALY",
      "severity": "HIGH",
      "recommendations": [
        {
          "action_type": "CHANNEL_DEEP_DIVE",
          "priority": 1,
          "apply_mode": "AUTO",
          "description": "Generate channel-specific analysis"
        },
        {
          "action_type": "CHECK_INTEGRATION_HEALTH",
          "priority": 2,
          "apply_mode": "SEMI_AUTO",
          "description": "Verify channel integration is functioning"
        }
      ]
    }
  ]
}
```

### 5.2 Decision Matrix Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DECISION MATRIX                                   │
├──────────────────┬──────────┬────────────────────────────┬─────────────────┤
│ Signal           │ Severity │ Primary Action             │ Apply Mode      │
├──────────────────┼──────────┼────────────────────────────┼─────────────────┤
│ CONFIDENCE_DROP  │ CRITICAL │ Immediate Alert + Review   │ AUTO + MANUAL   │
│                  │ HIGH     │ Team Alert + Schedule      │ AUTO + SEMI     │
│                  │ MEDIUM   │ Log + Monitor              │ AUTO            │
├──────────────────┼──────────┼────────────────────────────┼─────────────────┤
│ ESCALATION_SPIKE │ CRITICAL │ Alert + Scale + Analyze    │ AUTO + SEMI     │
│                  │ HIGH     │ Alert + Report             │ AUTO            │
│                  │ MEDIUM   │ Log + Weekly Report        │ AUTO            │
├──────────────────┼──────────┼────────────────────────────┼─────────────────┤
│ RESOLUTION_DROP  │ CRITICAL │ Alert + Investigate        │ AUTO + MANUAL   │
│                  │ HIGH     │ Alert + Compare Agents     │ AUTO            │
│                  │ MEDIUM   │ Monitor + Trend Report     │ AUTO            │
├──────────────────┼──────────┼────────────────────────────┼─────────────────┤
│ COMPLAINT_SURGE  │ CRITICAL │ Mgmt Alert + Analysis      │ AUTO + SEMI     │
│                  │ HIGH     │ Alert + Pattern Analysis   │ AUTO            │
│                  │ MEDIUM   │ Product Notification       │ SEMI_AUTO       │
├──────────────────┼──────────┼────────────────────────────┼─────────────────┤
│ AGENT_DEGRADE    │ HIGH     │ Isolate + Compare + Train  │ AUTO + MANUAL   │
│                  │ MEDIUM   │ Monitor + Report           │ AUTO            │
├──────────────────┼──────────┼────────────────────────────┼─────────────────┤
│ CHANNEL_ANOMALY  │ HIGH     │ Deep Dive + Check Health   │ AUTO + SEMI     │
│                  │ MEDIUM   │ Log + Monitor              │ AUTO            │
└──────────────────┴──────────┴────────────────────────────┴─────────────────┘
```

---

## 6. Recommendation Schema

### 6.1 JSON Recommendation Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "TuningRecommendation",
  "type": "object",
  "required": ["recommendation_id", "signal_id", "action_type", "priority", "apply_mode", "details"],
  "properties": {
    "recommendation_id": {
      "type": "string",
      "format": "uuid",
      "description": "Unique identifier for this recommendation"
    },
    "signal_id": {
      "type": "string",
      "format": "uuid",
      "description": "Reference to the triggering signal"
    },
    "action_type": {
      "type": "string",
      "enum": [
        "ALERT_IMMEDIATE",
        "ALERT_TEAM",
        "ALERT_MANAGEMENT",
        "GENERATE_REPORT",
        "SCHEDULE_REVIEW",
        "ANALYZE_PATTERNS",
        "COMPARE_HISTORICAL",
        "CHECK_INTEGRATION",
        "RECOMMEND_RETRAINING",
        "SCALE_RESOURCES",
        "ADJUST_THRESHOLD",
        "CREATE_TICKET"
      ],
      "description": "Type of recommended action"
    },
    "priority": {
      "type": "integer",
      "minimum": 1,
      "maximum": 5,
      "description": "Priority level (1=highest, 5=lowest)"
    },
    "apply_mode": {
      "type": "string",
      "enum": ["MANUAL", "SEMI_AUTO", "AUTO"],
      "description": "How this recommendation should be applied"
    },
    "details": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "maxLength": 200
        },
        "description": {
          "type": "string"
        },
        "rationale": {
          "type": "string",
          "description": "Why this action is recommended"
        },
        "expected_impact": {
          "type": "string",
          "description": "Expected outcome of applying this recommendation"
        },
        "affected_scope": {
          "type": "object",
          "properties": {
            "agents": { "type": "array", "items": { "type": "string" } },
            "channels": { "type": "array", "items": { "type": "string" } },
            "time_range": { "type": "string" }
          }
        }
      },
      "required": ["title", "description"]
    },
    "execution": {
      "type": "object",
      "properties": {
        "target_system": {
          "type": "string",
          "enum": ["EMAIL", "SLACK", "JIRA", "DASHBOARD", "WEBHOOK", "DATABASE"]
        },
        "payload": {
          "type": "object",
          "description": "System-specific execution payload"
        },
        "timeout_seconds": {
          "type": "integer",
          "default": 30
        },
        "retry_count": {
          "type": "integer",
          "default": 3
        }
      }
    },
    "safety": {
      "type": "object",
      "properties": {
        "requires_approval": {
          "type": "boolean",
          "default": true
        },
        "approval_roles": {
          "type": "array",
          "items": { "type": "string" }
        },
        "rollback_available": {
          "type": "boolean",
          "default": false
        },
        "max_auto_executions_per_day": {
          "type": "integer",
          "default": 10
        }
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "created_at": { "type": "string", "format": "date-time" },
        "expires_at": { "type": "string", "format": "date-time" },
        "version": { "type": "string" }
      }
    }
  }
}
```

### 6.2 Example Recommendation Objects

#### Example 1: Critical Alert

```json
{
  "recommendation_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "signal_id": "f0e9d8c7-b6a5-4321-9876-543210fedcba",
  "action_type": "ALERT_IMMEDIATE",
  "priority": 1,
  "apply_mode": "AUTO",
  "details": {
    "title": "Critical: Voice Channel Confidence Dropped Below 50%",
    "description": "Voice channel AI confidence has dropped to 0.47, which is below the critical threshold of 0.50. This indicates potential issues with voice recognition or intent classification.",
    "rationale": "Confidence below 50% means the AI is uncertain about more than half of voice interactions, leading to poor customer experience and potential escalation overload.",
    "expected_impact": "Immediate notification enables rapid response, potentially preventing customer dissatisfaction and operational strain.",
    "affected_scope": {
      "agents": ["sales", "support"],
      "channels": ["voice"],
      "time_range": "Last 1 hour"
    }
  },
  "execution": {
    "target_system": "SLACK",
    "payload": {
      "channel": "#ai-alerts-critical",
      "message": "🚨 *CRITICAL: Voice AI Confidence Drop*\n\nCurrent: 0.47 | Threshold: 0.50\nAffected: Sales, Support agents\n\nImmediate investigation required.",
      "mention": ["@ai-team", "@on-call"]
    },
    "timeout_seconds": 10,
    "retry_count": 3
  },
  "safety": {
    "requires_approval": false,
    "rollback_available": false,
    "max_auto_executions_per_day": 5
  },
  "metadata": {
    "created_at": "2026-01-29T10:30:00Z",
    "expires_at": "2026-01-29T11:30:00Z",
    "version": "1.0.0"
  }
}
```

#### Example 2: Semi-Auto Report Generation

```json
{
  "recommendation_id": "b2c3d4e5-f6a7-8901-bcde-f23456789012",
  "signal_id": "f0e9d8c7-b6a5-4321-9876-543210fedcba",
  "action_type": "GENERATE_REPORT",
  "priority": 2,
  "apply_mode": "SEMI_AUTO",
  "details": {
    "title": "Generate Escalation Pattern Analysis Report",
    "description": "Create detailed analysis of escalation patterns over the past 24 hours to identify root causes of the current spike.",
    "rationale": "Understanding escalation patterns will help identify whether the issue is agent-specific, channel-specific, or systemic.",
    "expected_impact": "Report will provide actionable insights for targeted improvements within 24 hours.",
    "affected_scope": {
      "agents": ["all"],
      "channels": ["voice", "chat"],
      "time_range": "Last 24 hours"
    }
  },
  "execution": {
    "target_system": "DASHBOARD",
    "payload": {
      "report_type": "escalation_analysis",
      "parameters": {
        "time_range": "24h",
        "group_by": ["agent", "channel", "hour"],
        "include_charts": true
      },
      "notify_on_completion": ["ai-team@janssen.com"]
    },
    "timeout_seconds": 120,
    "retry_count": 2
  },
  "safety": {
    "requires_approval": true,
    "approval_roles": ["ai_engineer", "ops_manager"],
    "rollback_available": false,
    "max_auto_executions_per_day": 20
  },
  "metadata": {
    "created_at": "2026-01-29T10:31:00Z",
    "expires_at": "2026-01-30T10:31:00Z",
    "version": "1.0.0"
  }
}
```

#### Example 3: Manual Review Recommendation

```json
{
  "recommendation_id": "c3d4e5f6-a7b8-9012-cdef-345678901234",
  "signal_id": "f0e9d8c7-b6a5-4321-9876-543210fedcba",
  "action_type": "RECOMMEND_RETRAINING",
  "priority": 3,
  "apply_mode": "MANUAL",
  "details": {
    "title": "Consider Retraining Support Agent Intent Model",
    "description": "The Support agent has shown consistent underperformance (resolution rate 71.2% vs peer average 79.5%) over the past week. Review training data and consider model retraining.",
    "rationale": "Support agent handles 35% of total volume. Improvement here would significantly impact overall system performance.",
    "expected_impact": "Retraining could improve resolution rate by 5-8 percentage points based on historical retraining outcomes.",
    "affected_scope": {
      "agents": ["support"],
      "channels": ["all"],
      "time_range": "Ongoing"
    }
  },
  "execution": {
    "target_system": "JIRA",
    "payload": {
      "project": "JANAI",
      "issue_type": "Task",
      "summary": "[Auto-Tuning] Review Support Agent Retraining",
      "description": "Auto-generated recommendation based on performance degradation signal.",
      "labels": ["auto-tuning", "retraining", "support-agent"],
      "assignee": null,
      "priority": "Medium"
    },
    "timeout_seconds": 30,
    "retry_count": 2
  },
  "safety": {
    "requires_approval": true,
    "approval_roles": ["ai_lead", "product_manager"],
    "rollback_available": false,
    "max_auto_executions_per_day": 5
  },
  "metadata": {
    "created_at": "2026-01-29T10:32:00Z",
    "expires_at": "2026-02-05T10:32:00Z",
    "version": "1.0.0"
  }
}
```

---

## 7. Apply Modes

### 7.1 Mode Definitions

#### MANUAL Mode

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MANUAL MODE                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Flow:                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ Detect   │───▶│ Generate │───▶│ Human    │───▶│ Human    │         │
│  │ Signal   │    │ Recommend│    │ Review   │    │ Execute  │         │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘         │
│                                                                         │
│  Characteristics:                                                       │
│  • Recommendation stored in database                                    │
│  • Notification sent to designated reviewers                            │
│  • Human reviews and decides to accept/reject                           │
│  • Human manually executes approved actions                             │
│  • Full audit trail maintained                                          │
│                                                                         │
│  Use Cases:                                                             │
│  • Agent retraining decisions                                           │
│  • Threshold modifications                                              │
│  • Architectural changes                                                │
│  • Any action with business impact                                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### SEMI_AUTO Mode

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SEMI-AUTO MODE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Flow:                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ Detect   │───▶│ Generate │───▶│ Human    │───▶│ System   │         │
│  │ Signal   │    │ Recommend│    │ Approve  │    │ Execute  │         │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘         │
│                                        │                │               │
│                                        │         ┌──────▼──────┐       │
│                                        │         │  Auto       │       │
│                                   [Timeout]      │  Rollback   │       │
│                                        │         │  if failed  │       │
│                                        ▼         └─────────────┘       │
│                                 ┌──────────┐                           │
│                                 │ Escalate │                           │
│                                 │ or Expire│                           │
│                                 └──────────┘                           │
│                                                                         │
│  Characteristics:                                                       │
│  • Recommendation requires human approval                               │
│  • Once approved, system executes automatically                         │
│  • Approval timeout triggers escalation                                 │
│  • Automatic rollback on execution failure                              │
│                                                                         │
│  Use Cases:                                                             │
│  • Scaling human agent coverage                                         │
│  • Generating detailed reports                                          │
│  • Creating support tickets                                             │
│  • Integration health checks                                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### AUTO Mode

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            AUTO MODE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Flow:                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ Detect   │───▶│ Generate │───▶│ Safety   │───▶│ System   │         │
│  │ Signal   │    │ Recommend│    │ Check    │    │ Execute  │         │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘         │
│                                        │                │               │
│                                   [Blocked]      ┌──────▼──────┐       │
│                                        │         │  Audit Log  │       │
│                                        ▼         │  + Notify   │       │
│                                 ┌──────────┐     └─────────────┘       │
│                                 │ Fallback │                           │
│                                 │ to SEMI  │                           │
│                                 └──────────┘                           │
│                                                                         │
│  Characteristics:                                                       │
│  • No human approval required                                           │
│  • Safety checks prevent harmful actions                                │
│  • Rate limits prevent runaway automation                               │
│  • All actions logged for audit                                         │
│  • Notifications sent post-execution                                    │
│                                                                         │
│  Use Cases:                                                             │
│  • Alert notifications                                                  │
│  • Standard report generation                                           │
│  • Logging and monitoring                                               │
│  • Low-risk, high-frequency actions                                     │
│                                                                         │
│  Safety Constraints:                                                    │
│  • Max 10 auto executions per day per action type                       │
│  • Must pass all safety checks                                          │
│  • Cannot modify agents or flows                                        │
│  • Cannot change thresholds                                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Mode Selection Criteria

```json
{
  "mode_selection_rules": {
    "AUTO": {
      "allowed_actions": [
        "ALERT_IMMEDIATE",
        "ALERT_TEAM",
        "GENERATE_REPORT",
        "LOG_EVENT"
      ],
      "conditions": [
        "action_is_reversible OR action_is_notification_only",
        "daily_execution_count < max_auto_executions",
        "severity != 'CRITICAL' OR action_type == 'ALERT_IMMEDIATE'"
      ]
    },
    "SEMI_AUTO": {
      "allowed_actions": [
        "ALERT_MANAGEMENT",
        "SCALE_RESOURCES",
        "CREATE_TICKET",
        "CHECK_INTEGRATION",
        "SCHEDULE_REVIEW"
      ],
      "conditions": [
        "action_has_business_impact",
        "action_requires_resource_allocation",
        "action_creates_external_artifacts"
      ]
    },
    "MANUAL": {
      "required_for_actions": [
        "RECOMMEND_RETRAINING",
        "ADJUST_THRESHOLD",
        "MODIFY_ROUTING",
        "CHANGE_CONFIGURATION"
      ],
      "conditions": [
        "action_affects_ai_behavior",
        "action_has_cost_implications",
        "action_requires_expertise"
      ]
    }
  }
}
```

---

## 8. n8n Workflow Design

### 8.1 Main Auto-Tuning Workflow

```json
{
  "name": "Janssen_AI_Auto_Tuning",
  "description": "Detects AI performance degradation and generates tuning recommendations",
  "version": "1.0.0",
  "nodes": [
    {
      "id": "trigger_schedule",
      "name": "Scheduled_Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "position": [100, 200],
      "parameters": {
        "rule": {
          "interval": [{ "field": "minutes", "minutesInterval": 15 }]
        }
      },
      "notes": "Runs every 15 minutes to detect performance issues"
    },
    
    {
      "id": "detect_signals",
      "name": "Detect_Degradation_Signals",
      "type": "n8n-nodes-base.postgres",
      "position": [300, 200],
      "parameters": {
        "operation": "executeQuery",
        "query": "-- Combined signal detection query\n-- Returns all active signals from detection queries\n-- (Include SIG_001 through SIG_006 queries here)"
      },
      "notes": "Executes all signal detection queries against analytics_events"
    },
    
    {
      "id": "filter_signals",
      "name": "Filter_New_Signals",
      "type": "n8n-nodes-base.function",
      "position": [500, 200],
      "parameters": {
        "functionCode": "// Filter out signals already processed in last hour\nconst items = $input.all();\nconst results = [];\n\nfor (const item of items) {\n  const signal = item.json;\n  \n  // Skip if confidence score too low\n  if (signal.confidence_score < 0.6) continue;\n  \n  // Skip if sample size too small\n  if (signal.sample_size < 20) continue;\n  \n  results.push({ json: signal });\n}\n\nreturn results;"
      }
    },
    
    {
      "id": "store_signals",
      "name": "Store_Signals",
      "type": "n8n-nodes-base.postgres",
      "position": [700, 200],
      "parameters": {
        "operation": "insert",
        "table": "tuning_signals",
        "columns": "signal_type, signal_category, affected_agent, affected_channel, current_value, baseline_value, threshold_value, deviation_pct, severity, confidence_score, sample_size, detection_window_start, detection_window_end"
      }
    },
    
    {
      "id": "lookup_decision_matrix",
      "name": "Lookup_Decision_Matrix",
      "type": "n8n-nodes-base.function",
      "position": [900, 200],
      "parameters": {
        "functionCode": "// Map signals to recommendations using decision matrix\nconst decisionMatrix = $node['Load_Decision_Matrix'].json;\nconst items = $input.all();\nconst recommendations = [];\n\nfor (const item of items) {\n  const signal = item.json;\n  const matrixEntry = decisionMatrix.find(\n    m => m.signal_type === signal.signal_type && \n         m.severity === signal.severity\n  );\n  \n  if (matrixEntry) {\n    for (const rec of matrixEntry.recommendations) {\n      recommendations.push({\n        json: {\n          signal_id: signal.signal_id,\n          ...rec,\n          signal_context: signal\n        }\n      });\n    }\n  }\n}\n\nreturn recommendations;"
      }
    },
    
    {
      "id": "generate_recommendations",
      "name": "Generate_Recommendations",
      "type": "n8n-nodes-base.function",
      "position": [1100, 200],
      "parameters": {
        "functionCode": "// Generate full recommendation objects\nconst items = $input.all();\nconst recommendations = [];\n\nfor (const item of items) {\n  const rec = item.json;\n  const signal = rec.signal_context;\n  \n  const recommendation = {\n    recommendation_id: crypto.randomUUID(),\n    signal_id: rec.signal_id,\n    action_type: rec.action_type,\n    priority: rec.priority,\n    apply_mode: rec.apply_mode,\n    details: {\n      title: generateTitle(rec, signal),\n      description: generateDescription(rec, signal),\n      rationale: generateRationale(rec, signal),\n      expected_impact: rec.expected_impact || 'To be determined',\n      affected_scope: {\n        agents: signal.affected_agent ? [signal.affected_agent] : ['all'],\n        channels: signal.affected_channel ? [signal.affected_channel] : ['all'],\n        time_range: 'Current'\n      }\n    },\n    safety: {\n      requires_approval: rec.apply_mode !== 'AUTO',\n      rollback_available: false,\n      max_auto_executions_per_day: 10\n    },\n    metadata: {\n      created_at: new Date().toISOString(),\n      expires_at: new Date(Date.now() + 24*60*60*1000).toISOString(),\n      version: '1.0.0'\n    }\n  };\n  \n  recommendations.push({ json: recommendation });\n}\n\nfunction generateTitle(rec, signal) {\n  return `${signal.severity}: ${signal.signal_category} - ${rec.action_type}`;\n}\n\nfunction generateDescription(rec, signal) {\n  return `${signal.signal_category} detected. Current: ${signal.current_value}, Baseline: ${signal.baseline_value}, Deviation: ${signal.deviation_pct}%`;\n}\n\nfunction generateRationale(rec, signal) {\n  return `Signal confidence: ${signal.confidence_score}, Sample size: ${signal.sample_size}`;\n}\n\nreturn recommendations;"
      }
    },
    
    {
      "id": "store_recommendations",
      "name": "Store_Recommendations",
      "type": "n8n-nodes-base.postgres",
      "position": [1300, 200],
      "parameters": {
        "operation": "insert",
        "table": "tuning_actions",
        "columns": "action_id, signal_id, action_type, action_category, priority, recommendation_title, recommendation_detail, recommendation_json, apply_mode, requires_approval"
      }
    },
    
    {
      "id": "route_by_mode",
      "name": "Route_By_Apply_Mode",
      "type": "n8n-nodes-base.switch",
      "position": [1500, 200],
      "parameters": {
        "rules": {
          "rules": [
            { "value": "AUTO", "output": 0 },
            { "value": "SEMI_AUTO", "output": 1 },
            { "value": "MANUAL", "output": 2 }
          ]
        },
        "fallbackOutput": 2,
        "dataPropertyName": "apply_mode"
      }
    },
    
    {
      "id": "auto_execute",
      "name": "Auto_Execute_Actions",
      "type": "n8n-nodes-base.function",
      "position": [1700, 100],
      "parameters": {
        "functionCode": "// Execute AUTO mode actions\nconst items = $input.all();\nconst results = [];\n\nfor (const item of items) {\n  const rec = item.json;\n  \n  // Safety checks\n  if (!checkSafetyLimits(rec)) {\n    results.push({\n      json: { ...rec, execution_result: 'BLOCKED_SAFETY', status: 'FAILED' }\n    });\n    continue;\n  }\n  \n  // Execute based on action type\n  let result;\n  switch (rec.action_type) {\n    case 'ALERT_IMMEDIATE':\n    case 'ALERT_TEAM':\n      result = { status: 'PENDING_NOTIFICATION' };\n      break;\n    case 'GENERATE_REPORT':\n      result = { status: 'PENDING_REPORT' };\n      break;\n    default:\n      result = { status: 'LOGGED' };\n  }\n  \n  results.push({\n    json: { ...rec, execution_result: 'SUCCESS', ...result }\n  });\n}\n\nfunction checkSafetyLimits(rec) {\n  // Check daily execution limits\n  // (In production, query tuning_actions for today's count)\n  return true;\n}\n\nreturn results;"
      }
    },
    
    {
      "id": "send_notifications",
      "name": "Send_Notifications",
      "type": "n8n-nodes-base.slack",
      "position": [1900, 100],
      "parameters": {
        "channel": "={{ $json.severity === 'CRITICAL' ? '#ai-alerts-critical' : '#ai-alerts' }}",
        "text": "={{ $json.details.title }}\n\n{{ $json.details.description }}\n\nPriority: {{ $json.priority }}\nMode: {{ $json.apply_mode }}"
      },
      "continueOnFail": true
    },
    
    {
      "id": "semi_auto_approval",
      "name": "Request_Approval",
      "type": "n8n-nodes-base.slack",
      "position": [1700, 200],
      "parameters": {
        "channel": "#ai-tuning-approvals",
        "text": "🔔 *Approval Required*\n\n*{{ $json.details.title }}*\n\n{{ $json.details.description }}\n\nPriority: {{ $json.priority }}\n\nReact with ✅ to approve or ❌ to reject."
      }
    },
    
    {
      "id": "manual_notification",
      "name": "Manual_Review_Notification",
      "type": "n8n-nodes-base.email",
      "position": [1700, 300],
      "parameters": {
        "to": "ai-team@janssen.com",
        "subject": "[Auto-Tuning] Manual Review Required: {{ $json.details.title }}",
        "text": "A manual review is required for the following recommendation:\n\n{{ $json.details.description }}\n\nPlease review in the tuning dashboard."
      }
    },
    
    {
      "id": "update_status",
      "name": "Update_Action_Status",
      "type": "n8n-nodes-base.postgres",
      "position": [2100, 200],
      "parameters": {
        "operation": "update",
        "table": "tuning_actions",
        "updateKey": "action_id",
        "columns": "status, executed_at, execution_result"
      }
    },
    
    {
      "id": "audit_log",
      "name": "Write_Audit_Log",
      "type": "n8n-nodes-base.postgres",
      "position": [2300, 200],
      "parameters": {
        "operation": "insert",
        "table": "tuning_audit_log",
        "columns": "action_id, signal_id, event_type, event_detail, actor_type"
      }
    }
  ],
  
  "connections": {
    "Scheduled_Trigger": { "main": [[{ "node": "Detect_Degradation_Signals" }]] },
    "Detect_Degradation_Signals": { "main": [[{ "node": "Filter_New_Signals" }]] },
    "Filter_New_Signals": { "main": [[{ "node": "Store_Signals" }]] },
    "Store_Signals": { "main": [[{ "node": "Lookup_Decision_Matrix" }]] },
    "Lookup_Decision_Matrix": { "main": [[{ "node": "Generate_Recommendations" }]] },
    "Generate_Recommendations": { "main": [[{ "node": "Store_Recommendations" }]] },
    "Store_Recommendations": { "main": [[{ "node": "Route_By_Apply_Mode" }]] },
    "Route_By_Apply_Mode": {
      "main": [
        [{ "node": "Auto_Execute_Actions" }],
        [{ "node": "Request_Approval" }],
        [{ "node": "Manual_Review_Notification" }]
      ]
    },
    "Auto_Execute_Actions": { "main": [[{ "node": "Send_Notifications" }]] },
    "Send_Notifications": { "main": [[{ "node": "Update_Action_Status" }]] },
    "Request_Approval": { "main": [[{ "node": "Update_Action_Status" }]] },
    "Manual_Review_Notification": { "main": [[{ "node": "Update_Action_Status" }]] },
    "Update_Action_Status": { "main": [[{ "node": "Write_Audit_Log" }]] }
  }
}
```

---

## 9. Example Tuning Events

### 9.1 Scenario: Voice Confidence Drop

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TUNING EVENT EXAMPLE #1                              │
│                   Voice Confidence Drop                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  DETECTION (10:15 AM)                                                   │
│  ─────────────────────────────────────────────────────────────────────  │
│  Signal: SIG_001 (CONFIDENCE_DROP)                                      │
│  Severity: HIGH                                                         │
│  Scope: Voice channel, Sales agent                                      │
│  Current Value: 0.62                                                    │
│  Baseline: 0.78                                                         │
│  Deviation: -20.5%                                                      │
│  Sample Size: 87 interactions                                           │
│  Confidence: 0.89                                                       │
│                                                                         │
│  RECOMMENDATIONS GENERATED                                              │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. [AUTO] Alert AI Team via Slack                                      │
│  2. [SEMI_AUTO] Generate Voice Performance Report                       │
│  3. [MANUAL] Review Voice Recognition Model                             │
│                                                                         │
│  EXECUTION LOG                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│  10:15:02 - Signal detected and stored                                  │
│  10:15:03 - 3 recommendations generated                                 │
│  10:15:04 - [AUTO] Slack alert sent to #ai-alerts                       │
│  10:15:05 - [SEMI_AUTO] Approval requested in #ai-tuning-approvals      │
│  10:15:06 - [MANUAL] Email sent to ai-team@janssen.com                  │
│  10:23:41 - [SEMI_AUTO] Approved by @john.smith                         │
│  10:23:42 - Report generation initiated                                 │
│  10:25:18 - Report generated and distributed                            │
│  10:45:00 - [MANUAL] Ticket created: JANAI-1234                         │
│                                                                         │
│  OUTCOME                                                                │
│  ─────────────────────────────────────────────────────────────────────  │
│  Root cause identified: Recent voice prompt changes                     │
│  Resolution: Prompt rollback + targeted retraining                      │
│  Time to detect: 15 minutes                                             │
│  Time to resolve: 4 hours                                               │
│  Impact avoided: ~300 poor customer interactions                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Scenario: Escalation Spike

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TUNING EVENT EXAMPLE #2                              │
│                   Escalation Rate Spike                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  DETECTION (2:30 PM)                                                    │
│  ─────────────────────────────────────────────────────────────────────  │
│  Signal: SIG_002 (ESCALATION_SPIKE)                                     │
│  Severity: CRITICAL                                                     │
│  Scope: All channels, Support agent                                     │
│  Current Value: 32%                                                     │
│  Baseline: 16%                                                          │
│  Threshold: 25%                                                         │
│  Deviation: +100%                                                       │
│  Sample Size: 156 interactions                                          │
│  Confidence: 0.95                                                       │
│                                                                         │
│  RECOMMENDATIONS GENERATED                                              │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. [AUTO] CRITICAL Alert to Operations                                 │
│  2. [SEMI_AUTO] Scale Human Agent Coverage                              │
│  3. [AUTO] Generate Escalation Pattern Analysis                         │
│  4. [MANUAL] Deep Dive Investigation                                    │
│                                                                         │
│  EXECUTION LOG                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│  14:30:01 - Signal detected - CRITICAL severity                         │
│  14:30:02 - [AUTO] Slack alert sent to #ai-alerts-critical              │
│  14:30:02 - [AUTO] SMS sent to on-call engineer                         │
│  14:30:03 - [SEMI_AUTO] Scaling approval requested                      │
│  14:30:04 - [AUTO] Pattern analysis initiated                           │
│  14:32:15 - [SEMI_AUTO] Approved by @ops.manager                        │
│  14:32:16 - Human agent pool increased by 2                             │
│  14:35:00 - Pattern analysis complete                                   │
│  14:35:01 - Root cause identified: Product recall queries               │
│                                                                         │
│  PATTERN ANALYSIS FINDINGS                                              │
│  ─────────────────────────────────────────────────────────────────────  │
│  • 78% of escalations contained keyword "recall"                        │
│  • New product recall announced at 2:00 PM                              │
│  • AI not trained on recall procedures                                  │
│  • Customers frustrated by AI responses                                 │
│                                                                         │
│  OUTCOME                                                                │
│  ─────────────────────────────────────────────────────────────────────  │
│  Immediate: Human agents handled recall queries                         │
│  Short-term: FAQ updated with recall information                        │
│  Long-term: Recall handling added to training data                      │
│  Time to detect: 30 minutes after recall announcement                   │
│  Customer impact: Minimized through rapid scaling                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 9.3 Scenario: Gradual Agent Degradation

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TUNING EVENT EXAMPLE #3                              │
│                 Gradual Agent Degradation                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  DETECTION (Daily Analysis - 6:00 AM)                                   │
│  ─────────────────────────────────────────────────────────────────────  │
│  Signal: SIG_005 (AGENT_DEGRADATION)                                    │
│  Severity: MEDIUM                                                       │
│  Scope: Complaint agent                                                 │
│  Current Resolution: 72%                                                │
│  Peer Average: 81%                                                      │
│  Historical (30d ago): 79%                                              │
│  Trend: -7pp over 30 days                                               │
│  Confidence: 0.87                                                       │
│                                                                         │
│  PATTERN ANALYSIS                                                       │
│  ─────────────────────────────────────────────────────────────────────  │
│  Week 1: 79% → Week 2: 77% → Week 3: 75% → Week 4: 72%                  │
│  Gradual decline suggests model drift, not sudden issue                 │
│                                                                         │
│  RECOMMENDATIONS GENERATED                                              │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. [AUTO] Generate Agent Performance Comparison Report                 │
│  2. [AUTO] Alert AI Team (non-urgent)                                   │
│  3. [MANUAL] Evaluate Retraining Need                                   │
│  4. [MANUAL] Review Training Data Freshness                             │
│                                                                         │
│  INVESTIGATION FINDINGS                                                 │
│  ─────────────────────────────────────────────────────────────────────  │
│  • Training data last updated 45 days ago                               │
│  • New complaint categories emerged (delivery issues)                   │
│  • Model not aware of new product line                                  │
│  • Competitor mentions increasing (not in training)                     │
│                                                                         │
│  RETRAINING PLAN (Manual Approval Required)                             │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. Collect last 30 days of complaint interactions                      │
│  2. Label new complaint categories                                      │
│  3. Add delivery-related training examples                              │
│  4. Include new product information                                     │
│  5. Retrain model with updated dataset                                  │
│  6. A/B test before full deployment                                     │
│                                                                         │
│  EXPECTED OUTCOME                                                       │
│  ─────────────────────────────────────────────────────────────────────  │
│  Resolution rate improvement: +5-8pp                                    │
│  Timeline: 2 weeks for retraining cycle                                 │
│  Cost: Standard retraining (included in ops budget)                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Governance & Safety Rules

### 10.1 Core Safety Principles

```json
{
  "safety_principles": {
    "principle_1": {
      "name": "No Direct Agent Modification",
      "description": "Auto-tuning system NEVER directly modifies agent configurations, prompts, or models",
      "enforcement": "All agent modifications require manual human action outside this system"
    },
    "principle_2": {
      "name": "No Flow Modification",
      "description": "Auto-tuning system NEVER modifies unified-agent-flow.json or any workflow files",
      "enforcement": "Flow changes require separate change management process"
    },
    "principle_3": {
      "name": "Recommendation Only",
      "description": "System generates recommendations; humans make decisions",
      "enforcement": "All modifications tracked in tuning_actions with human approval"
    },
    "principle_4": {
      "name": "Audit Everything",
      "description": "Every signal, recommendation, and action is logged immutably",
      "enforcement": "tuning_audit_log table with no DELETE permissions"
    },
    "principle_5": {
      "name": "Fail Safe",
      "description": "On any error, system fails to safe state (no action)",
      "enforcement": "All n8n nodes have continueOnFail with safe defaults"
    }
  }
}
```

### 10.2 Rate Limits & Safeguards

```json
{
  "rate_limits": {
    "auto_executions": {
      "per_action_type_per_day": 10,
      "total_per_day": 50,
      "per_hour": 10
    },
    "notifications": {
      "critical_alerts_per_hour": 5,
      "team_alerts_per_hour": 10,
      "email_per_day": 20
    },
    "approvals": {
      "pending_max": 20,
      "timeout_hours": 24,
      "escalation_after_hours": 4
    }
  },
  "safeguards": {
    "minimum_sample_size": 20,
    "minimum_confidence_score": 0.6,
    "cooldown_after_action_minutes": 30,
    "max_recommendations_per_signal": 5,
    "duplicate_signal_window_hours": 1
  }
}
```

### 10.3 Approval Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       APPROVAL WORKFLOW                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  SEMI_AUTO Actions:                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ Generate │───▶│ Request  │───▶│  Wait    │───▶│ Execute  │         │
│  │ Recommend│    │ Approval │    │ Response │    │ or       │         │
│  └──────────┘    └──────────┘    └──────────┘    │ Escalate │         │
│                                        │         └──────────┘         │
│                                        │                               │
│                              [4 hours timeout]                         │
│                                        │                               │
│                                        ▼                               │
│                                 ┌──────────┐                           │
│                                 │ Escalate │                           │
│                                 │ to Mgmt  │                           │
│                                 └──────────┘                           │
│                                                                         │
│  MANUAL Actions:                                                        │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                         │
│  │ Generate │───▶│ Create   │───▶│ Human    │                         │
│  │ Recommend│    │ Ticket   │    │ Executes │                         │
│  └──────────┘    └──────────┘    └──────────┘                         │
│                                                                         │
│  Approval Roles by Severity:                                            │
│  ─────────────────────────────────────────────────────────────────────  │
│  CRITICAL: CTO, VP Engineering, On-call Lead                            │
│  HIGH: Engineering Manager, Senior Engineer                             │
│  MEDIUM: Any AI Team Member                                             │
│  LOW: Auto-approve after 24h if no objection                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 10.4 Prohibited Actions

```json
{
  "prohibited_actions": [
    {
      "action": "Direct agent configuration changes",
      "reason": "Agents must be modified through standard deployment process"
    },
    {
      "action": "Threshold changes without approval",
      "reason": "Thresholds affect system behavior and require careful evaluation"
    },
    {
      "action": "Automatic model retraining",
      "reason": "Retraining has significant cost and risk implications"
    },
    {
      "action": "Customer-facing message modifications",
      "reason": "All customer communications require human review"
    },
    {
      "action": "Production deployment",
      "reason": "Deployments require full CI/CD pipeline with testing"
    },
    {
      "action": "Database schema changes",
      "reason": "Schema changes require migration planning"
    },
    {
      "action": "Access control modifications",
      "reason": "Security changes require security team approval"
    }
  ]
}
```

### 10.5 Rollback Procedures

```json
{
  "rollback_procedures": {
    "notification_rollback": {
      "available": false,
      "reason": "Notifications cannot be unsent",
      "mitigation": "Send correction notification"
    },
    "report_rollback": {
      "available": true,
      "procedure": "Mark report as superseded, generate corrected version"
    },
    "ticket_rollback": {
      "available": true,
      "procedure": "Close ticket with 'Created in error' resolution"
    },
    "scaling_rollback": {
      "available": true,
      "procedure": "Reduce human agent pool to previous level"
    }
  }
}
```

---

## 11. Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

| Task | Description | Owner |
|------|-------------|-------|
| Create database tables | tuning_signals, tuning_actions, tuning_audit_log | DB Team |
| Implement detection queries | SIG_001 through SIG_006 | AI Team |
| Define thresholds | Global, agent, channel thresholds | AI Lead |
| Set up monitoring | Dashboard for tuning system health | Ops |

### Phase 2: Detection (Weeks 3-4)

| Task | Description | Owner |
|------|-------------|-------|
| Build n8n detection workflow | Scheduled signal detection | Automation |
| Implement signal filtering | Confidence, sample size filters | AI Team |
| Test detection accuracy | Validate against known issues | QA |
| Create alert templates | Slack, email templates | Ops |

### Phase 3: Recommendations (Weeks 5-6)

| Task | Description | Owner |
|------|-------------|-------|
| Implement decision matrix | Signal → recommendation mapping | AI Team |
| Build recommendation generator | JSON recommendation objects | Automation |
| Set up approval workflow | Slack-based approval flow | Ops |
| Implement AUTO mode | Low-risk automatic actions | Automation |

### Phase 4: Governance (Weeks 7-8)

| Task | Description | Owner |
|------|-------------|-------|
| Implement rate limits | Per-action, per-day limits | Automation |
| Build audit logging | Immutable audit trail | DB Team |
| Create admin dashboard | Monitor and manage tuning | Frontend |
| Document procedures | Runbooks and escalation paths | Tech Writer |

### Phase 5: Optimization (Ongoing)

| Task | Description | Owner |
|------|-------------|-------|
| Tune thresholds | Based on observed performance | AI Team |
| Add new signals | Expand detection capabilities | AI Team |
| Improve recommendations | Better action suggestions | AI Team |
| Reduce false positives | Refine detection queries | AI Team |

---

## Appendix A: Quick Reference

### Signal Types

| ID | Name | Frequency | Default Severity |
|----|------|-----------|------------------|
| SIG_001 | CONFIDENCE_DROP | Hourly | HIGH |
| SIG_002 | ESCALATION_SPIKE | Hourly | HIGH |
| SIG_003 | RESOLUTION_DECLINE | 4 hours | MEDIUM |
| SIG_004 | COMPLAINT_SURGE | Daily | HIGH |
| SIG_005 | AGENT_DEGRADATION | 4 hours | MEDIUM |
| SIG_006 | CHANNEL_ANOMALY | Hourly | MEDIUM |

### Apply Mode Summary

| Mode | Human Approval | Auto Execute | Use Case |
|------|----------------|--------------|----------|
| AUTO | No | Yes | Alerts, logging |
| SEMI_AUTO | Yes | Yes (after approval) | Reports, scaling |
| MANUAL | Yes | No (human executes) | Retraining, config |

### Threshold Quick Reference

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Confidence | ≥0.75 | 0.60-0.74 | <0.60 |
| Escalation Rate | ≤15% | 15-25% | >25% |
| Resolution Rate | ≥85% | 75-84% | <75% |
| Complaint Ratio | ≤20% | 20-35% | >35% |

---

*Document Version: 1.0.0*  
*Janssen AI Engineering Team*  
*Contact: ai-engineering@janssen.com*
