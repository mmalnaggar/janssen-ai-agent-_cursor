# Janssen AI - Governance & Risk Control Layer

> **Document Type:** Governance Framework & Technical Specification  
> **Version:** 1.0.0  
> **Last Updated:** 2026-01-29  
> **Classification:** Internal - Confidential  
> **Owner:** AI Governance Committee

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Governance Architecture](#2-governance-architecture)
3. [AI Policy Matrix](#3-ai-policy-matrix)
4. [Agent Action Whitelist](#4-agent-action-whitelist)
5. [Runtime Response Validation](#5-runtime-response-validation)
6. [Audit Log Schema](#6-audit-log-schema)
7. [Escalation Enforcement Rules](#7-escalation-enforcement-rules)
8. [Global Controls (Kill-Switch & Limited Mode)](#8-global-controls)
9. [Configuration Management](#9-configuration-management)
10. [Implementation Guide](#10-implementation-guide)

---

## 1. Executive Summary

### Purpose

The AI Governance & Risk Control Layer ensures that all AI interactions comply with company policies, legal requirements, and ethical standards. This layer operates as an independent enforcement mechanism that:

- **Validates** all AI responses before delivery to customers
- **Blocks** prohibited actions and content
- **Enforces** mandatory escalation triggers
- **Logs** every interaction for audit and compliance
- **Enables** emergency controls without code changes

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Config-Driven** | All rules externalized to JSON configuration files |
| **Non-Invasive** | No modifications to agents or widget code |
| **Fail-Safe** | On any error, escalate to human (never expose risk) |
| **Observable** | Complete audit trail for every decision |
| **Layered Defense** | Multiple validation stages (pre-process, runtime, post-process) |

### System Context

```
Agents: sales, support, warranty, complaint, escalation
Orchestration: n8n workflow engine
Analytics: analytics_events table (PostgreSQL)
Governance: Config-driven policy enforcement via n8n
```

---

## 2. Governance Architecture

### 2.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AI GOVERNANCE ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                        CONFIGURATION LAYER                            │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │ │
│  │  │   Policy    │ │  Whitelist  │ │ Escalation  │ │   Global    │     │ │
│  │  │   Matrix    │ │   Rules     │ │   Rules     │ │  Controls   │     │ │
│  │  │   .json     │ │   .json     │ │   .json     │ │   .json     │     │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                      │                                      │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      ENFORCEMENT LAYER (n8n)                          │ │
│  │                                                                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐               │ │
│  │  │ PRE-PROCESS │───▶│   RUNTIME   │───▶│POST-PROCESS │               │ │
│  │  │   GUARD     │    │   GUARD     │    │   GUARD     │               │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘               │ │
│  │        │                  │                  │                        │ │
│  │        ▼                  ▼                  ▼                        │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │  │                      AUDIT LOGGER                               │ │ │
│  │  │              (Every decision logged immutably)                  │ │ │
│  │  └─────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                      │                                      │
│                    ┌─────────────────┼─────────────────┐                   │
│                    ▼                 ▼                 ▼                   │
│             ┌──────────┐      ┌──────────┐      ┌──────────┐              │
│             │  ALLOW   │      │  MODIFY  │      │  BLOCK   │              │
│             │ Response │      │ Response │      │ Escalate │              │
│             └──────────┘      └──────────┘      └──────────┘              │
│                    │                 │                 │                   │
│                    └─────────────────┼─────────────────┘                   │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         MONITORING LAYER                              │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │ │
│  │  │   Audit     │ │   Alert     │ │  Dashboard  │ │   Report    │     │ │
│  │  │   Database  │ │   System    │ │   (Live)    │ │   (Weekly)  │     │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘     │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Request Flow with Governance

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        REQUEST FLOW WITH GOVERNANCE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Customer         Widget/Voice          n8n                 Agent           │
│     │                  │                 │                    │             │
│     │  1. Message      │                 │                    │             │
│     │─────────────────▶│                 │                    │             │
│     │                  │  2. Request     │                    │             │
│     │                  │────────────────▶│                    │             │
│     │                  │                 │                    │             │
│     │                  │      ┌──────────┴──────────┐         │             │
│     │                  │      │ 3. PRE-PROCESS      │         │             │
│     │                  │      │    GUARD            │         │             │
│     │                  │      │ • Check kill-switch │         │             │
│     │                  │      │ • Validate input    │         │             │
│     │                  │      │ • Check blacklist   │         │             │
│     │                  │      └──────────┬──────────┘         │             │
│     │                  │                 │                    │             │
│     │                  │    [BLOCKED?]───┼───▶ Escalate       │             │
│     │                  │                 │                    │             │
│     │                  │                 │  4. Route to Agent │             │
│     │                  │                 │───────────────────▶│             │
│     │                  │                 │                    │             │
│     │                  │                 │  5. Agent Response │             │
│     │                  │                 │◀───────────────────│             │
│     │                  │                 │                    │             │
│     │                  │      ┌──────────┴──────────┐         │             │
│     │                  │      │ 6. RUNTIME GUARD    │         │             │
│     │                  │      │ • Validate response │         │             │
│     │                  │      │ • Check whitelist   │         │             │
│     │                  │      │ • Content filter    │         │             │
│     │                  │      │ • Confidence check  │         │             │
│     │                  │      └──────────┬──────────┘         │             │
│     │                  │                 │                    │             │
│     │                  │    [MODIFIED?]──┼───▶ Sanitize       │             │
│     │                  │    [BLOCKED?]───┼───▶ Escalate       │             │
│     │                  │                 │                    │             │
│     │                  │      ┌──────────┴──────────┐         │             │
│     │                  │      │ 7. POST-PROCESS     │         │             │
│     │                  │      │    GUARD            │         │             │
│     │                  │      │ • Final validation  │         │             │
│     │                  │      │ • Audit logging     │         │             │
│     │                  │      │ • Analytics event   │         │             │
│     │                  │      └──────────┬──────────┘         │             │
│     │                  │                 │                    │             │
│     │                  │  8. Response    │                    │             │
│     │                  │◀────────────────│                    │             │
│     │  9. Response     │                 │                    │             │
│     │◀─────────────────│                 │                    │             │
│     │                  │                 │                    │             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Component Interaction

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       COMPONENT INTERACTION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                     ┌─────────────────────────────┐                         │
│                     │     CONFIG STORE            │                         │
│                     │  (Redis / Environment)      │                         │
│                     └─────────────┬───────────────┘                         │
│                                   │                                         │
│         ┌─────────────────────────┼─────────────────────────┐               │
│         │                         │                         │               │
│         ▼                         ▼                         ▼               │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐         │
│  │   Policy    │          │  Whitelist  │          │   Global    │         │
│  │   Loader    │          │   Loader    │          │  Controls   │         │
│  └──────┬──────┘          └──────┬──────┘          └──────┬──────┘         │
│         │                        │                        │                 │
│         └────────────────────────┼────────────────────────┘                 │
│                                  │                                          │
│                                  ▼                                          │
│                    ┌─────────────────────────────┐                          │
│                    │    GOVERNANCE ENGINE        │                          │
│                    │    (n8n Function Node)      │                          │
│                    └─────────────┬───────────────┘                          │
│                                  │                                          │
│         ┌────────────────────────┼────────────────────────┐                 │
│         │                        │                        │                 │
│         ▼                        ▼                        ▼                 │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐         │
│  │ Pre-Process │          │   Runtime   │          │Post-Process │         │
│  │   Guard     │          │   Guard     │          │   Guard     │         │
│  └─────────────┘          └─────────────┘          └─────────────┘         │
│                                  │                                          │
│                                  ▼                                          │
│                    ┌─────────────────────────────┐                          │
│                    │      AUDIT DATABASE         │                          │
│                    │   (governance_audit_log)    │                          │
│                    └─────────────────────────────┘                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. AI Policy Matrix

### 3.1 Policy Matrix Overview

The Policy Matrix defines what AI agents can and cannot do across all interaction types.

### 3.2 Policy Matrix JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AIPolicyMatrix",
  "type": "object",
  "required": ["version", "effective_date", "policies"],
  "properties": {
    "version": { "type": "string" },
    "effective_date": { "type": "string", "format": "date" },
    "last_reviewed": { "type": "string", "format": "date" },
    "approved_by": { "type": "string" },
    "policies": {
      "type": "object",
      "properties": {
        "allowed_actions": { "type": "array" },
        "forbidden_actions": { "type": "array" },
        "conditional_actions": { "type": "array" },
        "content_restrictions": { "type": "object" }
      }
    }
  }
}
```

### 3.3 Complete Policy Matrix Configuration

```json
{
  "version": "1.0.0",
  "effective_date": "2026-01-29",
  "last_reviewed": "2026-01-29",
  "approved_by": "AI Governance Committee",
  "description": "Janssen AI Policy Matrix - Defines allowed and forbidden AI actions",
  
  "policies": {
    "allowed_actions": [
      {
        "action_id": "ALLOW_001",
        "action": "provide_product_information",
        "description": "Share product specifications, features, and general information",
        "scope": "all_agents",
        "conditions": [],
        "audit_level": "STANDARD"
      },
      {
        "action_id": "ALLOW_002",
        "action": "answer_faq",
        "description": "Respond to frequently asked questions from knowledge base",
        "scope": "all_agents",
        "conditions": [],
        "audit_level": "STANDARD"
      },
      {
        "action_id": "ALLOW_003",
        "action": "collect_contact_information",
        "description": "Gather customer contact details for follow-up",
        "scope": ["sales", "support"],
        "conditions": ["customer_consent_given"],
        "audit_level": "ELEVATED"
      },
      {
        "action_id": "ALLOW_004",
        "action": "schedule_callback",
        "description": "Schedule a callback from human agent",
        "scope": "all_agents",
        "conditions": [],
        "audit_level": "STANDARD"
      },
      {
        "action_id": "ALLOW_005",
        "action": "provide_store_locations",
        "description": "Share store locations and operating hours",
        "scope": "all_agents",
        "conditions": [],
        "audit_level": "MINIMAL"
      },
      {
        "action_id": "ALLOW_006",
        "action": "explain_warranty_terms",
        "description": "Explain standard warranty terms and conditions",
        "scope": ["support", "warranty"],
        "conditions": [],
        "audit_level": "STANDARD"
      },
      {
        "action_id": "ALLOW_007",
        "action": "log_complaint",
        "description": "Record customer complaint details",
        "scope": ["complaint", "support"],
        "conditions": [],
        "audit_level": "ELEVATED"
      },
      {
        "action_id": "ALLOW_008",
        "action": "provide_order_status",
        "description": "Share order tracking and status information",
        "scope": ["support", "sales"],
        "conditions": ["customer_verified"],
        "audit_level": "STANDARD"
      },
      {
        "action_id": "ALLOW_009",
        "action": "recommend_products",
        "description": "Suggest products based on customer needs",
        "scope": ["sales"],
        "conditions": [],
        "audit_level": "STANDARD"
      },
      {
        "action_id": "ALLOW_010",
        "action": "initiate_escalation",
        "description": "Transfer conversation to human agent",
        "scope": "all_agents",
        "conditions": [],
        "audit_level": "ELEVATED"
      }
    ],
    
    "forbidden_actions": [
      {
        "action_id": "FORBID_001",
        "action": "approve_refund",
        "description": "AI cannot approve or process refunds",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ESCALATE",
        "reason": "Financial decisions require human authorization"
      },
      {
        "action_id": "FORBID_002",
        "action": "modify_order",
        "description": "AI cannot modify, cancel, or change orders",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ESCALATE",
        "reason": "Order modifications require system access and verification"
      },
      {
        "action_id": "FORBID_003",
        "action": "provide_legal_advice",
        "description": "AI cannot give legal advice or interpretations",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ESCALATE",
        "reason": "Legal advice must come from qualified professionals"
      },
      {
        "action_id": "FORBID_004",
        "action": "disclose_internal_policies",
        "description": "AI cannot share internal company policies or procedures",
        "scope": "all_agents",
        "severity": "HIGH",
        "violation_response": "BLOCK_AND_LOG",
        "reason": "Internal policies are confidential"
      },
      {
        "action_id": "FORBID_005",
        "action": "share_customer_data",
        "description": "AI cannot disclose other customers' information",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ALERT",
        "reason": "GDPR and privacy compliance"
      },
      {
        "action_id": "FORBID_006",
        "action": "make_promises",
        "description": "AI cannot make binding promises or guarantees beyond policy",
        "scope": "all_agents",
        "severity": "HIGH",
        "violation_response": "MODIFY_RESPONSE",
        "reason": "Commitments require human authorization"
      },
      {
        "action_id": "FORBID_007",
        "action": "discuss_competitors_negatively",
        "description": "AI cannot make negative statements about competitors",
        "scope": "all_agents",
        "severity": "MEDIUM",
        "violation_response": "MODIFY_RESPONSE",
        "reason": "Maintain professional brand image"
      },
      {
        "action_id": "FORBID_008",
        "action": "provide_medical_advice",
        "description": "AI cannot give health or medical recommendations",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ESCALATE",
        "reason": "Medical advice requires qualified professionals"
      },
      {
        "action_id": "FORBID_009",
        "action": "negotiate_prices",
        "description": "AI cannot negotiate or offer custom pricing",
        "scope": "all_agents",
        "severity": "HIGH",
        "violation_response": "BLOCK_AND_ESCALATE",
        "reason": "Pricing decisions require sales management"
      },
      {
        "action_id": "FORBID_010",
        "action": "admit_liability",
        "description": "AI cannot admit fault or liability on behalf of company",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ALERT",
        "reason": "Legal and insurance implications"
      },
      {
        "action_id": "FORBID_011",
        "action": "share_employee_information",
        "description": "AI cannot disclose employee names, contacts, or details",
        "scope": "all_agents",
        "severity": "HIGH",
        "violation_response": "BLOCK_AND_LOG",
        "reason": "Employee privacy protection"
      },
      {
        "action_id": "FORBID_012",
        "action": "discuss_pending_litigation",
        "description": "AI cannot discuss any ongoing legal matters",
        "scope": "all_agents",
        "severity": "CRITICAL",
        "violation_response": "BLOCK_AND_ALERT",
        "reason": "Legal confidentiality requirements"
      }
    ],
    
    "conditional_actions": [
      {
        "action_id": "COND_001",
        "action": "process_warranty_claim",
        "description": "Initiate warranty claim process",
        "scope": ["warranty", "support"],
        "conditions": {
          "required": [
            "product_in_warranty_period",
            "valid_proof_of_purchase",
            "customer_identity_verified"
          ],
          "any_of": []
        },
        "fallback": "ESCALATE_TO_HUMAN",
        "audit_level": "ELEVATED"
      },
      {
        "action_id": "COND_002",
        "action": "provide_pricing_information",
        "description": "Share product pricing details",
        "scope": ["sales"],
        "conditions": {
          "required": ["pricing_is_public"],
          "any_of": []
        },
        "fallback": "REFER_TO_SALES_TEAM",
        "audit_level": "STANDARD"
      },
      {
        "action_id": "COND_003",
        "action": "share_account_details",
        "description": "Provide customer account information",
        "scope": ["support"],
        "conditions": {
          "required": [
            "customer_identity_verified",
            "account_ownership_confirmed"
          ],
          "any_of": []
        },
        "fallback": "REQUEST_VERIFICATION",
        "audit_level": "ELEVATED"
      },
      {
        "action_id": "COND_004",
        "action": "apply_discount_code",
        "description": "Validate and apply promotional codes",
        "scope": ["sales"],
        "conditions": {
          "required": ["code_is_valid", "code_not_expired"],
          "any_of": ["new_customer", "returning_customer_eligible"]
        },
        "fallback": "EXPLAIN_CODE_INVALID",
        "audit_level": "ELEVATED"
      }
    ],
    
    "content_restrictions": {
      "prohibited_phrases": [
        "I promise",
        "I guarantee",
        "We will definitely",
        "100% certain",
        "Legally speaking",
        "Our lawyer",
        "Sue us",
        "It's your fault",
        "You're wrong",
        "That's a lie"
      ],
      "prohibited_patterns": [
        "refund.*approved",
        "compensation.*will.*receive",
        "legal.*action",
        "lawsuit",
        "attorney.*contact",
        "\\$\\d+.*refund",
        "credit.*\\d+.*account"
      ],
      "pii_patterns": [
        "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",
        "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b",
        "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"
      ],
      "sentiment_restrictions": {
        "max_negative_sentiment_score": 0.3,
        "forbidden_emotions": ["anger", "frustration_directed_at_customer"]
      }
    }
  }
}
```

---

## 4. Agent Action Whitelist

### 4.1 Whitelist Structure

Each agent has a specific whitelist defining exactly what actions they can perform.

### 4.2 Agent Whitelist Configuration

```json
{
  "version": "1.0.0",
  "effective_date": "2026-01-29",
  "description": "Per-agent action whitelist",
  
  "agent_whitelists": {
    "sales": {
      "agent_id": "sales",
      "display_name": "Sales Agent",
      "description": "Handles sales inquiries and lead generation",
      
      "allowed_intents": [
        "product_inquiry",
        "pricing_inquiry",
        "availability_check",
        "store_location",
        "catalog_request",
        "quote_request",
        "schedule_demo",
        "contact_sales_team"
      ],
      
      "allowed_actions": [
        "provide_product_information",
        "recommend_products",
        "provide_pricing_information",
        "provide_store_locations",
        "collect_contact_information",
        "schedule_callback",
        "generate_lead",
        "send_catalog_link",
        "initiate_escalation"
      ],
      
      "forbidden_actions": [
        "process_payment",
        "approve_discount",
        "negotiate_prices",
        "access_customer_orders",
        "modify_order"
      ],
      
      "response_constraints": {
        "max_response_length": 500,
        "must_include_disclaimer": false,
        "require_follow_up_offer": true,
        "confidence_threshold": 0.70
      },
      
      "escalation_triggers": [
        "bulk_order_inquiry",
        "custom_pricing_request",
        "corporate_account",
        "competitor_comparison"
      ],
      
      "data_access": {
        "can_access_product_catalog": true,
        "can_access_pricing": true,
        "can_access_inventory": true,
        "can_access_customer_history": false,
        "can_access_order_details": false
      }
    },
    
    "support": {
      "agent_id": "support",
      "display_name": "Support Agent",
      "description": "Handles customer support and general inquiries",
      
      "allowed_intents": [
        "order_status",
        "delivery_inquiry",
        "product_usage",
        "troubleshooting",
        "account_inquiry",
        "general_support",
        "feedback"
      ],
      
      "allowed_actions": [
        "provide_order_status",
        "explain_delivery_process",
        "provide_product_information",
        "answer_faq",
        "log_feedback",
        "schedule_callback",
        "provide_store_locations",
        "initiate_escalation"
      ],
      
      "forbidden_actions": [
        "modify_order",
        "cancel_order",
        "process_refund",
        "change_delivery_address",
        "access_payment_details"
      ],
      
      "response_constraints": {
        "max_response_length": 600,
        "must_include_disclaimer": false,
        "require_follow_up_offer": false,
        "confidence_threshold": 0.65
      },
      
      "escalation_triggers": [
        "order_cancellation_request",
        "address_change_request",
        "payment_issue",
        "urgent_delivery",
        "repeated_contact"
      ],
      
      "data_access": {
        "can_access_product_catalog": true,
        "can_access_pricing": true,
        "can_access_inventory": false,
        "can_access_customer_history": true,
        "can_access_order_details": true
      }
    },
    
    "warranty": {
      "agent_id": "warranty",
      "display_name": "Warranty Agent",
      "description": "Handles warranty inquiries and claims",
      
      "allowed_intents": [
        "warranty_inquiry",
        "warranty_claim",
        "warranty_status",
        "warranty_extension",
        "product_registration"
      ],
      
      "allowed_actions": [
        "explain_warranty_terms",
        "check_warranty_status",
        "initiate_warranty_claim",
        "provide_claim_requirements",
        "explain_claim_process",
        "schedule_callback",
        "initiate_escalation"
      ],
      
      "forbidden_actions": [
        "approve_warranty_claim",
        "authorize_replacement",
        "approve_refund",
        "extend_warranty_period",
        "waive_warranty_conditions"
      ],
      
      "response_constraints": {
        "max_response_length": 700,
        "must_include_disclaimer": true,
        "disclaimer_text": "Final warranty decisions are subject to review by our warranty team.",
        "require_follow_up_offer": false,
        "confidence_threshold": 0.70
      },
      
      "escalation_triggers": [
        "warranty_dispute",
        "out_of_warranty_request",
        "goodwill_request",
        "legal_mention",
        "repeat_claim"
      ],
      
      "data_access": {
        "can_access_product_catalog": true,
        "can_access_pricing": false,
        "can_access_inventory": false,
        "can_access_customer_history": true,
        "can_access_order_details": true
      }
    },
    
    "complaint": {
      "agent_id": "complaint",
      "display_name": "Complaint Agent",
      "description": "Handles customer complaints and escalations",
      
      "allowed_intents": [
        "file_complaint",
        "complaint_status",
        "escalate_issue",
        "express_dissatisfaction",
        "request_resolution"
      ],
      
      "allowed_actions": [
        "log_complaint",
        "acknowledge_concern",
        "provide_case_number",
        "explain_resolution_process",
        "check_complaint_status",
        "schedule_callback",
        "initiate_escalation"
      ],
      
      "forbidden_actions": [
        "approve_compensation",
        "offer_refund",
        "make_promises",
        "admit_liability",
        "negotiate_settlement"
      ],
      
      "response_constraints": {
        "max_response_length": 600,
        "must_include_disclaimer": true,
        "disclaimer_text": "Your complaint has been logged and will be reviewed by our team within 48 hours.",
        "require_follow_up_offer": false,
        "confidence_threshold": 0.60,
        "tone": "empathetic_professional"
      },
      
      "escalation_triggers": [
        "threat_mention",
        "legal_action_mention",
        "media_mention",
        "regulatory_mention",
        "repeated_complaint",
        "high_value_customer"
      ],
      
      "data_access": {
        "can_access_product_catalog": true,
        "can_access_pricing": false,
        "can_access_inventory": false,
        "can_access_customer_history": true,
        "can_access_order_details": true
      }
    },
    
    "escalation": {
      "agent_id": "escalation",
      "display_name": "Escalation Agent",
      "description": "Facilitates handoff to human agents",
      
      "allowed_intents": [
        "request_human",
        "urgent_matter",
        "complex_issue",
        "callback_request"
      ],
      
      "allowed_actions": [
        "confirm_escalation",
        "collect_callback_details",
        "provide_wait_time_estimate",
        "summarize_conversation",
        "set_expectations",
        "initiate_escalation"
      ],
      
      "forbidden_actions": [
        "attempt_resolution",
        "make_promises",
        "provide_compensation",
        "access_sensitive_data"
      ],
      
      "response_constraints": {
        "max_response_length": 300,
        "must_include_disclaimer": false,
        "require_follow_up_offer": false,
        "confidence_threshold": 0.50
      },
      
      "escalation_triggers": [],
      
      "data_access": {
        "can_access_product_catalog": false,
        "can_access_pricing": false,
        "can_access_inventory": false,
        "can_access_customer_history": false,
        "can_access_order_details": false
      }
    }
  }
}
```

---

## 5. Runtime Response Validation

### 5.1 Pre-Send Guards

```json
{
  "version": "1.0.0",
  "description": "Runtime response validation rules",
  
  "pre_send_guards": {
    "guard_sequence": [
      "kill_switch_check",
      "limited_mode_check",
      "confidence_threshold_check",
      "forbidden_content_check",
      "pii_leak_check",
      "whitelist_action_check",
      "response_length_check",
      "sentiment_check",
      "mandatory_disclaimer_check"
    ],
    
    "guards": {
      "kill_switch_check": {
        "id": "GUARD_001",
        "name": "Kill Switch Check",
        "description": "Check if AI system is disabled",
        "priority": 1,
        "action_on_fail": "ESCALATE_IMMEDIATELY",
        "fail_message": "Our AI assistant is temporarily unavailable. Connecting you to a human agent."
      },
      
      "limited_mode_check": {
        "id": "GUARD_002",
        "name": "Limited Mode Check",
        "description": "Check if system is in limited mode",
        "priority": 2,
        "action_on_fail": "APPLY_LIMITED_RESPONSES",
        "limited_mode_config": {
          "allowed_actions": ["answer_faq", "provide_store_locations", "initiate_escalation"],
          "auto_escalate_after_turns": 3
        }
      },
      
      "confidence_threshold_check": {
        "id": "GUARD_003",
        "name": "Confidence Threshold Check",
        "description": "Verify AI confidence meets minimum threshold",
        "priority": 3,
        "thresholds": {
          "sales": 0.70,
          "support": 0.65,
          "warranty": 0.70,
          "complaint": 0.60,
          "escalation": 0.50,
          "default": 0.65
        },
        "action_on_fail": "ESCALATE_LOW_CONFIDENCE",
        "fail_message": "I want to make sure I give you accurate information. Let me connect you with a specialist."
      },
      
      "forbidden_content_check": {
        "id": "GUARD_004",
        "name": "Forbidden Content Check",
        "description": "Scan response for prohibited phrases and patterns",
        "priority": 4,
        "action_on_fail": "BLOCK_AND_SANITIZE",
        "checks": [
          {
            "type": "phrase_blacklist",
            "source": "policies.content_restrictions.prohibited_phrases"
          },
          {
            "type": "pattern_blacklist",
            "source": "policies.content_restrictions.prohibited_patterns"
          }
        ]
      },
      
      "pii_leak_check": {
        "id": "GUARD_005",
        "name": "PII Leak Prevention",
        "description": "Detect and redact potential PII in responses",
        "priority": 5,
        "action_on_fail": "REDACT_AND_LOG",
        "pii_types": [
          "phone_number",
          "email_address",
          "credit_card",
          "social_security",
          "address"
        ]
      },
      
      "whitelist_action_check": {
        "id": "GUARD_006",
        "name": "Whitelist Action Check",
        "description": "Verify response action is on agent's whitelist",
        "priority": 6,
        "action_on_fail": "BLOCK_AND_ESCALATE"
      },
      
      "response_length_check": {
        "id": "GUARD_007",
        "name": "Response Length Check",
        "description": "Ensure response doesn't exceed maximum length",
        "priority": 7,
        "action_on_fail": "TRUNCATE_AND_LOG"
      },
      
      "sentiment_check": {
        "id": "GUARD_008",
        "name": "Response Sentiment Check",
        "description": "Verify response has appropriate tone",
        "priority": 8,
        "action_on_fail": "MODIFY_TONE",
        "config": {
          "max_negative_score": 0.3,
          "required_politeness_score": 0.7
        }
      },
      
      "mandatory_disclaimer_check": {
        "id": "GUARD_009",
        "name": "Mandatory Disclaimer Check",
        "description": "Ensure required disclaimers are included",
        "priority": 9,
        "action_on_fail": "APPEND_DISCLAIMER"
      }
    }
  }
}
```

### 5.2 Guard Execution Logic (n8n Function)

```javascript
// Runtime Response Validation Guard
// Execute in n8n Function Node

const response = $json.ai_response;
const agent = $json.agent_used;
const confidence = $json.confidence;
const sessionId = $json.session_id;

// Load configurations
const globalControls = $node['Load_Global_Controls'].json;
const policyMatrix = $node['Load_Policy_Matrix'].json;
const agentWhitelist = $node['Load_Agent_Whitelist'].json[agent];
const guards = $node['Load_Guards'].json.pre_send_guards.guards;

// Initialize validation result
const validationResult = {
  original_response: response,
  validated_response: response,
  passed: true,
  guards_executed: [],
  modifications: [],
  blocked: false,
  escalate: false,
  audit_events: []
};

// GUARD 1: Kill Switch Check
if (globalControls.kill_switch.enabled) {
  validationResult.passed = false;
  validationResult.blocked = true;
  validationResult.escalate = true;
  validationResult.validated_response = guards.kill_switch_check.fail_message;
  validationResult.guards_executed.push({
    guard: 'kill_switch_check',
    result: 'BLOCKED',
    reason: 'System kill switch is enabled'
  });
  validationResult.audit_events.push({
    event_type: 'KILL_SWITCH_TRIGGERED',
    severity: 'CRITICAL'
  });
  return [{ json: validationResult }];
}

// GUARD 2: Limited Mode Check
if (globalControls.limited_mode.enabled) {
  const limitedActions = guards.limited_mode_check.limited_mode_config.allowed_actions;
  const detectedAction = detectActionFromResponse(response);
  
  if (!limitedActions.includes(detectedAction)) {
    validationResult.escalate = true;
    validationResult.validated_response = 
      "I'm currently operating with limited capabilities. " + 
      "Let me connect you with a team member who can better assist you.";
    validationResult.guards_executed.push({
      guard: 'limited_mode_check',
      result: 'LIMITED',
      reason: 'Action not allowed in limited mode'
    });
  }
}

// GUARD 3: Confidence Threshold Check
const confidenceThreshold = guards.confidence_threshold_check.thresholds[agent] || 
                           guards.confidence_threshold_check.thresholds.default;
if (confidence < confidenceThreshold) {
  validationResult.escalate = true;
  validationResult.audit_events.push({
    event_type: 'LOW_CONFIDENCE_ESCALATION',
    severity: 'MEDIUM',
    confidence: confidence,
    threshold: confidenceThreshold
  });
  validationResult.guards_executed.push({
    guard: 'confidence_threshold_check',
    result: 'ESCALATE',
    reason: `Confidence ${confidence} below threshold ${confidenceThreshold}`
  });
}

// GUARD 4: Forbidden Content Check
const forbiddenPhrases = policyMatrix.policies.content_restrictions.prohibited_phrases;
const forbiddenPatterns = policyMatrix.policies.content_restrictions.prohibited_patterns;

for (const phrase of forbiddenPhrases) {
  if (response.toLowerCase().includes(phrase.toLowerCase())) {
    validationResult.modifications.push({
      type: 'PHRASE_REMOVED',
      phrase: phrase
    });
    validationResult.validated_response = 
      validationResult.validated_response.replace(new RegExp(phrase, 'gi'), '[REDACTED]');
    validationResult.audit_events.push({
      event_type: 'FORBIDDEN_PHRASE_DETECTED',
      severity: 'HIGH',
      phrase: phrase
    });
  }
}

for (const pattern of forbiddenPatterns) {
  const regex = new RegExp(pattern, 'gi');
  if (regex.test(response)) {
    validationResult.modifications.push({
      type: 'PATTERN_REMOVED',
      pattern: pattern
    });
    validationResult.validated_response = 
      validationResult.validated_response.replace(regex, '[REDACTED]');
    validationResult.audit_events.push({
      event_type: 'FORBIDDEN_PATTERN_DETECTED',
      severity: 'HIGH',
      pattern: pattern
    });
  }
}

// GUARD 5: PII Leak Check
const piiPatterns = policyMatrix.policies.content_restrictions.pii_patterns;
for (const piiPattern of piiPatterns) {
  const regex = new RegExp(piiPattern, 'g');
  if (regex.test(validationResult.validated_response)) {
    validationResult.validated_response = 
      validationResult.validated_response.replace(regex, '[PII_REDACTED]');
    validationResult.audit_events.push({
      event_type: 'PII_LEAK_PREVENTED',
      severity: 'CRITICAL',
      pattern_type: piiPattern
    });
  }
}

// GUARD 6: Whitelist Action Check
const detectedAction = detectActionFromResponse(response);
if (agentWhitelist && !agentWhitelist.allowed_actions.includes(detectedAction)) {
  if (agentWhitelist.forbidden_actions.includes(detectedAction)) {
    validationResult.blocked = true;
    validationResult.escalate = true;
    validationResult.validated_response = 
      "I apologize, but I'm not able to help with that specific request. " +
      "Let me connect you with someone who can assist you.";
    validationResult.audit_events.push({
      event_type: 'FORBIDDEN_ACTION_BLOCKED',
      severity: 'HIGH',
      action: detectedAction,
      agent: agent
    });
  }
}

// GUARD 7: Response Length Check
const maxLength = agentWhitelist?.response_constraints?.max_response_length || 500;
if (validationResult.validated_response.length > maxLength) {
  validationResult.validated_response = 
    validationResult.validated_response.substring(0, maxLength - 3) + '...';
  validationResult.modifications.push({
    type: 'TRUNCATED',
    original_length: response.length,
    new_length: maxLength
  });
}

// GUARD 9: Mandatory Disclaimer Check
if (agentWhitelist?.response_constraints?.must_include_disclaimer) {
  const disclaimer = agentWhitelist.response_constraints.disclaimer_text;
  if (!validationResult.validated_response.includes(disclaimer)) {
    validationResult.validated_response += '\n\n' + disclaimer;
    validationResult.modifications.push({
      type: 'DISCLAIMER_ADDED'
    });
  }
}

// Determine final status
validationResult.guards_executed.push({
  guard: 'all_guards_complete',
  result: validationResult.blocked ? 'BLOCKED' : 
          validationResult.escalate ? 'ESCALATE' : 
          validationResult.modifications.length > 0 ? 'MODIFIED' : 'PASSED'
});

validationResult.passed = !validationResult.blocked;

// Helper function
function detectActionFromResponse(text) {
  // Simplified action detection - in production, use NLP
  const actionKeywords = {
    'refund': 'process_refund',
    'compensation': 'offer_compensation',
    'cancel': 'cancel_order',
    'warranty claim': 'process_warranty_claim',
    'legal': 'provide_legal_advice'
  };
  
  for (const [keyword, action] of Object.entries(actionKeywords)) {
    if (text.toLowerCase().includes(keyword)) {
      return action;
    }
  }
  return 'general_response';
}

return [{ json: validationResult }];
```

---

## 6. Audit Log Schema

### 6.1 Database Schema

```sql
-- ============================================================================
-- GOVERNANCE AUDIT LOG SCHEMA
-- Purpose: Immutable audit trail for every AI conversation turn
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance_audit_log (
    -- Primary identification
    id BIGSERIAL PRIMARY KEY,
    audit_id UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    
    -- Session context
    session_id VARCHAR(100) NOT NULL,
    conversation_turn INT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Channel & Agent
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('chat', 'voice', 'whatsapp')),
    agent_used VARCHAR(30) NOT NULL,
    
    -- Input
    customer_input TEXT NOT NULL,
    customer_input_hash VARCHAR(64) NOT NULL,  -- SHA-256 for integrity
    detected_intent VARCHAR(100) NULL,
    detected_entities JSONB NULL,
    
    -- AI Processing
    ai_confidence DECIMAL(5,4) NOT NULL,
    ai_raw_response TEXT NOT NULL,
    ai_response_hash VARCHAR(64) NOT NULL,
    processing_time_ms INT NOT NULL,
    
    -- Governance Validation
    governance_result VARCHAR(20) NOT NULL CHECK (governance_result IN ('PASSED', 'MODIFIED', 'BLOCKED', 'ESCALATED')),
    guards_executed JSONB NOT NULL,
    modifications_applied JSONB NULL,
    
    -- Final Output
    final_response TEXT NOT NULL,
    final_response_hash VARCHAR(64) NOT NULL,
    response_delivered BOOLEAN DEFAULT TRUE,
    
    -- Risk Assessment
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('NONE', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    risk_factors JSONB NULL,
    
    -- Escalation
    escalated BOOLEAN DEFAULT FALSE,
    escalation_reason VARCHAR(200) NULL,
    escalation_queue VARCHAR(50) NULL,
    
    -- Policy Compliance
    policies_checked JSONB NOT NULL,
    policy_violations JSONB NULL,
    
    -- Metadata
    system_version VARCHAR(20) NOT NULL,
    governance_config_version VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for common queries
    INDEX idx_audit_session (session_id),
    INDEX idx_audit_timestamp (timestamp),
    INDEX idx_audit_agent (agent_used),
    INDEX idx_audit_channel (channel),
    INDEX idx_audit_result (governance_result),
    INDEX idx_audit_risk (risk_level),
    INDEX idx_audit_escalated (escalated),
    INDEX idx_audit_date (DATE(timestamp))
);

-- Partitioning by month for performance
-- (Implementation depends on PostgreSQL version)

-- ============================================================================
-- GOVERNANCE EVENTS TABLE
-- Purpose: Discrete governance events (violations, alerts, etc.)
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance_events (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    audit_id UUID NOT NULL REFERENCES governance_audit_log(audit_id),
    
    -- Event details
    event_type VARCHAR(50) NOT NULL,
    event_severity VARCHAR(20) NOT NULL CHECK (event_severity IN ('INFO', 'WARNING', 'HIGH', 'CRITICAL')),
    event_description TEXT NOT NULL,
    event_data JSONB NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_events_audit (audit_id),
    INDEX idx_events_type (event_type),
    INDEX idx_events_severity (event_severity),
    INDEX idx_events_time (created_at)
);

-- ============================================================================
-- GOVERNANCE ALERTS TABLE
-- Purpose: Alerts generated by governance system
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance_alerts (
    id SERIAL PRIMARY KEY,
    alert_id UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    
    -- Alert details
    alert_type VARCHAR(50) NOT NULL,
    alert_severity VARCHAR(20) NOT NULL CHECK (alert_severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    alert_title VARCHAR(200) NOT NULL,
    alert_description TEXT NOT NULL,
    
    -- Related records
    related_session_ids TEXT[] NULL,
    related_audit_ids UUID[] NULL,
    
    -- Status
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'INVESTIGATING', 'RESOLVED', 'FALSE_POSITIVE')),
    
    -- Resolution
    resolved_by VARCHAR(100) NULL,
    resolved_at TIMESTAMP WITH TIME ZONE NULL,
    resolution_notes TEXT NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_alerts_type (alert_type),
    INDEX idx_alerts_severity (alert_severity),
    INDEX idx_alerts_status (status),
    INDEX idx_alerts_time (created_at)
);
```

### 6.2 Audit Log JSON Record Example

```json
{
  "audit_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "session_id": "sess_20260129_abc123",
  "conversation_turn": 3,
  "timestamp": "2026-01-29T14:32:15.123Z",
  
  "channel": "whatsapp",
  "agent_used": "warranty",
  
  "customer_input": "My mattress is sagging after only 6 months. I want a full refund or I'll contact my lawyer.",
  "customer_input_hash": "sha256:abc123def456...",
  "detected_intent": "warranty_claim",
  "detected_entities": {
    "product": "mattress",
    "issue": "sagging",
    "timeframe": "6 months",
    "threat_indicators": ["lawyer", "refund"]
  },
  
  "ai_confidence": 0.72,
  "ai_raw_response": "I understand your frustration. I can help you with a full refund for your mattress. Let me process that for you right away.",
  "ai_response_hash": "sha256:789xyz...",
  "processing_time_ms": 234,
  
  "governance_result": "BLOCKED",
  "guards_executed": [
    {"guard": "kill_switch_check", "result": "PASSED", "duration_ms": 2},
    {"guard": "limited_mode_check", "result": "PASSED", "duration_ms": 1},
    {"guard": "confidence_threshold_check", "result": "PASSED", "duration_ms": 1},
    {"guard": "forbidden_content_check", "result": "FAILED", "reason": "Contains refund approval", "duration_ms": 15},
    {"guard": "whitelist_action_check", "result": "FAILED", "reason": "approve_refund not in whitelist", "duration_ms": 3}
  ],
  "modifications_applied": null,
  
  "final_response": "I understand your concern about the mattress sagging, and I want to help resolve this for you. I've logged your warranty claim and our warranty team will review it within 48 business hours. They will contact you directly to discuss the resolution options. In the meantime, is there anything else I can help you with?",
  "final_response_hash": "sha256:final123...",
  "response_delivered": true,
  
  "risk_level": "HIGH",
  "risk_factors": {
    "legal_mention": true,
    "refund_demand": true,
    "escalation_indicators": ["lawyer", "full refund"],
    "customer_sentiment": "angry"
  },
  
  "escalated": true,
  "escalation_reason": "Legal mention + Refund request + High-risk customer",
  "escalation_queue": "warranty_supervisors",
  
  "policies_checked": [
    "FORBID_001 (approve_refund)",
    "FORBID_003 (provide_legal_advice)",
    "FORBID_006 (make_promises)",
    "FORBID_010 (admit_liability)"
  ],
  "policy_violations": [
    {
      "policy_id": "FORBID_001",
      "policy_name": "approve_refund",
      "violation_type": "ATTEMPTED_ACTION",
      "blocked": true
    }
  ],
  
  "system_version": "1.5.0",
  "governance_config_version": "1.0.0",
  "created_at": "2026-01-29T14:32:15.456Z"
}
```

### 6.3 Audit Log Insert Query

```sql
-- Insert audit log entry
INSERT INTO governance_audit_log (
    session_id,
    conversation_turn,
    channel,
    agent_used,
    customer_input,
    customer_input_hash,
    detected_intent,
    detected_entities,
    ai_confidence,
    ai_raw_response,
    ai_response_hash,
    processing_time_ms,
    governance_result,
    guards_executed,
    modifications_applied,
    final_response,
    final_response_hash,
    response_delivered,
    risk_level,
    risk_factors,
    escalated,
    escalation_reason,
    escalation_queue,
    policies_checked,
    policy_violations,
    system_version,
    governance_config_version
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
    $21, $22, $23, $24, $25, $26, $27
);
```

---

## 7. Escalation Enforcement Rules

### 7.1 Mandatory Escalation Triggers

```json
{
  "version": "1.0.0",
  "description": "Mandatory escalation enforcement rules",
  
  "escalation_rules": {
    "legal_triggers": {
      "rule_id": "ESC_LEGAL",
      "name": "Legal Mention Escalation",
      "description": "Escalate when legal action or lawyers are mentioned",
      "priority": "CRITICAL",
      "auto_escalate": true,
      "queue": "legal_review",
      
      "triggers": {
        "keywords": [
          "lawyer",
          "attorney",
          "legal action",
          "sue",
          "lawsuit",
          "court",
          "consumer protection",
          "trading standards",
          "regulatory",
          "solicitor"
        ],
        "patterns": [
          "contact.*(lawyer|attorney|solicitor)",
          "take.*legal.*action",
          "see.*you.*court",
          "file.*complaint.*authority"
        ]
      },
      
      "response_template": "I understand this is a serious matter for you. I'm going to connect you with a senior team member who can better assist with your concerns. Please hold.",
      
      "audit_level": "CRITICAL",
      "alert_channels": ["slack_legal", "email_legal_team"]
    },
    
    "refund_triggers": {
      "rule_id": "ESC_REFUND",
      "name": "Refund Request Escalation",
      "description": "Escalate all refund requests to human agents",
      "priority": "HIGH",
      "auto_escalate": true,
      "queue": "refunds_team",
      
      "triggers": {
        "keywords": [
          "refund",
          "money back",
          "return",
          "reimburse",
          "compensation",
          "credit",
          "chargeback"
        ],
        "patterns": [
          "want.*(my money|refund|return)",
          "give.*back.*(money|payment)",
          "credit.*account"
        ],
        "intents": [
          "request_refund",
          "demand_compensation"
        ]
      },
      
      "exceptions": {
        "skip_if": [
          "general_refund_policy_inquiry",
          "refund_status_check"
        ]
      },
      
      "response_template": "I understand you'd like to discuss a refund. Let me connect you with our customer care team who can review your request and help you with the next steps.",
      
      "audit_level": "HIGH",
      "alert_channels": ["slack_refunds"]
    },
    
    "low_confidence_triggers": {
      "rule_id": "ESC_CONFIDENCE",
      "name": "Low Confidence Escalation",
      "description": "Escalate when AI confidence is below threshold",
      "priority": "MEDIUM",
      "auto_escalate": true,
      "queue": "general_support",
      
      "triggers": {
        "confidence_thresholds": {
          "sales": 0.60,
          "support": 0.55,
          "warranty": 0.60,
          "complaint": 0.50,
          "default": 0.55
        },
        "consecutive_low_confidence": 2
      },
      
      "response_template": "I want to make sure I give you the most accurate information. Let me connect you with a specialist who can better assist you.",
      
      "audit_level": "MEDIUM"
    },
    
    "sentiment_triggers": {
      "rule_id": "ESC_SENTIMENT",
      "name": "Negative Sentiment Escalation",
      "description": "Escalate highly negative or aggressive customer interactions",
      "priority": "HIGH",
      "auto_escalate": true,
      "queue": "customer_care_priority",
      
      "triggers": {
        "sentiment_score_below": -0.7,
        "aggression_keywords": [
          "idiot",
          "stupid",
          "useless",
          "hate",
          "worst",
          "terrible",
          "incompetent",
          "scam",
          "fraud",
          "rip off"
        ],
        "consecutive_negative_turns": 2
      },
      
      "response_template": "I can see you're frustrated, and I truly want to help resolve this for you. Let me connect you with a senior team member who has more authority to assist with your situation.",
      
      "audit_level": "HIGH",
      "alert_channels": ["slack_escalations"]
    },
    
    "vip_customer_triggers": {
      "rule_id": "ESC_VIP",
      "name": "VIP Customer Escalation",
      "description": "Escalate interactions with high-value customers",
      "priority": "HIGH",
      "auto_escalate": true,
      "queue": "vip_support",
      
      "triggers": {
        "customer_flags": [
          "vip",
          "corporate_account",
          "high_lifetime_value",
          "influencer"
        ],
        "order_value_above": 10000
      },
      
      "response_template": "Thank you for being a valued customer. Let me connect you with a dedicated account specialist who can provide personalized assistance.",
      
      "audit_level": "ELEVATED"
    },
    
    "safety_triggers": {
      "rule_id": "ESC_SAFETY",
      "name": "Safety Concern Escalation",
      "description": "Escalate any safety-related concerns immediately",
      "priority": "CRITICAL",
      "auto_escalate": true,
      "queue": "safety_team",
      
      "triggers": {
        "keywords": [
          "injury",
          "hurt",
          "hospital",
          "allergic",
          "dangerous",
          "unsafe",
          "hazard",
          "fire",
          "electric shock",
          "child safety"
        ],
        "patterns": [
          "(my|the).*child.*(hurt|injured)",
          "caused.*(injury|harm)",
          "went.*hospital",
          "allergic.*reaction"
        ]
      },
      
      "response_template": "I'm very sorry to hear about this safety concern. This is being immediately escalated to our safety team who will contact you urgently. Please stay on the line.",
      
      "audit_level": "CRITICAL",
      "alert_channels": ["slack_safety_critical", "sms_safety_team", "email_safety_director"]
    },
    
    "media_triggers": {
      "rule_id": "ESC_MEDIA",
      "name": "Media/Social Mention Escalation",
      "description": "Escalate when media or social media exposure is threatened",
      "priority": "HIGH",
      "auto_escalate": true,
      "queue": "pr_communications",
      
      "triggers": {
        "keywords": [
          "social media",
          "twitter",
          "facebook",
          "instagram",
          "tiktok",
          "youtube",
          "newspaper",
          "journalist",
          "reporter",
          "news",
          "viral",
          "followers"
        ],
        "patterns": [
          "post.*(social media|online)",
          "tell.*(followers|everyone)",
          "going.*viral",
          "contact.*(journalist|reporter|news)"
        ]
      },
      
      "response_template": "I want to ensure your experience is handled with the attention it deserves. Let me connect you with a senior member of our team.",
      
      "audit_level": "HIGH",
      "alert_channels": ["slack_pr", "email_pr_team"]
    },
    
    "repeated_contact_triggers": {
      "rule_id": "ESC_REPEAT",
      "name": "Repeated Contact Escalation",
      "description": "Escalate customers who have contacted multiple times about same issue",
      "priority": "MEDIUM",
      "auto_escalate": true,
      "queue": "retention_team",
      
      "triggers": {
        "same_issue_contacts": 3,
        "timeframe_days": 7,
        "keywords_previous": ["still", "again", "already", "third time", "keep"]
      },
      
      "response_template": "I can see you've been in touch with us about this before, and I apologize that it hasn't been fully resolved. Let me connect you with a team lead who can take ownership of this for you.",
      
      "audit_level": "MEDIUM"
    }
  },
  
  "escalation_queues": {
    "legal_review": {
      "queue_id": "legal_review",
      "name": "Legal Review Queue",
      "priority_level": 1,
      "sla_minutes": 30,
      "backup_queue": "senior_management",
      "notification_channels": ["slack", "sms", "email"]
    },
    "safety_team": {
      "queue_id": "safety_team",
      "name": "Safety Team Queue",
      "priority_level": 1,
      "sla_minutes": 15,
      "backup_queue": "senior_management",
      "notification_channels": ["slack", "sms", "email", "phone"]
    },
    "refunds_team": {
      "queue_id": "refunds_team",
      "name": "Refunds Team Queue",
      "priority_level": 2,
      "sla_minutes": 60,
      "backup_queue": "customer_care_priority"
    },
    "vip_support": {
      "queue_id": "vip_support",
      "name": "VIP Support Queue",
      "priority_level": 2,
      "sla_minutes": 30,
      "backup_queue": "customer_care_priority"
    },
    "general_support": {
      "queue_id": "general_support",
      "name": "General Support Queue",
      "priority_level": 3,
      "sla_minutes": 120,
      "backup_queue": null
    }
  }
}
```

### 7.2 Escalation Decision Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ESCALATION DECISION FLOW                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Customer Input                                                             │
│       │                                                                     │
│       ▼                                                                     │
│  ┌─────────────────────────────────────────┐                               │
│  │         CRITICAL TRIGGERS CHECK         │                               │
│  │  • Legal mention?                       │                               │
│  │  • Safety concern?                      │                               │
│  └──────────────────┬──────────────────────┘                               │
│                     │                                                       │
│           ┌────YES──┴──NO────┐                                             │
│           ▼                  ▼                                              │
│   ┌──────────────┐   ┌─────────────────────────────────────┐               │
│   │  IMMEDIATE   │   │         HIGH PRIORITY CHECK         │               │
│   │  ESCALATION  │   │  • Refund request?                  │               │
│   │              │   │  • VIP customer?                    │               │
│   │  Queue:      │   │  • Media threat?                    │               │
│   │  legal/safety│   │  • Aggressive sentiment?            │               │
│   └──────────────┘   └──────────────────┬──────────────────┘               │
│                                         │                                   │
│                               ┌────YES──┴──NO────┐                         │
│                               ▼                  ▼                          │
│                       ┌──────────────┐   ┌─────────────────────────────┐   │
│                       │   PRIORITY   │   │      STANDARD CHECK         │   │
│                       │  ESCALATION  │   │  • Low confidence?          │   │
│                       │              │   │  • Repeated contact?        │   │
│                       │  Queue:      │   │  • Customer request?        │   │
│                       │  refunds/vip │   └──────────────┬──────────────┘   │
│                       └──────────────┘                  │                   │
│                                                ┌────YES─┴──NO────┐         │
│                                                ▼                 ▼         │
│                                        ┌──────────────┐   ┌────────────┐   │
│                                        │   STANDARD   │   │  CONTINUE  │   │
│                                        │  ESCALATION  │   │    WITH    │   │
│                                        │              │   │     AI     │   │
│                                        │  Queue:      │   │            │   │
│                                        │  general     │   │            │   │
│                                        └──────────────┘   └────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Global Controls

### 8.1 Kill-Switch & Limited Mode Configuration

```json
{
  "version": "1.0.0",
  "description": "Global AI control settings",
  "last_updated": "2026-01-29T10:00:00Z",
  "updated_by": "system_admin",
  
  "global_controls": {
    "kill_switch": {
      "enabled": false,
      "description": "Completely disables AI responses, routes all to human",
      "activation_reason": null,
      "activated_at": null,
      "activated_by": null,
      "auto_disable_after_hours": null,
      
      "fallback_response": "Our AI assistant is temporarily unavailable. Please hold while we connect you with a human agent.",
      
      "notification_on_activate": {
        "channels": ["slack_critical", "sms_on_call", "email_leadership"],
        "message": "🚨 AI KILL SWITCH ACTIVATED: All AI responses disabled."
      }
    },
    
    "limited_mode": {
      "enabled": false,
      "description": "Restricts AI to basic functions only",
      "activation_reason": null,
      "activated_at": null,
      "activated_by": null,
      "auto_disable_after_hours": 24,
      
      "restrictions": {
        "allowed_agents": ["sales", "support"],
        "disabled_agents": ["complaint", "warranty"],
        "allowed_actions": [
          "answer_faq",
          "provide_store_locations",
          "provide_product_information",
          "schedule_callback",
          "initiate_escalation"
        ],
        "max_conversation_turns": 3,
        "auto_escalate_after_turns": 3,
        "confidence_threshold_boost": 0.15
      },
      
      "fallback_response": "I'm operating with limited capabilities right now. Let me help you with basic information or connect you with a team member.",
      
      "notification_on_activate": {
        "channels": ["slack_ops", "email_ops_team"],
        "message": "⚠️ AI LIMITED MODE ACTIVATED: Restricted functionality enabled."
      }
    },
    
    "maintenance_mode": {
      "enabled": false,
      "description": "Scheduled maintenance window",
      "scheduled_start": null,
      "scheduled_end": null,
      "message": "We're performing scheduled maintenance. Please try again shortly or call us at [phone number]."
    },
    
    "agent_specific_controls": {
      "sales": {
        "enabled": true,
        "confidence_override": null,
        "rate_limit_per_minute": 100
      },
      "support": {
        "enabled": true,
        "confidence_override": null,
        "rate_limit_per_minute": 150
      },
      "warranty": {
        "enabled": true,
        "confidence_override": null,
        "rate_limit_per_minute": 50
      },
      "complaint": {
        "enabled": true,
        "confidence_override": 0.70,
        "rate_limit_per_minute": 50
      },
      "escalation": {
        "enabled": true,
        "confidence_override": null,
        "rate_limit_per_minute": 200
      }
    },
    
    "channel_controls": {
      "chat": {
        "enabled": true,
        "max_concurrent_sessions": 1000,
        "session_timeout_minutes": 30
      },
      "voice": {
        "enabled": true,
        "max_concurrent_calls": 50,
        "call_timeout_minutes": 15
      },
      "whatsapp": {
        "enabled": true,
        "max_concurrent_sessions": 500,
        "session_timeout_minutes": 60
      }
    },
    
    "rate_limiting": {
      "global_requests_per_minute": 500,
      "per_session_requests_per_minute": 10,
      "burst_limit": 20,
      "cooldown_seconds": 5
    },
    
    "circuit_breaker": {
      "enabled": true,
      "error_threshold_percent": 10,
      "error_window_seconds": 60,
      "trip_duration_seconds": 300,
      "half_open_requests": 5
    }
  },
  
  "activation_procedures": {
    "kill_switch_activation": {
      "authorized_roles": ["ai_director", "cto", "coo", "ceo", "on_call_lead"],
      "requires_confirmation": true,
      "confirmation_method": "2fa",
      "must_provide_reason": true,
      "auto_create_incident": true
    },
    "limited_mode_activation": {
      "authorized_roles": ["ai_lead", "ai_director", "ops_manager", "on_call_engineer"],
      "requires_confirmation": true,
      "must_provide_reason": true,
      "max_duration_hours": 72
    }
  }
}
```

### 8.2 Control State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GLOBAL CONTROL STATE MACHINE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                            ┌─────────────────┐                              │
│                            │     NORMAL      │                              │
│                            │     MODE        │                              │
│                            └────────┬────────┘                              │
│                                     │                                       │
│           ┌─────────────────────────┼─────────────────────────┐            │
│           │                         │                         │            │
│           ▼                         ▼                         ▼            │
│   ┌───────────────┐        ┌───────────────┐        ┌───────────────┐      │
│   │   LIMITED     │        │  MAINTENANCE  │        │ KILL SWITCH   │      │
│   │    MODE       │        │    MODE       │        │   ENABLED     │      │
│   │               │        │               │        │               │      │
│   │ • Restricted  │        │ • Scheduled   │        │ • All AI      │      │
│   │   actions     │        │ • Planned     │        │   disabled    │      │
│   │ • Lower       │        │ • Time-based  │        │ • 100% human  │      │
│   │   thresholds  │        │   auto-end    │        │ • Emergency   │      │
│   │ • Auto-       │        │               │        │               │      │
│   │   escalate    │        │               │        │               │      │
│   └───────┬───────┘        └───────┬───────┘        └───────┬───────┘      │
│           │                        │                        │               │
│           │    [TIMEOUT/MANUAL]    │     [SCHEDULED END]    │   [MANUAL]   │
│           │                        │                        │               │
│           └────────────────────────┼────────────────────────┘               │
│                                    │                                        │
│                                    ▼                                        │
│                            ┌─────────────────┐                              │
│                            │     NORMAL      │                              │
│                            │     MODE        │                              │
│                            └─────────────────┘                              │
│                                                                             │
│  Transitions:                                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  NORMAL → LIMITED:      Manual activation by authorized role                │
│  NORMAL → MAINTENANCE:  Scheduled or manual activation                      │
│  NORMAL → KILL_SWITCH:  Emergency activation (2FA required)                 │
│  LIMITED → NORMAL:      Manual deactivation or timeout (24h default)        │
│  LIMITED → KILL_SWITCH: Emergency escalation                                │
│  MAINTENANCE → NORMAL:  Scheduled end time or manual                        │
│  KILL_SWITCH → NORMAL:  Manual deactivation (2FA required)                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Kill-Switch Activation n8n Workflow

```json
{
  "name": "AI_Kill_Switch_Control",
  "description": "Manages kill-switch and limited mode activation",
  "nodes": [
    {
      "id": "webhook_trigger",
      "name": "Control_Webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "ai-governance/control",
        "method": "POST",
        "authentication": "headerAuth"
      }
    },
    {
      "id": "validate_request",
      "name": "Validate_Authorization",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const request = $json;\nconst authorizedRoles = ['ai_director', 'cto', 'coo', 'ceo', 'on_call_lead'];\n\nif (!authorizedRoles.includes(request.user_role)) {\n  throw new Error('Unauthorized: Role not permitted to activate controls');\n}\n\nif (request.action === 'activate_kill_switch' && !request.confirmation_2fa) {\n  throw new Error('Kill switch requires 2FA confirmation');\n}\n\nreturn [{ json: { ...request, validated: true } }];"
      }
    },
    {
      "id": "update_redis",
      "name": "Update_Global_State",
      "type": "n8n-nodes-base.redis",
      "parameters": {
        "operation": "set",
        "key": "ai_governance:global_controls",
        "value": "={{ JSON.stringify($json.new_state) }}"
      }
    },
    {
      "id": "send_notifications",
      "name": "Send_Alerts",
      "type": "n8n-nodes-base.slack",
      "parameters": {
        "channel": "#ai-alerts-critical",
        "text": "🚨 *AI CONTROL CHANGE*\n\nAction: {{ $json.action }}\nActivated by: {{ $json.user }}\nReason: {{ $json.reason }}\nTime: {{ $json.timestamp }}"
      }
    },
    {
      "id": "audit_log",
      "name": "Log_Control_Change",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "governance_control_log"
      }
    }
  ]
}
```

---

## 9. Configuration Management

### 9.1 Configuration Loading Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONFIGURATION MANAGEMENT                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CONFIG SOURCES (Priority Order)                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  1. Redis (Real-time overrides)        ← Highest Priority                  │
│     └─ ai_governance:global_controls                                        │
│     └─ ai_governance:kill_switch                                            │
│     └─ ai_governance:limited_mode                                           │
│                                                                             │
│  2. Environment Variables              ← Runtime Configuration              │
│     └─ AI_GOVERNANCE_KILL_SWITCH=false                                      │
│     └─ AI_GOVERNANCE_LIMITED_MODE=false                                     │
│     └─ AI_GOVERNANCE_CONFIG_PATH=/config                                    │
│                                                                             │
│  3. JSON Config Files                  ← Default Configuration              │
│     └─ /config/policy-matrix.json                                           │
│     └─ /config/agent-whitelist.json                                         │
│     └─ /config/escalation-rules.json                                        │
│     └─ /config/global-controls.json                                         │
│                                                                             │
│  CONFIG LOADING FLOW                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐                │
│  │  Load    │──▶│  Load    │──▶│  Load    │──▶│  Merge   │                │
│  │  JSON    │   │   ENV    │   │  Redis   │   │  Configs │                │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘                │
│                                                      │                      │
│                                                      ▼                      │
│                                               ┌──────────────┐              │
│                                               │   Validate   │              │
│                                               │    Schema    │              │
│                                               └──────┬───────┘              │
│                                                      │                      │
│                                                      ▼                      │
│                                               ┌──────────────┐              │
│                                               │    Cache     │              │
│                                               │  (60 sec)    │              │
│                                               └──────────────┘              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Configuration Hot-Reload

```javascript
// Configuration Hot-Reload Logic (n8n Function Node)

const CONFIG_CACHE_TTL = 60; // seconds
let configCache = null;
let configCacheTime = 0;

async function loadGovernanceConfig() {
  const now = Date.now() / 1000;
  
  // Check cache
  if (configCache && (now - configCacheTime) < CONFIG_CACHE_TTL) {
    return configCache;
  }
  
  // Load from sources (priority: Redis > Env > JSON)
  const jsonConfig = await loadJsonConfigs();
  const envOverrides = loadEnvOverrides();
  const redisOverrides = await loadRedisOverrides();
  
  // Merge configurations
  const mergedConfig = {
    ...jsonConfig,
    ...envOverrides,
    ...redisOverrides,
    _loaded_at: new Date().toISOString(),
    _sources: ['json', 'env', 'redis']
  };
  
  // Validate schema
  validateConfigSchema(mergedConfig);
  
  // Update cache
  configCache = mergedConfig;
  configCacheTime = now;
  
  return mergedConfig;
}

async function loadJsonConfigs() {
  const configPath = process.env.AI_GOVERNANCE_CONFIG_PATH || '/config';
  return {
    policyMatrix: require(`${configPath}/policy-matrix.json`),
    agentWhitelist: require(`${configPath}/agent-whitelist.json`),
    escalationRules: require(`${configPath}/escalation-rules.json`),
    globalControls: require(`${configPath}/global-controls.json`)
  };
}

function loadEnvOverrides() {
  return {
    globalControls: {
      kill_switch: {
        enabled: process.env.AI_GOVERNANCE_KILL_SWITCH === 'true'
      },
      limited_mode: {
        enabled: process.env.AI_GOVERNANCE_LIMITED_MODE === 'true'
      }
    }
  };
}

async function loadRedisOverrides() {
  // In production, load from Redis
  // const redis = require('redis');
  // const client = redis.createClient();
  // const killSwitch = await client.get('ai_governance:kill_switch');
  // return JSON.parse(killSwitch || '{}');
  return {};
}

function validateConfigSchema(config) {
  // Validate required fields exist
  const requiredKeys = ['policyMatrix', 'agentWhitelist', 'escalationRules', 'globalControls'];
  for (const key of requiredKeys) {
    if (!config[key]) {
      throw new Error(`Missing required configuration: ${key}`);
    }
  }
  return true;
}

module.exports = { loadGovernanceConfig };
```

### 9.3 Configuration File Structure

```
/config/
├── policy-matrix.json          # Allowed/forbidden actions
├── agent-whitelist.json        # Per-agent permissions
├── escalation-rules.json       # Escalation triggers
├── global-controls.json        # Kill-switch, limited mode
├── content-filters.json        # Prohibited content patterns
├── audit-config.json           # Audit logging settings
└── notifications.json          # Alert channel configuration

/config/schemas/
├── policy-matrix.schema.json
├── agent-whitelist.schema.json
├── escalation-rules.schema.json
└── global-controls.schema.json
```

---

## 10. Implementation Guide

### 10.1 Implementation Phases

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Phase 1: Foundation** | 2 weeks | Database schema, config files, basic guards |
| **Phase 2: Core Guards** | 2 weeks | Pre-send validation, content filtering |
| **Phase 3: Escalation** | 1 week | Escalation rules, queue routing |
| **Phase 4: Audit** | 1 week | Full audit logging, compliance reports |
| **Phase 5: Controls** | 1 week | Kill-switch, limited mode, dashboards |
| **Phase 6: Testing** | 2 weeks | Integration testing, security review |

### 10.2 n8n Integration Points

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                  n8n GOVERNANCE INTEGRATION POINTS                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  EXISTING WORKFLOW: Janssen_AI_Brain                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  ┌─────────────┐                                                           │
│  │  Webhook    │                                                           │
│  │  Receive    │                                                           │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────┐                               │
│  │  🆕 GOVERNANCE: Pre-Process Guard       │  ← INSERT HERE                │
│  │     • Load global controls              │                               │
│  │     • Check kill-switch                 │                               │
│  │     • Validate input                    │                               │
│  └──────┬──────────────────────────────────┘                               │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │  Route to   │                                                           │
│  │   Agent     │  (existing)                                               │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │  Agent      │                                                           │
│  │  Response   │  (existing)                                               │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────┐                               │
│  │  🆕 GOVERNANCE: Runtime Guard           │  ← INSERT HERE                │
│  │     • Validate response content         │                               │
│  │     • Check whitelist                   │                               │
│  │     • Apply content filters             │                               │
│  │     • Enforce escalation rules          │                               │
│  └──────┬──────────────────────────────────┘                               │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────┐                               │
│  │  🆕 GOVERNANCE: Audit Logger            │  ← INSERT HERE                │
│  │     • Log complete interaction          │                               │
│  │     • Record governance decisions       │                               │
│  │     • Generate alerts if needed         │                               │
│  └──────┬──────────────────────────────────┘                               │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │  Send       │                                                           │
│  │  Response   │  (existing)                                               │
│  └─────────────┘                                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.3 Testing Checklist

```markdown
## Governance Testing Checklist

### Kill-Switch Tests
- [ ] Kill-switch activates correctly
- [ ] All AI responses blocked when enabled
- [ ] Fallback message delivered
- [ ] Notifications sent to correct channels
- [ ] Audit log records activation
- [ ] Deactivation requires proper authorization

### Limited Mode Tests
- [ ] Limited mode restricts to allowed actions only
- [ ] Auto-escalation after N turns works
- [ ] Confidence threshold boost applied
- [ ] Timeout auto-disables limited mode
- [ ] Proper notifications sent

### Policy Matrix Tests
- [ ] Forbidden phrases detected and blocked
- [ ] Forbidden patterns caught by regex
- [ ] PII detected and redacted
- [ ] Allowed actions pass validation
- [ ] Conditional actions check all conditions

### Whitelist Tests
- [ ] Each agent respects its whitelist
- [ ] Forbidden actions blocked per agent
- [ ] Data access restrictions enforced
- [ ] Response length limits applied
- [ ] Disclaimers added when required

### Escalation Tests
- [ ] Legal mentions trigger escalation
- [ ] Refund requests escalate correctly
- [ ] Low confidence triggers escalation
- [ ] VIP customers routed to VIP queue
- [ ] Safety concerns get immediate escalation
- [ ] Correct queues receive escalations

### Audit Tests
- [ ] Every turn logged to database
- [ ] All fields populated correctly
- [ ] Hashes computed and stored
- [ ] Governance decisions recorded
- [ ] Events table populated for violations
- [ ] Alerts generated for critical events
```

---

## Appendix A: Quick Reference

### Control Activation Commands

```bash
# Activate Kill-Switch (Emergency)
curl -X POST https://n8n.janssen.com/webhook/ai-governance/control \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-2FA-Code: $OTP_CODE" \
  -d '{"action": "activate_kill_switch", "reason": "Security incident"}'

# Activate Limited Mode
curl -X POST https://n8n.janssen.com/webhook/ai-governance/control \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action": "activate_limited_mode", "reason": "Performance issues", "duration_hours": 24}'

# Deactivate Controls
curl -X POST https://n8n.janssen.com/webhook/ai-governance/control \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action": "deactivate_all", "reason": "Issue resolved"}'
```

### Escalation Priority Levels

| Priority | Response Time | Examples |
|----------|---------------|----------|
| CRITICAL | < 15 minutes | Legal, Safety, Kill-switch |
| HIGH | < 1 hour | Refund, VIP, Media |
| MEDIUM | < 4 hours | Low confidence, Repeat contact |
| LOW | < 24 hours | General feedback |

### Audit Retention Policy

| Data Type | Retention | Archive |
|-----------|-----------|---------|
| Audit Logs | 2 years | 7 years |
| Events | 1 year | 5 years |
| Alerts | 6 months | 2 years |
| Controls Log | Forever | N/A |

---

*Document Version: 1.0.0*  
*AI Governance Committee*  
*Contact: ai-governance@janssen.com*
