-- ============================================================================
-- JANSSEN AI - ANALYTICS DASHBOARD VIEWS (STEP 8)
-- ============================================================================
-- Database: PostgreSQL
-- Source Table: analytics_events (read-only, populated by n8n)
-- Purpose: Read-only views for Metabase/Grafana dashboards
--
-- ENHANCEMENTS (Metabase-friendly):
-- - business_hours_only filter column on all views
-- - confidence_flag: GOOD (>0.7) | WARNING (0.5-0.7) | BAD (<0.5)
-- - No subqueries inside SELECT
-- - Explicit column names
-- - Stable ordering (deterministic)
--
-- CONSTRAINTS:
-- - No modifications to analytics_events
-- - No triggers, procedures, or functions
-- - SELECT-only operations
-- ============================================================================


-- ============================================================================
-- VIEW 1: system_health_view
-- ============================================================================
-- KPI Purpose: Executive dashboard & system monitoring
-- Shows daily system health including confidence by channel and escalation rates
--
-- Recommended Charts:
--   - Line Chart: escalation_rate, avg_confidence over time
--   - Gauge: current avg_confidence, escalation_rate
--   - Grouped Bar: voice_confidence vs chat_confidence vs whatsapp_confidence
--   - KPI Cards: total_events, avg_urgency_score
-- ============================================================================

CREATE OR REPLACE VIEW system_health_view AS
SELECT
    date AS date,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Volume
    COUNT(*) AS total_events,
    
    -- Escalation Rate
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS escalation_rate,
    
    -- AI Quality
    ROUND(AVG(confidence), 3) AS avg_confidence,
    ROUND(AVG(urgency_score), 1) AS avg_urgency_score,
    
    -- Confidence Flag (based on avg)
    CASE
        WHEN AVG(confidence) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Confidence by Channel
    ROUND(AVG(confidence) FILTER (WHERE channel = 'voice'), 3) AS voice_confidence,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'chat'), 3) AS chat_confidence,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'whatsapp'), 3) AS whatsapp_confidence

FROM analytics_events
GROUP BY date, is_business_hours
ORDER BY date DESC, is_business_hours DESC;


-- ============================================================================
-- VIEW 2: sales_kpi_view
-- ============================================================================
-- KPI Purpose: Sales performance tracking
-- Tracks lead generation by date and channel with conversion metrics
--
-- Recommended Charts:
--   - Line Chart: leads_count trend over time
--   - Stacked Bar: leads_count by channel
--   - Combo Chart: leads_count (bar) + lead_rate (line)
--   - Table: daily breakdown
--
-- NOTE: Removed subquery for peak_hour (use sales_peak_hours_view instead)
-- ============================================================================

CREATE OR REPLACE VIEW sales_kpi_view AS
SELECT
    date AS date,
    channel AS channel,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Lead Metrics
    COUNT(*) FILTER (WHERE is_lead = TRUE) AS leads_count,
    COUNT(*) AS total_events,
    
    -- Lead Rate (conversion proxy)
    ROUND(
        COUNT(*) FILTER (WHERE is_lead = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS lead_rate,
    
    -- Quality
    ROUND(AVG(confidence) FILTER (WHERE is_lead = TRUE), 3) AS avg_confidence,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) FILTER (WHERE is_lead = TRUE) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) FILTER (WHERE is_lead = TRUE) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- High/Low Confidence Leads
    COUNT(*) FILTER (WHERE is_lead = TRUE AND confidence > 0.7) AS high_confidence_leads,
    COUNT(*) FILTER (WHERE is_lead = TRUE AND confidence < 0.5) AS low_confidence_leads

FROM analytics_events
GROUP BY date, channel, is_business_hours
ORDER BY date DESC, channel ASC, is_business_hours DESC;


-- ============================================================================
-- VIEW 2b: sales_peak_hours_view
-- ============================================================================
-- Purpose: Identify peak lead hours (replaces subquery in sales_kpi_view)
-- ============================================================================

CREATE OR REPLACE VIEW sales_peak_hours_view AS
SELECT
    date AS date,
    channel AS channel,
    hour AS hour,
    is_business_hours AS business_hours_only,
    COUNT(*) FILTER (WHERE is_lead = TRUE) AS leads_count,
    COUNT(*) AS total_events,
    ROW_NUMBER() OVER (PARTITION BY date, channel ORDER BY COUNT(*) FILTER (WHERE is_lead = TRUE) DESC) AS rank_by_leads

