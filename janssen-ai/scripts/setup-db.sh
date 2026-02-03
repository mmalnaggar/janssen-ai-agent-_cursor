#!/usr/bin/env bash
# ============================================
# Janssen AI - Database Setup Script
# Creates the database, runs schema, seeds data
# ============================================
# Usage:
#   ./scripts/setup-db.sh                    # Uses defaults
#   DB_USER=myuser DB_NAME=mydb ./scripts/setup-db.sh
# ============================================

set -e

DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-janssen_ai}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_DIR="$PROJECT_DIR/backend/db"

echo "=================================="
echo "  Janssen AI - Database Setup"
echo "=================================="
echo ""
echo "Config:"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  User: $DB_USER"
echo "  Database: $DB_NAME"
echo ""

# Step 1: Create database (ignore if exists)
echo "[1/3] Creating database '$DB_NAME'..."
createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" 2>/dev/null && echo "  Database created." || echo "  Database already exists (OK)."

# Step 2: Run schema
echo "[2/3] Running schema..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$DB_DIR/schema.sql" 2>&1 | grep -v "already exists" || true
echo "  Schema applied."

# Step 3: Seed data
echo "[3/3] Seeding data..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$DB_DIR/seed.sql" 2>&1 | grep -v "already exists" || true
echo "  Seed data inserted."

echo ""
echo "=================================="
echo "  Database setup complete!"
echo "=================================="
echo ""
echo "Verify with:"
echo "  psql -U $DB_USER -d $DB_NAME -c 'SELECT name_en, price_egp FROM products p JOIN prices pr ON pr.product_id = p.id WHERE pr.is_current = true;'"
echo ""
