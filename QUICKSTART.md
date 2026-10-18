# QUICKSTART — do zero ao app instalado em ~5 minutos de leitura

> Este é o **único guia** que você precisa. Detalhes técnicos: `README.md`.
> Guia antigo detalhado: `docs/INSTALL.md`.

---

## Passo 1 — GitHub: repositório (1 min)

1. Baixe o ZIP do projeto (link que o assistente te enviou) e descompacte no PC.
2. No GitHub: **+ → New repository** → nome `whatsapp-business-hub` → **Create repository**.
3. Na página do repo vazio, clique em **"uploading an existing file"** → arraste **todo o conteúdo** da pasta descompactada → **Commit changes**.
   (O `.gitignore` já protege `.env`, keystores e builds.)
4. Aba **Actions**: se pedir, clique em **"I understand my workflows, go ahead and enable them"**.

> **Sobre os 3 Secrets** (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`):
> você **não precisa deles agora**. Sem keystore, o primeiro build gera um APK
> de **teste (debug)** — instala e funciona no seu celular normalmente.
> Os Secrets só entram em cena quando você quiser a versão final assinada
> (para publicar na Play Store ou distribuir): aí rode o `generate_keystore.sh`
> uma vez e cadastre os 3 em **Settings → Secrets and variables → Actions**.

## Passo 2 — Servidor de webhooks (2 min)

O app **não recebe mensagens sem o servidor**. Opções:

**A) No seu PC (teste):**
```
./setup_env.sh        # responde 4 perguntas e cria server/.env
./quick_start.sh      # sobe o servidor
ngrok http 3000       # expõe na internet (anote a URL https)
```
**B) Nuvem grátis (uso real):** suba a pasta `server/` no **Render** ou **Railway**
(botão "New Web Service", comando `npm start`), configure as mesmas variáveis
do `.env` no painel deles.

Depois, na Meta (**developers.facebook.com → seu app → WhatsApp → Configuration → Webhook**):
- **Callback URL:** `https://SUA-URL/webhook`
- **Verify Token:** o mesmo do `.env`
- Assine o campo **messages**. A Meta testa na hora — o servidor precisa estar no ar.

## Passo 3 — Baixar o APK (1 min)

No repositório: **Actions → CI/CD — One-Click → último build verde → Artifacts → `app-release`**.
O download vem como ZIP — descompacte no PC para obter o `.apk`.
(Em releases publicadas, o APK também vai anexado na página da release, com changelog.)

⏱️ O primeiro build demora ~10–20 min (o GitHub baixa as ferramentas do zero). É normal.

## Passo 4 — Instalar no celular (1 min)

1. Envie o APK ao celular (USB, Drive, e-mail).
2. Toque no arquivo → permita "instalar de fontes desconhecidas" (só dessa vez).
3. Abra o app → onboarding de 3 telas → **"Testar conexão"** envia uma mensagem de verdade e confirma o pipeline.

---

## Resumo dos segredos

| Onde | Segredo | Para quê |
|---|---|---|
| GitHub Secrets (build) | `KEYSTORE_BASE64` | Assinar o APK |
| GitHub Secrets (build) | `KEYSTORE_PASSWORD` | Assinar o APK |
| GitHub Secrets (build) | `KEY_ALIAS` | Assinar o APK |
| `server/.env` (runtime) | `WA_TOKEN`, `VERIFY_TOKEN`, `FIREBASE_SA` | Operação do webhook |

**Primeiro build:** acontece sozinho no primeiro `git push` na `main` — acompanhe em Actions.