FROM analytics_events
WHERE is_lead = TRUE
GROUP BY date, channel, hour, is_business_hours
ORDER BY date DESC, channel ASC, leads_count DESC;


-- ============================================================================
-- VIEW 3: complaints_kpi_view_simple
-- ============================================================================
-- KPI Purpose: Customer service & quality monitoring
-- Tracks complaints, categories, and escalation patterns
-- (Simple version without JSON - Metabase friendly)
--
-- Recommended Charts:
--   - Area Chart: complaint_count trend
--   - Stacked Bar: complaints by category
--   - Gauge: escalation_ratio (target < 20%)
--   - Line Chart: avg_urgency_score over time
-- ============================================================================

CREATE OR REPLACE VIEW complaints_kpi_view AS
SELECT
    date AS date,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Complaint Volume
    COUNT(*) FILTER (WHERE is_complaint = TRUE) AS complaint_count,
    COUNT(*) AS total_events,
    
    -- Category Breakdown (separate columns)
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND category = 'product') AS complaints_product,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND category = 'delivery') AS complaints_delivery,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND category = 'service') AS complaints_service,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND category = 'warranty') AS complaints_warranty,
    COUNT(*) FILTER (WHERE is_complaint = TRUE AND (category IS NULL OR category = '')) AS complaints_uncategorized,
    
    -- Escalation Ratio
    ROUND(
        COUNT(*) FILTER (WHERE is_complaint = TRUE AND escalated = TRUE) * 100.0 /
        NULLIF(COUNT(*) FILTER (WHERE is_complaint = TRUE), 0),
        2
    ) AS escalation_ratio,
    
    -- Urgency
    ROUND(AVG(urgency_score) FILTER (WHERE is_complaint = TRUE), 1) AS avg_urgency_score,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) FILTER (WHERE is_complaint = TRUE) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) FILTER (WHERE is_complaint = TRUE) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Quality
    ROUND(AVG(confidence) FILTER (WHERE is_complaint = TRUE), 3) AS avg_confidence

FROM analytics_events
GROUP BY date, is_business_hours
ORDER BY date DESC, is_business_hours DESC;


-- ============================================================================
-- VIEW 4: escalation_heatmap_view
-- ============================================================================
-- KPI Purpose: Staffing & operations optimization
-- Shows escalation patterns by day of week and hour for staffing decisions
--
-- Recommended Charts:
--   - Heatmap: escalation_count (rows=day_of_week, cols=hour)
--   - Heatmap: escalation_rate (intensity by rate)
--   - Pivot Table: day × hour matrix
-- ============================================================================

CREATE OR REPLACE VIEW escalation_heatmap_view AS
SELECT
    day_of_week AS day_of_week,
    
    -- Day Name for display
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    
    hour AS hour,
    
    -- Business Hours Flag
    CASE WHEN hour >= 9 AND hour < 18 THEN TRUE ELSE FALSE END AS business_hours_only,
    
    -- Escalation Metrics
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalation_count,
    COUNT(*) AS total_events,
    
    -- Escalation Rate
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS escalation_rate,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) FILTER (WHERE escalated = TRUE) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) FILTER (WHERE escalated = TRUE) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Avg confidence before escalation
    ROUND(AVG(confidence) FILTER (WHERE escalated = TRUE), 3) AS avg_confidence_escalated

FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY day_of_week, hour
ORDER BY day_of_week ASC, hour ASC;


-- ============================================================================
-- VIEW 5: ai_quality_view
-- ============================================================================
-- KPI Purpose: AI performance monitoring & tuning
-- Tracks AI confidence distribution by agent and identifies low-performing areas
--
-- Recommended Charts:
--   - Stacked Bar: interactions_count by confidence_bucket
--   - Line Chart: low_confidence_rate, fallback_rate over time
--   - Table: agent_used × confidence_bucket matrix
--   - Gauge: overall low_confidence_rate (target < 10%)
-- ============================================================================

