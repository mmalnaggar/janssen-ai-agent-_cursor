-- ============================================================================
-- JANSSEN AI - ANALYTICS EVENTS SCHEMA
-- ============================================================================
-- Purpose: Unified analytics schema for KPI tracking and dashboard visualization
-- Source: Events from Analytics_Event_Mirror node in n8n workflow
-- 
-- DESIGN PRINCIPLES:
-- 1. PASSIVE: Read-only analytics layer - never modifies chatbot behavior
-- 2. NON-BLOCKING: Analytics sink uses continueOnFail - chatbot response unaffected
-- 3. CRM-INDEPENDENT: Captures ALL events, not just CRM-worthy ones
-- 4. DASHBOARD-READY: Pre-computed dimensions and aggregation keys
--
-- INTEGRATION: n8n Janssen_AI_Brain workflow → Analytics_Event_Mirror node
-- ============================================================================

-- Drop existing table if recreating
-- DROP TABLE IF EXISTS analytics_events CASCADE;

-- ============================================================================
-- TABLE: analytics_events
-- Purpose: Unified event store for all chatbot interactions
-- Populated by: Analytics_Event_Mirror → Normalize_KPI_Event → Analytics_DB_Sink
-- ============================================================================
CREATE TABLE IF NOT EXISTS analytics_events (
    -- ========================================
    -- PRIMARY KEY & IDENTIFIERS
    -- ========================================
    id SERIAL PRIMARY KEY,
    event_id VARCHAR(50) UNIQUE NOT NULL,          -- Unique event ID (evt_timestamp_random)
    session_id VARCHAR(100) NOT NULL,               -- Conversation session ID
    
    -- ========================================
    -- EVENT CLASSIFICATION
    -- ========================================
    event_type VARCHAR(30) NOT NULL,                -- LEAD_CREATED | COMPLAINT_LOGGED | ESCALATION | NO_CRM_EVENT
    agent_used VARCHAR(30) NOT NULL,                -- sales | support | warranty | complaint | escalation
    intent VARCHAR(100),                            -- Detected customer intent
    
    -- ========================================
    -- CHANNEL & LANGUAGE
    -- ========================================
    channel VARCHAR(20) NOT NULL,                   -- chat | voice | whatsapp
    language VARCHAR(5) NOT NULL DEFAULT 'ar',      -- ar | en
    
    -- ========================================
    -- AI METRICS
    -- ========================================
    confidence DECIMAL(4,3),                        -- AI confidence score (0.000 - 1.000)
    confidence_bucket VARCHAR(20),                  -- very_high | high | medium | low | very_low
    sentiment VARCHAR(20),                          -- positive | neutral | negative
    
    -- ========================================
    -- STATUS FLAGS
    -- ========================================
    escalated BOOLEAN DEFAULT FALSE,                -- Whether escalated to human agent
    is_lead BOOLEAN DEFAULT FALSE,                  -- event_type = 'LEAD_CREATED'
    is_complaint BOOLEAN DEFAULT FALSE,             -- event_type = 'COMPLAINT_LOGGED'
    is_escalation BOOLEAN DEFAULT FALSE,            -- escalated = true
    
    -- ========================================
    -- COMPLAINT-SPECIFIC FIELDS
    -- ========================================
    category VARCHAR(50),                           -- Complaint category (product/delivery/service)
    
    -- ========================================
    -- URGENCY SCORING
    -- ========================================
    urgency_score SMALLINT DEFAULT 0,               -- 0-100 composite urgency score
    -- Formula: +50 (escalation) +30 (complaint) +20 (negative sentiment) +10 (low confidence)
    
    -- ========================================
    -- TIME DIMENSIONS (for dashboard aggregation)
    -- ========================================
    timestamp TIMESTAMPTZ NOT NULL,                 -- Event timestamp (ISO 8601)
    date DATE NOT NULL,                             -- YYYY-MM-DD (for daily aggregation)
    hour SMALLINT CHECK (hour >= 0 AND hour <= 23), -- 0-23 (for hourly patterns)
    day_of_week SMALLINT CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sun, 6=Sat
    is_business_hours BOOLEAN,                      -- Egypt business hours (9 AM - 6 PM)
    is_weekend BOOLEAN,                             -- Saturday or Sunday
    
    -- ========================================
    -- AGGREGATION KEYS (pre-computed for fast GROUP BY)
    -- ========================================
    agg_key_daily VARCHAR(100),                     -- date_agent (e.g., "2025-01-29_sales")
    agg_key_channel VARCHAR(100),                   -- date_channel (e.g., "2025-01-29_whatsapp")
    agg_key_hourly VARCHAR(100),                    -- date_hour_channel (e.g., "2025-01-29_14_voice")
    
    -- ========================================
    -- METADATA
    -- ========================================
    created_at TIMESTAMPTZ DEFAULT NOW(),           -- Record insertion time
    
    -- ========================================
    -- CONSTRAINTS
    -- ========================================
    CONSTRAINT chk_event_type CHECK (event_type IN ('LEAD_CREATED', 'COMPLAINT_LOGGED', 'ESCALATION', 'NO_CRM_EVENT')),
    CONSTRAINT chk_channel CHECK (channel IN ('chat', 'voice', 'whatsapp')),
    CONSTRAINT chk_language CHECK (language IN ('ar', 'en')),
    CONSTRAINT chk_confidence_bucket CHECK (confidence_bucket IN ('very_high', 'high', 'medium', 'low', 'very_low')),
    CONSTRAINT chk_sentiment CHECK (sentiment IN ('positive', 'neutral', 'negative') OR sentiment IS NULL),
    CONSTRAINT chk_confidence_range CHECK (confidence >= 0 AND confidence <= 1),
    CONSTRAINT chk_urgency_range CHECK (urgency_score >= 0 AND urgency_score <= 100)
);

