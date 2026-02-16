// Janssen AI - Chatbot Routes
// Handles incoming customer messages and routes them to appropriate agents
// Uses PostgreSQL for persistence and agent configs for response generation

const express = require('express');
const router = express.Router();
const agentLoader = require('../services/agentLoader');
const db = require('../db/connection');
const openai = require('../services/openai');

// ============================================
// INTENT DETECTION (keyword-based)
// Will be replaced with AI-based detection via n8n/OpenAI
// ============================================

function detectIntent(text) {
  const lowerText = text.toLowerCase();

  // Ordered by specificity: escalation > complaint > warranty > delivery > store > sales > product > greeting > general
  const intentPatterns = [
    ['HUMAN_REQUEST', [
      'human', 'agent', 'person', 'real person', 'talk to someone',
      'حد يرد', 'اتكلم مع حد', 'موظف', 'خدمة عملاء', 'كلمني حد'
    ]],
    ['COMPLAINT', [
      'complaint', 'problem', 'angry', 'disappointed', 'terrible', 'worst', 'broken',
      'شكوى', 'مشكلة', 'زعلان', 'سيء', 'وحش', 'عايز أشكي', 'مش راضي'
    ]],
    ['WARRANTY', [
      'warranty', 'guarantee', 'defect', 'repair', 'warranty claim',
      'ضمان', 'عيب', 'تصليح', 'كسر', 'استبدال'
    ]],
    ['DELIVERY', [
      'delivery', 'shipping', 'deliver', 'arrive', 'track',
      'توصيل', 'شحن', 'يوصل', 'ميعاد', 'هيوصل امتى', 'مواعيد التوصيل'
    ]],
    ['STORE_INFO', [
      'store', 'branch', 'location', 'address', 'where',
      'فرع', 'فين', 'عنوان', 'مكان', 'الفروع', 'فين الفرع'
    ]],
    ['SALES_PRICE', [
      'price', 'cost', 'how much', 'pricing',
      'كام', 'سعر', 'بكام', 'تكلفة', 'أسعار', 'ثمن'
    ]],
    ['SALES_RECOMMENDATION', [
      'recommend', 'suggest', 'best', 'help me choose', 'which one',
      'انصحني', 'ايه احسن', 'اختار', 'افضل', 'عايز مرتبة', 'تنصحني بإيه'
    ]],
    ['PRODUCT_INQUIRY', [
      'orthopedic', 'memory foam', 'super soft', 'mattress', 'types', 'sizes',
      'أورثوبيديك', 'ميموري فوم', 'سوبر سوفت', 'مرتبة', 'انواع', 'مقاسات'
    ]],
    ['GREETING', [
      'hello', 'hi', 'hey', 'good morning', 'good evening',
      'مرحبا', 'أهلا', 'السلام عليكم', 'صباح الخير', 'مساء الخير', 'ازيك', 'ازاي'
    ]]
  ];

  for (const [intent, keywords] of intentPatterns) {
    for (const keyword of keywords) {
      if (lowerText.includes(keyword)) {
        return { intent, confidence: 0.80 };
      }
    }
  }

  return { intent: 'GENERAL', confidence: 0.5 };
}

// ============================================
// DETECT LANGUAGE (Arabic vs English)
// ============================================

function detectLanguage(text) {
  const arabicPattern = /[\u0600-\u06FF]/;
  return arabicPattern.test(text) ? 'ar' : 'en';
}

// ============================================
// RESPONSE GENERATORS (per agent type)
// ============================================

