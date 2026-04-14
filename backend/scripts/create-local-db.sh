#!/usr/bin/env bash
set -euo pipefail
# Creates the spendly database using a local PostgreSQL (e.g. Homebrew), no Docker.

if ! command -v createdb >/dev/null 2>&1; then
  echo "PostgreSQL tools not found. Install and start PostgreSQL, for example:"
  echo "  brew install postgresql@16"
  echo "  brew services start postgresql@16"
  echo "  echo 'export PATH=\"/opt/homebrew/opt/postgresql@16/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
  exit 1
fi

if createdb spendly 2>/dev/null; then
  echo "Created database: spendly"
else
  echo "Database spendly already exists or could not be created (if it exists, you can ignore this)."
fi

echo ""
echo "Set this in backend/.env (replace USER if needed):"
echo "DATABASE_URL=\"postgresql://$(whoami)@localhost:5432/spendly\""
echo ""
echo "Then from backend/: npx prisma migrate deploy && npm run dev"
