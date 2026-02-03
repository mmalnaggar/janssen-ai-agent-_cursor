-- ============================================================================
-- JANSSEN CRM - AI INTEGRATION SCHEMA EXTENSION
-- ============================================================================
-- Purpose: Extend JanssenCRM tables to store AI interaction metadata
-- Source: n8n Janssen_AI_Brain workflow CRM event sync
-- 
-- DESIGN PRINCIPLES:
-- 1. ADDITIVE ONLY: No modifications to existing columns or constraints
-- 2. BACKWARD COMPATIBLE: All new columns are nullable with defaults
-- 3. NON-BREAKING: Existing business logic remains unchanged
--
-- TABLES MODIFIED:
-- - customercall: Add AI intent, confidence, and agent fields
-- - tickets: Add AI escalation tracking fields
-- - Both: Add channel field for omnichannel tracking
-- ============================================================================


-- ============================================================================
-- EXTENSION: customercall table
-- Purpose: Store AI interaction metadata for customer calls
-- ============================================================================

-- AI Intent Classification
-- Stores the detected intent from AI analysis
ALTER TABLE customercall 
ADD COLUMN IF NOT EXISTS ai_intent VARCHAR(100) NULL 
COMMENT 'AI-detected customer intent (e.g., buy_mattress, complaint, warranty_inquiry)';

-- AI Confidence Score
-- Stores the confidence level (0.0 - 1.0) of intent classification
ALTER TABLE customercall 
ADD COLUMN IF NOT EXISTS ai_confidence DECIMAL(4,3) NULL 
COMMENT 'AI confidence score for intent classification (0.000 - 1.000)';

-- AI Agent Used
-- Stores which AI agent handled the interaction
ALTER TABLE customercall 
ADD COLUMN IF NOT EXISTS ai_agent VARCHAR(30) NULL 
COMMENT 'AI agent that handled the call (sales, support, warranty, complaint, escalation)';

-- Channel Field
-- Stores the communication channel (chat, voice, whatsapp)
ALTER TABLE customercall 
ADD COLUMN IF NOT EXISTS channel VARCHAR(20) NULL DEFAULT 'voice'
COMMENT 'Communication channel: chat, voice, whatsapp';

-- AI Session Reference
-- Links to the AI conversation session for context retrieval
ALTER TABLE customercall 
ADD COLUMN IF NOT EXISTS ai_session_id VARCHAR(100) NULL 
COMMENT 'Reference to AI conversation session ID for context lookup';

-- AI Processing Timestamp
-- When the AI processed this interaction
ALTER TABLE customercall 
ADD COLUMN IF NOT EXISTS ai_processed_at DATETIME NULL 
COMMENT 'Timestamp when AI processed this interaction';


-- ============================================================================
-- EXTENSION: tickets table
-- Purpose: Store AI escalation tracking for support tickets
-- ============================================================================

-- AI Escalation Flag
-- Indicates if this ticket was escalated by AI
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS escalated_by_ai TINYINT(1) NULL DEFAULT 0 
COMMENT 'Flag indicating ticket was escalated by AI (0=No, 1=Yes)';

-- AI Escalation Reason
-- Stores the reason AI escalated this ticket
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS escalation_reason VARCHAR(255) NULL 
COMMENT 'Reason for AI escalation (e.g., customer_request, high_urgency, complex_issue, sentiment_negative)';

-- Channel Field
-- Stores the communication channel for omnichannel tracking
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS channel VARCHAR(20) NULL DEFAULT 'voice'
COMMENT 'Communication channel: chat, voice, whatsapp';

-- AI Session Reference
-- Links to the AI conversation session
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS ai_session_id VARCHAR(100) NULL 
COMMENT 'Reference to AI conversation session ID';

-- AI Urgency Score
-- Stores the AI-computed urgency score
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS ai_urgency_score SMALLINT NULL 
COMMENT 'AI-computed urgency score (0-100)';

