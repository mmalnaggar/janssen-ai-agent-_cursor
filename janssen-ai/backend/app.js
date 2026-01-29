// Janssen AI - Main Express Application Entry Point
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const routes = require('./routes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api', routes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'janssen-ai' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Janssen AI server running on port ${PORT}`);
});

module.exports = app;
