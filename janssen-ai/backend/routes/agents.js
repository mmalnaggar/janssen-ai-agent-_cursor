// Janssen AI - Agents API Routes
// ============================================
// Purpose: Serve agent configurations to n8n and other consumers
// This is the HTTP interface to the agentLoader service
// ============================================

const express = require('express');
const router = express.Router();
const agentLoader = require('../services/agentLoader');

// ============================================
// GET /api/agents
// List all available agents
// ============================================
router.get('/', (req, res) => {
  const agents = agentLoader.getAllAgents();
  const agentNames = agentLoader.getAgentNames();

  res.json({
    success: true,
    count: agentNames.length,
    agents: agentNames.map(name => ({
      name: agents[name].name,
      role: agents[name].role,
      status: agents[name].status || 'active',
      supported_channels: agents[name].supported_channels,
      supported_languages: agents[name].supported_languages
    }))
  });
});

// ============================================
// GET /api/agents/:name
// Get full agent configuration by name
// This is the primary endpoint for n8n
// ============================================
router.get('/:name', (req, res) => {
  const { name } = req.params;
  const agent = agentLoader.getAgentByName(name);

  if (!agent) {
    return res.status(404).json({
      success: false,
      error: `Agent '${name}' not found`,
      available_agents: agentLoader.getAgentNames()
    });
  }

  // Return full agent configuration
  res.json(agent);
});

// ============================================
// GET /api/agents/:name/config
// Get specific config section of an agent
// Useful for n8n to fetch only what it needs
// ============================================
router.get('/:name/config', (req, res) => {
  const { name } = req.params;
  const { section } = req.query;
  const agent = agentLoader.getAgentByName(name);

  if (!agent) {
    return res.status(404).json({
      success: false,
      error: `Agent '${name}' not found`
    });
  }

  // If section specified, return only that section
  if (section) {
    const sections = section.split(',');
    const result = {};
    
    sections.forEach(s => {
      if (agent[s] !== undefined) {
        result[s] = agent[s];
      }
    });

    return res.json({
      name: agent.name,
      ...result
    });
  }

  // Return core config sections
  res.json({
    name: agent.name,
    role: agent.role,
    allowed_outputs: agent.allowed_outputs,
    allowed_actions: agent.allowed_actions,
    forbidden_actions: agent.forbidden_actions,
    escalation_rules: agent.escalation_rules,
    response_templates: agent.response_templates
  });
});

// ============================================
// GET /api/agents/:name/triggers
// Get trigger keywords for intent detection
// ============================================
router.get('/:name/triggers', (req, res) => {
  const { name } = req.params;
  const { language } = req.query;
  const agent = agentLoader.getAgentByName(name);

  if (!agent) {
    return res.status(404).json({
      success: false,
      error: `Agent '${name}' not found`
    });
  }

  const triggers = agent.triggers || {};
  
  // If language specified, return only that language's keywords
  if (language && triggers.intent_keywords) {
    return res.json({
      name: agent.name,
      language: language,
      keywords: triggers.intent_keywords[language] || [],
      intent_categories: triggers.intent_categories || []
    });
  }

  res.json({
    name: agent.name,
    triggers: triggers
  });
});

// ============================================
// GET /api/agents/:name/escalation
// Get escalation rules and messages
// ============================================
router.get('/:name/escalation', (req, res) => {
  const { name } = req.params;
  const agent = agentLoader.getAgentByName(name);

  if (!agent) {
    return res.status(404).json({
      success: false,
      error: `Agent '${name}' not found`
    });
  }

  res.json({
    name: agent.name,
    escalation_rules: agent.escalation_rules || {},
    de_escalation_phrases: agent.de_escalation_phrases || null,
    routing_queues: agent.routing_queues || null
  });
});

// ============================================
// GET /api/agents/:name/templates
// Get response templates
// ============================================
router.get('/:name/templates', (req, res) => {
  const { name } = req.params;
  const { language, template } = req.query;
  const agent = agentLoader.getAgentByName(name);

  if (!agent) {
    return res.status(404).json({
      success: false,
      error: `Agent '${name}' not found`
    });
  }

  const templates = agent.response_templates || {};

  // If specific template requested
  if (template) {
    const t = templates[template];
    if (!t) {
      return res.status(404).json({
        success: false,
        error: `Template '${template}' not found for agent '${name}'`
      });
    }

    // If language specified, return only that language
    if (language && t[language]) {
      return res.json({
        name: agent.name,
        template: template,
        language: language,
        text: t[language]
      });
    }

    return res.json({
      name: agent.name,
      template: template,
      content: t
    });
  }

  res.json({
    name: agent.name,
    response_templates: templates
  });
});

// ============================================
// POST /api/agents/reload
// Hot-reload all agent configurations
// ============================================
router.post('/reload', (req, res) => {
  try {
    const result = agentLoader.reloadAgents();
    res.json({
      success: true,
      message: 'Agents reloaded successfully',
      ...result
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: `Failed to reload agents: ${error.message}`
    });
  }
});

// ============================================
// POST /api/agents/route
// Route an intent to the appropriate agent
// ============================================
router.post('/route', (req, res) => {
  const { intent } = req.body;

  if (!intent) {
    return res.status(400).json({
      success: false,
      error: 'Missing required field: intent'
    });
  }

  const agent = agentLoader.routeByIntent(intent);

  if (!agent) {
    return res.json({
      success: true,
      routed: false,
      message: `No agent found for intent '${intent}'`,
      default_agent: 'support'
    });
  }

  res.json({
    success: true,
    routed: true,
    intent: intent,
    agent: agent
  });
});

module.exports = router;