-- AI Agent that Created/Escalated
ALTER TABLE tickets 
ADD COLUMN IF NOT EXISTS ai_agent VARCHAR(30) NULL 
COMMENT 'AI agent that created or escalated this ticket';


-- ============================================================================
-- EXTENSION: ticket_items table (Media Support)
-- Purpose: Store WhatsApp media URLs linked to ticket items
-- ============================================================================

-- Media URL (primary image/video)
ALTER TABLE ticket_items 
ADD COLUMN IF NOT EXISTS media_url VARCHAR(500) NULL 
COMMENT 'Primary media URL (WhatsApp image/video)';

-- Media Type
ALTER TABLE ticket_items 
ADD COLUMN IF NOT EXISTS media_type VARCHAR(20) NULL 
COMMENT 'Media type: image, video, document';

-- Media Validated Flag
-- AI validates PRESENCE only, never judges quality
ALTER TABLE ticket_items 
ADD COLUMN IF NOT EXISTS media_validated TINYINT(1) NULL DEFAULT 0 
COMMENT 'AI validated media presence (0=No media, 1=Media attached). AI does NOT judge quality.';

-- Media Count
ALTER TABLE ticket_items 
ADD COLUMN IF NOT EXISTS media_count SMALLINT NULL DEFAULT 0 
COMMENT 'Number of media files attached to this ticket item';

-- WhatsApp Media ID (for retrieval)
ALTER TABLE ticket_items 
ADD COLUMN IF NOT EXISTS whatsapp_media_id VARCHAR(100) NULL 
COMMENT 'WhatsApp media ID for API retrieval';


