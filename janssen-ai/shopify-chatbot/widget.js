/**
 * Janssen AI - Shopify Chatbot Widget
 * Production-ready integration with n8n AI backend
 * 
 * Features:
 * - Arabic (RTL) and English (LTR) support
 * - Text messages, product cards, and handover
 * - Real-time communication with n8n webhook
 * 
 * @version 2.0.0
 */

(function() {
  'use strict';
  
  // Prevent multiple loads
  if (window.JanssenChatbotLoaded) return;
  window.JanssenChatbotLoaded = true;
  
  // Don't show on checkout pages
  if (window.location.pathname.includes('/checkout')) return;

  // ============================================
  // CONFIGURATION
  // ============================================
  
  const CONFIG = {
    position: 'bottom-right',
    defaultLanguage: 'ar',
    brandName: 'Janssen',
    brandColor: '#C41E3A',
    
    strings: {
      ar: {
        title: 'يانسن',
        subtitle: 'مساعدك الذكي',
        placeholder: 'اكتب رسالتك هنا...',
        sendButton: 'إرسال',
        welcomeMessage: 'أهلاً بيك في يانسن! 👋 إزاي أقدر أساعدك النهاردة؟',
        typingIndicator: 'جاري الكتابة...',
        productViewButton: 'عرض المنتج',
        productAddToCart: 'أضف للسلة',
        poweredBy: 'مدعوم بالذكاء الاصطناعي',
        errorMessage: 'حصلت مشكلة، حاول تاني لو سمحت',
        inputDisabled: 'تم تحويلك لخدمة العملاء'
      },
      en: {
        title: 'Janssen',
        subtitle: 'AI Assistant',
        placeholder: 'Type your message...',
        sendButton: 'Send',
        welcomeMessage: 'Welcome to Janssen! 👋 How can I help you today?',
        typingIndicator: 'Typing...',
        productViewButton: 'View Product',
        productAddToCart: 'Add to Cart',
        poweredBy: 'Powered by AI',
        errorMessage: 'Something went wrong, please try again',
        inputDisabled: 'Connected to customer service'
      }
    }
  };

  // ============================================
  // BACKEND CONFIGURATION
  // n8n webhook endpoint
  // ============================================
  
  const BACKEND = {
    // Replace with your actual n8n webhook URL
    endpoint: window.JANSSEN_WEBHOOK_URL || 'http://localhost:5678/webhook/janssen-ai-incoming',
    timeout: 15000
  };

  // ============================================
  // STATE MANAGEMENT
  // ============================================
  
  const state = {
    isOpen: false,
    language: CONFIG.defaultLanguage,
    messages: [],
    isTyping: false,
    sessionId: null,
    isLocked: false  // True after escalation
  };

  // ============================================
  // DOM ELEMENT REFERENCES
  // ============================================
  
  let elements = {
    container: null,
    toggleButton: null,
    chatWindow: null,
    messagesContainer: null,
    inputField: null,
    sendButton: null,
    languageToggle: null,
    closeButton: null,
    typingIndicator: null
  };

  // ============================================
  // INITIALIZATION
  // ============================================
  
  function init() {
    state.sessionId = generateSessionId();
    createWidgetDOM();
    attachEventListeners();
    applyLanguageDirection();
    addWelcomeMessage();
    console.log('[JanssenChat] Widget initialized', { sessionId: state.sessionId });
  }

  function generateSessionId() {
    return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  // ============================================
  // DOM CREATION
  // ============================================
  
  function createWidgetDOM() {
    elements.container = document.createElement('div');
    elements.container.id = 'janssen-chatbot-widget';
    elements.container.className = 'janssen-chat-container';
    elements.container.setAttribute('data-position', CONFIG.position);
    
    elements.container.innerHTML = `
      <button class="janssen-chat-toggle" aria-label="Open chat">
        <span class="toggle-icon">💬</span>
        <span class="unread-badge" style="display: none;">1</span>
      </button>
      
      <div class="janssen-chat-window" aria-hidden="true">
        <div class="janssen-chat-header">
          <div class="header-info">
            <div class="header-avatar">J</div>
            <div class="header-text">
              <span class="header-title">${CONFIG.strings[state.language].title}</span>
              <span class="header-subtitle">${CONFIG.strings[state.language].subtitle}</span>
            </div>
          </div>
          <div class="header-actions">
            <button class="language-toggle" aria-label="Toggle language">
              <span class="lang-indicator">EN</span>
            </button>
            <button class="close-button" aria-label="Close chat">✕</button>
          </div>
        </div>
        
        <div class="janssen-chat-messages"></div>
        
        <div class="janssen-typing-indicator" style="display: none;">
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
          <span class="typing-text"></span>
        </div>
        
        <div class="janssen-chat-input">
          <input type="text" class="message-input" autocomplete="off" />
          <button class="send-button" aria-label="Send message">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
        
        <div class="janssen-chat-footer">
          <span class="powered-by"></span>
        </div>
      </div>
    `;
    
    document.body.appendChild(elements.container);
    cacheElementReferences();
    updateTextContent();
  }

  function cacheElementReferences() {
    elements.toggleButton = elements.container.querySelector('.janssen-chat-toggle');
    elements.chatWindow = elements.container.querySelector('.janssen-chat-window');
    elements.messagesContainer = elements.container.querySelector('.janssen-chat-messages');
    elements.inputField = elements.container.querySelector('.message-input');
    elements.sendButton = elements.container.querySelector('.send-button');
    elements.languageToggle = elements.container.querySelector('.language-toggle');
    elements.closeButton = elements.container.querySelector('.close-button');
    elements.typingIndicator = elements.container.querySelector('.janssen-typing-indicator');
  }

  // ============================================
  // EVENT HANDLERS
  // ============================================
  
  function attachEventListeners() {
    elements.toggleButton.addEventListener('click', toggleChat);
    elements.closeButton.addEventListener('click', closeChat);
    elements.sendButton.addEventListener('click', handleSendClick);
    elements.inputField.addEventListener('keypress', function(e) {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSendClick();
      }
    });
    elements.languageToggle.addEventListener('click', toggleLanguage);
  }

  function toggleChat() {
    state.isOpen = !state.isOpen;
    elements.container.classList.toggle('is-open', state.isOpen);
    elements.chatWindow.setAttribute('aria-hidden', !state.isOpen);
    
    if (state.isOpen) {
      elements.container.querySelector('.unread-badge').style.display = 'none';
      setTimeout(() => elements.inputField.focus(), 300);
      scrollToBottom();
    }
  }

  function closeChat() {
    state.isOpen = false;
    elements.container.classList.remove('is-open');
    elements.chatWindow.setAttribute('aria-hidden', 'true');
  }

  function toggleLanguage() {
    state.language = state.language === 'ar' ? 'en' : 'ar';
    applyLanguageDirection();
    updateTextContent();
  }

  function applyLanguageDirection() {
    const direction = state.language === 'ar' ? 'rtl' : 'ltr';
    elements.container.setAttribute('dir', direction);
    elements.container.setAttribute('data-lang', state.language);
    elements.languageToggle.querySelector('.lang-indicator').textContent = 
      state.language === 'ar' ? 'EN' : 'عربي';
  }

  function updateTextContent() {
    const strings = CONFIG.strings[state.language];
    elements.container.querySelector('.header-title').textContent = strings.title;
    elements.container.querySelector('.header-subtitle').textContent = strings.subtitle;
    elements.inputField.placeholder = state.isLocked ? strings.inputDisabled : strings.placeholder;
    elements.container.querySelector('.typing-text').textContent = strings.typingIndicator;
    elements.container.querySelector('.powered-by').textContent = strings.poweredBy;
  }

  // ============================================
  // MESSAGE HANDLING - PRODUCTION READY
  // ============================================
  
  function handleSendClick() {
    const text = elements.inputField.value.trim();
    if (!text || state.isLocked) return;
    
    elements.inputField.value = '';
    sendMessage(text);
  }

  /**
   * Send message to n8n backend
   * NO LOGIC HERE - just send and render
   * @param {string} text - User message
   */
  async function sendMessage(text) {
    // Add user message to chat
    addMessage(text, 'user');

    // Build payload for n8n
    const payload = {
      session_id: state.sessionId,
      channel: 'chat',
      language: state.language,
      user_message: text,
      metadata: {
        page: window.location.pathname,
        customer_id: window.JANSSEN_CUSTOMER_ID || null
      }
    };

    showTyping();

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), BACKEND.timeout);

      const response = await fetch(BACKEND.endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();
      hideTyping();
      handleBotResponse(data);

    } catch (error) {
      console.error('[JanssenChat] Error:', error);
      hideTyping();
      addMessage(CONFIG.strings[state.language].errorMessage, 'bot');
    }
  }

  /**
   * Handle response from n8n backend
   * Renders based on response_type
   * @param {object} data - Response from n8n
   */
  function handleBotResponse(data) {
    console.log('[JanssenChat] Response:', data);

    switch (data.response_type) {
      case 'text':
        // Simple text message
        addMessage(data.content.text, 'bot');
        break;

      case 'product_card':
        // Product card with optional intro text
        if (data.content.text) {
          addMessage(data.content.text, 'bot');
        }
        renderProductCard(data.content.product);
        break;

      case 'handover':
        // Human escalation - TERMINAL
        addMessage(data.content.handover_message || data.content.text, 'bot');
        lockInput();
        break;

      default:
        // Fallback for unknown types
        if (data.content && data.content.text) {
          addMessage(data.content.text, 'bot');
        } else {
          addMessage(CONFIG.strings[state.language].welcomeMessage, 'bot');
        }
    }
  }

  /**
   * Render a product card in chat
   * @param {object} product - Product data from n8n
   */
  function renderProductCard(product) {
    if (!product) return;

    const strings = CONFIG.strings[state.language];
    const imageHtml = product.image_url 
      ? `<img src="${escapeHtml(product.image_url)}" alt="${escapeHtml(product.name)}" class="product-image" />`
      : `<div class="product-image-placeholder">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
            <circle cx="8.5" cy="8.5" r="1.5"></circle>
            <polyline points="21 15 16 10 5 21"></polyline>
          </svg>
        </div>`;

    const cardHtml = `
      <div class="message-wrapper message-bot">
        <div class="janssen-product-card">
          ${imageHtml}
          <div class="product-info">
            <h4 class="product-name">${escapeHtml(product.name)}</h4>
            ${product.description ? `<p class="product-description">${escapeHtml(product.description)}</p>` : ''}
            ${product.warranty ? `<span class="product-warranty">⭐ ${escapeHtml(product.warranty)}</span>` : ''}
            <div class="product-price">${escapeHtml(product.price)}</div>
            <div class="product-actions">
              <button class="product-btn product-btn-primary" onclick="window.location='${escapeHtml(product.url || '#')}'">
                ${strings.productViewButton}
              </button>
            </div>
          </div>
        </div>
      </div>
    `;

    elements.messagesContainer.insertAdjacentHTML('beforeend', cardHtml);
    scrollToBottom();

    // Track in state
    state.messages.push({
      type: 'product_card',
      content: product,
      sender: 'bot',
      timestamp: new Date().toISOString()
    });
  }

  /**
   * Lock input after escalation
   * NO MORE AI MESSAGES - human takes over
   */
  function lockInput() {
    state.isLocked = true;
    elements.inputField.disabled = true;
    elements.inputField.placeholder = CONFIG.strings[state.language].inputDisabled;
    elements.sendButton.disabled = true;
    elements.inputField.classList.add('is-locked');
    elements.sendButton.classList.add('is-locked');
    
    console.log('[JanssenChat] Input locked - escalated to human');
  }

  // ============================================
  // MESSAGE DISPLAY
  // ============================================

  function addWelcomeMessage() {
    addMessage(CONFIG.strings[state.language].welcomeMessage, 'bot');
  }

  /**
   * Add a message to the chat
   * @param {string} text - Message text
   * @param {string} sender - 'user' or 'bot'
   */
  function addMessage(text, sender) {
    const timestamp = new Date().toISOString();
    
    state.messages.push({
      type: 'text',
      content: text,
      sender: sender,
      timestamp: timestamp
    });

    const wrapper = document.createElement('div');
    wrapper.className = `message-wrapper message-${sender}`;
    wrapper.innerHTML = `
      <div class="message-bubble">
        <div class="message-text">${escapeHtml(text)}</div>
        <div class="message-time">${formatTime(timestamp)}</div>
      </div>
    `;

    elements.messagesContainer.appendChild(wrapper);
    scrollToBottom();
  }

  // ============================================
  // TYPING INDICATOR
  // ============================================
  
  function showTyping() {
    state.isTyping = true;
    elements.typingIndicator.style.display = 'flex';
    scrollToBottom();
  }

  function hideTyping() {
    state.isTyping = false;
    elements.typingIndicator.style.display = 'none';
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================
  
  function scrollToBottom() {
    setTimeout(() => {
      elements.messagesContainer.scrollTop = elements.messagesContainer.scrollHeight;
    }, 50);
  }

  function formatTime(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleTimeString(state.language === 'ar' ? 'ar-EG' : 'en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // ============================================
  // PUBLIC API
  // ============================================
  
  window.JanssenChat = {
    open: function() {
      state.isOpen = true;
      elements.container.classList.add('is-open');
      elements.chatWindow.setAttribute('aria-hidden', 'false');
      setTimeout(() => elements.inputField.focus(), 300);
    },
    
    close: closeChat,
    toggle: toggleChat,
    
    setLanguage: function(lang) {
      if (lang === 'ar' || lang === 'en') {
        state.language = lang;
        applyLanguageDirection();
        updateTextContent();
      }
    },
    
    getState: function() {
      return { ...state };
    },
    
    sendMessage: function(text) {
      if (!state.isLocked && text) {
        sendMessage(text);
      }
    },
    
    isLocked: function() {
      return state.isLocked;
    }
  };

  // ============================================
  // INITIALIZATION
  // ============================================
  
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
