'use strict';
const test = require('node:test');
const assert = require('node:assert');
const {
  newState, createProduct, testDay, rollDay, missionsForDay, pendingMissions,
  currentMission, addDays, dayKey,
} = require('../Resources/core.js');

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};

function withProduct(patch, name = 'Lámpara', place = 'casa') {
  const s = createProduct(newState(), { name, place });
  Object.assign(s.products[0], patch);
  return s;
}

test('createProduct añade producto en preparación sin mutar', () => {
  const s0 = newState();
  const s = createProduct(s0, { name: 'Lámpara', place: 'casa' });
  assert.strictEqual(s0.products.length, 0);
  assert.strictEqual(s0.productsStarted, 0);
  assert.strictEqual(s.productsStarted, 1);
  const p = s.products[0];
  assert.strictEqual(p.id, 'p1');
  assert.strictEqual(p.status, 'preparacion');
  assert.deepStrictEqual(p.accounts, { tiktok: false, instagram: false, youtube: false });
  assert.strictEqual(p.testStartDay, null);
  assert.strictEqual(p.sold, false);
  assert.deepStrictEqual(p.viralPlatforms, []);
  assert.strictEqual(p.salesLevel, null);
});

test('testDay', () => {
  assert.strictEqual(testDay({ testStartDay: null }, '2026-10-21'), 0);
  assert.strictEqual(testDay({ testStartDay: '2026-10-21' }, '2026-10-21'), 1);
  assert.strictEqual(testDay({ testStartDay: '2026-10-21' }, '2026-11-03'), 14);
  assert.strictEqual(testDay({ testStartDay: '2026-10-22' }, '2026-10-21'), 0);
});

test('preparación: una misión por cuenta que falta', () => {
  const s = withProduct({});
  const m = missionsForDay(s, at('2026-10-21', 10));
  assert.deepStrictEqual(m.map(x => x.id), ['p1:cuenta:tiktok', 'p1:cuenta:instagram', 'p1:cuenta:youtube']);
  assert.deepStrictEqual(m.map(x => x.block), ['mañana', 'tarde', 'noche']);
  assert.strictEqual(m[0].text, 'Crea la cuenta de TikTok de Lámpara');
  assert.strictEqual(m[0].xp, 10);
  assert.strictEqual(m[0].kind, 'cuenta');
  s.products[0].accounts.tiktok = true;
  assert.deepStrictEqual(missionsForDay(s, at('2026-10-21', 10)).map(x => x.id),
    ['p1:cuenta:instagram', 'p1:cuenta:youtube']);
});

test('test día 1 en casa: ligera + 1 vídeo', () => {
  const s = withProduct({ status: 'test', videos: 1, testStartDay: '2026-10-21' });
  const m = missionsForDay(s, at('2026-10-21', 9));
  assert.deepStrictEqual(m.map(x => x.id), ['p1:ligera', 'p1:video:1']);
  assert.strictEqual(m[0].text, 'Responde comentarios y revisa las cuentas de Lámpara');
  assert.strictEqual(m[1].block, 'tarde');
  assert.strictEqual(m[1].text, 'Graba y sube 1 vídeo de Lámpara');
  assert.strictEqual(m[1].xp, 20);
});

test('test día 6 en calle: 3 vídeos, sin ligera', () => {
  const s = withProduct({ status: 'test', videos: 1, testStartDay: '2026-10-21', place: 'calle' });
  s.streetStep = 1;
  const m = missionsForDay(s, at('2026-10-26', 9));
  assert.deepStrictEqual(m.map(x => x.id), ['p1:video:1', 'p1:video:2', 'p1:video:3']);
  assert.strictEqual(m[0].text, 'Graba y sube 1 vídeo de Lámpara en una calle tranquila');
  assert.strictEqual(m[0].xp, 30);
});

test('test día 3: dos vídeos tarde y noche', () => {
  const s = withProduct({ status: 'test', videos: 1, testStartDay: '2026-10-21' });
  const m = missionsForDay(s, at('2026-10-23', 9));
  assert.deepStrictEqual(m.map(x => [x.id, x.block]),
    [['p1:ligera', 'mañana'], ['p1:video:1', 'tarde'], ['p1:video:2', 'noche']]);
});