async function generateSalesResponse(intent, message, language) {
  const lang = language || 'ar';
  const lowerMsg = message.toLowerCase();

  let productFilter = null;
  if (lowerMsg.includes('orthop') || lowerMsg.includes('أورثوبيديك') || lowerMsg.includes('طبي')) {
    productFilter = 'orthopedic';
  } else if (lowerMsg.includes('memory') || lowerMsg.includes('ميموري')) {
    productFilter = 'memory_foam';
  } else if (lowerMsg.includes('soft') || lowerMsg.includes('سوفت') || lowerMsg.includes('ناعم')) {
    productFilter = 'soft';
  }

  let query, params;
  if (productFilter) {
    query = `
      SELECT p.*, pr.price_egp, pr.discount_percent
      FROM products p
      JOIN prices pr ON pr.product_id = p.id AND pr.is_current = true
      WHERE p.is_active = true AND p.category = $1
      ORDER BY pr.price_egp ASC
    `;
    params = [productFilter];
  } else {
    query = `
      SELECT p.*, pr.price_egp, pr.discount_percent
      FROM products p
      JOIN prices pr ON pr.product_id = p.id AND pr.is_current = true
      WHERE p.is_active = true AND p.category != 'accessories'
      ORDER BY pr.price_egp ASC
      LIMIT 3
    `;
    params = [];
  }

  const result = await db.query(query, params);

  if (result.rows.length === 0) {
    return {
      response_type: 'text',
      content: {
        text: lang === 'ar'
          ? 'للأسف مش لاقي المنتج ده دلوقتي. ممكن أعرض عليك بدايل تانية؟'
          : "I couldn't find that specific product right now. Would you like to see some alternatives?"
      }
    };
  }

  if (intent === 'SALES_PRICE' || intent === 'PRODUCT_INQUIRY') {
    // Check if the customer mentioned a specific size in their message
    const sizePattern = /\b(120|140|150|160|170|180|200)\s*(cm|سم)?\b/i;
    const mentionedSize = lowerMsg.match(sizePattern);

    if (mentionedSize) {
      // Customer specified a size — find the matching product and show price
      const sizeValue = mentionedSize[1];
      const matchingProduct = result.rows.find(p => p.dimensions && p.dimensions.includes(sizeValue));
      if (matchingProduct) {
        const p = matchingProduct;
        return {
          response_type: 'product_card',
          content: {
            text: lang === 'ar'
              ? `تمام! ده تفاصيل ${p.name_ar}:`
              : `Here are the details for ${p.name_en}:`,
            product: {
              name: lang === 'ar' ? p.name_ar : p.name_en,
              description: lang === 'ar' ? p.description_ar : p.description_en,
              price: `${Number(p.price_egp).toLocaleString()} EGP`,
              warranty: `${p.warranty_years} ${lang === 'ar' ? 'سنين ضمان' : 'years warranty'}`,
              url: '#'
            }
          }
        };
      }
    }

    // No size specified — ask for size first (do NOT show prices)
    const categoryName = productFilter
      ? (lang === 'ar'
          ? { orthopedic: 'أورثوبيديك', memory_foam: 'ميموري فوم', soft: 'سوبر سوفت' }[productFilter]
          : { orthopedic: 'Orthopedic', memory_foam: 'Memory Foam', soft: 'Super Soft' }[productFilter])
      : null;

    const availableSizes = [...new Set(result.rows.map(p => p.dimensions).filter(Boolean))].join(', ');

    return {
      response_type: 'text',
      content: {
        text: lang === 'ar'
          ? `تمام! ${categoryName ? `مرتبة ${categoryName} متاحة` : 'المراتب متاحة'} بالمقاسات دي: ${availableSizes}.\n\nمحتاج مقاس كام؟ قولي المقاس وهقولك السعر على طول.`
          : `Great! ${categoryName ? `The ${categoryName} mattress is` : 'Our mattresses are'} available in these sizes: ${availableSizes}.\n\nWhich size do you need? Tell me and I'll give you the exact price.`
      }
    };
  }

  return {
    response_type: 'text',
    content: {
      text: lang === 'ar'
        ? 'أهلاً بيك! عندنا 3 أنواع مراتب: أورثوبيديك (طبية للظهر)، ميموري فوم (راحة فائقة)، وسوبر سوفت (نعومة استثنائية). عايز أساعدك تختار؟ قولي ميزانيتك أو إيه اللي بتدور عليه.'
        : "Welcome! We have 3 mattress types: Orthopedic (back support), Memory Foam (ultimate comfort), and Super Soft (exceptional softness). Would you like help choosing? Tell me your budget or what you're looking for."
    }
  };
}

async function generateSupportResponse(intent, message, language) {
  const lang = language || 'ar';

  if (intent === 'DELIVERY') {
    const result = await db.query(
      'SELECT * FROM delivery_rules WHERE is_active = true ORDER BY delivery_days_min'
    );

    if (result.rows.length > 0) {
      const rules = result.rows.map(r => {
        const region = lang === 'ar' ? r.governorate : r.region;
        const notes = lang === 'ar' ? r.notes_ar : r.notes_en;
        return `• ${region}: ${r.delivery_days_min}-${r.delivery_days_max} ${lang === 'ar' ? 'يوم' : 'days'} - ${notes}`;
      }).join('\n');

      return {
        response_type: 'text',
        content: {
          text: lang === 'ar'
            ? `مواعيد التوصيل حسب المنطقة:\n\n${rules}\n\nالتوصيل مجاني للطلبات فوق 5,000 جنيه في القاهرة والجيزة.`
            : `Delivery times by region:\n\n${rules}\n\nFree delivery for orders above 5,000 EGP in Cairo and Giza.`
        }
      };
    }
  }

  return {
    response_type: 'text',
    content: {
      text: lang === 'ar'
        ? 'أهلاً بيك في يانسن! إزاي أقدر أساعدك؟ ممكن أساعدك في:\n• أسعار المراتب\n• مواعيد التوصيل\n• معلومات الضمان\n• شكوى أو مشكلة'
        : 'Welcome to Janssen! How can I help you? I can assist with:\n• Mattress prices\n• Delivery information\n• Warranty details\n• Complaints or issues'
    }
  };
}

async function generateWarrantyResponse(intent, message, language) {
  const lang = language || 'ar';
  return {
    response_type: 'text',
    content: {
      text: lang === 'ar'
        ? 'الضمان في يانسن:\n\n• مرتبة أورثوبيديك: ضمان 10 سنين\n• مرتبة ميموري فوم: ضمان 12 سنة\n• مرتبة سوبر سوفت: ضمان 8 سنين\n\nالضمان يشمل عيوب الصناعة. لو عندك مشكلة، ابعتلنا صورة ورقم الفاتورة وهنساعدك.'
        : "Janssen Warranty:\n\n• Orthopedic: 10-year warranty\n• Memory Foam: 12-year warranty\n• Super Soft: 8-year warranty\n\nWarranty covers manufacturing defects. If you have an issue, send us a photo and invoice number and we'll help."
    }
  };
}

