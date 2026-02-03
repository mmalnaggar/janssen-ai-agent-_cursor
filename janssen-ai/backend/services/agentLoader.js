// Janssen AI - Agent Loader Service
// ============================================
// SOURCE OF TRUTH: /agents/*.agent.json
// This service loads full agent configurations
// and serves them to n8n and other consumers
// ============================================

const fs = require('fs');
const path = require('path');

// ============================================
// CONFIGURATION
// ============================================

// Primary path: Root /agents folder (source of truth)
const AGENTS_DIR_PRIMARY = path.join(__dirname, '..', '..', 'agents');

// Fallback path: /backend/agents folder
const AGENTS_DIR_FALLBACK = path.join(__dirname, '..', 'agents');

// File pattern for agent configuration files
const AGENT_FILE_PATTERN = /\.agent\.json$/;

// ============================================
// STORAGE
// ============================================

// Stores all loaded agents indexed by name
const agentsRegistry = {};

// Stores the router agent separately for intent routing
let routerAgent = null;

// ============================================
// LOADER FUNCTIONS
// ============================================

/**
 * Determines which agents directory to use
 * Prefers /agents (root) over /backend/agents
 */
function getAgentsDirectory() {
  if (fs.existsSync(AGENTS_DIR_PRIMARY)) {
    const files = fs.readdirSync(AGENTS_DIR_PRIMARY);
    const agentFiles = files.filter(file => AGENT_FILE_PATTERN.test(file));
    if (agentFiles.length > 0) {
      console.log(`[AgentLoader] Using primary agents directory: ${AGENTS_DIR_PRIMARY}`);
      return AGENTS_DIR_PRIMARY;
    }
  }
  
  console.log(`[AgentLoader] Using fallback agents directory: ${AGENTS_DIR_FALLBACK}`);
  return AGENTS_DIR_FALLBACK;
}

/**
 * Loads all *.agent.json files from the agents directory
 * Called once on module initialization
 */
function loadAllAgents() {
  const agentsDir = getAgentsDirectory();
  
  // Read all files from agents directory
  const files = fs.readdirSync(agentsDir);

  // Filter for agent JSON files only
  const agentFiles = files.filter(file => AGENT_FILE_PATTERN.test(file));

  // Load each agent file
  agentFiles.forEach(file => {
    const filePath = path.join(agentsDir, file);
    loadAgentFile(filePath);
  });

  // Identify and store the router agent for intent routing
  if (agentsRegistry['router']) {
    routerAgent = agentsRegistry['router'];
  }

  console.log(`[AgentLoader] Loaded ${Object.keys(agentsRegistry).length} agents: ${Object.keys(agentsRegistry).join(', ')}`);
}

/**
 * Loads a single agent configuration file
 * @param {string} filePath - Full path to the agent JSON file
 */
function loadAgentFile(filePath) {
  try {
    // Read file contents synchronously
    const fileContent = fs.readFileSync(filePath, 'utf-8');

    // Parse JSON content
    const agentConfig = JSON.parse(fileContent);

    // Validate and normalize structure
    const normalized = normalizeAgentConfig(agentConfig, filePath);
    if (!normalized) {
      return;
    }

    // Store agent in registry using name as key
    const agentName = normalized.name;
    agentsRegistry[agentName] = normalized;

    console.log(`[AgentLoader] Loaded agent: ${agentName}`);
  } catch (error) {
    console.error(`[AgentLoader] Error loading ${filePath}: ${error.message}`);
  }
}

/**
 * Normalizes agent configuration to handle both old and new formats
 * Old format: uses agent_name, role
 * New format: uses name, description, role
 */
function normalizeAgentConfig(agent, filePath) {
  // Get agent name (support both 'name' and 'agent_name')
  const name = agent.name || agent.agent_name;
  
  if (!name || typeof name !== 'string') {
    console.error(`[AgentLoader] Invalid agent: missing name in ${filePath}`);
    return null;
  }

  // Build normalized config
  const normalized = {
    // Core identity
    name: name,
    agent_name: name, // Backward compatibility
    description: agent.description || agent.role || '',
    role: agent.role || agent.description || '',
    version: agent.version || '1.0.0',
    status: agent.status || 'active',
    
    // Channel support
    supported_channels: agent.supported_channels || ['chat', 'voice', 'whatsapp'],
    supported_languages: agent.supported_languages || ['ar', 'en'],
    
    // Triggers for intent detection
    triggers: agent.triggers || {
      intent_keywords: agent.intents ? { ar: [], en: [] } : { ar: [], en: [] },
      intent_categories: []
    },
    
    // Allowed outputs
    allowed_outputs: agent.allowed_outputs || {
      text: { enabled: true, max_length: 400, tone: { ar: '', en: '' } },
      product_card: { enabled: false },
      handover: { enabled: true }
    },
    
    // Actions
    allowed_actions: agent.allowed_actions || [],
    forbidden_actions: agent.forbidden_actions || [],
    
    // Data sources
    data_sources: agent.data_sources || [],
    
    // Escalation rules
    escalation_rules: agent.escalation_rules || {
      conditions: agent.escalation_conditions ? 
        agent.escalation_conditions.map(c => ({ trigger: c, action: 'escalate_to_human', priority: 'medium' })) : 
        [],
      escalation_message: agent.messages || { ar: '', en: '' }
    },
    
    // Response templates
    response_templates: agent.response_templates || {},
    
    // Agent-specific data (copy all custom fields)
    ...extractCustomFields(agent)
  };

  // Handle old router format
  if (name === 'router' && agent.intents) {
    normalized.intents = agent.intents;
    normalized.default_agent = agent.default_agent || 'support';
  }

  return normalized;
}

