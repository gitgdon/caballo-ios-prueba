'use strict';
const test = require('node:test');
const assert = require('node:assert');
const {
  newState, createProduct, rollDay, retoInfo, apuntarFacturacion, editarReto, nuevoReto,
  achievements, totalVideos, parseState,
} = require('../Resources/core.js');

const at = (day) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, 12, 0, 0);
};
const NOW = at('2026-10-27');

function conReto() {
  return rollDay(newState(), NOW);
}

test('un estado de la ronda 2 sin reto lo recibe con los valores por defecto', () => {
  const viejo = JSON.parse(JSON.stringify(newState()));
  delete viejo.ganchos;
  delete viejo.reto;
  const s = rollDay(parseState(JSON.stringify(viejo)), NOW);
  assert.deepStrictEqual(s.reto, { meta: 10000, fin: '2026-12-31', inicio: '2026-10-27', base: 0, facturado: 0, cumplido: false, baseFacturacion: 0 });
  assert.deepStrictEqual(s.ganchos, []);
  assert.strictEqual(retoInfo(s, NOW).diasQuedan, 65);
});

test('base del reto = vídeos que ya había', () => {
  let s = createProduct(newState(), { name: 'A', place: 'casa' });
  s.products[0].videos = 4;
  s = rollDay(s, NOW);
  assert.strictEqual(s.reto.base, 4);
  s.products[0].videos = 7;
  assert.strictEqual(retoInfo(s, NOW).videos, 3);
});

test('apuntarFacturacion redondea y calcula el progreso', () => {
  const s = apuntarFacturacion(conReto(), 1240, NOW);
  assert.strictEqual(s.reto.facturado, 1240);
  assert.strictEqual(retoInfo(s, NOW).progreso, 0.124);
  assert.strictEqual(apuntarFacturacion(s, 99.6, NOW).reto.facturado, 100);
});

test('valores no válidos no cambian el estado', () => {
  const s = apuntarFacturacion(conReto(), 500, NOW);
  for (const malo of [NaN, -5, 'abc', Infinity, null, undefined]) {
    assert.deepStrictEqual(apuntarFacturacion(s, malo, NOW), s);
  }
});

test('al llegar a la meta: cumplido, medalla oculta y logro, una sola vez', () => {
  const s0 = conReto();
  const s1 = apuntarFacturacion(s0, 10000, NOW);
  assert.strictEqual(s1.reto.cumplido, true);
  assert.deepStrictEqual(s1.secretas, ['reto-cumplido']);
  assert.ok(achievements(s0, s1).includes('🎯 ¡Reto cumplido!'));
  const s2 = apuntarFacturacion(s1, 12000, NOW);
  assert.deepStrictEqual(s2.secretas, ['reto-cumplido']);
  assert.ok(!achievements(s1, s2).includes('🎯 ¡Reto cumplido!'));
  assert.strictEqual(retoInfo(s2, NOW).progreso, 1);
});

test('editarReto mantiene inicio y base; nuevoReto los reinicia', () => {
  let s = createProduct(newState(), { name: 'A', place: 'casa' });
  s.products[0].videos = 2;
  s = apuntarFacturacion(rollDay(s, NOW), 800, NOW);
  s.products[0].videos = 5;
  const e = editarReto(s, 5000, '2027-01-31');
  assert.strictEqual(e.reto.meta, 5000);
  assert.strictEqual(e.reto.fin, '2027-01-31');
  assert.strictEqual(e.reto.base, 2);
  assert.strictEqual(e.reto.inicio, '2026-10-27');
  assert.strictEqual(e.reto.facturado, 800);
  const n = nuevoReto(e, 3000, '2027-03-01', at('2027-01-02'));
  assert.deepStrictEqual(n.reto, { meta: 3000, fin: '2027-03-01', inicio: '2027-01-02', base: 5, facturado: 0, cumplido: false, baseFacturacion: 800 });
  assert.strictEqual(totalVideos(n), 5);
});

test('el 31-12 sigue vigente y el 01-01 vence sin castigo', () => {
  const s = conReto();
  const ultimo = retoInfo(s, at('2026-12-31'));
  assert.strictEqual(ultimo.vencido, false);
  assert.strictEqual(ultimo.diasQuedan, 0);
  const v = retoInfo(s, at('2027-01-01'));
  assert.strictEqual(v.vencido, true);
  assert.strictEqual(v.diasQuedan, 0);
});

test('sin reto en el estado: retoInfo no muta y los mutadores lo crean', () => {
  const s = newState();
  assert.strictEqual(s.reto, undefined);
  const info = retoInfo(s, NOW);
  assert.strictEqual(info.meta, 10000);
  assert.strictEqual(info.diasQuedan, 65);
  assert.strictEqual(s.reto, undefined);
  assert.strictEqual(apuntarFacturacion(s, 300, NOW).reto.facturado, 300);
  const e = editarReto(s, 5000, '2027-01-31');
  assert.strictEqual(e.reto.meta, 5000);
  assert.strictEqual(e.reto.base, 0);
  assert.strictEqual(nuevoReto(s, 5000, '2027-01-31', NOW).reto.inicio, '2026-10-27');
});

test('editarReto y nuevoReto ignoran meta o fecha no válidas', () => {
  const s = conReto();
  for (const meta of [NaN, 0, -1, '500', Infinity, null, 0.2]) {
    assert.deepStrictEqual(editarReto(s, meta, '2027-01-31'), s);
    assert.deepStrictEqual(nuevoReto(s, meta, '2027-01-31', NOW), s);
  }
  for (const fin of ['31-12-2026', '2026-13-01', '2026-02-30', 'abc', null, '2026-1-1']) {
    assert.deepStrictEqual(editarReto(s, 500, fin), s);
    assert.deepStrictEqual(nuevoReto(s, 500, fin, NOW), s);
  }
  assert.strictEqual(editarReto(s, 499.6, '2027-01-31').reto.meta, 500);
});

test('rollDay conserva un reto existente', () => {
  const s = apuntarFacturacion(conReto(), 700, NOW);
  const otro = rollDay(s, at('2026-11-05'));
  assert.deepStrictEqual(otro.reto, s.reto);
});
