'use strict';
const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');
const { newState, createProduct, completeMission, markViral, markWinner, skipToday, XP_GANADOR } = c;

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};
const now = at('2026-10-21', 9);

function withTest(startDay) {
  const s = createProduct(newState(), { name: 'P1', place: 'casa' });
  s.products[0].status = 'test';
  s.products[0].testStartDay = startDay || '2026-10-21';
  return s;
}

test('partida antigua recibe videos, winners, bajonAvisado y why', () => {
  const s = c.parseState(JSON.stringify({
    version: 1, xp: 5, today: { day: null, done: [], skipped: false },
    products: [{ id: 'p1', name: 'X', place: 'casa', status: 'test', accounts: {}, viralPlatforms: [] }],
  }));
  assert.strictEqual(s.why, null);
  assert.strictEqual(s.products[0].videos, 0);
  assert.strictEqual(s.products[0].winners, 0);
  assert.strictEqual(s.products[0].bajonAvisado, false);
  assert.strictEqual(newState().why, null);
  const p = createProduct(newState(), { name: 'A', place: 'casa' }).products[0];
  assert.deepStrictEqual([p.videos, p.winners, p.bajonAvisado], [0, 0, false]);
});

test('un vídeo completado suma 1 a videos', () => {
  const seeded = createProduct(withTest(), { name: 'P0', place: 'casa' });
  Object.assign(seeded.products[1], { status: 'descartado', videos: 1 });
  const s = completeMission(seeded, 'p1:video:1', at('2026-10-22', 9));
  assert.strictEqual(s.products[0].videos, 1);
});

test('markWinner dos veces: winners 2 y +100 XP', () => {
  let s = withTest();
  s = markWinner(markWinner(s, 'p1', now), 'p1', now);
  assert.strictEqual(s.products[0].winners, 2);
  assert.strictEqual(s.xp, 2 * XP_GANADOR);
  assert.strictEqual(XP_GANADOR, 50);
});

test('markViral suma ganador y XP y sigue yendo a decisión', () => {
  const s = markViral(withTest(), 'p1', 'tiktok', now);
  assert.strictEqual(s.products[0].winners, 1);
  assert.strictEqual(s.xp, 50);
  assert.strictEqual(s.products[0].status, 'decision');
});

test('winnerText', () => {
  assert.strictEqual(c.winnerText({ winners: 1, videos: 0 }), '🟢 Ganador 1. Lo normal es 1–2 de cada 10: vas bien');
  assert.strictEqual(c.winnerText({ winners: 2, videos: 14 }), '🟢 Ganador 2 de 14. Lo normal es 1–2 de cada 10: vas bien');
});

test('setWhy recorta, corta a 80 y vacío da null', () => {
  assert.strictEqual(c.setWhy(newState(), '  mi familia  ').why, 'mi familia');
  assert.strictEqual(c.setWhy(newState(), 'a'.repeat(100)).why.length, 80);
  assert.strictEqual(c.setWhy(c.setWhy(newState(), 'algo'), '   ').why, null);
});

test('setWhy corta por caracteres sin partir un emoji', () => {
  const why = c.setWhy(newState(), 'a'.repeat(79) + '🐴' + 'b').why;
  assert.strictEqual(why, 'a'.repeat(79) + '🐴');
  assert.strictEqual(Array.from(why).length, 80);
});

test('whyToShow', () => {
  let s = c.setWhy(newState(), 'por mi familia');
  assert.strictEqual(c.whyToShow(s, now), null);
  const barro = { ...s, lastActiveDay: '2026-10-17' };
  assert.strictEqual(c.whyToShow(barro, now), 'por mi familia');
  const ayer = { ...s, lastActiveDay: '2026-10-20', lastSkipDay: '2026-10-20' };
  assert.strictEqual(c.whyToShow(ayer, now), 'por mi familia');
  assert.strictEqual(c.whyToShow({ ...ayer, why: null }, now), null);
  assert.strictEqual(c.whyToShow({ ...s, lastActiveDay: '2026-10-20' }, now), null);
});

test('bajonProducts por día, markBajonAvisado y bajonText', () => {
  const dayOf = (n) => at(c.addDays('2026-10-01', n - 1), 9);
  const s = withTest('2026-10-01');
  const names = (n) => c.bajonProducts(c.rollDay(s, dayOf(n)), dayOf(n)).length;
  assert.deepStrictEqual([7, 8, 14, 15].map(names), [0, 1, 1, 0]);
  const r = c.rollDay(s, dayOf(8));
  const done = c.markBajonAvisado(r, ['p1']);
  assert.strictEqual(c.bajonProducts(done, dayOf(8)).length, 0);
  assert.strictEqual(r.products[0].bajonAvisado, false);
  assert.strictEqual(c.inBajon(r.products[0], '2026-10-08'), true);
  assert.strictEqual(c.inBajon(r.products[0], '2026-10-07'), false);
  assert.strictEqual(c.inBajon(r.products[0], '2026-10-15'), false);
  assert.strictEqual(c.bajonText([{ name: 'P1' }]), 'P1: ' + c.BAJON_TEXT);
  assert.strictEqual(c.bajonText([{ name: 'P1' }, { name: 'P2' }]), 'P1, P2: ' + c.BAJON_TEXT);
  assert.strictEqual(c.BAJON_TEXT, '🧗 Entras en los días 8–14: aquí es donde más gente lo deja. Los resultados tardan 2–4 semanas en llegar. Sigue.');
});

test('ninguna función modifica su entrada', () => {
  const s = c.setWhy(withTest('2026-10-01'), 'x');
  const snap = JSON.stringify(s);
  markWinner(s, 'p1', now);
  c.setWhy(s, 'otro');
  c.markBajonAvisado(s, ['p1']);
  c.bajonProducts(s, now);
  c.whyToShow(s, now);
  assert.strictEqual(JSON.stringify(s), snap);
});

test('saltar con escudo y racha muerta conserva el escudo', () => {
  const s = skipToday(newState(), now);
  assert.strictEqual(s.shields, 1);
  assert.strictEqual(s.today.skipped, true);
  assert.strictEqual(s.lastSkipDay, '2026-10-21');
});

test('doble salto el mismo día gasta como mucho un escudo', () => {
  let s = withTest();
  s.products[0].status = 'vendiendo';
  s = completeMission(s, 'p1:video:1', at('2026-10-20', 9));
  s.shields = 2;
  s = skipToday(s, now);
  const again = skipToday(s, now);
  assert.strictEqual(s.shields, 1);
  assert.deepStrictEqual(again, s);
});

test('un producto vendido no está en el bajón', () => {
  const dayOf = (n) => at(c.addDays('2026-10-01', n - 1), 9);
  const s = withTest('2026-10-01');
  s.products[0].sold = true;
  const r = c.rollDay(s, dayOf(9));
  assert.strictEqual(c.bajonProducts(r, dayOf(9)).length, 0);
  assert.strictEqual(c.inBajon(r.products[0], '2026-10-09'), false);
});
