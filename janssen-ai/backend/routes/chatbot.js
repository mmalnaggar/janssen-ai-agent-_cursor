// Janssen AI - Chatbot Routes
// Handles incoming customer messages and routes them to appropriate agents
// Note: Database operations are placeholder - replace with actual DB client

const express = require('express');
const router = express.Router();
const agentLoader = require('../services/agentLoader');

// ============================================
// TEMPORARY: In-memory storage (replace with PostgreSQL)
// ============================================
const conversations = new Map();
const conversationMessages = [];
const agentsLog = [];
let conversationIdCounter = 1;
let messageIdCounter = 1;
let logIdCounter = 1;

// ============================================
// INTENT DETECTION (Temporary keyword-based)
// This will be replaced with AI-based intent detection
// ============================================

/**
 * Detects intent from message text using simple keyword matching
 * @param {string} text - The message text to analyze
 * @returns {object} - Object with intent and confidence
 */
function detectIntent(text) {
  // Normalize text for matching
  const lowerText = text.toLowerCase();

  // Define keyword patterns for each intent
  const intentPatterns = {
    // Sales-related intents
    SALES_PRICE: [
      'price', 'cost', 'how much', 'كام', 'سعر', 'بكام', 'تكلفة'
    ],
    SALES_RECOMMENDATION: [
      'recommend', 'suggest', 'best', 'which', 'help me choose',
      'انصحني', 'ايه احسن', 'اختار', 'افضل'
    ],

    // Support-related intents
    DELIVERY: [
      'delivery', 'shipping', 'deliver', 'arrive', 'when',
      'توصيل', 'شحن', 'يوصل', 'امتى', 'ميعاد'
    ],
    WARRANTY: [
      'warranty', 'guarantee', 'broken', 'defect', 'repair',
      'ضمان', 'مكسور', 'عيب', 'تصليح'
    ],

    // Escalation-related intents
    COMPLAINT: [
      'complaint', 'problem', 'angry', 'disappointed', 'terrible', 'worst',
      'شكوى', 'مشكلة', 'زعلان', 'سيء', 'وحش'
    ],
    HUMAN_REQUEST: [
      'human', 'agent', 'person', 'real person', 'talk to someone',
      'حد يرد', 'اتكلم مع حد', 'موظف', 'خدمة عملاء'
    ]
  };

  // Check each intent pattern
  for (const [intent, keywords] of Object.entries(intentPatterns)) {
    for (const keyword of keywords) {
      if (lowerText.includes(keyword)) {
        return {
          intent: intent,
          confidence: 0.75 // Fixed confidence for keyword matching
        };
      }
    }
  }

  // Default to GENERAL intent if no keywords match
  return {
    intent: 'GENERAL',
    confidence: 0.5
  };
}

// ============================================
// DATABASE HELPER FUNCTIONS (Temporary in-memory)
// Replace these with actual PostgreSQL queries
// ============================================

/**
 * Finds or creates a conversation for the given session
 * @param {string} sessionId - Unique session identifier
 * @param {object} metadata - Additional conversation metadata
 * @returns {object} - Conversation object
 */
function findOrCreateConversation(sessionId, metadata = {}) {
  // Check if conversation exists
  if (conversations.has(sessionId)) {
    const conversation = conversations.get(sessionId);
    // Update last message timestamp
    conversation.last_message_at = new Date().toISOString();
    return conversation;
  }

  // Create new conversation
  const conversation = {
    id: conversationIdCounter++,
    session_id: sessionId,
    customer_phone: metadata.phone || null,
    customer_name: metadata.name || null,
    channel: metadata.channel || 'whatsapp',
    language: metadata.language || 'ar',
    status: 'open',
    started_at: new Date().toISOString(),
    last_message_at: new Date().toISOString(),
    assigned_agent: null,
    escalated: false,
    created_at: new Date().toISOString()
  };

  conversations.set(sessionId, conversation);
  return conversation;
}

/**
 * Inserts a message into the conversation_messages table
 * @param {object} messageData - Message data to insert
 * @returns {object} - Inserted message with ID
 */
function insertMessage(messageData) {
  const message = {
    id: messageIdCounter++,
    conversation_id: messageData.conversation_id,
    sender_type: messageData.sender_type,
    sender_id: messageData.sender_id || null,
    message_text: messageData.message_text,
    message_type: messageData.message_type || 'text',
    intent_detected: messageData.intent_detected || null,
    confidence_score: messageData.confidence_score || null,
    created_at: new Date().toISOString()
  };

  conversationMessages.push(message);
  return message;
}

/**
 * Logs agent decision/action to agents_log table
 * @param {object} logData - Log entry data
 * @returns {object} - Inserted log entry with ID
 */