-- ============================================================================
-- INDEXES
-- Purpose: Optimized for dashboard queries and KPI calculations
-- ============================================================================

-- Primary lookups
CREATE INDEX IF NOT EXISTS idx_analytics_event_id ON analytics_events(event_id);
CREATE INDEX IF NOT EXISTS idx_analytics_session_id ON analytics_events(session_id);

-- Time-based queries (most common for dashboards)
CREATE INDEX IF NOT EXISTS idx_analytics_timestamp ON analytics_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_date ON analytics_events(date);
CREATE INDEX IF NOT EXISTS idx_analytics_date_hour ON analytics_events(date, hour);

-- Dimension filtering
CREATE INDEX IF NOT EXISTS idx_analytics_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_agent ON analytics_events(agent_used);
CREATE INDEX IF NOT EXISTS idx_analytics_channel ON analytics_events(channel);
CREATE INDEX IF NOT EXISTS idx_analytics_escalated ON analytics_events(escalated);

-- Aggregation key indexes (for fast GROUP BY)
CREATE INDEX IF NOT EXISTS idx_analytics_agg_daily ON analytics_events(agg_key_daily);
CREATE INDEX IF NOT EXISTS idx_analytics_agg_channel ON analytics_events(agg_key_channel);
CREATE INDEX IF NOT EXISTS idx_analytics_agg_hourly ON analytics_events(agg_key_hourly);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_analytics_date_agent ON analytics_events(date, agent_used);
CREATE INDEX IF NOT EXISTS idx_analytics_date_channel ON analytics_events(date, channel);
CREATE INDEX IF NOT EXISTS idx_analytics_date_event_type ON analytics_events(date, event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_channel_confidence ON analytics_events(channel, confidence);

-- Partial indexes for common filters
CREATE INDEX IF NOT EXISTS idx_analytics_leads_only ON analytics_events(date) WHERE is_lead = TRUE;
CREATE INDEX IF NOT EXISTS idx_analytics_complaints_only ON analytics_events(date) WHERE is_complaint = TRUE;
CREATE INDEX IF NOT EXISTS idx_analytics_escalations_only ON analytics_events(date) WHERE escalated = TRUE;
CREATE INDEX IF NOT EXISTS idx_analytics_high_urgency ON analytics_events(date) WHERE urgency_score >= 50;

-- Partial index optimized for escalation heatmaps (hour x day_of_week queries)
CREATE INDEX IF NOT EXISTS idx_analytics_escalation_heatmap ON analytics_events(timestamp) WHERE escalated = TRUE;


-- ============================================================================
-- EXAMPLE DATA (for testing)
-- ============================================================================
-- INSERT INTO analytics_events (
--     event_id, session_id, event_type, agent_used, intent, channel, language,
--     confidence, confidence_bucket, sentiment, escalated, is_lead, is_complaint, is_escalation,
--     urgency_score, timestamp, date, hour, day_of_week, is_business_hours, is_weekend,
--     agg_key_daily, agg_key_channel, agg_key_hourly
-- ) VALUES (
--     'evt_1706540400000_abc123', 'session_001', 'LEAD_CREATED', 'sales', 'buy_mattress',
--     'whatsapp', 'ar', 0.85, 'high', 'positive', FALSE, TRUE, FALSE, FALSE,
--     0, '2025-01-29T14:00:00Z', '2025-01-29', 14, 3, TRUE, FALSE,
--     '2025-01-29_sales', '2025-01-29_whatsapp', '2025-01-29_14_whatsapp'
-- );


-- ============================================================================
-- ============================================================================
--                        DASHBOARD QUERIES
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- QUERY 1: LEADS PER DAY
-- Chart Type: Line Chart
-- X-Axis: Date
-- Y-Axis: Lead Count
-- Purpose: Track sales lead generation over time
-- ============================================================================

-- Basic: Leads per day
SELECT 
    date,
    COUNT(*) AS lead_count
FROM analytics_events
WHERE event_type = 'LEAD_CREATED'
GROUP BY date
ORDER BY date;

-- With 7-day moving average
SELECT 
    date,
    COUNT(*) AS lead_count,
    ROUND(AVG(COUNT(*)) OVER (
        ORDER BY date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS lead_count_7d_avg
FROM analytics_events
WHERE event_type = 'LEAD_CREATED'
GROUP BY date
ORDER BY date;

-- Leads per day by channel
SELECT 
    date,
    channel,
    COUNT(*) AS lead_count
FROM analytics_events
WHERE event_type = 'LEAD_CREATED'
GROUP BY date, channel
ORDER BY date, channel;

-- Lead rate (percentage of all interactions that are leads)
SELECT 
    date,
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
    ROUND(
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') * 100.0 / NULLIF(COUNT(*), 0), 
        2
    ) AS lead_rate_percent
FROM analytics_events
GROUP BY date
ORDER BY date;


-- ============================================================================
-- QUERY 2: COMPLAINTS VS SALES (LEADS)
-- Chart Type: Stacked Bar Chart or Dual Axis Line Chart
-- X-Axis: Date
-- Y-Axis: Count (Leads vs Complaints)
-- Purpose: Compare positive (leads) vs negative (complaints) interactions
-- ============================================================================

-- Daily comparison
SELECT 
    date,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') - 
        COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS net_sentiment
FROM analytics_events
GROUP BY date
ORDER BY date;

-- With ratio calculation
SELECT 
    date,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
    CASE 
        WHEN COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') = 0 THEN NULL
        ELSE ROUND(
            COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED')::DECIMAL / 
            COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED'), 
            2
        )
    END AS lead_to_complaint_ratio
FROM analytics_events
GROUP BY date
ORDER BY date;

-- By channel
SELECT 
    date,
    channel,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints
FROM analytics_events
GROUP BY date, channel
ORDER BY date, channel;

-- Weekly summary
SELECT 
    DATE_TRUNC('week', date)::DATE AS week_start,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS total_leads,
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS total_complaints,
    COUNT(*) AS total_interactions
FROM analytics_events
GROUP BY DATE_TRUNC('week', date)
ORDER BY week_start;


-- ============================================================================
-- QUERY 3: ESCALATION HEATMAP
-- Chart Type: Heatmap
-- X-Axis: Hour (0-23)
-- Y-Axis: Day of Week (Sun-Sat)
-- Value: Escalation Rate or Count
-- Purpose: Identify peak escalation times for staffing optimization
-- ============================================================================

-- Escalation count by hour and day of week
SELECT 
    day_of_week,
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    hour,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalation_count,
    COUNT(*) AS total_events,
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0), 
        2
    ) AS escalation_rate_percent
FROM analytics_events
GROUP BY day_of_week, hour
ORDER BY day_of_week, hour;

-- Pivot format for heatmap (hours as columns)
SELECT 
    day_of_week,
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(*) FILTER (WHERE hour = 9 AND escalated) AS h09,
    COUNT(*) FILTER (WHERE hour = 10 AND escalated) AS h10,
    COUNT(*) FILTER (WHERE hour = 11 AND escalated) AS h11,
    COUNT(*) FILTER (WHERE hour = 12 AND escalated) AS h12,
    COUNT(*) FILTER (WHERE hour = 13 AND escalated) AS h13,
    COUNT(*) FILTER (WHERE hour = 14 AND escalated) AS h14,
    COUNT(*) FILTER (WHERE hour = 15 AND escalated) AS h15,
    COUNT(*) FILTER (WHERE hour = 16 AND escalated) AS h16,
    COUNT(*) FILTER (WHERE hour = 17 AND escalated) AS h17
FROM analytics_events
GROUP BY day_of_week
ORDER BY day_of_week;

-- Business hours vs after-hours escalation comparison
SELECT 
    CASE 
        WHEN is_business_hours THEN 'Business Hours (9AM-6PM)'
        ELSE 'After Hours'
    END AS time_period,
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations,
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0), 
        2
    ) AS escalation_rate_percent
