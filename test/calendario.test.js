'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {
  newState, rollDay, parseState, retoInfo, apuntarFacturacion, anadirGasto, borrarMovimiento, calendarioMes,
} = require('../Resources/core.js');

const at = (day, hour = 12) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};

const dia = (cal, d) => cal.dias.find((x) => x.dia === d);

function base() {
  return rollDay(newState(), at('2026-10-01'));
}

test('apuntar 980 y otro día 1240 da +980 y +260 en sus días', () => {
  let s = apuntarFacturacion(base(), 980, at('2026-10-20'));
  s = apuntarFacturacion(s, 1240, at('2026-10-27'));
  const cal = calendarioMes(s, '2026-10');
  assert.strictEqual(dia(cal, '2026-10-20').ingresos, 980);
  assert.strictEqual(dia(cal, '2026-10-27').ingresos, 260);
  assert.strictEqual(dia(cal, '2026-10-27').neto, 260);
  assert.deepStrictEqual(s.movimientos[1], { dia: '2026-10-27', tipo: 'ingreso', importe: 260, concepto: 'Facturación' });
});

test('corregir a 1200 el mismo día deja el neto del día en +220', () => {
  let s = apuntarFacturacion(base(), 980, at('2026-10-20'));
  s = apuntarFacturacion(s, 1240, at('2026-10-27', 10));
  s = apuntarFacturacion(s, 1200, at('2026-10-27', 18));
  assert.strictEqual(dia(calendarioMes(s, '2026-10'), '2026-10-27').neto, 220);
});

test('apuntar el mismo total no añade movimiento; bajar el total da un ajuste negativo', () => {
  let s = apuntarFacturacion(base(), 980, at('2026-10-20'));
  s = apuntarFacturacion(s, 980, at('2026-10-21'));
  assert.strictEqual(s.movimientos.length, 1);
  s = apuntarFacturacion(s, 900, at('2026-10-22'));
  assert.strictEqual(dia(calendarioMes(s, '2026-10'), '2026-10-22').neto, -80);
});

test('un gasto de 29 en un día sin ingresos da neto −29 y cuenta como rojo', () => {
  const s = anadirGasto(base(), 29, 'Shopify', at('2026-10-05'));
  const cal = calendarioMes(s, '2026-10');
  const d = dia(cal, '2026-10-05');
  assert.strictEqual(d.gastos, 29);
  assert.strictEqual(d.neto, -29);
  assert.strictEqual(cal.rojos, 1);
  assert.strictEqual(cal.verdes, 0);
  assert.deepStrictEqual(d.movimientos, [{ indice: 0, tipo: 'gasto', importe: 29, concepto: 'Shopify' }]);
});

test('gastos con céntimos se guardan a 2 decimales y el concepto se recorta a 40', () => {
  const s = anadirGasto(base(), 29.994, '  ' + 'x'.repeat(50) + ' ', at('2026-10-05'));
  assert.strictEqual(s.movimientos[0].importe, 29.99);
  assert.strictEqual(s.movimientos[0].concepto, 'x'.repeat(40));
  const vacio = anadirGasto(base(), 5, '', at('2026-10-05'));
  assert.strictEqual(vacio.movimientos[0].concepto, 'Gasto');
});

test("calendarioMes('2026-10') tiene 31 días y total = suma de los netos", () => {
  let s = apuntarFacturacion(base(), 980, at('2026-10-20'));
  s = apuntarFacturacion(s, 1240, at('2026-10-27'));
  s = anadirGasto(s, 29.99, 'Shopify', at('2026-10-05'));
  s = anadirGasto(s, 10, 'Dominio', at('2026-10-27'));
  s = anadirGasto(s, 5, 'Otro mes', at('2026-11-02'));
  const cal = calendarioMes(s, '2026-10');
  assert.strictEqual(cal.mes, '2026-10');
  assert.strictEqual(cal.dias.length, 31);
  assert.strictEqual(cal.dias[0].dia, '2026-10-01');
  assert.strictEqual(cal.dias[30].dia, '2026-10-31');
  assert.strictEqual(cal.total, cal.dias.reduce((n, d) => n + d.neto, 0));
  assert.strictEqual(cal.total, 980 + 250 - 29.99);
  assert.strictEqual(cal.verdes, 2);
  assert.strictEqual(cal.rojos, 1);
  assert.deepStrictEqual(dia(cal, '2026-10-02'), { dia: '2026-10-02', ingresos: 0, gastos: 0, neto: 0, movimientos: [] });
});