async function generateComplaintResponse(intent, message, language) {
  const lang = language || 'ar';
  return {
    response_type: 'text',
    content: {
      text: lang === 'ar'
        ? 'آسفين جداً لأي إزعاج! رأيك مهم لينا. ممكن تقولنا:\n\n1. إيه المشكلة بالظبط؟\n2. إمتى حصلت؟\n3. رقم الفاتورة لو متاح\n\nهنحاول نحل المشكلة بأسرع وقت.'
        : "We're very sorry for any inconvenience! Your feedback matters. Can you tell us:\n\n1. What exactly is the issue?\n2. When did it happen?\n3. Invoice number if available\n\nWe'll try to resolve this as quickly as possible."
    }
  };
}

function generateEscalationResponse(language) {
  const lang = language || 'ar';
  return {
    response_type: 'handover',
    content: {
      handover_message: lang === 'ar'
        ? 'هحولك دلوقتي لأحد ممثلي خدمة العملاء. استنى لحظة من فضلك.'
        : "I'm connecting you with a customer service representative. Please hold."
    }
  };
}

function generateStoreInfoResponse(language) {
  const lang = language || 'ar';
  return {
    response_type: 'text',
    content: {
      text: lang === 'ar'
        ? 'فروع يانسن:\n\n📍 فرع مدينة نصر: عباس العقاد، القاهرة\n📍 فرع المهندسين: شارع جامعة الدول العربية\n\n📞 للاستفسار: +20 2 2345 6789\n⏰ مواعيد العمل: السبت - الخميس، 10 صباحاً - 10 مساءً'
        : "Janssen Branches:\n\n📍 Nasr City: Abbas El-Akkad St., Cairo\n📍 Mohandiseen: Gameat El Dowal El Arabeya St.\n\n📞 Call us: +20 2 2345 6789\n⏰ Hours: Sat - Thu, 10 AM - 10 PM"
    }
  };
}

function generateGreetingResponse(language) {
  const lang = language || 'ar';
  return {
    response_type: 'text',
    content: {
      text: lang === 'ar'
        ? 'أهلاً بيك في يانسن! إزاي أقدر أساعدك النهاردة؟ ممكن أساعدك في:\n\n• أسعار المراتب والمنتجات\n• توصيات واختيار المرتبة المناسبة\n• مواعيد التوصيل والشحن\n• معلومات الضمان\n• عناوين الفروع'
        : "Welcome to Janssen! How can I help you today? I can assist with:\n\n• Mattress prices and products\n• Recommendations and choosing the right mattress\n• Delivery and shipping times\n• Warranty information\n• Branch locations"
    }
  };
}

// ============================================
// LLM RESPONSE GENERATION (OpenAI-powered)
// Falls back to keyword-based generators if unavailable
// ============================================

