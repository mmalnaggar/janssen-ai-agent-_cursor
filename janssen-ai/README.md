# Janssen AI

AI-powered customer service agent system for Janssen.

## Project Structure

```
janssen-ai/
├── backend/
│   ├── agents/           # Agent configuration JSON files
│   │   ├── router.agent.json
│   │   ├── sales.agent.json
│   │   ├── support.agent.json
│   │   └── escalation.agent.json
│   ├── controllers/      # Request/response handlers
│   ├── routes/           # API route definitions
│   ├── services/         # Business logic layer
│   ├── utils/            # Helper functions
│   └── app.js            # Express application entry point
├── package.json
└── README.md
```

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   ```

2. Copy environment file:
   ```bash
   cp .env.example .env
   ```

3. Start the server:
   ```bash
   npm start
   ```

   Or for development with auto-reload:
   ```bash
   npm run dev
   ```

## API Endpoints

- `GET /health` - Health check
- `POST /api/message` - Handle incoming messages
- `GET /api/agents` - Get available agents

## Agent System

The system uses 4 specialized agents:

- **Router Agent**: Routes messages to appropriate agents based on intent
- **Sales Agent**: Handles product inquiries, pricing, and recommendations
- **Support Agent**: Handles FAQs, delivery info, and warranty questions
- **Escalation Agent**: Transfers to human support when needed
