'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Carga los scripts como JavaScriptCore: globales en un solo contexto, sin require dentro.
// `new Date()` sin argumentos devuelve la hora fija del test.
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

const at = (day, hour, min = 0) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, min, 0);
};

const HOY = '2026-10-27';
const ctx = contexto(at(HOY, 10));

const vista = (json) => JSON.parse(ctx.vista(json));
const accion = (json, nombre, args = []) => {
  const r = JSON.parse(ctx.accion(json, nombre, JSON.stringify(args)));
  const s = JSON.parse(r.estado);
  assert.strictEqual(s.version, 1, nombre + ': estado válido');
  assert.ok(Array.isArray(r.logros), nombre + ': logros');
  return r;
};
const estadoDe = (r) => JSON.parse(r.estado);

// Producto en test desde `inicio`, con `videos` publicados.
function enTest(inicio, videos = 0, place = 'casa') {
  const s = estadoDe(accion(null, 'nuevo', ['Lámpara', place]));
  Object.assign(s.products[0], { status: 'test', testStartDay: inicio, videos });
  return JSON.stringify(s);
}

test('vista(null): reto, técnicas, avisos, primer vídeo y consejo por defecto', () => {
  const v = vista(null);
  assert.strictEqual(v.reto.meta, 10000);
  assert.strictEqual(v.reto.fin, '2026-12-31');
  assert.strictEqual(v.reto.facturado, 0);
  assert.strictEqual(v.tecnicas.length, 15);
  assert.deepStrictEqual(Object.keys(v.tecnicas[0]).sort(), ['desbloqueada', 'id', 'mision', 'nivel', 'texto', 'titulo']);
  assert.strictEqual(v.tecnicas[0].desbloqueada, true);
  assert.ok(v.tecnicas[0].texto.length > 0 && v.tecnicas[0].mision.length > 0);
  for (const t of v.tecnicas.slice(1)) {
    assert.strictEqual(t.desbloqueada, false);
    assert.strictEqual(t.texto, '');
    assert.strictEqual(t.mision, '');
    assert.ok(t.titulo.length > 0);
  }
  assert.strictEqual(v.tecnicasNuevas, 1);
  assert.deepStrictEqual(v.secretas, []);
  assert.deepStrictEqual(v.ganchos, []);
  assert.deepStrictEqual(v.avisos, { activos: true, hora: '18:00' });
  assert.strictEqual(v.primerVideo, false);
  assert.ok(v.consejo.texto.length > 0 && v.consejo.autor.length > 0);
  assert.deepStrictEqual(Object.keys(v.consejo).sort(), ['autor', 'texto']);
});

test('nuevo: copia si / no / vacío / sin tercer argumento', () => {
  const copia = (args) => estadoDe(accion(null, 'nuevo', args)).products[0].copia;
  assert.strictEqual(copia(['A', 'casa', 'si']), true);
  assert.strictEqual(copia(['A', 'casa', 'no']), false);
  assert.strictEqual(copia(['A', 'casa', '']), null);
  assert.strictEqual(copia(['A', 'casa']), null);
  const v = vista(accion(null, 'nuevo', ['A', 'calle', 'si']).estado);
  assert.deepStrictEqual(
    { copia: v.productos[0].copia, visitasMax: v.productos[0].visitasMax, vendido: v.productos[0].vendido, lugar: v.productos[0].lugar },
    { copia: true, visitasMax: 0, vendido: false, lugar: 'calle' }
  );
});

test('primer vídeo: vista lo marca y las misiones llevan tipo ensayo y xp', () => {
  const v = vista(enTest(HOY));
  assert.strictEqual(v.primerVideo, true);
  assert.strictEqual(typeof v.mision.xp, 'number');
  const ensayo = v.pendientes.find((m) => m.id === 'p1:primer:1');
  assert.deepStrictEqual(ensayo, { id: 'p1:primer:1', texto: 'Graba 3 tomas en casa o en el portal, sin publicarlas', bloque: 'tarde', tipo: 'ensayo', xp: 10 });
  for (const m of v.pendientes) assert.strictEqual(typeof m.xp, 'number');
});

test('hechoAviso: marca la misión si sigue pendiente; si ya está hecha, el siguiente vídeo', () => {
  let json = enTest(HOY);
  json = accion(json, 'hechoAviso', ['p1:primer:1']).estado;
  assert.deepStrictEqual(JSON.parse(json).today.done, ['p1:primer:1']);
  json = accion(json, 'hechoAviso', ['p1:primer:1']).estado;
  const s = JSON.parse(json);
  assert.ok(s.today.done.includes('p1:primer:2'));
  assert.strictEqual(s.products[0].videos, 1);

  // Día 3 (2 vídeos), con un vídeo ya publicado antes.
  let j2 = enTest('2026-10-25', 1);
  j2 = accion(j2, 'hechoAviso', ['p1:video:1']).estado;
  j2 = accion(j2, 'hechoAviso', ['p1:video:1']).estado;
  assert.deepStrictEqual(JSON.parse(j2).today.done, ['p1:video:1', 'p1:video:2']);
  // Sin vídeos pendientes: no hace nada.
  const j3 = accion(j2, 'hechoAviso', ['p1:video:1']).estado;
  assert.deepStrictEqual(JSON.parse(j3).today.done, ['p1:video:1', 'p1:video:2']);
  assert.strictEqual(JSON.parse(j3).xp, JSON.parse(j2).xp);
});

