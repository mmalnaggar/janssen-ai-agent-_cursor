#!/usr/bin/env bash
# Janssen AI – quick webhook test (curl)
# Usage: ./scripts/test-webhook.sh [BASE_URL]
# Example: ./scripts/test-webhook.sh https://n8n-2-7fw9.onrender.com

BASE="${1:-https://n8n-2-7fw9.onrender.com}"
URL="${BASE}/webhook/janssen-ai-incoming"

echo "Testing: POST $URL"
echo ""

# Test 1: Arabic price
echo "=== Test 1: Arabic (بكام المرتبة) ==="
curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"بكام المرتبة","channel":"chat","language":"ar"}' | head -c 500
echo ""
echo ""

# Test 2: English
echo "=== Test 2: English (delivery) ==="
curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"How long is delivery to Cairo?","channel":"chat","language":"en"}' | head -c 500
echo ""
echo ""

# Test 3: Handover (complaint)
echo "=== Test 3: Complaint (should return handover) ==="
curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{"user_message":"عايز أشكي","channel":"chat","language":"ar"}' | head -c 500
echo ""

echo "Done. If you see JSON with response_type and content.text, the webhook is working."
