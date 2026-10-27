'use strict';
const test = require('node:test');
const assert = require('node:assert');
const {
  newState, createProduct, rollDay, missionsForDay, completeMission, hashDay, addDays,
  faseDeVisitas, apuntarVisitas, pideGancho, guardarGancho, recomendacionDia14, resumenDescarte,
  avisoCopia, parseState,
} = require('../Resources/core.js');
const { TECNICAS } = require('../Resources/tecnicas.js');

const at = (day) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, 12, 0, 0);
};
const len = (s) => Array.from(s).length;
const EXTRA = { tecnicas: TECNICAS, encuentros: [] };

// Producto en test (día 3 de test, 2 vídeos al día) en el día dado.
function enTest(day) {
  const s = createProduct(newState(), { name: 'Lámpara', place: 'casa' });
  Object.assign(s.products[0], { status: 'test', testStartDay: addDays(day, -2), videos: 1 });
  return rollDay(s, at(day));
}
function diaDonde(pred) {
  for (let i = 0; i < 400; i++) {
    const d = addDays('2026-11-01', i);
    if (pred(d)) return d;
  }
  throw new Error('sin día');
}
const gancho4 = (d) => hashDay(d + ':gancho') % 4 === 0;
const tec2 = (d) => hashDay(d + ':tec') % 2 === 0;
const primerVideo = (s, d) => missionsForDay(s, at(d), EXTRA).find((m) => m.kind === 'video');

test('faseDeVisitas en los límites de cada tramo', () => {
  const casos = [[0, 'arranque'], [99, 'arranque'], [100, 'palabras'], [249, 'palabras'], [250, 'gancho'],
    [1999, 'gancho'], [2000, 'ritmo'], [4999, 'ritmo'], [5000, 'cierre'], [9999, 'cierre'], [10000, 'interaccion']];
  for (const [n, fase] of casos) assert.strictEqual(faseDeVisitas(n).fase, fase, String(n));
  assert.strictEqual(faseDeVisitas(50).donde, 'No arranca');
  assert.strictEqual(faseDeVisitas(3000).cambio, 'algo nuevo cada 2 s');
  for (const n of [0, 100, 250, 2000, 5000, 10000]) {
    const v = faseDeVisitas(n).variante;
    assert.ok(len(v) <= 40 && v.startsWith('·'), v);
  }
});

test('apuntarVisitas guarda la visita y el cambio; la misión lo lleva y al completarla se borra', () => {
  const d = diaDonde((x) => !gancho4(x) && !tec2(x));
  let s = enTest(d);
  s = apuntarVisitas(s, 'p1', 300, at(d));
  assert.deepStrictEqual(s.products[0].visitas, [{ dia: d, visitas: 300, fase: 'gancho' }]);
  assert.strictEqual(s.products[0].siguienteCambio, '· cambia solo el gancho');
  const m = primerVideo(s, d);
  assert.ok(m.text.endsWith(' · cambia solo el gancho'));
  const s2 = completeMission(s, m.id, at(d), EXTRA);
  assert.strictEqual(s2.products[0].siguienteCambio, null);
  assert.ok(!primerVideo(s2, d).text.includes('gancho'));
});

test('siguienteCambio gana a la técnica y al gancho guardado', () => {
  const d = diaDonde((x) => gancho4(x) && tec2(x));
  let s = enTest(d);
  s.xp = 5000;
  s = guardarGancho(s, 'p1', 'Esto no lo sabías', 6000, at(d));
  s = apuntarVisitas(s, 'p1', 3000, at(d));
  const m = primerVideo(s, d);
  assert.ok(m.text.endsWith('· algo nuevo cada 2 segundos'));
  assert.ok(!m.text.includes('gancho «'));
  assert.strictEqual(m.tecnica, undefined);
});

test('el gancho guardado gana a la técnica y se recorta a 60 caracteres', () => {
  const d = diaDonde((x) => gancho4(x) && tec2(x));
  const base = enTest(d);
  base.xp = 5000;
  const s = guardarGancho(base, 'p1', 'Esto no lo sabías', 6000, at(d));
  const m = primerVideo(s, d);
  assert.ok(m.text.endsWith('· reutiliza tu gancho «Esto no lo sabías»'));
  assert.strictEqual(m.tecnica, undefined);
  const largo = guardarGancho(base, 'p1', 'x'.repeat(80), 6000, at(d));
  const suf = '· ' + primerVideo(largo, d).text.split(' · ')[1];
  assert.strictEqual(len(suf), 60);
  assert.ok(suf.endsWith('»'));
});

