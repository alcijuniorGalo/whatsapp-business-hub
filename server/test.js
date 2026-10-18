/**
 * Testes do webhook server (node:test, sem dependências extras).
 * Roda com: npm test   (também executado no CI)
 *
 * Sobe o servidor de verdade como processo filho, com credenciais falsas
 * (chave RSA gerada em tempo de execução), e valida as rotas HTTP.
 */
const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { generateKeyPairSync } = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const PORT = 3210;
const BASE = `http://localhost:${PORT}`;
let child;

before(async () => {
  // Conta de serviço falsa, mas com chave RSA válida (o firebase-admin
  // valida o PEM no boot; a chave nunca é usada de verdade aqui).
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
  const saPath = path.join(os.tmpdir(), 'bhub-test-sa.json');
  fs.writeFileSync(
    saPath,
    JSON.stringify({
      type: 'service_account',
      project_id: 'test',
      private_key_id: '1',
      private_key: pem,
      client_email: 'test@test.iam.gserviceaccount.com',
      client_id: '1',
      token_uri: 'https://oauth2.googleapis.com/token',
    })
  );

  child = spawn('node', [path.join(__dirname, 'webhook_server.js')], {
    env: {
      ...process.env,
      VERIFY_TOKEN: 'segredo-teste',
      WA_TOKEN: 'fake',
      FIREBASE_SA: saPath,
      PORT: String(PORT),
    },
    stdio: 'pipe',
  });

  // Aguarda o "webhook on :3210" (ou falha em 10s).
  await new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error('servidor não subiu em 10s')),
      10000
    );
    child.stdout.on('data', (d) => {
      if (d.toString().includes(`webhook on :${PORT}`)) {
        clearTimeout(timer);
        resolve();
      }
    });
    child.stderr.on('data', (d) => {
      clearTimeout(timer);
      reject(new Error('stderr: ' + d.toString().slice(0, 300)));
    });
  });
});

after(() => {
  child.kill();
});

describe('webhook server', () => {
  it('GET /webhook rejeita verify token errado (403)', async () => {
    const r = await fetch(
      `${BASE}/webhook?hub.mode=subscribe&hub.verify_token=errado&hub.challenge=123`
    );
    assert.equal(r.status, 403);
  });

  it('GET /webhook devolve o challenge com token certo', async () => {
    const r = await fetch(
      `${BASE}/webhook?hub.mode=subscribe&hub.verify_token=segredo-teste&hub.challenge=ABC`
    );
    assert.equal(r.status, 200);
    assert.equal(await r.text(), 'ABC');
  });

  it('POST /webhook aceita evento e o registra no log', async () => {
    const payload = {
      entry: [
        {
          changes: [
            {
              value: {
                metadata: { phone_number_id: 'pid1' },
                contacts: [
                  { wa_id: '5511999999999', profile: { name: 'Cli' } },
                ],
                messages: [
                  {
                    id: 'w-test-1',
                    from: '5511999999999',
                    type: 'text',
                    text: { body: 'oi' },
                  },
                ],
              },
            },
          ],
        },
      ],
    };
    const r = await fetch(`${BASE}/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    assert.equal(r.status, 200);

    // O evento aparece no /events/since (com delay de escrita).
    await new Promise((res) => setTimeout(res, 500));
    const r2 = await fetch(`${BASE}/events/since`);
    const { events } = await r2.json();
    assert.ok(
      events.some((e) => e.wamid === 'w-test-1'),
      'evento w-test-1 deveria estar no log'
    );
  });

  it('POST /token/refresh retorna 501 (stub documentado)', async () => {
    const r = await fetch(`${BASE}/token/refresh`, { method: 'POST' });
    assert.equal(r.status, 501);
  });
});