test('calendarioMes: febrero y meses inválidos', () => {
  assert.strictEqual(calendarioMes(base(), '2026-02').dias.length, 28);
  assert.strictEqual(calendarioMes(base(), '2028-02').dias.length, 29);
  for (const malo of ['2026-13', '2026-00', '2026-1', 'abc', '', null, undefined, 202610]) {
    assert.strictEqual(calendarioMes(base(), malo), null, String(malo));
  }
});

test('anadirGasto con -5, 0 o "abc" no cambia nada', () => {
  const s = base();
  for (const malo of [-5, 0, 'abc', NaN, Infinity, 0.001, 1e300]) {
    assert.deepStrictEqual(anadirGasto(s, malo, 'X', at('2026-10-05')), s, String(malo));
  }
});

test('borrarMovimiento borra gastos pero no ingresos', () => {
  let s = apuntarFacturacion(base(), 980, at('2026-10-20'));
  s = anadirGasto(s, 29, 'Shopify', at('2026-10-20'));
  assert.deepStrictEqual(borrarMovimiento(s, 0), s);
  assert.deepStrictEqual(borrarMovimiento(s, 7), s);
  assert.deepStrictEqual(borrarMovimiento(s, 1.5), s);
  const b = borrarMovimiento(s, 1);
  assert.strictEqual(b.movimientos.length, 1);
  assert.strictEqual(b.movimientos[0].tipo, 'ingreso');
});

test('un estado sin movimientos se normaliza con []', () => {
  assert.deepStrictEqual(newState().movimientos, []);
  const viejo = newState();
  delete viejo.movimientos;
  assert.deepStrictEqual(parseState(JSON.stringify(viejo)).movimientos, []);
});

test('el reto no cambia al añadir gastos', () => {
  const s = apuntarFacturacion(base(), 980, at('2026-10-20'));
  const g = anadirGasto(s, 29, 'Shopify', at('2026-10-21'));
  assert.strictEqual(retoInfo(g, at('2026-10-21')).facturado, 980);
  assert.deepStrictEqual(g.reto, s.reto);
});

// Puente: como JavaScriptCore, con `new Date()` fijo.
function contexto(now) {
  const ctx = vm.createContext({ __now: now.getTime() });
  vm.runInContext(
    '(function () { const D = Date; class F extends D { constructor(...a) { if (a.length === 0) super(globalThis.__now); else super(...a); } static now() { return globalThis.__now; } } globalThis.Date = F; })();',
    ctx
  );
  for (const f of ['tecnicas', 'frases', 'core', 'puente']) {
    vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Resources', f + '.js'), 'utf8'), ctx, { filename: f + '.js' });
  }
  return ctx;
}

test('puente: gasto, borrarMovimiento y calendario', () => {
  const ctx = contexto(at('2026-10-27', 10));
  const accion = (json, nombre, args) => JSON.parse(ctx.accion(json, nombre, JSON.stringify(args))).estado;
  let json = accion(null, 'facturacion', ['1240']);
  json = accion(json, 'gasto', ['29.99', 'Shopify']);
  json = accion(json, 'gasto', ['', 'Nada']);
  json = accion(json, 'gasto', ['abc', 'Nada']);
  let cal = JSON.parse(ctx.calendario(json, '2026-10'));
  let d = cal.dias.find((x) => x.dia === '2026-10-27');
  assert.strictEqual(d.neto, 1210.01);
  assert.strictEqual(d.movimientos.length, 2);
  json = accion(json, 'borrarMovimiento', ['0']);
  json = accion(json, 'borrarMovimiento', ['1']);
  cal = JSON.parse(ctx.calendario(json, '2026-10'));
  d = cal.dias.find((x) => x.dia === '2026-10-27');
  assert.strictEqual(d.neto, 1240);
  assert.strictEqual(ctx.calendario(json, 'malo'), 'null');
});

