import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer, validateRequest, cleanWords } from './server.mjs';

const input = { topic: 'Кухня', difficulty: 'Лёгкое', count: 30 };
test('validates user input', () => {
  assert.equal(validateRequest(input).topic, 'Кухня');
  for (const body of [{ ...input, topic: '' }, { ...input, count: 9999 }, { ...input, difficulty: 'unknown' }]) assert.throws(() => validateRequest(body));
});
test('removes duplicates and invalid values', () => {
  assert.deepEqual(cleanWords([' Ёж ', 'еж', '', 7, 'Венчик', 'слово\nпотом', 'http://bad'], 30), ['Ёж', 'Венчик', 'слово потом']);
});
async function withServer(options, run) {
  const server = createServer(options);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await run(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
const post = (base, body = input) => fetch(base + '/generate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
test('without key returns explicit 503, not fabricated words', async () => withServer({ apiKey: '' }, async base => {
  assert.equal((await fetch(base + '/health')).status, 200);
  assert.equal((await post(base)).status, 503);
  assert.equal((await post(base, { ...input, topic: '' })).status, 400);
}));
test('calls upstream and returns validated words', async () => withServer({ apiKey: 'test-only', fetchImpl: async (url, init) => {
  assert.equal(url, 'https://api.groq.com/openai/v1/chat/completions');
  assert.equal(JSON.parse(init.body).response_format.json_schema.strict, true);
  return Response.json({ choices: [{ message: { content: JSON.stringify({ words: Array.from({ length: 30 }, (_, i) => 'Слово ' + String.fromCharCode(1040 + i)) }) } }] });
}}, async base => {
  const reply = await post(base); assert.equal(reply.status, 200); assert.equal((await reply.json()).words.length, 30);
}));
test('upstream limits and malformed answers are handled', async () => {
  await withServer({ apiKey: 'test', fetchImpl: async () => new Response('', { status: 429 }) }, async base => assert.equal((await post(base)).status, 429));
  await withServer({ apiKey: 'test', fetchImpl: async () => Response.json({ choices: [] }) }, async base => assert.equal((await post(base)).status, 502));
});
test('limits repeated generation requests', async () => withServer({ apiKey: '' }, async base => {
  for (let i = 0; i < 6; i++) assert.equal((await post(base)).status, 503);
  assert.equal((await post(base)).status, 429);
}));
