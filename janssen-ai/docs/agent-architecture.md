# Janssen AI - Agent Architecture

## Overview

The Janssen AI system uses a multi-agent architecture where specialized agents handle different types of customer interactions. Each agent has defined capabilities, restrictions, and escalation rules.

## Architecture Diagram

```
                    ┌─────────────────┐
                    │   Customer      │
                    │  (Chat/Voice/   │
                    │   WhatsApp)     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Channel Layer  │
                    │  (Widget/Avaya/ │
                    │   WhatsApp API) │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   n8n Workflow  │
                    │  (Orchestrator) │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───┐  ┌───────▼──────┐  ┌───▼────────┐
     │  Intent    │  │  Knowledge   │  │  Business  │
     │  Detection │  │  Base (DB)   │  │  Rules     │
     └────────┬───┘  └───────┬──────┘  └───┬────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼────────┐
                    │  Agent Router   │
                    └────────┬────────┘
                             │
        ┌────────┬───────┬───┴───┬────────┬─────────┐
        │        │       │       │        │         │
   ┌────▼──┐ ┌───▼───┐ ┌─▼──┐ ┌──▼───┐ ┌──▼────┐ ┌──▼──────┐
   │ Sales │ │Support│ │War-│ │Comp- │ │Escal- │ │  Human  │
   │ Agent │ │ Agent │ │anty│ │laint │ │ation  │ │  Agent  │
   └───────┘ └───────┘ └────┘ └──────┘ └───────┘ └─────────┘
```

## Agent Definitions

### 1. Sales Agent (`sales.agent.json`)

**Role**: Sales Assistant

**Capabilities**:
- Fetch product information
- Provide pricing from database
- Recommend products based on needs
- Capture sales leads
- Show product cards

**Restrictions**:
- Never invent prices
- Never promise specific delivery times
- Never offer unauthorized discounts

**Escalation Triggers**:
- Missing price in database
- Bulk order inquiries
- Custom discount requests

**Tone**:
- Arabic: Egyptian Arabic, confident, persuasive but polite
- English: Professional, friendly, sales-oriented

---

### 2. Support Agent (`support.agent.json`)

**Role**: Customer Support Agent

**Capabilities**:
- Answer FAQs
- Provide delivery information
- Share store locations
- Explain processes

**Restrictions**:
- No price negotiation
- No warranty decisions
- No legal statements

**Escalation Triggers**:
- Policy not found
- Complex delivery issues
- Multiple failed answers

**Tone**:
- Arabic: Egyptian Arabic, calm and reassuring
- English: Clear, calm, and helpful

---

### 3. Warranty Agent (`warranty.agent.json`)

**Role**: Warranty Support Agent

**Capabilities**:
- Explain warranty policies
- Guide warranty activation
- Collect claim details
- Check warranty status

**Restrictions**:
- Never approve/reject claims
- Never promise replacements
- No legal statements

**Escalation Triggers**:
- Warranty claim request
- Warranty disputes
- Complex defects

**Tone**:
- Arabic: Egyptian Arabic, professional and understanding
- English: Professional, empathetic, informative

---

### 4. Complaint Agent (`complaint.agent.json`)

**Role**: Complaint Handling Agent

**Capabilities**:
- Acknowledge complaints
- Validate customer feelings
- Collect complaint details
- De-escalate situations

**Restrictions**:
- Never argue with customer
- Never blame customer
- Never promise refunds/compensation

**Escalation Triggers**:
- All complaints (after collection)
- Angry customers
- Legal/media threats

**Tone**:
- Arabic: Egyptian Arabic, deeply empathetic, apologetic
- English: Empathetic, apologetic, patient

---

### 5. Escalation Agent (`escalation.agent.json`)

**Role**: Human Escalation Handler

**Capabilities**:
- Summarize conversation
- Route to appropriate queue
- Provide wait time
- Offer callback

**Restrictions**:
- Never attempt resolution
- Never delay handover
- Never answer questions

**Queues**:
- Sales Queue
- Support Queue
- Warranty Queue
- Complaints Queue (priority)
- Priority Queue (critical)

---

## Intent Routing

| Intent | Routed To |
|--------|-----------|
| SALES_PRICE | sales |
| SALES_RECOMMENDATION | sales |
| DELIVERY | support |
| WARRANTY | warranty |
| COMPLAINT | complaint |
| HUMAN_REQUEST | escalation |
| GENERAL | support |

## Data Flow

1. **Message Received** → Channel layer receives customer message
2. **Normalization** → Clean and validate input, detect language
3. **Intent Detection** → Classify intent using keywords or AI
4. **Agent Selection** → Route to appropriate agent
5. **Knowledge Fetch** → Retrieve relevant data from database
6. **Rule Enforcement** → Check allowed/forbidden actions
7. **Response Generation** → Generate response with agent's tone
8. **Escalation Check** → Evaluate if human needed
9. **Response Delivery** → Send response to customer
10. **Logging** → Log interaction for analytics

## Language Support

| Language | Code | Dialect |
|----------|------|---------|
| Arabic | ar | Egyptian Arabic (عامية مصرية) |
| English | en | Standard English |

## Escalation Priority

| Priority | Response SLA | Examples |
|----------|--------------|----------|
| Critical | < 2 minutes | Legal threats, angry VIP |
| High | < 15 minutes | Complaints, warranty claims |
| Medium | < 1 hour | Sales inquiries, complex questions |

## Agent Files Location

```
agents/
├── sales.agent.json
├── support.agent.json
├── warranty.agent.json
├── complaint.agent.json
└── escalation.agent.json
```

## Best Practices

1. **Never Hardcode** - All business rules in agent configs
2. **Always Log** - Every action logged to agents_log
3. **Fail Gracefully** - Unknown intents go to support
4. **Escalate Early** - When in doubt, escalate
5. **Respect Tone** - Each agent has defined tone per language
