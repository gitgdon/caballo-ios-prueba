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
  const r = accion(json, 'facturacion', ['22500']);
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

// ── Ronda 4 ──

test('vista: favoritas, frasesConfig, misTecnicas, fraseIds, enviadasHoy y empujar por defecto', () => {
  const v = vista(null);
  assert.deepStrictEqual(v.favoritas, []);
  assert.deepStrictEqual(v.frasesConfig, { activos: true, cadaHoras: 3, desde: '10:00', hasta: '22:00', soloFavoritas: false, sonido: false });
  assert.deepStrictEqual(v.misTecnicas, []);
  const ids = JSON.parse(ctx.frasesTodas()).map((f) => f.id);
  assert.strictEqual(v.fraseIds.length, 477);
  assert.deepStrictEqual(v.fraseIds, ids);
  // A las 10:00 del test el aviso de las 10:00 aún no ha salido.
  assert.deepStrictEqual(v.enviadasHoy, []);
  assert.ok(v.empujar.length > 100 && v.empujar.length < 477);
  for (const id of v.empujar) assert.ok(v.fraseIds.includes(id));
});

test('vista.enviadasHoy: las frases de hoy anteriores a ahora, la más reciente primero', () => {
  const c = contexto(at(HOY, 17));
  const v = JSON.parse(c.vista(null));
  assert.deepStrictEqual(v.enviadasHoy.map((f) => f.fecha), ['2026-10-27T16:00', '2026-10-27T13:00', '2026-10-27T10:00']);
  for (const f of v.enviadasHoy) assert.deepStrictEqual(Object.keys(f).sort(), ['fecha', 'fraseId']);
});

test('frasesTodas: id, texto, autor, categoria, detalle y título del vídeo', () => {
  const todas = JSON.parse(ctx.frasesTodas());
  assert.strictEqual(todas.length, 477);
  for (const f of todas) {
    assert.deepStrictEqual(Object.keys(f).sort(), ['autor', 'categoria', 'detalle', 'id', 'texto', 'video']);
    for (const k of Object.keys(f)) assert.strictEqual(typeof f[k], 'string', f.id + '.' + k);
  }
  assert.strictEqual(todas[0].id, 'f001');
  assert.strictEqual(todas[0].video, 'John Ruiz, abogado billonario (Gables Estates)');
});

test('favorita: añade y quita; vista.favoritas lo refleja', () => {
  let json = accion(null, 'favorita', ['f001']).estado;
  json = accion(json, 'favorita', ['f002']).estado;
  assert.deepStrictEqual(vista(json).favoritas, ['f001', 'f002']);
  json = accion(json, 'favorita', ['f001']).estado;
  assert.deepStrictEqual(vista(json).favoritas, ['f002']);
});

test('frasesConfig: JSON válido cambia; JSON roto o valores malos no cambian nada', () => {
  let json = accion(null, 'frasesConfig', [JSON.stringify({ cadaHoras: 2, desde: '09:00', soloFavoritas: true, sonido: true })]).estado;
  assert.deepStrictEqual(vista(json).frasesConfig, { activos: true, cadaHoras: 2, desde: '09:00', hasta: '22:00', soloFavoritas: true, sonido: true });
  const antes = vista(json).frasesConfig;
  for (const malo of ['{', '', 'null', '"x"', JSON.stringify({ cadaHoras: 9, desde: '25:00', activos: 'no' })]) {
    json = accion(json, 'frasesConfig', [malo]).estado;
    assert.deepStrictEqual(vista(json).frasesConfig, antes, malo);
  }
  json = accion(json, 'frasesConfig', []).estado;
  assert.deepStrictEqual(vista(json).frasesConfig, antes);
});

test('vista.frasesConfig y favoritas: un estado guardado roto sale con tipos válidos', () => {
  const s = JSON.parse(accion(null, 'favorita', ['f001']).estado);
  s.frasesConfig = { activos: 'x', cadaHoras: 2.5, desde: 'a', hasta: 'b', soloFavoritas: 1, sonido: null };
  s.favoritas = ['f001', 3, null];
  const v = vista(JSON.stringify(s));
  assert.deepStrictEqual(v.frasesConfig, { activos: true, cadaHoras: 3, desde: '10:00', hasta: '22:00', soloFavoritas: false, sonido: false });
  assert.deepStrictEqual(v.favoritas, ['f001']);
});

test('empujar: con soloFavoritas y 3 favoritas son esas', () => {
  let json = null;
  for (const id of ['f003', 'f001', 'f002']) json = accion(json, 'favorita', [id]).estado;
  json = accion(json, 'frasesConfig', [JSON.stringify({ soloFavoritas: true })]).estado;
  assert.deepStrictEqual(vista(json).empujar, ['f001', 'f002', 'f003']);
});

