#!/usr/bin/env bash
# generate_keystore.sh — gera o keystore de produção UMA vez.
#
# Rode localmente (precisa de Java/keytool instalado):
#   ./generate_keystore.sh
#
# Ao final, o script mostra o Base64 pronto para colar no Secret
# KEYSTORE_BASE64 do GitHub.
#
# ⚠️  AVISO DE SEGURANÇA: guarde a senha do keystore em um local seguro
# (gerenciador de senhas). Se você perdê-la, NÃO poderá mais atualizar o
# app na Play Store nem gerar novos builds assinados com a mesma identidade.
set -euo pipefail

if ! command -v keytool >/dev/null; then
  echo "ERRO: keytool não encontrado. Instale o Java JDK 17+."
  exit 1
fi

echo "=== Gerador de keystore de produção ==="
read -rp "Alias da chave [hub-alias]: " ALIAS
ALIAS=${ALIAS:-hub-alias}
read -rsp "Senha do keystore (mín. 6 caracteres): " PASS
echo
if [ ${#PASS} -lt 6 ]; then echo "Senha muito curta."; exit 1; fi
read -rp "Seu nome/organização: " CN

OUT="$HOME/whatsapp_hub.keystore"
if [ -f "$OUT" ]; then
  echo "ERRO: $OUT já existe. Apague manualmente se quiser gerar outro."
  exit 1
fi

keytool -genkey -v \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=$CN"

echo
echo "Keystore gerado em: $OUT"
echo "--- COPIE O BLOCO ABAIXO PARA O SECRET KEYSTORE_BASE64 ---"
base64 -w0 "$OUT" 2>/dev/null || base64 "$OUT" | tr -d '\n'
echo
echo "--- FIM ---"
echo
echo "Configure também os Secrets KEYSTORE_PASSWORD (a senha digitada)"
echo "e KEY_ALIAS ($ALIAS) no GitHub. Detalhes no QUICKSTART.md passo 1."
