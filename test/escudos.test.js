'use strict';
const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');
const { newState, createProduct, completeMission, skipToday, streakNow, XP_BASE } = c;

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};
const dayN = (n) => c.addDays('2026-10-01', n - 1);

function selling() {
  let s = createProduct(newState(), { name: 'P1', place: 'casa' });
  s.products[0].status = 'vendiendo';
  return s;
}
const active = (s, day) => completeMission(s, 'p1:video:1', at(day, 9));
function streakOf(n) {
  let s = selling();
  for (let i = 1; i <= n; i++) s = active(s, dayN(i));
  return s;
}

test('partida antigua recibe shields, lastSkipDay y today.minimo', () => {
  const s = c.parseState(JSON.stringify({ version: 1, xp: 5, products: [], today: { day: null, done: [], skipped: false } }));
  assert.strictEqual(s.shields, 1);
  assert.strictEqual(s.lastSkipDay, null);
  assert.strictEqual(s.today.minimo, false);
  assert.strictEqual(c.rollDay(newState(), at('2026-10-21', 9)).today.minimo, false);
  assert.strictEqual(newState().shields, 1);
});

test('escudos: +1 cada 7 días, máximo 3', () => {
  assert.strictEqual(streakOf(6).shields, 1);
  assert.strictEqual(streakOf(7).shields, 2);
  assert.strictEqual(streakOf(14).shields, 3);
  assert.strictEqual(streakOf(21).shields, 3);
  assert.strictEqual(c.SHIELDS_MAX, 3);
  assert.strictEqual(c.SHIELD_EVERY, 7);
});

test('racha perdida y rehecha hasta 7 vuelve a ganar escudo', () => {
  let s = streakOf(7);
  assert.strictEqual(s.shields, 2);
  s.shields = 0;
  for (let i = 0; i < 7; i++) s = active(s, dayN(20 + i));
  assert.strictEqual(s.streak.current, 7);
  assert.strictEqual(s.shields, 1);
});

test('saltar con 1 escudo: lo gasta y mantiene la racha', () => {
  let s = active(selling(), dayN(1));
  s = skipToday(s, at(dayN(2), 9));
  assert.strictEqual(s.shields, 0);
  assert.strictEqual(s.lastSkipDay, dayN(2));
  assert.strictEqual(streakNow(s, at(dayN(3), 9)), 1);
  s = active(s, dayN(3));
  assert.strictEqual(s.streak.current, 2);
});

test('saltar sin escudos: no hace de puente y no hay barro', () => {
  let s = active(selling(), dayN(1));
  s.shields = 0;
  s = skipToday(s, at(dayN(2), 9));
  assert.strictEqual(s.shields, 0);
  assert.strictEqual(s.today.skipped, true);
  assert.strictEqual(s.lastSkipDay, dayN(2));
  assert.strictEqual(s.lastActiveDay, dayN(2));
  assert.strictEqual(streakNow(s, at(dayN(3), 9)), 0);
  assert.notStrictEqual(c.horseMood(s, at(dayN(3), 9)), 'barro');
  s = active(s, dayN(3));
  assert.strictEqual(s.streak.current, 1);
});

test('saltar tras completar una misión hoy no gasta escudo ni toca la racha', () => {
  let s = active(selling(), dayN(1));
  s = active(s, dayN(2));
  const st = JSON.stringify(s.streak);
  s = skipToday(s, at(dayN(2), 18));
  assert.strictEqual(s.shields, 1);
  assert.strictEqual(JSON.stringify(s.streak), st);
  assert.strictEqual(s.today.skipped, true);
  assert.strictEqual(s.lastSkipDay, dayN(2));
  assert.strictEqual(streakNow(s, at(dayN(3), 9)), 2);
});