test('test día 8 vendido y viral: pedidos, 3 vídeos y métricas', () => {
  const s = withProduct({ status: 'test', videos: 1, testStartDay: '2026-10-21', sold: true, viralPlatforms: ['tiktok'] });
  const m = missionsForDay(s, at('2026-10-28', 9));
  assert.deepStrictEqual(m.map(x => x.id),
    ['p1:pedidos', 'p1:video:1', 'p1:video:2', 'p1:video:3', 'p1:metricas']);
  const videos = m.filter(x => x.kind === 'video');
  assert.match(videos[0].text, /replica el estilo viral en TikTok$/);
  assert.strictEqual(m[0].text, 'Gestiona los pedidos de Lámpara');
  assert.strictEqual(m[4].text, 'Revisa las métricas de Lámpara');
});

test('vendiendo: 3 vídeos y métricas; varias plataformas unidas', () => {
  const s = withProduct({ status: 'vendiendo', viralPlatforms: ['tiktok', 'youtube'] });
  const m = missionsForDay(s, at('2026-11-20', 9));
  assert.deepStrictEqual(m.map(x => x.id), ['p1:video:1', 'p1:video:2', 'p1:video:3', 'p1:metricas']);
  assert.match(m[0].text, /replica el estilo viral en TikTok, YouTube Shorts$/);
});

test('decision: misión de decisión sin xp', () => {
  const s = withProduct({ status: 'decision' });
  const m = missionsForDay(s, at('2026-11-20', 9));
  assert.deepStrictEqual(m, [{
    id: 'p1:decision', productId: 'p1', block: 'mañana', kind: 'decision',
    text: 'Decide: ¿ha vendido Lámpara?', xp: 0,
  }]);
});

test('descartado: sin misiones', () => {
  const s = withProduct({ status: 'descartado' });
  assert.deepStrictEqual(missionsForDay(s, at('2026-11-20', 9)), []);
});

test('rollDay: día 15 pasa a decision y vacía done, sin mutar', () => {
  const start = '2026-10-21';
  const s = withProduct({ status: 'test', testStartDay: start });
  s.today = { day: start, done: ['p1:video:1'], skipped: true };
  const same = rollDay(s, at(addDays(start, 13), 9));
  assert.strictEqual(same.products[0].status, 'test');
  const rolled = rollDay(s, at(addDays(start, 14), 9));
  assert.strictEqual(rolled.products[0].status, 'decision');
  assert.deepStrictEqual(rolled.today, { day: addDays(start, 14), done: [], skipped: false, videos: 0, recordNotified: false, minimo: false });
  assert.strictEqual(s.products[0].status, 'test');
  assert.deepStrictEqual(s.today.done, ['p1:video:1']);
});

test('rollDay: mismo día conserva today', () => {
  const s = withProduct({});
  s.today = { day: '2026-10-21', done: ['x'], skipped: false };
  assert.deepStrictEqual(rollDay(s, at('2026-10-21', 22)).today.done, ['x']);
});

test('dos productos: el primero va antes', () => {
  let s2 = withProduct({});
  s2 = createProduct(s2, { name: 'Taza', place: 'casa' });
  const now = at('2026-10-21', 9);
  assert.strictEqual(currentMission(s2, now).productId, 'p1');
  assert.strictEqual(missionsForDay(s2, now).slice(-1)[0].productId, 'p2');
});

test('pendingMissions: done solo cuenta el mismo día; saltado vacío', () => {
  const s = withProduct({});
  const now = at('2026-10-21', 9);
  s.today = { day: dayKey(now), done: ['p1:cuenta:tiktok'], skipped: false };
  assert.deepStrictEqual(pendingMissions(s, now).map(m => m.id), ['p1:cuenta:instagram', 'p1:cuenta:youtube']);
  assert.strictEqual(currentMission(s, now).id, 'p1:cuenta:instagram');
  s.today.day = '2026-10-20';
  assert.strictEqual(pendingMissions(s, now).length, 3);
  const skipped = structuredClone(s);
  skipped.today = { day: dayKey(now), done: [], skipped: true };
  assert.deepStrictEqual(pendingMissions(skipped, now), []);
  assert.strictEqual(currentMission(skipped, now), null);
});

test('test con inicio mañana: sin misiones hoy', () => {
  const now = at('2026-10-21', 9);
  const s = withProduct({ status: 'test', testStartDay: addDays(dayKey(now), 1) });
  assert.deepStrictEqual(missionsForDay(s, now), []);
});

test('test día 1 vendido: pedidos y vídeo, sin ligera', () => {
  const s = withProduct({ status: 'test', videos: 1, testStartDay: '2026-10-21', sold: true });
  assert.deepStrictEqual(missionsForDay(s, at('2026-10-21', 9)).map(x => x.id), ['p1:pedidos', 'p1:video:1']);
});
