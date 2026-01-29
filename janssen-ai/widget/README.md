# Janssen AI - Chat Widget

A floating chatbot widget for Janssen stores with Arabic (RTL) and English (LTR) support.

## Features

- Floating toggle button with unread badge
- Arabic/English language switching
- RTL/LTR layout support
- Text message bubbles
- Product cards with actions
- Typing indicator
- Mobile responsive

## Files

| File | Description |
|------|-------------|
| `widget.js` | Main widget JavaScript |
| `styles.css` | Widget CSS with RTL support |

## Installation

### For Shopify

1. Upload `widget.js` and `styles.css` to your theme assets
2. Add to `theme.liquid` before `</head>`:

```html
<link rel="stylesheet" href="{{ 'styles.css' | asset_url }}">
```

3. Add before `</body>`:

```html
<script src="{{ 'widget.js' | asset_url }}" defer></script>
```

### For Other Platforms

```html
<link rel="stylesheet" href="path/to/styles.css">
<script src="path/to/widget.js" defer></script>
```

## Configuration

Edit the `CONFIG` object in `widget.js`:

```javascript
const CONFIG = {
  position: 'bottom-right',  // or 'bottom-left'
  defaultLanguage: 'ar',     // or 'en'
  brandName: 'Janssen',
  brandColor: '#C41E3A'
};
```

## Public API

```javascript
// Open/close widget
JanssenChat.open();
JanssenChat.close();
JanssenChat.toggle();

// Change language
JanssenChat.setLanguage('ar');  // or 'en'

// Send message programmatically
JanssenChat.sendMessage('Hello!');

// Get current state
JanssenChat.getState();
```

## Backend Integration

Replace the `BACKEND.endpoint` placeholder with your actual n8n webhook URL:

```javascript
const BACKEND = {
  endpoint: 'https://your-n8n-instance.com/webhook/janssen-ai',
  timeout: 8000
};
```

## Localization

Strings are defined in `CONFIG.strings` for both Arabic and English:

- `title` - Header title
- `subtitle` - Header subtitle
- `placeholder` - Input placeholder
- `welcomeMessage` - Initial bot message
- `typingIndicator` - Typing text
- `productViewButton` - Product card button
- `productAddToCart` - Add to cart button
- `poweredBy` - Footer text

## Notes

- Widget skips checkout pages automatically
- Prevents multiple loads with `window.JanssenChatbotLoaded`
- Uses Egyptian Arabic dialect for natural conversation