function insertAgentLog(logData) {
  const logEntry = {
    id: logIdCounter++,
    conversation_id: logData.conversation_id,
    agent_name: logData.agent_name,
    action_type: logData.action_type,
    intent_received: logData.intent_received || null,
    input_text: logData.input_text || null,
    output_text: logData.output_text || null,
    data_fetched: logData.data_fetched || null,
    response_time_ms: logData.response_time_ms || null,
    success: logData.success !== undefined ? logData.success : true,
    error_message: logData.error_message || null,
    escalated: logData.escalated || false,
    created_at: new Date().toISOString()
  };

  agentsLog.push(logEntry);
  return logEntry;
}

// ============================================
// ROUTE: POST /api/message
// Main endpoint for receiving customer messages
// ============================================

router.post('/message', (req, res) => {
  // Record start time for response time logging
  const startTime = Date.now();

  try {
    // ----------------------------------------
    // Step 1: Validate request body
    // ----------------------------------------
    const { session_id, message, phone, name, channel, language } = req.body;

    // Check required fields
    if (!session_id) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: session_id'
      });
    }

    if (!message || typeof message !== 'string' || message.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Missing or invalid field: message'
      });
    }

    // ----------------------------------------
    // Step 2: Find or create conversation
    // ----------------------------------------
    const conversation = findOrCreateConversation(session_id, {
      phone,
      name,
      channel,
      language
    });

    // ----------------------------------------
    // Step 3: Detect intent from message
    // ----------------------------------------
    const intentResult = detectIntent(message);

    // ----------------------------------------
    // Step 4: Insert message into conversation_messages
    // ----------------------------------------
    const savedMessage = insertMessage({
      conversation_id: conversation.id,
      sender_type: 'customer',
      sender_id: phone || session_id,
      message_text: message.trim(),
      message_type: 'text',
      intent_detected: intentResult.intent,
      confidence_score: intentResult.confidence
    });

    // ----------------------------------------
    // Step 5: Route to appropriate agent using agentLoader
    // ----------------------------------------
    const targetAgent = agentLoader.routeByIntent(intentResult.intent);

    if (!targetAgent) {
      // Log the failure
      insertAgentLog({
        conversation_id: conversation.id,
        agent_name: 'router',
        action_type: 'ROUTE_FAILED',
        intent_received: intentResult.intent,
        input_text: message,
        success: false,
        error_message: 'No agent found for intent',
        response_time_ms: Date.now() - startTime
      });

      return res.status(500).json({
        success: false,
        error: 'Unable to route message to agent'
      });
    }

    // Update conversation with assigned agent
    conversation.assigned_agent = targetAgent.agent_name;

    // Check if this is an escalation
    const isEscalation = targetAgent.agent_name === 'escalation';
    if (isEscalation) {
      conversation.escalated = true;
    }

    // ----------------------------------------
    // Step 6: Log agent decision to agents_log
    // ----------------------------------------
    const logEntry = insertAgentLog({
      conversation_id: conversation.id,
      agent_name: targetAgent.agent_name,
      action_type: 'MESSAGE_ROUTED',
      intent_received: intentResult.intent,
      input_text: message,
      output_text: null, // No AI response yet
      success: true,
      escalated: isEscalation,
      response_time_ms: Date.now() - startTime
    });

    // ----------------------------------------
    // Step 7: Build and return JSON response
    // ----------------------------------------

    // Get appropriate message based on language (for escalation agent)
    let agentMessage = null;
    if (targetAgent.messages) {
      const lang = conversation.language || 'ar';
      agentMessage = targetAgent.messages[lang] || targetAgent.messages['en'];
    }

    // Build response object
    const response = {
      success: true,
      data: {
        conversation_id: conversation.id,
        message_id: savedMessage.id,
        session_id: session_id,
        intent: {
          detected: intentResult.intent,
          confidence: intentResult.confidence
        },
        agent: {
          name: targetAgent.agent_name,
          role: targetAgent.role
        },
        escalated: isEscalation,
        // Placeholder for AI response (not implemented yet)
        response: agentMessage || {
          text: null,
          note: 'AI response not implemented yet'
        },
        timestamp: new Date().toISOString()
      }
    };

    return res.json(response);

  } catch (error) {
    // Log unexpected errors
    console.error('[Chatbot] Error processing message:', error);

    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: error.message
    });
  }
});

// ============================================
// ROUTE: GET /api/conversation/:sessionId
// Retrieve conversation history (for debugging)
// ============================================

router.get('/conversation/:sessionId', (req, res) => {
  const { sessionId } = req.params;

  // Find conversation
  const conversation = conversations.get(sessionId);

  if (!conversation) {
    return res.status(404).json({
      success: false,
      error: 'Conversation not found'
    });
  }

  // Get messages for this conversation
  const messages = conversationMessages.filter(
    m => m.conversation_id === conversation.id
  );

  // Get agent logs for this conversation
  const logs = agentsLog.filter(
    l => l.conversation_id === conversation.id
  );

  return res.json({
    success: true,
    data: {
      conversation,
      messages,
      agent_logs: logs
    }
  });
});

module.exports = router;
