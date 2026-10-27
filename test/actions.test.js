'use strict';
const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');
const {
  newState, createProduct, rollDay, completeMission, markSold, markViral, decide,
  skipToday, productsInDecision, activeProducts, horseMood,
} = c;

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};
const now = at('2026-10-21', 9);

function withProduct(patch, name = 'Lámpara', place = 'casa') {
  const s = createProduct(newState(), { name, place });
  Object.assign(s.products[0], patch);
  return s;
}

test('crear las tres cuentas arranca el test mañana', () => {
  let s = withProduct({});
  for (const k of ['tiktok', 'instagram', 'youtube']) s = completeMission(s, 'p1:cuenta:' + k, now);
  assert.strictEqual(s.products[0].status, 'test');
  assert.strictEqual(s.products[0].testStartDay, '2026-10-22');
  assert.strictEqual(s.xp, 30);
  assert.strictEqual(s.lastActiveDay, '2026-10-21');
  assert.deepStrictEqual(s.products[0].accounts, { tiktok: true, instagram: true, youtube: true });
});

test('completar dos veces la misma misión no da XP dos veces', () => {
  const s = withProduct({});
  const once = completeMission(s, 'p1:cuenta:tiktok', now);
  const twice = completeMission(once, 'p1:cuenta:tiktok', now);
  assert.strictEqual(once.xp, 10);
  assert.strictEqual(twice.xp, once.xp);
});

test('no se puede completar una misión de decisión con "Hecho"', () => {
  const d = withProduct({ status: 'decision' });
  assert.deepStrictEqual(completeMission(d, 'p1:decision', now), rollDay(d, now));
});

test('misión inexistente devuelve el estado sin cambios', () => {
  const d = withProduct({});
  assert.deepStrictEqual(completeMission(d, 'p9:nada', now), rollDay(d, now));
});

test('escalera de la calle: sube tras 5 vídeos y se queda en el último escalón', () => {
  const s = withProduct({ status: 'vendiendo', place: 'calle' });
  const day = (n) => at('2026-10-' + String(10 + n).padStart(2, '0'), 9);
  let st = s;
  let n = 0;
  const doVideos = (count) => {
    while (count > 0) {
      const t = day(n++);
      for (let i = 1; i <= 3 && count > 0; i++, count--) st = completeMission(st, 'p1:video:' + i, t);
    }
  };
  doVideos(4);
  assert.strictEqual(st.streetStep, 0);
  assert.strictEqual(st.streetVideos, 4);
  doVideos(1);
  const after5 = st;
  assert.strictEqual(after5.streetStep, 1); assert.strictEqual(after5.streetVideos, 0);
  doVideos(10);
  const after15 = st;
  assert.strictEqual(after15.streetStep, 2);
  doVideos(10);
  assert.strictEqual(st.streetStep, 2);
});

test('en casa no avanza la escalera', () => {
  const s = withProduct({ status: 'vendiendo' });
  const home = completeMission(s, 'p1:video:1', now);
  assert.strictEqual(home.streetVideos, 0);
  assert.strictEqual(home.xp, 20);
});

test('viral sin ventas -> decisión; viral con ventas -> sigue en test', () => {
  const s = withProduct({ status: 'test', testStartDay: '2026-10-21' });
  const v = markViral(s, 'p1', 'tiktok', now);
  assert.strictEqual(v.products[0].status, 'decision');
  assert.deepStrictEqual(v.products[0].viralPlatforms, ['tiktok']);
  assert.strictEqual(markViral(markSold(s, 'p1', now), 'p1', 'tiktok', now).products[0].status, 'test');
  const twice = markViral(markViral(s, 'p1', 'tiktok', now), 'p1', 'tiktok', now);
  assert.deepStrictEqual(twice.products[0].viralPlatforms, ['tiktok']);
});

test('markSold', () => {
  const s = withProduct({ status: 'test', testStartDay: '2026-10-21' });
  assert.strictEqual(markSold(s, 'p1', now).products[0].sold, true);
  assert.strictEqual(s.products[0].sold, false);
});

test('decide', () => {
  const d = withProduct({ status: 'decision' });
  assert.strictEqual(decide(d, 'p1', 'descartar', now).products[0].status, 'descartado');
  const n = decide(d, 'p1', 'normal', now);
  assert.strictEqual(n.products[0].salesLevel, 'normal');
  assert.strictEqual(n.products[0].status, 'vendiendo');
  assert.strictEqual(decide(d, 'p1', 'poco', now).xp, d.xp + 100);
  assert.strictEqual(n.lastActiveDay, '2026-10-21');
});

test('productsInDecision y activeProducts', () => {
  let two = withProduct({ status: 'decision' });
  two = createProduct(two, { name: 'Taza', place: 'casa' });
  two.products[1].status = 'decision';
  two = createProduct(two, { name: 'Vela', place: 'casa' });
  two.products[2].status = 'descartado';
  assert.deepStrictEqual(productsInDecision(two).map(p => p.id), ['p1', 'p2']);
  assert.deepStrictEqual(activeProducts(two).map(p => p.id), ['p1', 'p2']);
});

test('skipToday', () => {
  const s = skipToday(withProduct({}), now);
  assert.strictEqual(s.today.skipped, true);
  assert.strictEqual(s.lastActiveDay, '2026-10-21');
});

test('caballo', () => {
  const base = withProduct({});
  assert.strictEqual(horseMood(newState(), now), 'normal');
  const doneToday = completeMission(base, 'p1:cuenta:tiktok', now);
  assert.strictEqual(horseMood(doneToday, now), 'radiante');
  assert.strictEqual(horseMood(skipToday(doneToday, now), now), 'radiante');
  const skippedToday = skipToday(base, now);
  assert.strictEqual(horseMood(skippedToday, now), 'normal');
  const a2 = structuredClone(base); a2.lastActiveDay = '2026-10-19';
  const a3 = structuredClone(base); a3.lastActiveDay = '2026-10-18';
  assert.strictEqual(horseMood(a2, now), 'normal');
  assert.strictEqual(horseMood(a3, now), 'barro');
});

test('las acciones no modifican el estado de entrada', () => {
  const original = withProduct({});
  const snap = structuredClone(original);
  completeMission(original, 'p1:cuenta:tiktok', now);
  markSold(original, 'p1', now);
  markViral(original, 'p1', 'tiktok', now);
  decide(original, 'p1', 'mucho', now);
  skipToday(original, now);
  assert.strictEqual(original.xp, 0);
  assert.deepStrictEqual(original, snap);
});

test('core no depende de structuredClone (Scriptable no lo tiene)', () => {
  const saved = globalThis.structuredClone;
  delete globalThis.structuredClone;
  try {
    let s = createProduct(newState(), { name: 'Gorra', place: 'casa' });
    s = rollDay(s, now);
    s = completeMission(s, 'p1:cuenta:tiktok', now);
    assert.strictEqual(s.xp, 10);
  } finally {
    globalThis.structuredClone = saved;
  }
});