FROM analytics_events
GROUP BY is_business_hours
ORDER BY is_business_hours DESC;


-- ============================================================================
-- QUERY 4: CHANNEL CONFIDENCE COMPARISON (Voice vs Chat)
-- Chart Type: Grouped Bar Chart or Box Plot
-- X-Axis: Agent Type
-- Y-Axis: Average Confidence
-- Series: Channel (chat, voice, whatsapp)
-- Purpose: Compare AI performance across channels and agent types
-- ============================================================================

-- Average confidence by channel
SELECT 
    channel,
    ROUND(AVG(confidence), 3) AS avg_confidence,
    ROUND(MIN(confidence), 3) AS min_confidence,
    ROUND(MAX(confidence), 3) AS max_confidence,
    ROUND(STDDEV(confidence), 3) AS stddev_confidence,
    COUNT(*) AS event_count
FROM analytics_events
GROUP BY channel
ORDER BY avg_confidence DESC;

-- Average confidence by agent and channel
SELECT 
    agent_used,
    channel,
    ROUND(AVG(confidence), 3) AS avg_confidence,
    COUNT(*) AS event_count
FROM analytics_events
GROUP BY agent_used, channel
ORDER BY agent_used, channel;

-- Pivot format: agents as rows, channels as columns
SELECT 
    agent_used,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'chat'), 3) AS chat_confidence,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'voice'), 3) AS voice_confidence,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'whatsapp'), 3) AS whatsapp_confidence,
    COUNT(*) FILTER (WHERE channel = 'chat') AS chat_count,
    COUNT(*) FILTER (WHERE channel = 'voice') AS voice_count,
    COUNT(*) FILTER (WHERE channel = 'whatsapp') AS whatsapp_count