test('skipEffect coincide con lo que hace skipToday', () => {
  const now = at(dayN(2), 9);
  const alive = c.rollDay(active(selling(), dayN(1)), now);
  assert.strictEqual(c.skipEffect(alive, now), 'escudo');
  assert.strictEqual(skipToday(alive, now).shields, 0);
  const none = { ...alive, shields: 0 };
  assert.strictEqual(c.skipEffect(none, now), 'pierde');
  const doneToday = active(active(selling(), dayN(1)), dayN(2));
  assert.strictEqual(c.skipEffect(doneToday, now), 'nada');
  assert.strictEqual(c.skipEffect({ ...doneToday, shields: 0 }, now), 'nada');
  const dead = c.rollDay(active(selling(), dayN(1)), at(dayN(5), 9));
  assert.strictEqual(c.skipEffect(dead, at(dayN(5), 9)), 'nada');
  assert.strictEqual(skipToday(dead, at(dayN(5), 9)).shields, 1);
  assert.strictEqual(c.skipEffect(c.rollDay(newState(), now), now), 'nada');
  assert.strictEqual(c.skipEffect(skipToday(alive, now), now), 'nada');
  assert.strictEqual(c.skipEffect(skipToday(none, now), now), 'nada');
});

test('canStartMinimo', () => {
  const now = at(dayN(1), 9);
  const s = c.rollDay(selling(), now);
  assert.strictEqual(c.canStartMinimo(s, now), true);
  assert.strictEqual(c.canStartMinimo(active(selling(), dayN(1)), now), false);
  assert.strictEqual(c.canStartMinimo(skipToday(selling(), now), now), false);
  assert.strictEqual(c.canStartMinimo(c.startMinimo(selling(), now), now), false);
  assert.strictEqual(c.canStartMinimo(c.rollDay(newState(), now), now), false);
  const dec = c.rollDay(selling(), now);
  dec.products[0].status = 'decision';
  assert.strictEqual(c.canStartMinimo(dec, now), false);
});

test('modo mínimo: solo minimo (más decisión si la hay)', () => {
  const now = at(dayN(1), 9);
  let s = c.startMinimo(selling(), now);
  assert.strictEqual(s.today.minimo, true);
  const ms = c.missionsForDay(s, now);
  assert.deepStrictEqual(ms, [{
    id: 'minimo', productId: null, block: 'mañana', kind: 'minimo', text: c.MINIMO_TEXT, xp: XP_BASE,
  }]);
  assert.strictEqual(c.MINIMO_TEXT, 'Haz lo mínimo: graba 1 vídeo corto o 1 toma de prueba, aunque sea en casa');
  assert.strictEqual(c.currentMission(s, now).id, 'minimo');
  assert.deepStrictEqual(c.pendingMissions(s, now).map((m) => m.id), ['minimo']);
  s = createProduct(s, { name: 'P2', place: 'casa' });
  s.products[1].status = 'decision';
  assert.deepStrictEqual(c.missionsForDay(s, now).map((m) => m.id), ['p2:decision', 'minimo']);
  // el cálculo de frases no se rompe sin producto
  assert.doesNotThrow(() => c.quoteCategories(s, now));
});

test('completar minimo: XP_BASE, racha, sin vídeos ni récords', () => {
  const now = at(dayN(2), 9);
  let s = active(selling(), dayN(1));
  const before = c.startMinimo(s, now);
  const snap = JSON.stringify([before.today.videos, before.records, before.streetVideos, before.products]);
  s = completeMission(before, 'minimo', now);
  assert.strictEqual(s.xp, before.xp + XP_BASE);
  assert.strictEqual(s.streak.current, 2);
  assert.strictEqual(s.lastActiveDay, dayN(2));
  assert.deepStrictEqual(s.today.done, ['minimo']);
  assert.strictEqual(JSON.stringify([s.today.videos, s.records, s.streetVideos, s.products]), snap);
  assert.deepStrictEqual(c.pendingMissions(s, now), []);
});

test('las acciones no modifican su entrada', () => {
  const now = at(dayN(1), 9);
  const s = c.rollDay(selling(), now);
  const snap = JSON.stringify(s);
  c.startMinimo(s, now);
  c.canStartMinimo(s, now);
  skipToday(s, now);
  assert.strictEqual(JSON.stringify(s), snap);
  const m = c.startMinimo(s, now);
  const snap2 = JSON.stringify(m);
  completeMission(m, 'minimo', now);
  assert.strictEqual(JSON.stringify(m), snap2);
});

test('achievements avisa del escudo ganado en el día 7', () => {
  const before = streakOf(6);
  const after = active(before, dayN(7));
  assert.ok(c.achievements(before, after).includes('🛡️ Escudo ganado (tienes ' + after.shields + ')'));
  assert.ok(!c.achievements(before, before).some((l) => l.includes('Escudo')));
});