function buildSystemPrompt(agentConfig, language, dbContext) {
  const lang = language || 'ar';
  const sections = [];

  // Identity
  sections.push(`You are ${agentConfig.description || 'a customer service agent for Janssen Mattresses (يانسن للمراتب), an Egyptian mattress brand since 1955.'}`);

  // Language & tone
  const tone = agentConfig.allowed_outputs?.text?.tone?.[lang];
  if (lang === 'ar') {
    sections.push('The customer is writing in Arabic. Respond ONLY in Egyptian Arabic (not formal Arabic).');
  } else {
    sections.push('The customer is writing in English. Respond ONLY in English.');
  }
  if (tone) {
    sections.push(`Your tone: ${tone}`);
  }

  // Allowed & forbidden actions
  if (agentConfig.allowed_actions?.length) {
    sections.push(`You are ALLOWED to: ${agentConfig.allowed_actions.join(', ')}`);
  }
  if (agentConfig.forbidden_actions?.length) {
    sections.push(`You are STRICTLY FORBIDDEN from: ${agentConfig.forbidden_actions.join(', ')}`);
  }

  // Sales-specific pricing rules (size before price)
  if (agentConfig.name === 'sales') {
    sections.push(`MANDATORY PRICING RULE — YOU MUST FOLLOW THIS:
- NEVER quote a price, list prices, or mention any EGP amount UNTIL the customer has confirmed which SIZE they want (120cm, 140cm, 160cm, 180cm, etc.)
- When a customer asks about price, you MUST first ask them which size/dimensions they need.
- Only AFTER the customer specifies a size, provide the price for that ONE specific size.
- Do NOT list multiple sizes with their prices. Ask for the size first, then give the single matching price.
- This rule applies to ALL price-related questions — no exceptions.`);
  }

  // Escalation rules
  if (agentConfig.escalation_rules?.conditions?.length) {
    const rules = agentConfig.escalation_rules.conditions
      .map(c => `- ${c.description} (priority: ${c.priority})`)
      .join('\n');
    sections.push(`If any of these conditions are met, tell the customer you will connect them with a specialist:\n${rules}`);
  }

  // Response templates (as style reference)
  if (agentConfig.response_templates) {
    const templates = Object.entries(agentConfig.response_templates)
      .map(([key, val]) => `${key}: "${val[lang] || val.ar || val.en}"`)
      .join('\n');
    sections.push(`Use these as STYLE reference (do not copy verbatim):\n${templates}`);
  }

  // Database context (filter out rows with missing critical fields)
  if (dbContext.products?.length) {
    const validProducts = dbContext.products.filter(p => p.name_en && p.price_egp != null);
    if (validProducts.length) {
      const productList = validProducts.map(p => {
        const name = lang === 'ar' ? (p.name_ar || p.name_en) : p.name_en;
        return `- ${name}: ${Number(p.price_egp).toLocaleString()} EGP, ${p.dimensions || 'N/A'}, ${p.warranty_years || 0}-year warranty, category: ${p.category || 'general'}`;
      }).join('\n');
      sections.push(`CURRENT PRODUCT CATALOG (use ONLY these prices — never invent prices):\n${productList}`);
    }
  }

  if (dbContext.delivery_rules?.length) {
    const validRules = dbContext.delivery_rules.filter(r => (r.governorate || r.region) && r.delivery_days_min != null);
    if (validRules.length) {
      const rules = validRules.map(r => {
        const region = lang === 'ar' ? (r.governorate || r.region) : (r.region || r.governorate);
        return `- ${region}: ${r.delivery_days_min}-${r.delivery_days_max} days, fee: ${Number(r.delivery_fee_egp || 0)} EGP, free above ${Number(r.free_delivery_threshold || 0)} EGP`;
      }).join('\n');
      sections.push(`DELIVERY RULES:\n${rules}`);
    }
  }

  // Agent-specific notes
  if (agentConfig.notes?.length) {
    sections.push(`IMPORTANT NOTES:\n${agentConfig.notes.map(n => `- ${n}`).join('\n')}`);
  }

  // Output format
  const maxLen = agentConfig.allowed_outputs?.text?.max_length || 500;
  sections.push(`OUTPUT RULES:
- Keep responses under ${maxLen} characters
- Respond in plain text only (no markdown formatting, no bullet symbols like *)
- Use newlines to separate sections
- Do NOT invent data not provided above
- Be conversational and helpful`);

  return sections.join('\n\n');
}

async function generateLLMResponse(agentName, intent, message, language, conversationHistory, dbContext) {
  if (!openai.isAvailable()) return null;

  const agentConfig = agentLoader.getAgentByName(agentName);
  if (!agentConfig) {
    console.warn('[LLM] Agent config not found for: %s', agentName);
    return null;
  }

  try {
    const systemPrompt = buildSystemPrompt(agentConfig, language, dbContext);

    // Build messages from conversation history
    const messages = [];
    if (conversationHistory?.length) {
      for (const msg of conversationHistory) {
        messages.push({
          role: msg.sender_type === 'customer' ? 'user' : 'assistant',
          content: msg.message_text
        });
      }
    }
    // Add current message
    messages.push({ role: 'user', content: message });

    const result = await openai.chatCompletion({
      systemPrompt,
      messages,
      temperature: 0.7,
      maxTokens: 500
    });

    if (!result || !result.content) {
      console.warn('[LLM] Empty response from OpenAI for intent: %s', intent);
      return null;
    }

    return {
      response_type: 'text',
      content: { text: result.content },
      _llmUsed: true
    };
  } catch (err) {
    console.error('[LLM] Error generating response for agent=%s intent=%s: %s', agentName, intent, err.message);
    return null;
  }
}

// ============================================
// ROUTE: POST /api/message
// Main endpoint for receiving customer messages
// ============================================