test('avisosFrases(json): array de avisos de frase con fraseId', () => {
  const plan = JSON.parse(ctx.avisosFrases(null));
  assert.ok(Array.isArray(plan) && plan.length > 0);
  for (const a of plan) {
    assert.strictEqual(a.tipo, 'frase');
    assert.match(a.fraseId, /^f\d{3}$/);
    assert.match(a.fecha, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
  }
  const off = accion(null, 'frasesConfig', [JSON.stringify({ activos: false })]).estado;
  assert.deepStrictEqual(JSON.parse(ctx.avisosFrases(off)), []);
});

test('borrarProducto y renombrarProducto', () => {
  let json = accion(null, 'nuevo', ['Lámpara', 'casa']).estado;
  json = accion(json, 'nuevo', ['Taza', 'casa']).estado;
  json = accion(json, 'renombrarProducto', ['p1', '  Lámpara azul ']).estado;
  assert.strictEqual(vista(json).productos[0].nombre, 'Lámpara azul');
  assert.strictEqual(accion(json, 'renombrarProducto', ['p1', '   ']).estado, json);
  const r = accion(json, 'borrarProducto', ['p1']);
  assert.strictEqual(r.checkpoint, null);
  assert.strictEqual(r.ganador, null);
  assert.deepStrictEqual(vista(r.estado).productos.map((p) => p.id), ['p2']);
  assert.strictEqual(accion(r.estado, 'borrarProducto', ['p9']).estado, r.estado);
});

test('decidir descartar de un producto borrado: checkpoint null', () => {
  const s = JSON.parse(enTest('2026-10-01', 4));
  s.products[0].status = 'decision';
  const json = accion(JSON.stringify(s), 'borrarProducto', ['p1']).estado;
  const r = accion(json, 'decidir', ['p1', 'descartar']);
  assert.strictEqual(r.checkpoint, null);
  assert.strictEqual(r.estado, json);
  for (const [nombre, args] of [['ganador', ['p1']], ['viral', ['p1', 'tiktok']], ['vendido', ['p1']], ['decidir', ['p1', 'poco']]]) {
    const x = accion(json, nombre, args);
    assert.strictEqual(x.estado, json, nombre);
    assert.strictEqual(x.ganador, null, nombre);
  }
});

test('editarGasto: índice, importe y concepto como texto', () => {
  let json = accion(null, 'gasto', ['12.5', 'Envío']).estado;
  json = accion(json, 'editarGasto', ['0', '20.25', 'Muestras']).estado;
  const m = JSON.parse(json).movimientos[0];
  assert.strictEqual(m.concepto, 'Muestras');
  assert.strictEqual(m.importe, 20.25);
  for (const args of [['0', 'abc', 'X'], ['0', '', 'X'], ['', '5', 'X'], ['7', '5', 'X'], ['0', '-3', 'X']]) {
    assert.strictEqual(accion(json, 'editarGasto', args).estado, json, args.join('|'));
  }
});

test('editarGancho y borrarGancho por índice', () => {
  let json = accion(null, 'nuevo', ['Lámpara', 'casa']).estado;
  json = accion(json, 'gancho', ['p1', 'Primero', '5000']).estado;
  json = accion(json, 'gancho', ['p1', 'Segundo', '6000']).estado;
  json = accion(json, 'editarGancho', ['1', 'Segundo bueno']).estado;
  assert.deepStrictEqual(vista(json).ganchos.map((g) => g.texto), ['Primero', 'Segundo bueno']);
  assert.strictEqual(accion(json, 'editarGancho', ['x', 'Nada']).estado, json);
  json = accion(json, 'borrarGancho', ['0']).estado;
  assert.deepStrictEqual(vista(json).ganchos.map((g) => g.texto), ['Segundo bueno']);
  assert.strictEqual(accion(json, 'borrarGancho', ['']).estado, json);
});

test('miTecnica, editarMiTecnica y borrarMiTecnica; vista.misTecnicas', () => {
  let json = accion(null, 'nuevo', ['Lámpara', 'casa']).estado;
  json = accion(json, 'miTecnica', ['Gancho con pregunta', 'p1']).estado;
  json = accion(json, 'miTecnica', ['Luz natural', '']).estado;
  assert.strictEqual(accion(json, 'miTecnica', ['Nada', 'p9']).estado, json);
  assert.strictEqual(accion(json, 'miTecnica', ['   ', '']).estado, json);
  assert.deepStrictEqual(vista(json).misTecnicas, [
    { id: 'mt1', texto: 'Gancho con pregunta', producto: 'p1', dia: HOY },
    { id: 'mt2', texto: 'Luz natural', producto: null, dia: HOY },
  ]);
  json = accion(json, 'editarMiTecnica', ['mt2', 'Luz de ventana']).estado;
  assert.strictEqual(vista(json).misTecnicas[1].texto, 'Luz de ventana');
  json = accion(json, 'borrarMiTecnica', ['mt1']).estado;
  assert.deepStrictEqual(vista(json).misTecnicas.map((m) => m.id), ['mt2']);
});

test('vista.misTecnicas: producto borrado se mantiene como id; campos rotos salen como texto', () => {
  let json = accion(null, 'nuevo', ['Lámpara', 'casa']).estado;
  json = accion(json, 'miTecnica', ['Gancho', 'p1']).estado;
  json = accion(json, 'borrarProducto', ['p1']).estado;
  assert.strictEqual(vista(json).misTecnicas[0].producto, 'p1');
  const s = JSON.parse(json);
  s.misTecnicas.push({ id: 5, texto: null, producto: 3 });
  assert.deepStrictEqual(vista(JSON.stringify(s)).misTecnicas[1], { id: '5', texto: '', producto: '3', dia: '' });
});
