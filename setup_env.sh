#!/usr/bin/env bash
# setup_env.sh — assistente de configuração (.env do servidor).
#
# Pergunta as credenciais, valida o formato básico e grava server/.env.
# Os Secrets do GitHub (build do APK) NÃO são configurados aqui: eles vão
# pela interface web do repositório (Settings > Secrets) ou via `gh` CLI.
set -euo pipefail
cd "$(dirname "$0")/server"

echo "=== Business Hub — configuração do servidor ==="

read -rp "1) Meta Access Token (começa com 'EA'): " WA_TOKEN
if [[ ! "$WA_TOKEN" =~ ^EA[0-9A-Za-z]+$ ]]; then
  echo "   ⚠️  Não parece um token da Meta (esperado algo como EAAB...). Continuando mesmo assim."
fi

read -rp "2) Phone Number ID (só números): " PHONE_ID
if [[ ! "$PHONE_ID" =~ ^[0-9]+$ ]]; then
  echo "   ⚠️  Phone Number ID costuma ser só números. Continuando mesmo assim."
fi

read -rp "3) Caminho do sa.json do Firebase [./sa.json]: " SA
SA=${SA:-./sa.json}

read -rp "4) Frase secreta do webhook (VERIFY_TOKEN) [gerei uma]: " VERIFY
if [ -z "$VERIFY" ]; then
  VERIFY=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  echo "   Gerada: $VERIFY"
fi

cat > .env <<EOF
# Gerado por setup_env.sh em $(date -Iseconds)
VERIFY_TOKEN=$VERIFY
WA_TOKEN=$WA_TOKEN
GRAPH_VERSION=v21.0
FIREBASE_SA=$SA
PORT=3000
# PHONE_NUMBER_ID principal (referência p/ testes): $PHONE_ID
EOF

echo
echo ".env criado em server/.env ✅"
echo
echo "Próximos passos:"
echo "  1. Coloque o sa.json do Firebase em server/ (se ainda não está)."
echo "  2. Rode ./quick_start.sh para subir o servidor."
echo "  3. Secrets do GitHub (APK): configure na interface web —"
echo "     Settings > Secrets and variables > Actions > New repository secret:"
echo "     KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS"
echo "     (ou via CLI: gh secret set KEYSTORE_BASE64 < <(base64 -w0 ~/whatsapp_hub.keystore))"