FROM analytics_events
GROUP BY agent_used
ORDER BY agent_used;

-- Confidence bucket distribution by channel
SELECT 
    channel,
    confidence_bucket,
    COUNT(*) AS event_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY channel), 
        2
    ) AS percentage
FROM analytics_events
GROUP BY channel, confidence_bucket
ORDER BY channel, 
    CASE confidence_bucket 
        WHEN 'very_high' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'low' THEN 4 
        WHEN 'very_low' THEN 5 
    END;

-- Daily trend: Voice vs Chat confidence
SELECT 
    date,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'voice'), 3) AS voice_avg_confidence,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'chat'), 3) AS chat_avg_confidence,
    ROUND(AVG(confidence) FILTER (WHERE channel = 'whatsapp'), 3) AS whatsapp_avg_confidence
FROM analytics_events
GROUP BY date
ORDER BY date;


-- ============================================================================
-- ADDITIONAL KPI QUERIES
-- ============================================================================

-- Overall KPI Summary (for dashboard header)
SELECT 
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS total_leads,
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS total_complaints,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS total_escalations,
    ROUND(AVG(confidence), 3) AS overall_avg_confidence,
    ROUND(AVG(urgency_score), 1) AS avg_urgency_score,
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0), 
        2
    ) AS escalation_rate_percent,
    ROUND(
        COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') * 100.0 / NULLIF(COUNT(*), 0), 
        2
    ) AS lead_rate_percent