// Ruling (a): un reto nuevo no vuelve a contar lo ya facturado.
const { nuevoReto } = require('../Resources/core.js');

test('total 5000, reto nuevo y total 5200: ingreso +200 y facturado 200', () => {
  let s = apuntarFacturacion(base(), 5000, at('2026-10-20'));
  s = nuevoReto(s, 10000, '2027-01-31', at('2026-10-21'));
  assert.strictEqual(s.reto.baseFacturacion, 5000);
  s = apuntarFacturacion(s, 5200, at('2026-10-22'));
  const cal = calendarioMes(s, '2026-10');
  assert.strictEqual(dia(cal, '2026-10-22').ingresos, 200);
  assert.strictEqual(dia(cal, '2026-10-20').ingresos, 5000);
  assert.strictEqual(s.movimientos.length, 2);
  assert.strictEqual(s.reto.facturado, 200);
  assert.strictEqual(s.ultimoTotal, 5200);
});

test('tras un reto nuevo, corregir por debajo de la base: ingreso −400 y facturado 0', () => {
  let s = apuntarFacturacion(base(), 5000, at('2026-10-20'));
  s = nuevoReto(s, 10000, '2027-01-31', at('2026-10-21'));
  s = apuntarFacturacion(s, 5200, at('2026-10-22'));
  const cumplido = s.reto.cumplido;
  s = apuntarFacturacion(s, 4800, at('2026-10-23'));
  assert.strictEqual(dia(calendarioMes(s, '2026-10'), '2026-10-23').ingresos, -400);
  assert.strictEqual(s.reto.facturado, 0);
  assert.strictEqual(s.reto.cumplido, cumplido);
});

test('migración: reto.facturado 2500 sin ultimoTotal da ultimoTotal 2500 y base 0; idempotente', () => {
  const viejo = rollDay(newState(), at('2026-10-01'));
  viejo.reto.facturado = 2500;
  delete viejo.reto.baseFacturacion;
  delete viejo.ultimoTotal;
  const s = parseState(JSON.stringify(viejo));
  assert.strictEqual(s.ultimoTotal, 2500);
  assert.strictEqual(s.reto.baseFacturacion, 0);
  assert.deepStrictEqual(parseState(JSON.stringify(s)), s);
  const n = apuntarFacturacion(s, 2600, at('2026-10-27'));
  assert.strictEqual(n.movimientos[n.movimientos.length - 1].importe, 100);
  assert.strictEqual(n.reto.facturado, 2600);
});

test('estado roto: reto.facturado 1e30 da ultimoTotal 0', () => {
  const viejo = rollDay(newState(), at('2026-10-01'));
  viejo.reto.facturado = 1e30;
  delete viejo.ultimoTotal;
  assert.strictEqual(parseState(JSON.stringify(viejo)).ultimoTotal, 0);
});

test('puente: facturacion 2500, retoNuevo, facturacion 2600 → facturado 100 y ultimoTotal 2600', () => {
  const ctx = contexto(at('2026-10-27', 10));
  const accion = (json, nombre, args) => JSON.parse(ctx.accion(json, nombre, JSON.stringify(args))).estado;
  let json = accion(null, 'facturacion', ['2500']);
  json = accion(json, 'retoNuevo', ['20000', '2027-06-30']);
  json = accion(json, 'facturacion', ['2600']);
  const v = JSON.parse(ctx.vista(json));
  assert.strictEqual(v.reto.facturado, 100);
  assert.strictEqual(v.ultimoTotal, 2600);
});
