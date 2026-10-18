#!/usr/bin/env bash
# setup_server.sh — prepara o webhook server para execução local (sem Docker).
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/4 Instalando dependências Node.js =="
if ! command -v node >/dev/null; then
  echo "ERRO: Node.js não encontrado. Instale em https://nodejs.org (versão 20+)."
  exit 1
fi
npm install --omit=dev --no-audit --no-fund

echo "== 2/4 Arquivo .env =="
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Criado .env a partir do template. EDITE-O com suas credenciais antes de continuar."
  echo "Abra o arquivo server/.env e preencha VERIFY_TOKEN, WA_TOKEN e FIREBASE_SA."
  exit 0
fi

echo "== 3/4 Verificando variáveis =="
missing=0
for v in VERIFY_TOKEN WA_TOKEN FIREBASE_SA; do
  val=$(grep -E "^$v=" .env | cut -d= -f2-)
  if [ -z "$val" ] || [[ "$val" == *aqui* ]] || [[ "$val" == *troque* ]]; then
    echo "  ! $v não preenchido no .env"
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  echo "Preencha o .env e rode novamente."
  exit 1
fi
if [ ! -f "$(grep -E '^FIREBASE_SA=' .env | cut -d= -f2-)" ]; then
  echo "  ! Arquivo da conta de serviço do Firebase não encontrado."
  exit 1
fi

echo "== 4/4 Iniciando servidor =="
echo "Servidor no ar em http://localhost:3000"
echo "Para expor na internet (a Meta exige URL pública HTTPS), em outro terminal rode:"
echo "  ngrok http 3000"
echo "Use a URL https gerada no painel da Meta (Webhook > Callback URL)."
npm start