FROM analytics_events
WHERE date >= CURRENT_DATE - INTERVAL '30 days';

-- Urgency distribution
SELECT 
    CASE 
        WHEN urgency_score >= 80 THEN 'Critical (80-100)'
        WHEN urgency_score >= 50 THEN 'High (50-79)'
        WHEN urgency_score >= 20 THEN 'Medium (20-49)'
        ELSE 'Low (0-19)'
    END AS urgency_level,
    COUNT(*) AS event_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) AS percentage
FROM analytics_events
GROUP BY 1
ORDER BY 
    CASE 
        WHEN urgency_score >= 80 THEN 1
        WHEN urgency_score >= 50 THEN 2
        WHEN urgency_score >= 20 THEN 3
        ELSE 4
    END;

-- Agent workload distribution
SELECT 
    agent_used,
    COUNT(*) AS total_events,
    COUNT(DISTINCT session_id) AS unique_sessions,
    ROUND(AVG(confidence), 3) AS avg_confidence,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations,
    ROUND(
        COUNT(*) FILTER (WHERE escalated = TRUE) * 100.0 / NULLIF(COUNT(*), 0), 
        2
    ) AS escalation_rate_percent
FROM analytics_events
GROUP BY agent_used
ORDER BY total_events DESC;

-- Language distribution
SELECT 
    language,
    COUNT(*) AS event_count,
    ROUND(AVG(confidence), 3) AS avg_confidence,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations
FROM analytics_events
GROUP BY language
ORDER BY event_count DESC;


-- ============================================================================
-- MATERIALIZED VIEWS (for performance on large datasets)
-- ============================================================================

-- Daily aggregates (refresh nightly)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_analytics_daily AS
SELECT 
    date,
    agent_used,
    channel,
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE event_type = 'LEAD_CREATED') AS leads,
    COUNT(*) FILTER (WHERE event_type = 'COMPLAINT_LOGGED') AS complaints,
    COUNT(*) FILTER (WHERE escalated = TRUE) AS escalations,
    ROUND(AVG(confidence), 3) AS avg_confidence,
    ROUND(AVG(urgency_score), 1) AS avg_urgency
FROM analytics_events
GROUP BY date, agent_used, channel;

-- Refresh command (run via cron or n8n schedule)
-- REFRESH MATERIALIZED VIEW mv_analytics_daily;

-- Index on materialized view
CREATE INDEX IF NOT EXISTS idx_mv_daily_date ON mv_analytics_daily(date);


-- ============================================================================
-- GRANTS (for dashboard read-only access)
-- ============================================================================
-- CREATE ROLE analytics_readonly;
-- GRANT CONNECT ON DATABASE janssen_analytics TO analytics_readonly;
-- GRANT USAGE ON SCHEMA public TO analytics_readonly;
-- GRANT SELECT ON analytics_events TO analytics_readonly;
-- GRANT SELECT ON mv_analytics_daily TO analytics_readonly;


-- ============================================================================
-- COMMENTS (for documentation)
-- ============================================================================
COMMENT ON TABLE analytics_events IS 'Unified analytics event store for Janssen AI chatbot. Populated by n8n Analytics_Event_Mirror node.';
COMMENT ON COLUMN analytics_events.event_id IS 'Unique event identifier (evt_timestamp_random) for deduplication';
COMMENT ON COLUMN analytics_events.event_type IS 'CRM event classification: LEAD_CREATED, COMPLAINT_LOGGED, ESCALATION, or NO_CRM_EVENT';
COMMENT ON COLUMN analytics_events.confidence IS 'AI intent classification confidence (0.0 to 1.0)';
COMMENT ON COLUMN analytics_events.urgency_score IS 'Composite urgency score (0-100). Formula: +50 escalation, +30 complaint, +20 negative sentiment, +10 low confidence';
COMMENT ON COLUMN analytics_events.agg_key_daily IS 'Pre-computed aggregation key: date_agent for fast daily GROUP BY';