test('facturacion, reto y retoNuevo', () => {
  let json = accion(null, 'facturacion', ['2500']).estado;
  assert.strictEqual(vista(json).reto.facturado, 2500);
  json = accion(json, 'facturacion', ['']).estado;
  assert.strictEqual(vista(json).reto.facturado, 2500);
  json = accion(json, 'reto', ['15000', '2027-03-31']).estado;
  assert.deepStrictEqual([vista(json).reto.meta, vista(json).reto.fin, vista(json).reto.facturado], [15000, '2027-03-31', 2500]);
  json = accion(json, 'retoNuevo', ['20000', '2027-06-30']).estado;
  assert.deepStrictEqual([vista(json).reto.meta, vista(json).reto.fin, vista(json).reto.facturado], [20000, '2027-06-30', 0]);
  const r = accion(json, 'facturacion', ['20000']);
  assert.ok(r.logros.includes('🎯 ¡Reto cumplido!'));
  assert.deepStrictEqual(vista(r.estado).secretas, [{ id: 'reto-cumplido', nombre: 'Reto cumplido' }]);
});

test('visitas: fase y pideGancho; gancho se guarda; visitasMax', () => {
  const json = enTest('2026-10-25', 1);
  const r = accion(json, 'visitas', ['p1', '300']);
  assert.deepStrictEqual(r.fase, { fase: 'gancho', donde: 'Segundos 0–2', cambio: 'el gancho' });
  assert.strictEqual(r.pideGancho, false);
  const r2 = accion(r.estado, 'visitas', ['p1', '6000']);
  assert.strictEqual(r2.fase.fase, 'cierre');
  assert.strictEqual(r2.pideGancho, true);
  const r3 = accion(r2.estado, 'gancho', ['p1', 'Mira lo que hace', '6000']);
  assert.strictEqual(r3.fase, null);
  assert.strictEqual(r3.pideGancho, false);
  const v = vista(r3.estado);
  assert.strictEqual(v.productos[0].visitasMax, 6000);
  assert.strictEqual(v.ganchos.length, 1);
  assert.strictEqual(v.ganchos[0].texto, 'Mira lo que hace');
  assert.strictEqual(v.ganchos[0].producto, 'p1');
  assert.strictEqual(v.ganchos[0].visitas, 6000);
});

test('tecnicaVista deja tecnicasNuevas a 0', () => {
  const json = accion(null, 'tecnicaVista').estado;
  assert.strictEqual(vista(json).tecnicasNuevas, 0);
});

test('avisosConfig y avisos(json)', () => {
  const base = enTest('2026-10-25', 1);
  const plan = JSON.parse(ctx.avisos(base));
  assert.ok(Array.isArray(plan));
  assert.ok(plan.length > 0);
  for (const a of plan) assert.deepStrictEqual(Object.keys(a).sort(), ['cuerpo', 'fecha', 'id', 'misionId', 'tipo', 'titulo']);
  assert.ok(Array.isArray(JSON.parse(ctx.avisos(null))));

  let json = accion(base, 'avisosConfig', ['0', '20:00']).estado;
  assert.deepStrictEqual(vista(json).avisos, { activos: false, hora: '20:00' });
  assert.deepStrictEqual(JSON.parse(ctx.avisos(json)), []);
  json = accion(json, 'avisosConfig', ['1', '19:30']).estado;
  assert.deepStrictEqual(vista(json).avisos, { activos: true, hora: '19:30' });
});

test('decidir descartar: checkpoint + resumen del descarte', () => {
  const s = JSON.parse(enTest('2026-10-01', 4));
  s.products[0].status = 'decision';
  const r = accion(JSON.stringify(s), 'decidir', ['p1', 'descartar']);
  assert.match(r.checkpoint, /^🏁 Checkpoint guardado\. Producto 2\/30 desbloqueado\nTe llevas: 4 vídeos · 0 técnicas practicadas · 0 ganchos guardados$/);
  const r2 = accion(JSON.stringify(s), 'decidir', ['p1', 'poco']);
  assert.strictEqual(r2.checkpoint, null);
});

test('vendido aparece en la fila del producto', () => {
  const r = accion(enTest('2026-10-25', 1), 'vendido', ['p1']);
  assert.strictEqual(vista(r.estado).productos[0].vendido, true);
});

test('avisoCopia y recomendacion como funciones de puente', () => {
  assert.strictEqual(ctx.avisoCopia(true, true, true), null);
  assert.strictEqual(typeof ctx.avisoCopia(false, true, true), 'string');
  assert.strictEqual(ctx.recomendacion(true, true, true), 'seguir');
  assert.strictEqual(ctx.recomendacion(true, false, true), 'soltar');
});

