'use strict';
const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');
const { newState, createProduct, completeMission, decide, skipToday, rollDay } = c;

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};

function selling(n = 1) {
  let s = newState();
  for (let i = 0; i < n; i++) {
    s = createProduct(s, { name: 'P' + (i + 1), place: 'casa' });
    Object.assign(s.products[i], { status: 'vendiendo' });
  }
  return s;
}
const active = (s, day) => completeMission(s, 'p1:video:1', at(day, 9));

test('estado antiguo se completa sin perder nada', () => {
  const old = JSON.stringify({
    version: 1, xp: 250, streetStep: 1, streetVideos: 2, productsStarted: 1, lastActiveDay: '2026-10-20',
    products: [{ id: 'p1', name: 'Lámpara', place: 'calle', status: 'test', accounts: { tiktok: true, instagram: true, youtube: true },
      testStartDay: '2026-10-15', sold: false, viralPlatforms: [], salesLevel: null }],
    today: { day: '2026-10-20', done: [], skipped: false },
  });
  const s = c.parseState(old);
  assert.strictEqual(s.xp, 250);
  assert.deepStrictEqual(s.streak, { current: 0, best: 0, lastDay: null, countedDay: null, startDay: null, recordAlertStart: null });
  assert.deepStrictEqual(s.medals, []);
  assert.deepStrictEqual(s.records, { bestVideosDay: 0 });
  assert.deepStrictEqual(s.quote, { day: null, id: null });
  assert.strictEqual(s.products[0].discardedDay, null);
  assert.deepStrictEqual(s.usedQuotes, []);
  assert.strictEqual(s.today.videos, 0);
  assert.strictEqual(s.today.recordNotified, false);
  assert.strictEqual(s.products[0].name, 'Lámpara');
});

test('rollDay reinicia today con los campos nuevos', () => {
  const s = rollDay(newState(), at('2026-10-21', 9));
  assert.deepStrictEqual(s.today, { day: '2026-10-21', done: [], skipped: false, videos: 0, recordNotified: false, minimo: false });
});

test('racha: 3 días seguidos -> 3; el mismo día dos veces no suma', () => {
  let s = selling();
  s = active(s, '2026-10-21');
  s = completeMission(s, 'p1:video:2', at('2026-10-21', 15));
  assert.strictEqual(s.streak.current, 1);
  s = active(s, '2026-10-22');
  s = active(s, '2026-10-23');
  assert.strictEqual(s.streak.current, 3);
  assert.strictEqual(s.streak.best, 3);
  assert.strictEqual(s.streak.lastDay, '2026-10-23');
  assert.strictEqual(s.streak.countedDay, '2026-10-23');
});

test('día saltado entre dos días activos mantiene la racha', () => {
  let s = selling();
  s = active(s, '2026-10-21');
  s = skipToday(s, at('2026-10-22', 9));
  assert.strictEqual(s.streak.lastDay, '2026-10-22');
  assert.strictEqual(s.streak.current, 1);
  s = active(s, '2026-10-23');
  assert.strictEqual(s.streak.current, 2);
});

test('saltar sin racha previa no crea puente', () => {
  const s = skipToday(selling(), at('2026-10-22', 9));
  assert.strictEqual(s.streak.lastDay, null);
});

test('un día sin nada reinicia la racha', () => {
  let s = selling();
  s = active(s, '2026-10-21');
  s = active(s, '2026-10-23');
  assert.strictEqual(s.streak.current, 1);
  assert.strictEqual(s.streak.best, 1);
});

test('streakNow', () => {
  let s = selling();
  s = active(s, '2026-10-21');
  s = active(s, '2026-10-22');
  assert.strictEqual(c.streakNow(s, at('2026-10-22', 20)), 2);
  assert.strictEqual(c.streakNow(s, at('2026-10-23', 9)), 2);
  assert.strictEqual(c.streakNow(s, at('2026-10-24', 9)), 0);
});

test('medalla a los 7 días y aviso', () => {
  let s = selling();
  s.secretas = ['semana-sin-saltar'];
  for (let d = 21; d <= 26; d++) s = active(s, '2026-10-' + d);
  const before = s;
  assert.deepStrictEqual(before.medals, []);
  s = active(s, '2026-10-27');
  assert.deepStrictEqual(s.medals, [7]);
  assert.deepStrictEqual(c.achievements(before, s), ['🏅 Medalla: 7 días seguidos', '🛡️ Escudo ganado (tienes ' + s.shields + ')']);
  const again = active(s, '2026-10-28');
  assert.deepStrictEqual(again.medals, [7]);
});

