-- ============================================================================
-- JANSSEN AI - EXECUTIVE DASHBOARD VIEWS
-- ============================================================================
-- Database: PostgreSQL
-- Source: analytics_events (read-only)
-- Timezone: Africa/Cairo
-- Purpose: Executive-level KPI monitoring (fast, simple, decision-oriented)
--
-- ENHANCEMENTS (Metabase-friendly):
-- - business_hours_only filter column on all views
-- - confidence_flag: GOOD (>0.7) | WARNING (0.5-0.7) | BAD (<0.5)
-- - No subqueries inside SELECT
-- - Explicit column names
-- - Stable ordering (deterministic)
--
-- CONSTRAINTS:
-- - Read-only (SELECT only)
-- - No joins with operational tables
-- - No alerts, automation, or writes
-- - Optimized for Grafana / Metabase / Superset
-- ============================================================================


-- ============================================================================
-- VIEW 1: v_exec_kpis_today
-- ============================================================================
-- Purpose: Top KPI tiles for today's snapshot
-- Usage: Executive dashboard header cards
-- Refresh: Real-time or 1-minute cache
--
-- Recommended Display:
--   [Leads Today]  [Complaints]  [Escalations]  [Avg Confidence]  [Esc Rate]
--       47             12             5             0.82            8.5%
-- ============================================================================

CREATE OR REPLACE VIEW v_exec_kpis_today AS
SELECT
    CURRENT_DATE AS date,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Lead KPI
    COUNT(*) FILTER (WHERE is_lead = TRUE) AS leads_today,
    
    -- Complaint KPI
    COUNT(*) FILTER (WHERE is_complaint = TRUE) AS complaints_today,
    
    -- Escalation KPI
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations_today,
    
    -- Total Events (for context)
    COUNT(*) AS total_events_today,
    
    -- AI Confidence KPI
    ROUND(AVG(confidence), 2) AS avg_confidence_today,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Escalation Rate KPI
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        1
    ) AS escalation_rate_today

FROM analytics_events
WHERE date = CURRENT_DATE
GROUP BY is_business_hours
ORDER BY is_business_hours DESC;


-- ============================================================================
-- VIEW 2: v_exec_trends_14d
-- ============================================================================
-- Purpose: 14-day trend overview for executive trend analysis
-- Usage: Line charts, sparklines, trend indicators
-- Refresh: 5-minute cache
--
-- Recommended Display:
--   Line Chart: leads_count, complaints_count over 14 days
--   Trend Arrows: Compare today vs 7-day average
-- ============================================================================

CREATE OR REPLACE VIEW v_exec_trends_14d AS
SELECT
    date AS date,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Volume Metrics
    COUNT(*) FILTER (WHERE is_lead = TRUE) AS leads_count,
    COUNT(*) FILTER (WHERE is_complaint = TRUE) AS complaints_count,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations_count,
    COUNT(*) AS total_events,
    
    -- Quality Metrics
    ROUND(AVG(confidence), 3) AS avg_confidence,
    ROUND(AVG(urgency_score), 1) AS avg_urgency,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Rates
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        1
    ) AS escalation_rate,
    
    ROUND(
        COUNT(*) FILTER (WHERE is_lead = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        1
    ) AS lead_rate

FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY date, is_business_hours
ORDER BY date ASC, is_business_hours DESC;


-- ============================================================================
-- VIEW 3: v_exec_channel_mix
-- ============================================================================
-- Purpose: Channel distribution for today
-- Usage: Pie chart, donut chart
-- Refresh: 5-minute cache
-- ============================================================================

CREATE OR REPLACE VIEW v_exec_channel_mix AS
SELECT
    channel AS channel,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    COUNT(*) AS events,
    COUNT(*) FILTER (WHERE is_lead = TRUE) AS leads,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations,
    ROUND(AVG(confidence), 2) AS avg_confidence,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    ROUND(
        COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY is_business_hours), 0),
        1
    ) AS percentage

FROM analytics_events
WHERE date = CURRENT_DATE
GROUP BY channel, is_business_hours
ORDER BY events DESC, channel ASC, is_business_hours DESC;


-- ============================================================================
-- VIEW 4: v_exec_hourly_today
-- ============================================================================
-- Purpose: Hourly activity for today (Egypt time)
-- Usage: Bar chart showing activity distribution
-- Refresh: 1-minute cache
-- ============================================================================

CREATE OR REPLACE VIEW v_exec_hourly_today AS
SELECT
    hour AS hour,
    
    -- Business Hours Flag (derived)
    CASE WHEN hour >= 9 AND hour < 18 THEN TRUE ELSE FALSE END AS business_hours_only,
    
    COUNT(*) AS events,
    COUNT(*) FILTER (WHERE is_lead = TRUE) AS leads,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations,
    ROUND(AVG(confidence), 2) AS avg_confidence,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag

FROM analytics_events
WHERE date = CURRENT_DATE
GROUP BY hour
ORDER BY hour ASC;


-- ============================================================================
-- VIEW 5: v_exec_week_over_week
-- ============================================================================
-- Purpose: Week-over-week comparison
-- Usage: Comparison cards with delta indicators
-- Refresh: 1-hour cache
-- ============================================================================

