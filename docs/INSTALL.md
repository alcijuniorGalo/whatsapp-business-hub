# Instalação — WhatsApp Business Hub (guia em 3 passos)

Você não precisa saber programar. Siga os 3 passos abaixo, nesta ordem.
Tempo estimado: 30–60 minutos (a maior parte é criar contas).

---

## Passo 1 — Ligar o servidor (o "cérebro" que recebe as mensagens)

O app do celular sozinho não recebe mensagens da Meta: ele precisa de um
servidor na internet. Vamos ligá-lo no seu computador.

1. Instale o **Node.js 20+** em https://nodejs.org (botão verde "LTS").
2. Baixe a pasta do projeto e abra um terminal **dentro da pasta `server/`**.
3. Rode:
   - **Com Docker:** `./quick_start.sh` (na raiz do projeto)
   - **Sem Docker:** `cd server` e depois `./setup_server.sh`
4. Na primeira vez, o script cria um arquivo `.env` e para. Abra o arquivo
   `server/.env` num editor de texto — você vai preenchê-lo no Passo 2.
5. Depois de preenchido, rode o script de novo. Deve aparecer
   `webhook on :3000`.
6. **Expor na internet:** a Meta só fala com endereços públicos. Instale o
   **ngrok** (https://ngrok.com → cadastro grátis), abra outro terminal e rode:
   ```
   ngrok http 3000
   ```
   Ele mostra uma URL tipo `https://abc123.ngrok-free.app`. **Anote essa URL**
   — ela será o "Callback URL" no Passo 2. (O ngrok grátis muda a URL a cada
   reinício; para uso definitivo, publique o servidor num serviço como
   Railway/Render.)

> Sem o servidor no ar, o app funciona só para enviar mensagens — nada chega.

---

## Passo 2 — Configurar a Meta (onde ficam seus números)

1. Acesse https://developers.facebook.com e crie uma conta/conta empresarial.
2. **Criar o app:** Meus Apps → Criar app → tipo **Business** → adicione o
   produto **WhatsApp**.
3. **Pegar o Token:** no menu WhatsApp → **API Setup**. Copie o *Access Token*
   temporário (vale 24h — para produção, crie um "System User" com token de
   60 dias; o app avisa 7 dias antes de vencer).
4. **Pegar o Phone Number ID:** na mesma tela, cada número tem um
   *phone_number_id*. Anote o de cada número (até 10).
5. **Preencher o `.env`:** volte ao arquivo `server/.env` e cole:
   - `VERIFY_TOKEN=` → invente uma frase secreta (ex: `minha-empresa-123`)
   - `WA_TOKEN=` → o token do passo 3
   - `FIREBASE_SA=` → caminho do arquivo da conta de serviço (passo 6)
6. **Firebase (push no celular):** em https://console.firebase.google.com,
   crie um projeto, adicione um app **Android** com o package do app,
   baixe o `google-services.json` (vai para `android/app/` na hora de compilar)
   e em Configurações → Contas de serviço gere a chave JSON → salve como
   `server/sa.json`.
7. **Cadastrar o Webhook:** na Meta, WhatsApp → **Configuration** →
   Webhook → Edit → cole:
   - **Callback URL:** `https://SUA-URL-DO-NGROK/webhook`
   - **Verify Token:** a mesma frase do `VERIFY_TOKEN`
   - Marque os campos **messages**. Salve — a Meta vai testar a URL na hora
     (o servidor precisa estar rodando).
8. **No app:** abra Configurações, cole o token e cadastre os números com os
   `phone_number_id` anotados. Ou use o onboarding guiado na primeira abertura.

---

## Passo 3 — Instalar o app no celular

1. Pegue o arquivo `WhatsAppBusinessHub_v1.0.apk` (pasta `dist/` do pacote).
2. Envie para o celular (USB, Google Drive, e-mail para você mesmo).
3. No celular, toque no arquivo para instalar. O Android vai pedir para
   **"permitir instalar apps de fontes desconhecidas"** — permita só dessa vez.
4. Abra o app e siga o onboarding de 3 telas (token → números → teste).
   O botão **"Testar conexão"** envia uma mensagem de verdade e confirma que
   o pipeline inteiro funciona.

**Glossário rápido:** *APK* = o instalador do Android. *Webhook* = o endereço
que a Meta chama quando chega mensagem. *Token* = a "senha" que autoriza o app
a falar com a Meta. *ngrok* = programa que expõe seu PC na internet.

---

## Se algo der errado

- "Webhook não verificado" → servidor fora do ar ou `VERIFY_TOKEN` diferente
  do cadastrado na Meta.
- "Token inválido (#190)" → token temporário expirou; gere outro.
- Nada chega no celular → confira o `FIREBASE_SA` e se o `google-services.json`
  estava no app na hora de compilar.
- Detalhes técnicos: veja a seção Troubleshooting no `README.md`.
