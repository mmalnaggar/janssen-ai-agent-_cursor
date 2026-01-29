-- Janssen AI Database Schema
-- PostgreSQL-compatible SQL
-- Purpose: Backend database for AI customer service system

-- ============================================
-- TABLE: products
-- Purpose: Stores the product catalog (mattresses, accessories)
-- Used by: Sales Agent for product lookups and recommendations
-- ============================================
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    product_code VARCHAR(50) UNIQUE NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255),
    description_en TEXT,
    description_ar TEXT,
    category VARCHAR(100),
    material VARCHAR(100),
    firmness_level VARCHAR(50),
    support_type VARCHAR(100),
    dimensions VARCHAR(100),
    warranty_years INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: prices
-- Purpose: Stores pricing information for products
-- Used by: Sales Agent for price lookups
-- Note: Separate from products to allow price versioning and history
-- ============================================
CREATE TABLE prices (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id),
    price_egp DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'EGP',
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    is_current BOOLEAN DEFAULT TRUE,
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: delivery_rules
-- Purpose: Stores delivery policies and regional rules
-- Used by: Support Agent for delivery inquiries
-- ============================================
CREATE TABLE delivery_rules (
    id SERIAL PRIMARY KEY,
    region VARCHAR(100) NOT NULL,
    governorate VARCHAR(100),
    delivery_days_min INTEGER DEFAULT 1,
    delivery_days_max INTEGER DEFAULT 7,
    delivery_fee_egp DECIMAL(10, 2) DEFAULT 0,
    free_delivery_threshold DECIMAL(10, 2),
    notes_en TEXT,
    notes_ar TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: conversations
-- Purpose: Stores chat conversation history
-- Used by: All agents for context and conversation tracking
-- ============================================
CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20),
    customer_name VARCHAR(255),
    channel VARCHAR(50) DEFAULT 'whatsapp',
    language VARCHAR(10) DEFAULT 'ar',
    status VARCHAR(50) DEFAULT 'open',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    last_message_at TIMESTAMP,
    assigned_agent VARCHAR(50),
    escalated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: conversation_messages
-- Purpose: Stores individual messages within conversations
-- Used by: All agents for message history and context
-- ============================================
CREATE TABLE conversation_messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id),
    sender_type VARCHAR(20) NOT NULL,
    sender_id VARCHAR(100),
    message_text TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text',
    intent_detected VARCHAR(100),
    confidence_score DECIMAL(5, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: leads
-- Purpose: Stores customer leads captured during sales conversations
-- Used by: Sales Agent when capturing potential customers
-- ============================================
CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER REFERENCES conversations(id),
    customer_name VARCHAR(255),
    customer_phone VARCHAR(20) NOT NULL,
    customer_email VARCHAR(255),
    interested_product_id INTEGER REFERENCES products(id),
    interest_level VARCHAR(50),
    notes TEXT,
    source VARCHAR(100) DEFAULT 'whatsapp',
    status VARCHAR(50) DEFAULT 'new',
    follow_up_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: agents_log
-- Purpose: Logs all agent activities and responses for auditing
-- Used by: System monitoring and debugging AI behavior
-- ============================================
CREATE TABLE agents_log (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER REFERENCES conversations(id),
    agent_name VARCHAR(50) NOT NULL,
    action_type VARCHAR(100) NOT NULL,
    intent_received VARCHAR(100),
    input_text TEXT,
    output_text TEXT,
    data_fetched TEXT,
    response_time_ms INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    escalated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES
-- Purpose: Basic indexes for common query patterns
-- ============================================
CREATE INDEX idx_products_code ON products(product_code);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_prices_product ON prices(product_id);
CREATE INDEX idx_prices_current ON prices(is_current);
CREATE INDEX idx_conversations_session ON conversations(session_id);
CREATE INDEX idx_conversations_phone ON conversations(customer_phone);
CREATE INDEX idx_conversation_messages_convo ON conversation_messages(conversation_id);
CREATE INDEX idx_leads_phone ON leads(customer_phone);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_agents_log_conversation ON agents_log(conversation_id);
CREATE INDEX idx_agents_log_agent ON agents_log(agent_name);
CREATE INDEX idx_agents_log_created ON agents_log(created_at);
