/**
 * Webhook server (Node.js) — ponte entre a Meta e o app.
 *
 * Responsabilidades:
 *  1. Verificar o webhook (GET /webhook — handshake da Meta).
 *  2. Receber mensagens (POST /webhook) e repassar ao app via FCM.
 *  3. Executar as regras de automação (< 2s), respondendo pela Cloud API.
 *
 * Variáveis de ambiente (nunca commite):
 *   VERIFY_TOKEN   — string que você cadastrou no painel da Meta
 *   WA_TOKEN       — token da Cloud API (System User, longa duração)
 *   GRAPH_VERSION  — ex: v21.0
 *   FIREBASE_SA    — caminho do serviceAccountKey.json (p/ FCM)
 *
 * Deploy sugerido: Railway, Fly.io ou Cloud Run (precisa de URL pública HTTPS).
 */
const express = require('express');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const VERIFY_TOKEN = process.env.VERIFY_TOKEN;
const WA_TOKEN = process.env.WA_TOKEN;
const GRAPH_VERSION = process.env.GRAPH_VERSION || 'v21.0';
const EVENTS_LOG = path.join(__dirname, 'events.jsonl');

admin.initializeApp({
  credential: admin.credential.cert(require(process.env.FIREBASE_SA)),
});

const app = express();
app.use(express.json());

/** Log append-only de eventos (fonte para StateSyncService do app). */
function appendEvent(event) {
  const line = JSON.stringify({ ts: new Date().toISOString(), ...event });
  fs.appendFileSync(EVENTS_LOG, line + '\n');
}

/** GET /events/since?since=ISO — eventos após o timestamp (reconciliação). */
app.get('/events/since', (req, res) => {
  const since = req.query.since || '';
  let events = [];
  try {
    const raw = fs.readFileSync(EVENTS_LOG, 'utf8').trim().split('\n');
    for (const line of raw) {
      if (!line.trim()) continue;
      const e = JSON.parse(line);
      if (!since || e.ts > since) events.push(e);
    }
  } catch (_) {
    // log ainda não existe: lista vazia
  }
  // Limita para não estourar memória em bases grandes.
  res.json({ events: events.slice(-500) });
});

/**
 * POST /token/refresh — stub honesto.
 * Renovar long-lived token exige client_secret: implemente aqui com
 * GET graph.facebook.com/oauth/access_token?grant_type=fb_exchange_token...
 * e retorne { access_token, expires_in }.
 */
app.post('/token/refresh', (req, res) => {
  res.status(501).json({
    error: 'não implementado: configure CLIENT_ID/CLIENT_SECRET e troque o token via fb_exchange_token',
  });
});

// Regras de automação (espelho do app; em produção, leia do banco).
// [{ keyword, replyTemplate, phoneNumberId | null }]
let automationRules = [];
app.post('/rules', (req, res) => {
  automationRules = req.body.rules || [];
  res.json({ ok: true, count: automationRules.length });
});

// 1) Handshake de verificação da Meta
app.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];
  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    return res.status(200).send(challenge);
  }
  return res.sendStatus(403);
});

// 2) Eventos (mensagens, status)
app.post('/webhook', async (req, res) => {
  res.sendStatus(200); // responda rápido; processe em seguida
  try {
    for (const entry of req.body.entry || []) {
      for (const change of entry.changes || []) {
        const value = change.value || {};
        const phoneNumberId = value.metadata?.phone_number_id;
        for (const msg of value.messages || []) {
          await handleInbound({ phoneNumberId, msg, contacts: value.contacts });
        }
      }
    }
  } catch (e) {
    console.error('webhook error:', e);
  }
});

async function handleInbound({ phoneNumberId, msg, contacts }) {
  const chatId = msg.from;
  const contactName =
    (contacts || []).find((c) => c.wa_id === chatId)?.profile?.name || chatId;
  const body = msg.text?.body || `[${msg.type}]`;

  // Loga o evento para reconciliação (StateSyncService do app).
  appendEvent({
    kind: 'inbound',
    wamid: msg.id,
    phoneNumberId: String(phoneNumberId),
    chatId: String(chatId),
    contactName: String(contactName),
    msgType: String(msg.type || 'text'),
    body: String(body).slice(0, 2000),
  });

  // 3) Automação: primeira regra com keyword contida na mensagem
  const rule = automationRules.find(
    (r) =>
      r.enabled !== false &&
      (!r.phoneNumberId || r.phoneNumberId === phoneNumberId) &&
      body.toLowerCase().includes((r.keyword || '').toLowerCase())
  );
  if (rule) {
    const reply = rule.replyTemplate
      .replaceAll('{{nome}}', contactName)
      .replaceAll('{{numero}}', chatId);
    await sendText(phoneNumberId, chatId, reply);
  }

  // 4) Push para o app via FCM (data-only; o app persiste no Hive)
  await admin.messaging().send({
    topic: `wa_${phoneNumberId}`,
    data: {
      type: 'wa_inbound',
      wamid: msg.id,
      phoneNumberId: String(phoneNumberId),
      chatId: String(chatId),
      contactName: String(contactName),
      msgType: String(msg.type || 'text'),
      body: String(body).slice(0, 500),
    },
  });
}

async function sendText(phoneNumberId, to, body) {
  const r = await fetch(
    `https://graph.facebook.com/${GRAPH_VERSION}/${phoneNumberId}/messages`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${WA_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to,
        type: 'text',
        text: { body },
      }),
    }
  );
  if (!r.ok) console.error('send failed:', await r.text());
}

const PORT = process.env.PORT || 3000;

// Permite importar sem subir o servidor (testes).
if (require.main === module) {
  app.listen(PORT, () => console.log(`webhook on :${PORT}`));
}

module.exports = app;
