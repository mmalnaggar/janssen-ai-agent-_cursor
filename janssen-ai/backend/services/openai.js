// Janssen AI - OpenAI Service
// ============================================
// Graceful: if OPENAI_API_KEY is missing, the app still runs
// using keyword-based fallback (no LLM)
// ============================================
const OpenAI = require('openai');

let client = null;
let isConfigured = false;

const MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const INTENT_MODEL = process.env.OPENAI_INTENT_MODEL || 'gpt-4o-mini';
const MAX_TOKENS = parseInt(process.env.OPENAI_MAX_TOKENS || '500');
const TEMPERATURE = parseFloat(process.env.OPENAI_TEMPERATURE || '0.7');
const TIMEOUT_MS = parseInt(process.env.OPENAI_TIMEOUT_MS || '15000');

if (process.env.OPENAI_API_KEY) {
  try {
    client = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      maxRetries: 2,
      timeout: TIMEOUT_MS
    });
    isConfigured = true;
    console.log('[OpenAI] Client initialized (model: %s)', MODEL);
  } catch (err) {
    console.warn('[OpenAI] Failed to initialize:', err.message);
  }
} else {
  console.log('[OpenAI] No API key — running in keyword-only mode');
}

const openai = {
  isAvailable: () => isConfigured && client !== null,

  /**
   * General chat completion
   * @returns {{ content: string, usage: object, model: string } | null}
   */
  chatCompletion: async ({ systemPrompt, messages, temperature, maxTokens }) => {
    if (!client || !isConfigured) return null;

    try {
      const allMessages = [
        { role: 'system', content: systemPrompt },
        ...messages
      ];

      const response = await client.chat.completions.create({
        model: MODEL,
        messages: allMessages,
        temperature: temperature ?? TEMPERATURE,
        max_tokens: maxTokens ?? MAX_TOKENS
      });

      const choice = response.choices[0];
      if (!choice || !choice.message) return null;

      const usage = response.usage;
      if (usage) {
        console.log('[OpenAI] Tokens — prompt: %d, completion: %d, total: %d',
          usage.prompt_tokens, usage.completion_tokens, usage.total_tokens);
      }

      return {
        content: choice.message.content,
        usage: usage || {},
        model: response.model
      };
    } catch (err) {
      console.error('[OpenAI] Chat completion error:', err.message);
      return null;
    }
  },

  /**
   * Classify user intent using a cheap LLM call
   * @returns {{ intent: string, confidence: number } | null}
   */
  detectIntentWithLLM: async (userMessage, language) => {
    if (!client || !isConfigured) return null;

    const systemPrompt = `You are an intent classifier for Janssen Mattresses (يانسن للمراتب), an Egyptian mattress company.

Classify the customer message into exactly ONE of these intents:
- SALES_PRICE: asking about prices, costs, how much
- SALES_RECOMMENDATION: asking for recommendations, which is best, advice
- PRODUCT_INQUIRY: asking about product details, types, sizes, materials
- DELIVERY: asking about delivery, shipping, tracking, delivery areas
- STORE_INFO: asking about store locations, branches, addresses, hours
- WARRANTY: asking about warranty, repair, defects, claims
- COMPLAINT: expressing dissatisfaction, problems, issues, anger
- HUMAN_REQUEST: wanting to talk to a human agent
- GREETING: greetings, hello, hi
- GENERAL: anything else that doesn't fit above

Respond with ONLY a JSON object: {"intent": "INTENT_NAME", "confidence": 0.95}
Do not include any other text.`;

    try {
      const response = await client.chat.completions.create({
        model: INTENT_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userMessage }
        ],
        temperature: 0.1,
        max_tokens: 50
      });

      const text = response.choices[0]?.message?.content?.trim();
      if (!text) return null;

      const parsed = JSON.parse(text);
      if (parsed.intent && typeof parsed.confidence === 'number') {
        console.log('[OpenAI] Intent detected: %s (%.2f)', parsed.intent, parsed.confidence);
        return parsed;
      }
      return null;
    } catch (err) {
      console.error('[OpenAI] Intent detection error:', err.message);
      return null;
    }
  }
};

module.exports = openai;