CREATE OR REPLACE VIEW v_exec_week_over_week AS
SELECT
    is_business_hours AS business_hours_only,
    
    -- This Week
    COUNT(*) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days') AS events_this_week,
    COUNT(*) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days' AND is_lead = TRUE) AS leads_this_week,
    COUNT(*) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days' AND escalated = TRUE) AS escalations_this_week,
    ROUND(AVG(confidence) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days'), 2) AS avg_confidence_this_week,
    
    -- Confidence Flag (This Week)
    CASE
        WHEN AVG(confidence) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days') > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days') >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag_this_week,
    
    -- Last Week
    COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days') AS events_last_week,
    COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days' AND is_lead = TRUE) AS leads_last_week,
    COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days' AND escalated = TRUE) AS escalations_last_week,
    ROUND(AVG(confidence) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days'), 2) AS avg_confidence_last_week,
    
    -- Confidence Flag (Last Week)
    CASE
        WHEN AVG(confidence) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days') > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days') >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag_last_week,
    
    -- Deltas (percentage change)
    ROUND(
        (COUNT(*) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days') - 
         COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days')) * 100.0 /
        NULLIF(COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days'), 0),
        1
    ) AS events_delta_pct,
    
    ROUND(
        (COUNT(*) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '6 days' AND is_lead = TRUE) - 
         COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days' AND is_lead = TRUE)) * 100.0 /
        NULLIF(COUNT(*) FILTER (WHERE date BETWEEN CURRENT_DATE - INTERVAL '13 days' AND CURRENT_DATE - INTERVAL '7 days' AND is_lead = TRUE), 0),
        1
    ) AS leads_delta_pct

FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '13 days'
GROUP BY is_business_hours
ORDER BY is_business_hours DESC;


-- ============================================================================
-- VIEW 6: v_exec_status_summary
-- ============================================================================
-- Purpose: Single-row executive status for dashboard header
-- Usage: Status indicator (HEALTHY / WARNING / CRITICAL)
-- Refresh: Real-time
-- ============================================================================

CREATE OR REPLACE VIEW v_exec_status_summary AS
SELECT
    NOW() AT TIME ZONE 'Africa/Cairo' AS snapshot_time,
    CURRENT_DATE AS report_date,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Today's Numbers
    COUNT(*) FILTER (WHERE date = CURRENT_DATE) AS events_today,
    COUNT(*) FILTER (WHERE date = CURRENT_DATE AND is_lead = TRUE) AS leads_today,
    COUNT(*) FILTER (WHERE date = CURRENT_DATE AND escalated = TRUE) AS escalations_today,
    
    -- Today's Rates
    ROUND(
        COUNT(*) FILTER (WHERE date = CURRENT_DATE AND escalated = TRUE) * 100.0 /
        NULLIF(COUNT(*) FILTER (WHERE date = CURRENT_DATE), 0),
        1
    ) AS escalation_rate_today,
    
    ROUND(AVG(confidence) FILTER (WHERE date = CURRENT_DATE), 2) AS avg_confidence_today,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) FILTER (WHERE date = CURRENT_DATE) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) FILTER (WHERE date = CURRENT_DATE) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Status Flag
    CASE
        WHEN COUNT(*) FILTER (WHERE date = CURRENT_DATE) = 0 THEN 'NO_DATA'
        WHEN COUNT(*) FILTER (WHERE date = CURRENT_DATE AND escalated = TRUE) * 100.0 /
             NULLIF(COUNT(*) FILTER (WHERE date = CURRENT_DATE), 0) > 25 THEN 'CRITICAL'
        WHEN COUNT(*) FILTER (WHERE date = CURRENT_DATE AND escalated = TRUE) * 100.0 /
             NULLIF(COUNT(*) FILTER (WHERE date = CURRENT_DATE), 0) > 15 THEN 'WARNING'
        WHEN AVG(confidence) FILTER (WHERE date = CURRENT_DATE) < 0.5 THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS system_status

FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '1 day'
GROUP BY is_business_hours
ORDER BY is_business_hours DESC;


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================

-- Today's KPIs (for header cards) - Business Hours Only
-- SELECT * FROM v_exec_kpis_today WHERE business_hours_only = TRUE;

-- 14-day trend (for line chart) - All Hours
-- SELECT date, leads_count, complaints_count, escalation_rate, confidence_flag 
-- FROM v_exec_trends_14d WHERE business_hours_only = TRUE;

-- Channel distribution (for pie chart)
-- SELECT channel, percentage, confidence_flag FROM v_exec_channel_mix WHERE business_hours_only = TRUE;

-- Today's hourly activity (for bar chart)
-- SELECT hour, events, leads, confidence_flag FROM v_exec_hourly_today;

-- Week-over-week comparison (for delta cards)
-- SELECT leads_this_week, leads_last_week, leads_delta_pct, confidence_flag_this_week 
-- FROM v_exec_week_over_week WHERE business_hours_only = TRUE;

-- System status (for status indicator)
-- SELECT system_status, escalation_rate_today, confidence_flag FROM v_exec_status_summary;


-- ============================================================================
-- GRANTS (run with admin privileges)
-- ============================================================================
-- GRANT SELECT ON v_exec_kpis_today TO metabase_readonly;
-- GRANT SELECT ON v_exec_trends_14d TO metabase_readonly;
-- GRANT SELECT ON v_exec_channel_mix TO metabase_readonly;
-- GRANT SELECT ON v_exec_hourly_today TO metabase_readonly;
-- GRANT SELECT ON v_exec_week_over_week TO metabase_readonly;
-- GRANT SELECT ON v_exec_status_summary TO metabase_readonly;


-- ============================================================================
-- END OF EXECUTIVE VIEWS
-- ============================================================================