router.post('/message', async (req, res) => {
  const startTime = Date.now();

  try {
    const { session_id, user_message, message, channel, language, metadata } = req.body;

    // Support both widget format (user_message) and API format (message)
    const msgText = user_message || message;
    const sessionId = session_id || ('session_' + Date.now());

    if (!msgText || typeof msgText !== 'string' || msgText.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Missing or invalid field: user_message'
      });
    }

    // Limit message length to prevent abuse
    const MAX_MESSAGE_LENGTH = 2000;
    if (msgText.length > MAX_MESSAGE_LENGTH) {
      return res.status(400).json({
        success: false,
        error: `Message too long (max ${MAX_MESSAGE_LENGTH} characters)`
      });
    }

    // Detect language and intent
    const detectedLang = language || detectLanguage(msgText);
    let intentResult = detectIntent(msgText);

    // If keyword detection returns GENERAL (no match), try LLM intent classification
    if (intentResult.intent === 'GENERAL' && openai.isAvailable()) {
      const llmIntent = await openai.detectIntentWithLLM(msgText, detectedLang);
      if (llmIntent && llmIntent.intent !== 'GENERAL' && llmIntent.confidence > 0.7) {
        intentResult = llmIntent;
      }
    }

    // DB operations wrapped in try/catch so we still respond if DB is down
    let conversation = null;
    try {
      if (db.isAvailable()) {
        const existingConvo = await db.query(
          'SELECT * FROM conversations WHERE session_id = $1',
          [sessionId]
        );

        if (existingConvo.rows.length > 0) {
          conversation = existingConvo.rows[0];
          await db.query(
            'UPDATE conversations SET last_message_at = NOW() WHERE id = $1',
            [conversation.id]
          );
        } else {
          const newConvo = await db.query(
            `INSERT INTO conversations (session_id, channel, language, status, started_at, last_message_at)
             VALUES ($1, $2, $3, 'open', NOW(), NOW())
             ON CONFLICT (session_id) DO UPDATE SET last_message_at = NOW()
             RETURNING *`,
            [sessionId, channel || 'chat', detectedLang]
          );
          conversation = newConvo.rows[0];
        }
      }
    } catch (dbErr) {
      console.warn('[Chatbot] DB conversation setup failed (continuing without persistence):', dbErr.message);
    }

    // Route to appropriate agent
    const targetAgent = agentLoader.routeByIntent(intentResult.intent);
    const agentName = targetAgent ? targetAgent.name : 'support';

    // Update conversation's assigned agent (if DB available)
    if (conversation) {
      try {
        await db.query(
          'UPDATE conversations SET assigned_agent = $1 WHERE id = $2',
          [agentName, conversation.id]
        );
      } catch (e) {
        console.warn('[Chatbot] Failed to update assigned agent:', e.message);
      }
    }

    // Fetch conversation history for LLM context BEFORE saving current message
    // to avoid duplicating the current message in the LLM context
    let conversationHistory = [];
    if (conversation && db.isAvailable()) {
      try {
        const historyResult = await db.query(
          `SELECT sender_type, message_text FROM conversation_messages
           WHERE conversation_id = $1 ORDER BY created_at DESC LIMIT 10`,
          [conversation.id]
        );
        conversationHistory = historyResult.rows.reverse();
      } catch (e) {
        console.warn('[Chatbot] Failed to fetch conversation history:', e.message);
      }
    }

    // Save customer message AFTER fetching history
    if (conversation && db.isAvailable()) {
      try {
        await db.query(
          `INSERT INTO conversation_messages (conversation_id, sender_type, sender_id, message_text, message_type, intent_detected, confidence_score)
           VALUES ($1, 'customer', $2, $3, 'text', $4, $5)`,
          [conversation.id, sessionId, msgText.trim(), intentResult.intent, intentResult.confidence]
        );
      } catch (e) {
        console.warn('[Chatbot] Failed to save customer message:', e.message);
      }
    }

    // Fetch DB context for LLM (products for sales, delivery rules for support)
    let dbContext = {};
    try {
      if (db.isAvailable() && (agentName === 'sales' || intentResult.intent === 'PRODUCT_INQUIRY' || intentResult.intent === 'SALES_PRICE' || intentResult.intent === 'SALES_RECOMMENDATION')) {
        const productsResult = await db.query(
          `SELECT p.name_en, p.name_ar, p.category, p.dimensions, p.warranty_years, p.description_en, p.description_ar, p.material, p.firmness_level,
                  pr.price_egp, pr.discount_percent
           FROM products p JOIN prices pr ON pr.product_id = p.id AND pr.is_current = true
           WHERE p.is_active = true ORDER BY p.category, pr.price_egp`
        );
        dbContext.products = productsResult.rows;
      }
      if (db.isAvailable() && (agentName === 'support' || intentResult.intent === 'DELIVERY')) {
        const deliveryResult = await db.query(
          'SELECT * FROM delivery_rules WHERE is_active = true'
        );
        dbContext.delivery_rules = deliveryResult.rows;
      }
    } catch (_) { /* non-critical */ }

    // Generate response based on agent and intent
    let responseData;
    let llmUsed = false;

    // Tier 1: No LLM needed — static responses
    if (intentResult.intent === 'GREETING') {
      responseData = generateGreetingResponse(detectedLang);
    } else if (intentResult.intent === 'STORE_INFO') {
      responseData = generateStoreInfoResponse(detectedLang);
    } else if (agentName === 'escalation') {
      responseData = generateEscalationResponse(detectedLang);
      if (conversation) {
        try {
          await db.query(
            'UPDATE conversations SET escalated = true WHERE id = $1',
            [conversation.id]
          );
        } catch (_) { /* non-critical */ }
      }
    } else {
      // Tier 2/3: Try LLM, fall back to keyword-based generators
      if (openai.isAvailable()) {
        responseData = await generateLLMResponse(agentName, intentResult.intent, msgText, detectedLang, conversationHistory, dbContext);
        if (responseData) {
          llmUsed = true;
        }
      }

      // Fallback to hardcoded generators if LLM unavailable or failed
      if (!responseData && openai.isAvailable()) {
        console.warn('[Chatbot] LLM response failed for agent=%s intent=%s, falling back to keyword generator', agentName, intentResult.intent);
      }
      if (!responseData) {
        switch (agentName) {
          case 'sales':
            responseData = await generateSalesResponse(intentResult.intent, msgText, detectedLang);
            break;
          case 'support':
            responseData = await generateSupportResponse(intentResult.intent, msgText, detectedLang);
            break;
          case 'warranty':
            responseData = await generateWarrantyResponse(intentResult.intent, msgText, detectedLang);
            break;
          case 'complaint':
            responseData = await generateComplaintResponse(intentResult.intent, msgText, detectedLang);
            break;
          default:
            responseData = await generateSupportResponse(intentResult.intent, msgText, detectedLang);
        }
      }
    }

    // Save bot response (non-critical)
    if (conversation && db.isAvailable()) {
      try {
        const responseText = responseData?.content?.text || responseData?.content?.handover_message || '';
        await db.query(
          `INSERT INTO conversation_messages (conversation_id, sender_type, sender_id, message_text, message_type)
           VALUES ($1, 'bot', $2, $3, 'text')`,
          [conversation.id, agentName, responseText]
        );
        await db.query(
          `INSERT INTO agents_log (conversation_id, agent_name, action_type, intent_received, input_text, output_text, response_time_ms, success)
           VALUES ($1, $2, 'MESSAGE_ROUTED', $3, $4, $5, $6, true)`,
          [conversation.id, agentName, intentResult.intent, msgText, responseText, Date.now() - startTime]
        );
        // --- CRM Webhook: fire-and-forget to n8n ---
        const crmUrl = process.env.CRM_WEBHOOK_URL;
        if (crmUrl) {
          fetch(crmUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              timestamp: new Date().toISOString(),
              session_id: sessionId,
              channel: channel || 'chat',
              language: detectedLang,
              user_message: msgText,
              bot_response: responseText,
              intent: intentResult.intent,
              agent_used: agentName,
              confidence: intentResult.confidence,
              escalated: agentName === 'escalation'
            })
          }).catch(() => { /* non-critical */ });
        }
      } catch (e) {
        console.warn('[Chatbot] Failed to save bot response:', e.message);
      }
    }

    // --- Auto Lead Capture: detect purchase intent from sales conversations ---
    if (conversation && db.isAvailable() && agentName === 'sales') {
      try {
        const sizePattern = /\b(120|140|150|160|170|180|200)\s*(cm|سم)?\b/i;
        const phonePattern = /\b01[0-9]{9}\b/;
        const buyIntentAr = /عايز|محتاج|هشتري|ابعتلي|اطلب|اشتري/i;
        const buyIntentEn = /buy|order|purchase|i('ll| will) take|send me/i;

        const hasSize = sizePattern.test(msgText);
        const hasPhone = msgText.match(phonePattern);
        const hasBuyIntent = buyIntentAr.test(msgText) || buyIntentEn.test(msgText);
        const isPriceWithSize = intentResult.intent === 'SALES_PRICE' && hasSize;
        const isStrongIntent = hasBuyIntent || isPriceWithSize;

        if (isStrongIntent) {
          const interestLevel = hasBuyIntent ? 'hot' : (hasSize ? 'warm' : 'cold');
          const phone = hasPhone ? hasPhone[0] : null;

          // Check for duplicate lead in same conversation
          const existingLead = await db.query(
            'SELECT id FROM leads WHERE conversation_id = $1 LIMIT 1',
            [conversation.id]
          );

          if (existingLead.rows.length === 0) {
            await db.query(
              `INSERT INTO leads (conversation_id, customer_phone, interest_level, notes, source, status)
               VALUES ($1, $2, $3, $4, $5, 'new')`,
              [
                conversation.id,
                phone || 'pending',
                interestLevel,
                `Intent: ${intentResult.intent} | Message: ${msgText.substring(0, 100)}`,
                channel || 'chat'
              ]
            );
            console.log('[CRM] Lead captured: conversation=%d level=%s', conversation.id, interestLevel);
          }
        }
      } catch (e) {
        console.warn('[CRM] Lead capture failed:', e.message);
      }
    }

    // Return response in widget-expected format
    return res.json({
      ...responseData,
      agent_used: agentName,
      intent: intentResult.intent,
      confidence_score: intentResult.confidence,
      session_id: sessionId,
      language: detectedLang,
      llm_used: llmUsed
    });

  } catch (error) {
    console.error('[Chatbot] Error:', error);
    return res.status(500).json({
      response_type: 'text',
      content: {
        text: 'حصلت مشكلة، حاول تاني لو سمحت / Something went wrong, please try again'
      },
      agent_used: 'system',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// ============================================
// ROUTE: GET /api/conversation/:sessionId
// Retrieve conversation history
// ============================================

router.get('/conversation/:sessionId', async (req, res) => {
  try {
    const { sessionId } = req.params;
    const convoResult = await db.query(
      'SELECT * FROM conversations WHERE session_id = $1',
      [sessionId]
    );

    if (convoResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Conversation not found' });
    }

    const conversation = convoResult.rows[0];
    const messagesResult = await db.query(
      'SELECT * FROM conversation_messages WHERE conversation_id = $1 ORDER BY created_at',
      [conversation.id]
    );
    const logsResult = await db.query(
      'SELECT * FROM agents_log WHERE conversation_id = $1 ORDER BY created_at',
      [conversation.id]
    );

    return res.json({
      success: true,
      data: { conversation, messages: messagesResult.rows, agent_logs: logsResult.rows }
    });
  } catch (error) {
    console.error('[Chatbot] Error fetching conversation:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================
// ROUTE: GET /api/products
// List products with prices
// ============================================

router.get('/products', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT p.*, pr.price_egp, pr.discount_percent
      FROM products p
      LEFT JOIN prices pr ON pr.product_id = p.id AND pr.is_current = true
      WHERE p.is_active = true
      ORDER BY p.category, pr.price_egp
    `);
    res.json({ success: true, products: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================
// ROUTE: GET /api/stats
// Analytics stats for dashboard
// ============================================

router.get('/stats', async (req, res) => {
  try {
    if (!db.isAvailable()) {
      // Return demo data when DB is unavailable
      return res.json({
        summary: { total_conversations: 0, today: 0, this_week: 0, escalation_rate: '0%', avg_confidence: 'N/A' },
        top_intents: [],
        by_agent: {},
        by_channel: { chat: 0, whatsapp: 0, voice: 0 },
        db_status: 'offline'
      });
    }

    // Total conversations
    const totalResult = await db.query('SELECT COUNT(*) as total FROM conversations');
    const total = parseInt(totalResult.rows[0]?.total || 0);

    // Today
    const todayResult = await db.query(
      "SELECT COUNT(*) as today FROM conversations WHERE started_at >= CURRENT_DATE"
    );
    const today = parseInt(todayResult.rows[0]?.today || 0);

    // This week
    const weekResult = await db.query(
      "SELECT COUNT(*) as week FROM conversations WHERE started_at >= CURRENT_DATE - INTERVAL '7 days'"
    );
    const thisWeek = parseInt(weekResult.rows[0]?.week || 0);

    // Escalation rate
    const escalatedResult = await db.query(
      'SELECT COUNT(*) as escalated FROM conversations WHERE escalated = true'
    );
    const escalated = parseInt(escalatedResult.rows[0]?.escalated || 0);
    const escalationRate = total > 0 ? ((escalated / total) * 100).toFixed(1) + '%' : '0%';

    // Avg confidence
    const confidenceResult = await db.query(
      'SELECT AVG(confidence_score) as avg_conf FROM conversation_messages WHERE confidence_score IS NOT NULL'
    );
    const avgConf = confidenceResult.rows[0]?.avg_conf
      ? (parseFloat(confidenceResult.rows[0].avg_conf) * 100).toFixed(1) + '%'
      : 'N/A';

    // Top intents
    const intentsResult = await db.query(
      `SELECT intent_detected as intent, COUNT(*) as count
       FROM conversation_messages
       WHERE intent_detected IS NOT NULL AND sender_type = 'customer'
       GROUP BY intent_detected
       ORDER BY count DESC LIMIT 5`
    );
    const topIntents = intentsResult.rows.map(r => {
      const cnt = parseInt(r.count);
      return { intent: r.intent, count: cnt, percentage: total > 0 ? ((cnt / total) * 100).toFixed(1) : '0' };
    });

    // By agent
    const agentResult = await db.query(
      `SELECT agent_name, COUNT(*) as count
       FROM agents_log
       GROUP BY agent_name
       ORDER BY count DESC`
    );
    const byAgent = {};
    agentResult.rows.forEach(r => { byAgent[r.agent_name] = parseInt(r.count); });

    // By channel
    const channelResult = await db.query(
      `SELECT channel, COUNT(*) as count
       FROM conversations
       GROUP BY channel`
    );
    const byChannel = { chat: 0, whatsapp: 0, voice: 0 };
    channelResult.rows.forEach(r => { byChannel[r.channel] = parseInt(r.count); });

    // Recent activity (last 10 conversations with agent context)
    const activityResult = await db.query(
      `SELECT al.agent_name, al.intent_received, al.input_text, al.created_at, al.escalated,
              c.channel, c.language
       FROM agents_log al
       LEFT JOIN conversations c ON c.id = al.conversation_id
       ORDER BY al.created_at DESC LIMIT 10`
    );
    const recentActivity = activityResult.rows.map(r => ({
      agent: r.agent_name,
      intent: r.intent_received,
      channel: r.channel || 'chat',
      language: r.language || 'ar',
      escalated: r.escalated || false,
      message_preview: r.input_text ? (r.input_text.length > 50 ? r.input_text.substring(0, 50) + '...' : r.input_text) : '',
      time: r.created_at
    }));

    // Lead stats
    const leadsTotal = await db.query('SELECT COUNT(*) as total FROM leads');
    const leadsToday = await db.query("SELECT COUNT(*) as today FROM leads WHERE created_at >= CURRENT_DATE");
    const leadsByLevel = await db.query(
      "SELECT interest_level, COUNT(*) as count FROM leads WHERE interest_level IS NOT NULL GROUP BY interest_level"
    );
    const leadsInterest = {};
    leadsByLevel.rows.forEach(r => { leadsInterest[r.interest_level] = parseInt(r.count); });

    return res.json({
      summary: {
        total_conversations: total,
        today: today,
        this_week: thisWeek,
        escalation_rate: escalationRate,
        avg_confidence: avgConf
      },
      top_intents: topIntents,
      by_agent: byAgent,
      by_channel: byChannel,
      recent_activity: recentActivity,
      leads: {
        total: parseInt(leadsTotal.rows[0]?.total || 0),
        today: parseInt(leadsToday.rows[0]?.today || 0),
        by_interest_level: leadsInterest
      },
      db_status: 'online'
    });

  } catch (error) {
    console.error('[Stats] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================
// ROUTES: /api/leads — CRM Lead Management
// ============================================

// POST /api/leads — Create a new lead
router.post('/leads', async (req, res) => {
  try {
    const { customer_name, customer_phone, customer_email, interested_product_id, interest_level, notes, source, conversation_id } = req.body;

    if (!customer_phone) {
      return res.status(400).json({ success: false, error: 'customer_phone is required' });
    }

    // Deduplicate: check if lead with same phone exists and is still 'new'
    if (db.isAvailable()) {
      const existing = await db.query(
        "SELECT id FROM leads WHERE customer_phone = $1 AND status = 'new' LIMIT 1",
        [customer_phone]
      );
      if (existing.rows.length > 0) {
        return res.json({ success: true, lead_id: existing.rows[0].id, message: 'Lead already exists', duplicate: true });
      }
    }

    if (!db.isAvailable()) {
      return res.status(503).json({ success: false, error: 'Database unavailable' });
    }

    const result = await db.query(
      `INSERT INTO leads (conversation_id, customer_name, customer_phone, customer_email, interested_product_id, interest_level, notes, source, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'new')
       RETURNING id, created_at`,
      [conversation_id || null, customer_name || null, customer_phone, customer_email || null, interested_product_id || null, interest_level || 'warm', notes || null, source || 'chat']
    );

    return res.json({ success: true, lead_id: result.rows[0].id, created_at: result.rows[0].created_at });
  } catch (error) {
    console.error('[Leads] Create error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/leads — List leads with optional filters
router.get('/leads', async (req, res) => {
  try {
    if (!db.isAvailable()) {
      return res.json({ success: true, leads: [], db_status: 'offline' });
    }

    const { status, interest_level, limit: lim } = req.query;
    let query = `
      SELECT l.*, p.name_en as product_name_en, p.name_ar as product_name_ar
      FROM leads l
      LEFT JOIN products p ON p.id = l.interested_product_id
      WHERE 1=1
    `;
    const params = [];
    let paramIdx = 1;

    if (status) {
      query += ` AND l.status = $${paramIdx++}`;
      params.push(status);
    }
    if (interest_level) {
      query += ` AND l.interest_level = $${paramIdx++}`;
      params.push(interest_level);
    }

    query += ` ORDER BY l.created_at DESC LIMIT $${paramIdx}`;
    params.push(parseInt(lim) || 50);

    const result = await db.query(query, params);
    return res.json({ success: true, leads: result.rows, count: result.rows.length });
  } catch (error) {
    console.error('[Leads] List error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/leads/:id — Get single lead with details
router.get('/leads/:id', async (req, res) => {
  try {
    if (!db.isAvailable()) {
      return res.status(503).json({ success: false, error: 'Database unavailable' });
    }

    const result = await db.query(
      `SELECT l.*, p.name_en as product_name_en, p.name_ar as product_name_ar
       FROM leads l
       LEFT JOIN products p ON p.id = l.interested_product_id
       WHERE l.id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Lead not found' });
    }

    // Get conversation messages if linked
    let messages = [];
    if (result.rows[0].conversation_id) {
      const msgResult = await db.query(
        `SELECT sender_type, message_text, intent_detected, created_at
         FROM conversation_messages
         WHERE conversation_id = $1
         ORDER BY created_at ASC`,
        [result.rows[0].conversation_id]
      );
      messages = msgResult.rows;
    }

    return res.json({ success: true, lead: result.rows[0], conversation_messages: messages });
  } catch (error) {
    console.error('[Leads] Get error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// PATCH /api/leads/:id — Update lead status/notes/follow_up
router.patch('/leads/:id', async (req, res) => {
  try {
    if (!db.isAvailable()) {
      return res.status(503).json({ success: false, error: 'Database unavailable' });
    }

    const { status, interest_level, notes, follow_up_date, customer_name, customer_phone, customer_email } = req.body;
    const updates = [];
    const params = [];
    let paramIdx = 1;

    if (status) { updates.push(`status = $${paramIdx++}`); params.push(status); }
    if (interest_level) { updates.push(`interest_level = $${paramIdx++}`); params.push(interest_level); }
    if (notes) { updates.push(`notes = $${paramIdx++}`); params.push(notes); }
    if (follow_up_date) { updates.push(`follow_up_date = $${paramIdx++}`); params.push(follow_up_date); }
    if (customer_name) { updates.push(`customer_name = $${paramIdx++}`); params.push(customer_name); }
    if (customer_phone) { updates.push(`customer_phone = $${paramIdx++}`); params.push(customer_phone); }
    if (customer_email) { updates.push(`customer_email = $${paramIdx++}`); params.push(customer_email); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, error: 'No fields to update' });
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    const query = `UPDATE leads SET ${updates.join(', ')} WHERE id = $${paramIdx} RETURNING *`;
    params.push(req.params.id);

    const result = await db.query(query, params);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Lead not found' });
    }

    return res.json({ success: true, lead: result.rows[0] });
  } catch (error) {
    console.error('[Leads] Update error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