CREATE OR REPLACE VIEW ai_quality_view AS
SELECT
    date AS date,
    agent_used AS agent_used,
    confidence_bucket AS confidence_bucket,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Confidence Flag (row-level based on bucket)
    CASE confidence_bucket
        WHEN 'very_high' THEN 'GOOD'
        WHEN 'high' THEN 'GOOD'
        WHEN 'medium' THEN 'WARNING'
        WHEN 'low' THEN 'BAD'
        WHEN 'very_low' THEN 'BAD'
        ELSE 'WARNING'
    END AS confidence_flag,
    
    -- Volume
    COUNT(*) AS interactions_count,
    
    -- Low Confidence Rate (confidence < 0.5)
    ROUND(
        COUNT(*) FILTER (WHERE confidence < 0.5) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS low_confidence_rate,
    
    -- Fallback Rate (confidence < 0.3, likely fallback/unknown intent)
    ROUND(
        COUNT(*) FILTER (WHERE confidence < 0.3) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS fallback_rate,
    
    -- Avg confidence
    ROUND(AVG(confidence), 3) AS avg_confidence

FROM analytics_events
WHERE confidence IS NOT NULL
GROUP BY date, agent_used, confidence_bucket, is_business_hours
ORDER BY date DESC, agent_used ASC, 
    CASE confidence_bucket
        WHEN 'very_high' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        WHEN 'very_low' THEN 5
        ELSE 6
    END ASC,
    is_business_hours DESC;


-- ============================================================================
-- VIEW 6: ai_quality_daily_summary
-- ============================================================================
-- Aggregated daily AI quality for trend analysis (simpler for line charts)
-- ============================================================================

CREATE OR REPLACE VIEW ai_quality_daily_summary AS
SELECT
    date AS date,
    agent_used AS agent_used,
    
    -- Business Hours Filter
    is_business_hours AS business_hours_only,
    
    -- Volume
    COUNT(*) AS interactions_count,
    
    -- Confidence Stats
    ROUND(AVG(confidence), 3) AS avg_confidence,
    ROUND(MIN(confidence), 3) AS min_confidence,
    ROUND(MAX(confidence), 3) AS max_confidence,
    
    -- Confidence Flag
    CASE
        WHEN AVG(confidence) > 0.7 THEN 'GOOD'
        WHEN AVG(confidence) >= 0.5 THEN 'WARNING'
        ELSE 'BAD'
    END AS confidence_flag,
    
    -- Bucket Distribution
    COUNT(*) FILTER (WHERE confidence_bucket IN ('very_high', 'high')) AS high_confidence_count,
    COUNT(*) FILTER (WHERE confidence_bucket = 'medium') AS medium_confidence_count,
    COUNT(*) FILTER (WHERE confidence_bucket IN ('low', 'very_low')) AS low_confidence_count,
    
    -- Rates
    ROUND(
        COUNT(*) FILTER (WHERE confidence < 0.5) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS low_confidence_rate,
    
    ROUND(
        COUNT(*) FILTER (WHERE confidence < 0.3) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS fallback_rate,
    
    -- Escalation correlation
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS escalation_rate

FROM analytics_events
WHERE confidence IS NOT NULL
GROUP BY date, agent_used, is_business_hours
ORDER BY date DESC, agent_used ASC, is_business_hours DESC;


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================

-- Example 1: System Health - Last 30 Days (Business Hours Only)
-- SELECT * FROM system_health_view 
-- WHERE date >= CURRENT_DATE - INTERVAL '30 days' AND business_hours_only = TRUE;

-- Example 2: Sales KPIs - Filter by confidence flag
-- SELECT * FROM sales_kpi_view WHERE confidence_flag = 'BAD';

-- Example 3: Complaints with High Urgency (All Hours)
-- SELECT * FROM complaints_kpi_view WHERE avg_urgency_score >= 50;

-- Example 4: Escalation Hotspots (Business Hours Only)
-- SELECT * FROM escalation_heatmap_view WHERE business_hours_only = TRUE ORDER BY escalation_rate DESC;

-- Example 5: AI Quality - Bad confidence only
-- SELECT * FROM ai_quality_daily_summary WHERE confidence_flag = 'BAD';

-- Example 6: Peak Lead Hours
-- SELECT * FROM sales_peak_hours_view WHERE rank_by_leads = 1;


-- ============================================================================
-- GRANTS (uncomment and run with admin privileges)
-- ============================================================================
-- GRANT SELECT ON system_health_view TO metabase_readonly;
-- GRANT SELECT ON sales_kpi_view TO metabase_readonly;
-- GRANT SELECT ON sales_peak_hours_view TO metabase_readonly;
-- GRANT SELECT ON complaints_kpi_view TO metabase_readonly;
-- GRANT SELECT ON escalation_heatmap_view TO metabase_readonly;
-- GRANT SELECT ON ai_quality_view TO metabase_readonly;
-- GRANT SELECT ON ai_quality_daily_summary TO metabase_readonly;


-- ============================================================================
-- END OF DASHBOARD VIEWS
-- ============================================================================
