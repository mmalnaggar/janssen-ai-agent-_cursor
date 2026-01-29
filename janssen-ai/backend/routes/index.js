// Janssen AI - Main API Routes
// ============================================
// Aggregates all route modules
// ============================================

const express = require('express');
const router = express.Router();

// Import route modules
const chatbotRoutes = require('./chatbot');
const agentRoutes = require('./agents');

// ============================================
// Mount routes
// ============================================

// Chatbot routes: /api/message, /api/conversation/:sessionId
router.use('/', chatbotRoutes);

// Agent routes: /api/agents, /api/agents/:name, etc.
router.use('/agents', agentRoutes);

module.exports = router;