test('récord de racha solo si había mejor previa >= 1', () => {
  const b = newState();
  const seeded = selling();
  seeded.products[0].videos = 1;
  const first = active(seeded, '2026-10-21');
  assert.deepStrictEqual(c.achievements(b, first), []);
});

test('récord de racha: un solo aviso por racha', () => {
  let s = active(selling(), '2026-10-21');
  let before = s;
  s = active(s, '2026-10-22');
  assert.deepStrictEqual(c.achievements(before, s), ['🏆 Nuevo récord: racha de 2 días']);
  for (let d = 23; d <= 27; d++) {
    before = s;
    s = active(s, '2026-10-' + d);
    assert.deepStrictEqual(c.achievements(before, s).filter((x) => x.includes('racha de')), [], 'día ' + d);
  }
});

const rec = (x, y) => c.achievements(x, y).filter((m) => m.includes('racha de'));

test('una racha posterior que supera el récord avisa una vez', () => {
  let s = active(selling(), '2026-10-21');
  s = active(s, '2026-10-22'); // best 2, avisó
  s = active(s, '2026-11-01'); // racha nueva, current 1
  let before = s;
  s = active(s, '2026-11-02'); // 2 = best, sin aviso
  assert.deepStrictEqual(rec(before, s), []);
  before = s;
  s = active(s, '2026-11-03'); // 3 > 2
  assert.deepStrictEqual(rec(before, s), ['🏆 Nuevo récord: racha de 3 días']);
  before = s;
  s = active(s, '2026-11-04');
  assert.deepStrictEqual(rec(before, s), []);
});

test('récord de vídeos: un solo aviso por día', () => {
  let s = selling(2);
  s.records.bestVideosDay = 2;
  s = completeMission(s, 'p1:video:1', at('2026-10-21', 9));
  s = completeMission(s, 'p1:video:2', at('2026-10-21', 15));
  assert.strictEqual(s.today.recordNotified, false);
  const before = s;
  s = completeMission(s, 'p1:video:3', at('2026-10-21', 21));
  assert.strictEqual(s.today.videos, 3);
  assert.strictEqual(s.records.bestVideosDay, 3);
  assert.deepStrictEqual(c.achievements(before, s), ['🏆 Nuevo récord: 3 vídeos en un día']);
  const before2 = s;
  s = completeMission(s, 'p2:video:1', at('2026-10-21', 22));
  assert.strictEqual(s.records.bestVideosDay, 4);
  assert.deepStrictEqual(c.achievements(before2, s), []);
});

test('decide descartar: discardedDay y día activo', () => {
  let s = selling();
  s.products[0].status = 'decision';
  s = decide(s, 'p1', 'descartar', at('2026-10-21', 9));
  assert.strictEqual(s.products[0].discardedDay, '2026-10-21');
  assert.strictEqual(s.streak.current, 1);
  assert.strictEqual(s.streak.lastDay, '2026-10-21');
});

test('decide no descartar también cuenta como día activo', () => {
  let s = selling();
  s.products[0].status = 'decision';
  s = decide(s, 'p1', 'bajo', at('2026-10-21', 9));
  assert.strictEqual(s.products[0].discardedDay, null);
  assert.strictEqual(s.streak.current, 1);
});

test('checkpointText', () => {
  assert.strictEqual(c.checkpointText({ productsStarted: 2 }), '🏁 Checkpoint guardado. Producto 3/30 desbloqueado');
  assert.strictEqual(c.checkpointText({ productsStarted: 30 }), '🏁 Checkpoint guardado. Producto 31 desbloqueado');
});

test('achievements incluye la subida de nivel', () => {
  const a = newState();
  const b = newState();
  b.xp = 100;
  assert.deepStrictEqual(c.achievements(a, b), ['¡Nivel 2! Ahora eres Jinete novato']);
  b.xp = 50 * 3 * 2;
  assert.deepStrictEqual(c.achievements(a, b), ['¡Nivel 3! Ahora eres Jinete']);
});
