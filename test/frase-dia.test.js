'use strict';
const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');
const { newState, createProduct, decide, pickDailyQuote, quoteCategories, currentQuote, skipQuote } = c;

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};

const q = (id, categoria) => ({ id, texto: 't' + id, autor: 'a', video: { id: 'v', titulo: 'v' }, categoria });
const Q = [
  q('a1', 'constancia'), q('a2', 'disciplina'), q('a3', 'sacrificio'),
  q('a4', 'imperfecto'), q('a5', 'verguenza'), q('a6', 'sin-resultados'),
];

test('determinista y no modifica la entrada', () => {
  const s = newState();
  const copy = JSON.stringify(s);
  const now = at('2026-10-21', 9);
  assert.strictEqual(pickDailyQuote(s, now, Q).quote.id, pickDailyQuote(s, now, Q).quote.id);
  assert.strictEqual(JSON.stringify(s), copy);
});

test('ya elegida hoy no cambia ni añade a usedQuotes', () => {
  const now = at('2026-10-21', 9);
  const s = pickDailyQuote(newState(), now, Q);
  const again = pickDailyQuote(s, now, Q);
  assert.deepStrictEqual(again, s);
  assert.strictEqual(again.usedQuotes.length, 1);
});

test('no repite y reinicia al agotar el banco', () => {
  const Q3 = Q.slice(0, 3);
  let s = newState();
  const ids = [];
  for (const d of ['21', '22', '23']) {
    s = pickDailyQuote(s, at('2026-10-' + d, 9), Q3);
    ids.push(s.quote.id);
  }
  assert.strictEqual(new Set(ids).size, 3);
  s = pickDailyQuote(s, at('2026-10-24', 9), Q3);
  assert.strictEqual(s.usedQuotes.length, 1);
  assert.deepStrictEqual(s.usedQuotes, [s.quote.id]);
  assert.ok(ids.includes(s.quote.id));
});

test('quoteCategories: producto descartado ayer', () => {
  let s = createProduct(newState(), { name: 'P', place: 'casa' });
  s.products[0].status = 'decision';
  s = decide(s, 'p1', 'descartar', at('2026-10-20', 9));
  assert.deepStrictEqual(quoteCategories(s, at('2026-10-21', 9)), ['sin-resultados', 'imperfecto', 'desde-cero']);
  assert.deepStrictEqual(quoteCategories(s, at('2026-10-20', 20)), ['sin-resultados', 'imperfecto', 'desde-cero']);
  assert.strictEqual(quoteCategories(s, at('2026-10-22', 9)), null);
});

test('quoteCategories: caballo con barro', () => {
  const s = newState();
  s.lastActiveDay = '2026-10-18';
  assert.deepStrictEqual(quoteCategories(s, at('2026-10-21', 9)), ['sin-resultados', 'constancia', 'desde-cero']);
});

test('quoteCategories: producto de calle en test día 1', () => {
  let s = createProduct(newState(), { name: 'P', place: 'calle' });
  Object.assign(s.products[0], { status: 'test', testStartDay: '2026-10-21' });
  assert.deepStrictEqual(quoteCategories(s, at('2026-10-21', 9)), ['verguenza', 'imperfecto', 'accion']);
});

test('quoteCategories: nada aplica -> null', () => {
  assert.strictEqual(quoteCategories(newState(), at('2026-10-21', 9)), null);
});

test('pickDailyQuote respeta las categorías', () => {
  const s = newState();
  s.lastActiveDay = '2026-10-18';
  const r = pickDailyQuote(s, at('2026-10-21', 9), Q);
  assert.ok(['sin-resultados', 'constancia', 'desde-cero'].includes(currentQuote(r, Q).categoria));
});

test('categoría agotada -> otra frase no usada', () => {
  const s = newState();
  s.lastActiveDay = '2026-10-18';
  s.usedQuotes = ['a1', 'a6'];
  const r = pickDailyQuote(s, at('2026-10-21', 9), Q);
  assert.ok(['a2', 'a3', 'a4', 'a5'].includes(r.quote.id));
  assert.strictEqual(r.usedQuotes.length, 3);
});

test('skipQuote devuelve disciplina o sacrificio', () => {
  const r = skipQuote(Q, at('2026-10-21', 9));
  assert.ok(['disciplina', 'sacrificio'].includes(r.categoria));
  assert.strictEqual(skipQuote(Q, at('2026-10-21', 9)).id, r.id);
  assert.ok(skipQuote([q('x', 'otros')], at('2026-10-21', 9)));
});

test('currentQuote', () => {
  const s = pickDailyQuote(newState(), at('2026-10-21', 9), Q);
  assert.strictEqual(currentQuote(s, Q), Q.find((x) => x.id === s.quote.id));
  assert.strictEqual(currentQuote(newState(), Q), null);
});

test('banco vacío: pickDailyQuote no cambia nada y skipQuote devuelve null', () => {
  const s = newState();
  const now = at('2026-10-21', 9);
  assert.deepStrictEqual(pickDailyQuote(s, now, []), s);
  assert.deepStrictEqual(pickDailyQuote(s, now, undefined), s);
  assert.strictEqual(skipQuote([], now), null);
  assert.strictEqual(skipQuote(undefined, now), null);
});
