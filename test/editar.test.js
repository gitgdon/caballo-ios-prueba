'use strict';
const test = require('node:test');
const assert = require('node:assert');
const {
  newState, createProduct, rollDay, retoInfo, primerVideoActivo, checkpointText, normalizeState,
  anadirGasto, apuntarFacturacion, guardarGancho, borrarProducto, renombrarProducto, editarGasto,
  editarGancho, borrarGancho, anadirMiTecnica, editarMiTecnica, borrarMiTecnica,
} = require('../Resources/core.js');

const at = (day) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, 12, 0, 0);
};
const NOW = at('2026-10-29');
const dos = () => createProduct(createProduct(rollDay(newState(), NOW), { name: 'A', place: 'casa' }), { name: 'B', place: 'casa' });

test('borrar un producto con vídeos no deja el reto en negativo y no toca las secretas', () => {
  let s = rollDay(createProduct(newState(), { name: 'A', place: 'casa' }), NOW);
  s = createProduct(s, { name: 'B', place: 'casa' });
  s.products[0].videos = 3;
  s.products[1].status = 'test';
  s.products[1].testStartDay = '2026-10-29';
  s.reto.base = 0;
  s.secretas = ['x'];
  const r = borrarProducto(s, 'p1', NOW);
  assert.strictEqual(retoInfo(r, NOW).videos, 0);
  assert.strictEqual(r.reto.base, 0);
  assert.strictEqual(primerVideoActivo(r, NOW), true);
  assert.deepStrictEqual(r.secretas, ['x']);
  assert.strictEqual(r.productosBorrados, 1);
});

test('borrar descuenta sus vídeos de la base y quita sus misiones hechas; conserva ganchos y XP', () => {
  let s = dos();
  s.products[0].videos = 2;
  s.products[1].videos = 1;
  s.reto.base = 2;
  s.xp = 50;
  s.today.done = ['p1:v1', 'p10:v1', 'p2:v1'];
  s.ganchos = [{ texto: 'g', producto: 'p1', visitas: 5000, dia: '2026-10-29' }];
  const r = borrarProducto(s, 'p1', NOW);
  assert.strictEqual(r.reto.base, 0);
  assert.deepStrictEqual(r.today.done, ['p10:v1', 'p2:v1']);
  assert.strictEqual(r.ganchos.length, 1);
  assert.strictEqual(r.xp, 50);
  assert.deepStrictEqual(r.products.map((p) => p.id), ['p2']);
});

test('borrar un id inexistente no hace nada', () => {
  const s = dos();
  assert.deepStrictEqual(borrarProducto(s, 'zz', NOW), s);
});

test('tras borrar p2 el siguiente es p3 y el checkpoint dice Producto 2/30', () => {
  let s = borrarProducto(dos(), 'p2', NOW);
  assert.match(checkpointText(s), /Producto 2\/30/);
  s = createProduct(s, { name: 'C', place: 'casa' });
  assert.strictEqual(s.products[s.products.length - 1].id, 'p3');
});

test('renombrar recorta y con vacío no cambia nada', () => {
  const s = dos();
  assert.strictEqual(renombrarProducto(s, 'p1', '  Nuevo  ').products[0].name, 'Nuevo');
  assert.deepStrictEqual(renombrarProducto(s, 'p1', '   '), s);
  assert.deepStrictEqual(renombrarProducto(s, 'zz', 'X'), s);
});

test('editarGasto: valida como anadirGasto y no toca ingresos', () => {
  let s = apuntarFacturacion(rollDay(newState(), NOW), 100, NOW);
  s = anadirGasto(s, 5, 'Foco', NOW);
  const g = s.movimientos.findIndex((m) => m.tipo === 'gasto');
  const e = editarGasto(s, g, 12.345, '  Trípode  ');
  assert.strictEqual(e.movimientos[g].importe, 12.35);
  assert.strictEqual(e.movimientos[g].concepto, 'Trípode');
  assert.strictEqual(editarGasto(s, g, 3, '').movimientos[g].concepto, 'Gasto');
  assert.strictEqual(editarGasto(s, g, 'x', 'a').movimientos[g].importe, 5);
  assert.strictEqual(editarGasto(s, g, 0, 'a').movimientos[g].importe, 5);
  assert.strictEqual(editarGasto(s, g, 1, 'x'.repeat(60)).movimientos[g].concepto.length, 40);
  const ing = s.movimientos.findIndex((m) => m.tipo === 'ingreso');
  assert.deepStrictEqual(editarGasto(s, ing, 9, 'a'), s);
  assert.deepStrictEqual(editarGasto(s, 99, 9, 'a'), s);
});

test('editar y borrar ganchos; índices fuera de rango no hacen nada', () => {
  let s = guardarGancho(dos(), 'p1', 'uno', 6000, NOW);
  s = guardarGancho(s, 'p1', 'dos', 7000, NOW);
  assert.strictEqual(editarGancho(s, 1, ' nuevo ').ganchos[1].texto, 'nuevo');
  assert.deepStrictEqual(editarGancho(s, 1, ' '), s);
  assert.deepStrictEqual(editarGancho(s, 5, 'x'), s);
  assert.deepStrictEqual(editarGancho(s, -1, 'x'), s);
  assert.deepStrictEqual(borrarGancho(s, 2), s);
  assert.deepStrictEqual(borrarGancho(s, -1), s);
  assert.deepStrictEqual(borrarGancho(s, 0).ganchos.map((g) => g.texto), ['dos']);
});

test('misTecnicas: CRUD, recorte a 140 e ids que no se repiten', () => {
  let s = dos();
  s = anadirMiTecnica(s, '  Gancho en 2 s  ', 'p1', NOW);
  s = anadirMiTecnica(s, 'x'.repeat(200), null, NOW);
  assert.strictEqual(s.misTecnicas[0].id, 'mt1');
  assert.strictEqual(s.misTecnicas[0].texto, 'Gancho en 2 s');
  assert.strictEqual(s.misTecnicas[0].producto, 'p1');
  assert.strictEqual(s.misTecnicas[0].dia, '2026-10-29');
  assert.strictEqual(Array.from(s.misTecnicas[1].texto).length, 140);
  assert.deepStrictEqual(anadirMiTecnica(s, '   ', null, NOW), s);
  assert.deepStrictEqual(anadirMiTecnica(s, 'a', 'p9', NOW), s);
  s = editarMiTecnica(s, 'mt1', ' Otro ');
  assert.strictEqual(s.misTecnicas[0].texto, 'Otro');
  assert.deepStrictEqual(editarMiTecnica(s, 'mt1', ' '), s);
  assert.deepStrictEqual(editarMiTecnica(s, 'zz', 'a'), s);
  s = borrarMiTecnica(s, 'mt2');
  assert.deepStrictEqual(borrarMiTecnica(s, 'zz'), s);
  s = anadirMiTecnica(s, 'tercera', null, NOW);
  assert.deepStrictEqual(s.misTecnicas.map((m) => m.id), ['mt1', 'mt3']);
});

test('un estado de la ronda 3 se normaliza con productosBorrados 0 y misTecnicas []', () => {
  const viejo = JSON.parse(JSON.stringify(newState()));
  delete viejo.productosBorrados;
  delete viejo.misTecnicas;
  delete viejo.misTecnicasN;
  const n = normalizeState(viejo);
  assert.strictEqual(n.productosBorrados, 0);
  assert.deepStrictEqual(n.misTecnicas, []);
  assert.strictEqual(n.misTecnicasN, 0);
});