test('encuentro raro: el puente pasa las técnicas y encuentros (sale en pendientes y se completa)', () => {
  let day = HOY;
  while (ctx.hashDay(day + ':raro') % 7 !== 0) day = ctx.addDays(day, 1);
  const c = contexto(at(day, 10));
  const json = enTest(ctx.addDays(day, -2), 1);
  const v = JSON.parse(c.vista(json));
  const raro = v.pendientes.find((m) => m.tipo === 'raro');
  assert.ok(raro, 'hay encuentro raro');
  assert.ok(raro.xp >= 40 && raro.xp <= 80);
  const r = JSON.parse(c.accion(json, 'hecho', JSON.stringify([raro.id])));
  const s = JSON.parse(r.estado);
  assert.ok(s.today.done.includes(raro.id));
  assert.strictEqual(s.xp, raro.xp);
});

test('visitas y gancho: decimales se redondean; 1e30 y negativos no se apuntan', () => {
  const json = enTest('2026-10-25', 1);
  const r = accion(json, 'visitas', ['p1', '6000.5']);
  assert.strictEqual(r.fase.fase, 'cierre');
  assert.strictEqual(estadoDe(r).products[0].visitas[0].visitas, 6001);
  assert.strictEqual(vista(r.estado).productos[0].visitasMax, 6001);
  for (const malo of ['1e30', '-3', 'abc']) {
    const r2 = accion(r.estado, 'visitas', ['p1', malo]);
    assert.strictEqual(r2.fase, null, malo);
    assert.strictEqual(r2.pideGancho, false, malo);
    assert.strictEqual(estadoDe(r2).products[0].visitas.length, 1, malo);
  }
  const g = accion(r.estado, 'gancho', ['p1', 'Mira', '6000.5']);
  assert.strictEqual(vista(g.estado).ganchos[0].visitas, 6001);
  for (const malo of ['1e30', '-3']) {
    assert.deepStrictEqual(estadoDe(accion(r.estado, 'gancho', ['p1', 'Mira', malo])).ganchos, [], malo);
  }
});

test('facturacion y reto: decimales se redondean; 1e30 y negativos no cambian nada', () => {
  let json = accion(null, 'facturacion', ['2500.6']).estado;
  assert.strictEqual(vista(json).reto.facturado, 2501);
  for (const malo of ['1e30', '-3']) assert.strictEqual(vista(accion(json, 'facturacion', [malo]).estado).reto.facturado, 2501, malo);
  json = accion(json, 'reto', ['15000.4', '2027-03-31']).estado;
  assert.strictEqual(vista(json).reto.meta, 15000);
  for (const malo of ['1e30', '-3']) {
    assert.strictEqual(vista(accion(json, 'reto', [malo, '2027-03-31']).estado).reto.meta, 15000, malo);
    assert.strictEqual(vista(accion(json, 'retoNuevo', [malo, '2027-03-31']).estado).reto.meta, 15000, malo);
  }
});

test('vista: un estado guardado roto sigue dando enteros y nombres', () => {
  const s = JSON.parse(enTest('2026-10-25', 1));
  s.products[0].visitas = [{ dia: '2026-10-26', visitas: 6000.5, fase: 'cierre' }, { dia: '2026-10-26', visitas: 1e30, fase: 'x' }];
  s.products[0].videos = 2.5;
  s.ganchos = [{ texto: 'Mira', producto: 'p1', visitas: 1e30, dia: '2026-10-26' }, { texto: 'Otra', producto: 'p1', visitas: -3.2, dia: '2026-10-26' }];
  s.reto = { meta: 10000.7, fin: '2026-12-31', inicio: '2026-10-01', base: 0, facturado: 1e30, cumplido: false };
  s.xp = 15.5;
  s.secretas = ['primer-video', 'de-una-version-futura'];
  const v = vista(JSON.stringify(s));
  const enteros = [
    v.nivel, v.xp, v.xpSig, v.racha, v.escudos, v.tecnicasNuevas,
    v.productos[0].visitasMax, v.productos[0].videos, v.productos[0].dia, v.productos[0].ganadores,
    v.reto.meta, v.reto.facturado, v.reto.diasQuedan, v.reto.videos,
    ...v.ganchos.map((g) => g.visitas), ...v.pendientes.map((m) => m.xp), ...v.tecnicas.map((t) => t.nivel),
  ];
  for (const n of enteros) assert.ok(Number.isSafeInteger(n), String(n));
  assert.strictEqual(v.productos[0].visitasMax, Number.MAX_SAFE_INTEGER);
  assert.strictEqual(v.ganchos[1].visitas, -3);
  assert.ok(v.reto.progreso >= 0 && v.reto.progreso <= 1);
  assert.deepStrictEqual(v.secretas, [
    { id: 'primer-video', nombre: 'Primer vídeo' },
    { id: 'de-una-version-futura', nombre: 'de-una-version-futura' },
  ]);
});
