// Janssen AI - Main Express Application Entry Point
const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const routes = require('./routes');
const db = require('./db/connection');
const openai = require('./services/openai');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve widget static files at /widget
app.use('/widget', express.static(path.join(__dirname, '..', 'widget')));

// Routes
app.use('/api', routes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'janssen-ai',
    database: db.isAvailable() ? 'connected' : 'fallback',
    openai: openai.isAvailable() ? 'connected' : 'disabled',
    timestamp: new Date().toISOString()
  });
});

// Dashboard page
app.get('/dashboard', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'widget', 'dashboard.html'));
});

// Serve demo page at root
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'widget', 'demo.html'));
});

// Global error handler
app.use((err, req, res, _next) => {
  console.error('[Server] Unhandled error:', err.message);
  res.status(500).json({
    response_type: 'text',
    content: { text: 'Internal server error' },
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\nJanssen AI server running on http://localhost:${PORT}`);
  console.log(`  Widget demo:  http://localhost:${PORT}/`);
  console.log(`  Dashboard:    http://localhost:${PORT}/dashboard`);
  console.log(`  API health:   http://localhost:${PORT}/health`);
  console.log(`  API agents:   http://localhost:${PORT}/api/agents`);
  console.log(`  DB status:    ${db.isAvailable() ? 'Connected' : 'Fallback mode (no PostgreSQL)'}\n`);
});

module.exports = app;