-- ============================================================================
-- NEW TABLE: ticket_media
-- Purpose: Store multiple media files per ticket (one-to-many)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ticket_media (
    id INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT NULL,
    ticket_id INT NOT NULL,
    ticket_item_id INT NULL,
    
    -- Media identification
    media_url VARCHAR(500) NOT NULL COMMENT 'Full URL to media file',
    media_type VARCHAR(20) NOT NULL COMMENT 'image, video, document, audio',
    mime_type VARCHAR(50) NULL COMMENT 'MIME type (image/jpeg, video/mp4, etc.)',
    
    -- WhatsApp specific
    whatsapp_media_id VARCHAR(100) NULL COMMENT 'WhatsApp media ID for API retrieval',
    whatsapp_message_id VARCHAR(100) NULL COMMENT 'WhatsApp message ID containing media',
    
    -- Storage metadata
    file_size INT NULL COMMENT 'File size in bytes',
    file_name VARCHAR(255) NULL COMMENT 'Original file name if available',
    storage_path VARCHAR(500) NULL COMMENT 'Local storage path if downloaded',
    
    -- AI Validation (presence only, NOT quality)
    ai_validated TINYINT(1) DEFAULT 0 COMMENT 'AI confirmed media is present and accessible (1=Yes, 0=No)',
    ai_validation_note VARCHAR(255) NULL COMMENT 'AI validation note (e.g., "Image received", "Video 15s")',
    
    -- Timestamps
    uploaded_at DATETIME NULL COMMENT 'When media was uploaded by customer',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    CONSTRAINT fk_ticket_media_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ticket_media_item FOREIGN KEY (ticket_item_id) REFERENCES ticket_items(id) ON DELETE SET NULL,
    
    -- Indexes
    INDEX idx_ticket_media_ticket (ticket_id),
    INDEX idx_ticket_media_item (ticket_item_id),
    INDEX idx_ticket_media_type (media_type),
    INDEX idx_ticket_media_whatsapp (whatsapp_media_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Stores WhatsApp media files (images/videos) linked to tickets. AI validates presence only.';


-- ============================================================================
-- INDEXES for AI fields
-- Purpose: Optimize queries filtering by AI-related fields
-- ============================================================================

-- customercall indexes
CREATE INDEX IF NOT EXISTS idx_customercall_ai_intent ON customercall(ai_intent);
CREATE INDEX IF NOT EXISTS idx_customercall_ai_agent ON customercall(ai_agent);
CREATE INDEX IF NOT EXISTS idx_customercall_channel ON customercall(channel);
CREATE INDEX IF NOT EXISTS idx_customercall_ai_session ON customercall(ai_session_id);
CREATE INDEX IF NOT EXISTS idx_customercall_ai_confidence ON customercall(ai_confidence);

-- tickets indexes
CREATE INDEX IF NOT EXISTS idx_tickets_escalated_by_ai ON tickets(escalated_by_ai);
CREATE INDEX IF NOT EXISTS idx_tickets_channel ON tickets(channel);
CREATE INDEX IF NOT EXISTS idx_tickets_ai_session ON tickets(ai_session_id);
CREATE INDEX IF NOT EXISTS idx_tickets_ai_urgency ON tickets(ai_urgency_score);

-- Composite indexes for common AI analytics queries
CREATE INDEX IF NOT EXISTS idx_customercall_channel_ai_agent ON customercall(channel, ai_agent);
CREATE INDEX IF NOT EXISTS idx_tickets_channel_escalated ON tickets(channel, escalated_by_ai);


-- ============================================================================
-- CHANNEL ENUM REFERENCE (for application validation)
-- ============================================================================
-- Valid channel values:
-- - 'chat'     : Web chat widget
-- - 'voice'    : Phone/IVR (Avaya integration)
-- - 'whatsapp' : WhatsApp Business API
--
-- Note: MySQL doesn't enforce ENUM after ALTER, so validation should be
-- done at application/n8n level. Consider adding CHECK constraint if using MySQL 8.0.16+:
--
-- ALTER TABLE customercall ADD CONSTRAINT chk_customercall_channel 
--   CHECK (channel IN ('chat', 'voice', 'whatsapp'));
-- ALTER TABLE tickets ADD CONSTRAINT chk_tickets_channel 
--   CHECK (channel IN ('chat', 'voice', 'whatsapp'));


-- ============================================================================
-- MIGRATION VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify the schema extension was applied correctly:

-- Check customercall columns
-- SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT 
-- FROM INFORMATION_SCHEMA.COLUMNS 
-- WHERE TABLE_NAME = 'customercall' 
-- AND COLUMN_NAME IN ('ai_intent', 'ai_confidence', 'ai_agent', 'channel', 'ai_session_id');

-- Check tickets columns
-- SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT 
-- FROM INFORMATION_SCHEMA.COLUMNS 
-- WHERE TABLE_NAME = 'tickets' 
-- AND COLUMN_NAME IN ('escalated_by_ai', 'escalation_reason', 'channel', 'ai_session_id', 'ai_urgency_score');


-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================
-- WARNING: Only use if you need to revert these changes
--
-- ALTER TABLE customercall DROP COLUMN IF EXISTS ai_intent;
-- ALTER TABLE customercall DROP COLUMN IF EXISTS ai_confidence;
-- ALTER TABLE customercall DROP COLUMN IF EXISTS ai_agent;
-- ALTER TABLE customercall DROP COLUMN IF EXISTS channel;
-- ALTER TABLE customercall DROP COLUMN IF EXISTS ai_session_id;
-- ALTER TABLE customercall DROP COLUMN IF EXISTS ai_processed_at;
--
-- ALTER TABLE tickets DROP COLUMN IF EXISTS escalated_by_ai;
-- ALTER TABLE tickets DROP COLUMN IF EXISTS escalation_reason;
-- ALTER TABLE tickets DROP COLUMN IF EXISTS channel;
-- ALTER TABLE tickets DROP COLUMN IF EXISTS ai_session_id;
-- ALTER TABLE tickets DROP COLUMN IF EXISTS ai_urgency_score;
-- ALTER TABLE tickets DROP COLUMN IF EXISTS ai_agent;


-- ============================================================================
-- COMMENTS for documentation
-- ============================================================================
-- Note: MySQL 5.7+ supports COMMENT on columns via ALTER TABLE
-- The comments above are included in the ALTER statements