/**
 * Extract custom fields specific to each agent type
 */
function extractCustomFields(agent) {
  const custom = {};
  
  // Support agent custom fields
  if (agent.delivery_info) {
    custom.delivery_info = agent.delivery_info;
  }
  
  // Warranty agent custom fields
  if (agent.warranty_policies) {
    custom.warranty_policies = agent.warranty_policies;
  }
  if (agent.claim_collection_fields) {
    custom.claim_collection_fields = agent.claim_collection_fields;
  }
  
  // Complaint agent custom fields
  if (agent.de_escalation_phrases) {
    custom.de_escalation_phrases = agent.de_escalation_phrases;
  }
  if (agent.complaint_categories) {
    custom.complaint_categories = agent.complaint_categories;
  }
  if (agent.complaint_collection_fields) {
    custom.complaint_collection_fields = agent.complaint_collection_fields;
  }
  if (agent.resolution_sla) {
    custom.resolution_sla = agent.resolution_sla;
  }
  
  // Escalation agent custom fields
  if (agent.routing_queues) {
    custom.routing_queues = agent.routing_queues;
  }
  if (agent.context_summary_template) {
    custom.context_summary_template = agent.context_summary_template;
  }
  if (agent.business_hours) {
    custom.business_hours = agent.business_hours;
  }
  if (agent.callback_settings) {
    custom.callback_settings = agent.callback_settings;
  }
  
  // Notes
  if (agent.notes) {
    custom.notes = agent.notes;
  }
  
  return custom;
}

// ============================================
// PUBLIC API FUNCTIONS
// ============================================

/**
 * Retrieves an agent configuration by its name
 * @param {string} name - The agent name to look up
 * @returns {object|null} - Agent configuration or null if not found
 */
function getAgentByName(name) {
  if (!name || typeof name !== 'string') {
    return null;
  }

  return agentsRegistry[name] || null;
}

/**
 * Routes an intent to the appropriate agent using the router agent's mapping
 * @param {string} intent - The intent string to route (e.g., "SALES_PRICE")
 * @returns {object|null} - Target agent configuration or null if not found
 */
function routeByIntent(intent) {
  // Check if router agent is loaded
  if (!routerAgent) {
    console.error('[AgentLoader] Router agent not loaded');
    return null;
  }

  // Check if router has intents mapping
  if (!routerAgent.intents) {
    console.error('[AgentLoader] Router agent has no intents mapping');
    return null;
  }

  // Look up the target agent name from intent mapping
  let targetAgentName = routerAgent.intents[intent];

  // Fall back to default agent if intent not found
  if (!targetAgentName && routerAgent.default_agent) {
    targetAgentName = routerAgent.default_agent;
  }

  // Return the target agent configuration
  if (targetAgentName) {
    return getAgentByName(targetAgentName);
  }

  return null;
}

/**
 * Returns all loaded agents (for debugging/admin purposes)
 * @returns {object} - Object containing all agents indexed by name
 */
function getAllAgents() {
  return { ...agentsRegistry };
}

/**
 * Returns the list of all loaded agent names
 * @returns {string[]} - Array of agent names
 */
function getAgentNames() {
  return Object.keys(agentsRegistry);
}

/**
 * Reloads all agents from disk
 * Useful for hot-reloading configuration changes
 */
function reloadAgents() {
  // Clear existing registry
  Object.keys(agentsRegistry).forEach(key => delete agentsRegistry[key]);
  routerAgent = null;
  
  // Reload all agents
  loadAllAgents();
  
  return {
    success: true,
    count: Object.keys(agentsRegistry).length,
    agents: getAgentNames()
  };
}

// ============================================
// INITIALIZATION
// ============================================

// Load all agents when this module is first required
loadAllAgents();

// ============================================
// MODULE EXPORTS
// ============================================

module.exports = {
  getAgentByName,
  routeByIntent,
  getAllAgents,
  getAgentNames,
  reloadAgents
};