test('sin gancho ese día, la técnica sigue funcionando', () => {
  const d = diaDonde((x) => !gancho4(x) && tec2(x));
  let s = enTest(d);
  s.xp = 5000;
  s = guardarGancho(s, 'p1', 'Algo', 6000, at(d));
  assert.ok(primerVideo(s, d).tecnica);
});

test('guardarGancho recorta a 80, ignora vacíos y pideGancho desde 5000', () => {
  const d = '2026-11-10';
  const s = guardarGancho(enTest(d), 'p1', 'y'.repeat(120), 7000, at(d));
  assert.strictEqual(len(s.ganchos[0].texto), 80);
  assert.deepStrictEqual({ ...s.ganchos[0], texto: '' }, { texto: '', producto: 'p1', visitas: 7000, dia: d });
  assert.strictEqual(guardarGancho(s, 'p1', '   ', 1, at(d)).ganchos.length, 1);
  assert.strictEqual(pideGancho(4999), false);
  assert.strictEqual(pideGancho(5000), true);
  assert.deepStrictEqual(parseState(JSON.stringify({ version: 1, products: [], today: {} })).ganchos, []);
});

test('recomendacionDia14', () => {
  assert.strictEqual(recomendacionDia14(true, true, true), 'seguir');
  assert.strictEqual(recomendacionDia14(false, true, true), 'soltar');
  assert.strictEqual(recomendacionDia14(true, false, true), 'soltar');
  assert.strictEqual(recomendacionDia14(true, true, false), 'soltar');
});

test('resumenDescarte con plurales correctos', () => {
  const d = '2026-11-10';
  let s = enTest(d);
  Object.assign(s.products[0], { videos: 3, tecnicasPracticadas: ['t01', 't02'] });
  s = guardarGancho(s, 'p1', 'Hola', 6000, at(d));
  s = guardarGancho(s, 'p2', 'Otro', 6000, at(d));
  assert.strictEqual(resumenDescarte(s, 'p1'), 'Te llevas: 3 vídeos · 2 técnicas practicadas · 1 gancho guardado');
  Object.assign(s.products[0], { videos: 1, tecnicasPracticadas: ['t01'] });
  assert.strictEqual(resumenDescarte(s, 'p1'), 'Te llevas: 1 vídeo · 1 técnica practicada · 1 gancho guardado');
  s.products[0].videos = 0;
  assert.ok(resumenDescarte(s, 'p1').startsWith('Te llevas: 0 vídeos'));
});

test('avisoCopia y copia en createProduct', () => {
  assert.strictEqual(avisoCopia(true, true, true), null);
  assert.strictEqual(typeof avisoCopia(true, false, true), 'string');
  assert.strictEqual(typeof avisoCopia(false, false, false), 'string');
  const n = createProduct(newState(), { name: 'A', place: 'casa' }).products[0];
  assert.strictEqual(n.copia, null);
  assert.deepStrictEqual(n.visitas, []);
  assert.strictEqual(n.siguienteCambio, null);
  assert.strictEqual(createProduct(newState(), { name: 'A', place: 'casa', copia: true }).products[0].copia, true);
  assert.strictEqual(createProduct(newState(), { name: 'A', place: 'casa', copia: false }).products[0].copia, false);
});

test('entradas inválidas: sin cambios o null', () => {
  const d = '2026-11-10';
  const s = enTest(d);
  assert.deepStrictEqual(apuntarVisitas(s, 'p1', NaN, at(d)), s);
  assert.deepStrictEqual(apuntarVisitas(s, 'p1', -3, at(d)), s);
  assert.deepStrictEqual(apuntarVisitas(s, 'p9', 300, at(d)), s);
  assert.deepStrictEqual(guardarGancho(s, 'p9', 'Hola', 6000, at(d)), s);
  assert.deepStrictEqual(guardarGancho(s, 'p1', 'Hola', 'mucho', at(d)), s);
  assert.strictEqual(resumenDescarte(s, 'p9'), null);
  assert.ok(avisoCopia(false, false, false).includes('sin margen'));
});
