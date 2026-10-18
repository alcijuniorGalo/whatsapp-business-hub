#!/usr/bin/env bash
# quick_start.sh — servidor do Business Hub em 1 comando.
# Uso:  ./quick_start.sh
# Depois: configure o webhook na Meta com a URL pública (ver INSTALL.md).
set -euo pipefail
cd "$(dirname "$0")/server"

chmod +x setup_server.sh 2>/dev/null || true

if command -v docker >/dev/null && [ -f Dockerfile ]; then
  echo "Docker detectado: subindo via docker compose..."
  if [ ! -f .env ]; then cp .env.example .env; echo "Edite server/.env e rode de novo."; exit 0; fi
  docker compose up --build
else
  echo "Sem Docker: usando setup local..."
  ./setup_server.sh
fi
