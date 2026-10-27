'use strict';
const test = require('node:test');
const assert = require('node:assert');
const {
  newState, createProduct, rollDay, pendingMissions, completeMission, skipToday, startMinimo,
  normalizeState, parseState, MINIMO_TEXT, planAvisos, configurarAvisos, AVISO_CATEGORIAS,
} = require('../Resources/core.js');
const { FRASES } = require('../Resources/frases.js');
const { TECNICAS } = require('../Resources/tecnicas.js');

const at = (day, hour, min = 0) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, min, 0);
};

const HOY = '2026-10-27';
const MANANA = '2026-10-28';
const CALLE_PREFIJO = 'Solo 3 tomas de prueba, no se publican · ';

// Día 10 del test: 3 vídeos + métricas. Con 1 vídeo publicado (sin modo primer vídeo).
function estado(patch = {}, place = 'casa', hora = '18:00', now = at(HOY, 10)) {
  let s = createProduct(newState(), { name: 'Lámpara', place });
  Object.assign(s.products[0], { status: 'test', testStartDay: '2026-10-18', videos: 1 }, patch);
  s = rollDay(s, now);
  return configurarAvisos(s, true, hora);
}

const linea = (a, n) => a.cuerpo.split('\n')[n];
const deDia = (plan, day) => plan.filter((a) => a.fecha.startsWith(day));
const fraseDe = (a) => FRASES.find((f) => f.texto === linea(a, 0));

test('estado: avisos por defecto activos a las 18:00, también en estados viejos', () => {
  assert.deepStrictEqual(newState().avisos, { activos: true, hora: '18:00' });
  const viejo = newState();
  delete viejo.avisos;
  assert.deepStrictEqual(normalizeState(viejo).avisos, { activos: true, hora: '18:00' });
  assert.deepStrictEqual(parseState(JSON.stringify(viejo)).avisos, { activos: true, hora: '18:00' });
  assert.deepStrictEqual(AVISO_CATEGORIAS, ['verguenza', 'accion', 'imperfecto']);
});

test('configurarAvisos valida HH:MM y no muta', () => {
  const s0 = newState();
  const s = configurarAvisos(s0, false, '07:05');
  assert.deepStrictEqual(s0.avisos, { activos: true, hora: '18:00' });
  assert.deepStrictEqual(s.avisos, { activos: false, hora: '07:05' });
  for (const mala of ['24:00', '18:60', '8:00', '18:0', 'abc', null, 1800]) {
    assert.strictEqual(configurarAvisos(s, true, mala).avisos.hora, '07:05', String(mala));
  }
  assert.strictEqual(configurarAvisos(s, true, 'x').avisos.activos, true);
  assert.strictEqual(configurarAvisos(s, true, '23:59').avisos.hora, '23:59');
  assert.strictEqual(configurarAvisos(s, true, '00:00').avisos.hora, '00:00');
});

test('hora 18:00 a las 10:00 con 3 vídeos: hoy y mañana a las 18:00 y 21:00', () => {
  const s = estado();
  const now = at(HOY, 10);
  const plan = planAvisos(s, now, FRASES);
  assert.deepStrictEqual(plan.map((a) => a.id), [
    'aviso-2026-10-27-1800', 'aviso-2026-10-27-2100', 'aviso-2026-10-28-1800', 'aviso-2026-10-28-2100',
  ]);
  assert.deepStrictEqual(plan.map((a) => a.fecha), [
    '2026-10-27T18:00', '2026-10-27T21:00', '2026-10-28T18:00', '2026-10-28T21:00',
  ]);
  assert.strictEqual(new Set(plan.map((a) => a.id)).size, plan.length);
  assert.deepStrictEqual(plan.map((a) => a.tipo), ['grabar', 'repetir', 'grabar', 'repetir']);
  for (const a of plan) {
    assert.strictEqual(a.titulo, 'Caballo Blanco');
    assert.strictEqual(a.misionId, 'p1:video:1');
    assert.strictEqual(a.cuerpo.split('\n').length, 2);
  }
  assert.strictEqual(linea(plan[0], 1), pendingMissions(s, now).find((m) => m.kind === 'video').text);
  assert.strictEqual(linea(plan[1], 1), 'Te quedan 3 vídeos hoy · ' + linea(plan[0], 1));
});

test('la frase es de las categorías de aviso, no se repite en el día y no es la frase del día', () => {
  const s = estado();
  const plan = planAvisos(s, at(HOY, 10), FRASES);
  for (const a of plan) {
    const q = fraseDe(a);
    assert.ok(q, a.id);
    assert.ok(AVISO_CATEGORIAS.includes(q.categoria), a.id + ' ' + q.categoria);
  }
  for (const day of [HOY, MANANA]) {
    const l = deDia(plan, day).map((a) => linea(a, 0));
    assert.strictEqual(new Set(l).size, l.length, day);
  }
  // Con 3 frases y una de ellas como frase del día, los 2 avisos de hoy usan las otras 2.
  const quotes = [
    { id: 'a', categoria: 'accion', texto: 'Frase A' },
    { id: 'b', categoria: 'verguenza', texto: 'Frase B' },
    { id: 'c', categoria: 'imperfecto', texto: 'Frase C' },
    { id: 'd', categoria: 'dinero', texto: 'Frase D' },
  ];
  for (const id of ['a', 'b', 'c']) {
    const s2 = Object.assign({}, s, { quote: { day: HOY, id } });
    const hoy = deDia(planAvisos(s2, at(HOY, 10), quotes), HOY).map((a) => linea(a, 0)).sort();
    assert.deepStrictEqual(hoy, ['Frase A', 'Frase B', 'Frase C'].filter((t) => t !== 'Frase ' + id.toUpperCase()));
  }
});

test('es estable: recalcular a otra hora da los mismos textos para los avisos que quedan', () => {
  const s = estado();
  const a = planAvisos(s, at(HOY, 10), FRASES);
  const b = planAvisos(s, at(HOY, 19), FRASES);
  assert.deepStrictEqual(b, a.slice(1));
});

test('a las 19:00 solo sale 21:00 de hoy', () => {
  const plan = planAvisos(estado(), at(HOY, 19), FRASES);
  assert.deepStrictEqual(deDia(plan, HOY).map((a) => a.id), ['aviso-2026-10-27-2100']);
  assert.strictEqual(deDia(plan, MANANA).length, 2);
});

test('el texto de la repetición cuenta los vídeos que quedan y lleva el siguiente', () => {
  let s = estado();
  s = completeMission(s, 'p1:video:1', at(HOY, 11));
  const plan = planAvisos(s, at(HOY, 12), FRASES);
  const [g, r] = deDia(plan, HOY);
  assert.strictEqual(g.misionId, 'p1:video:2');
  assert.ok(linea(r, 1).startsWith('Te quedan 2 vídeos hoy · Graba y sube 1 vídeo de Lámpara'));
  s = completeMission(s, 'p1:video:2', at(HOY, 13));
  const r1 = deDia(planAvisos(s, at(HOY, 14), FRASES), HOY)[1];
  assert.strictEqual(r1.misionId, 'p1:video:3');
  assert.ok(linea(r1, 1).startsWith('Te quedan 1 vídeo hoy · '));
});

test('tras completar todos los vídeos de hoy no queda aviso de hoy y siguen los de mañana', () => {
  let s = estado();
  for (const id of ['p1:video:1', 'p1:video:2', 'p1:video:3']) s = completeMission(s, id, at(HOY, 11));
  const plan = planAvisos(s, at(HOY, 12), FRASES);
  assert.strictEqual(deDia(plan, HOY).length, 0);
  assert.deepStrictEqual(deDia(plan, MANANA).map((a) => a.id), ['aviso-2026-10-28-1800', 'aviso-2026-10-28-2100']);
  assert.strictEqual(deDia(plan, MANANA)[0].misionId, 'p1:video:1');
});

test('completar una misión de métricas no cambia nada', () => {
  const s = estado();
  const s2 = completeMission(s, 'p1:metricas', at(HOY, 11));
  assert.ok(s2.today.done.includes('p1:metricas'));
  assert.deepStrictEqual(planAvisos(s2, at(HOY, 12), FRASES), planAvisos(s, at(HOY, 12), FRASES));
});

test('un día saltado o en Lo mínimo no tiene avisos', () => {
  const saltado = skipToday(estado(), at(HOY, 11));
  let plan = planAvisos(saltado, at(HOY, 12), FRASES);
  assert.strictEqual(deDia(plan, HOY).length, 0);
  assert.strictEqual(deDia(plan, MANANA).length, 2);
  const minimo = startMinimo(estado(), at(HOY, 11));
  assert.strictEqual(minimo.today.minimo, true);
  plan = planAvisos(minimo, at(HOY, 12), FRASES);
  assert.strictEqual(deDia(plan, HOY).length, 0);
  assert.strictEqual(deDia(plan, MANANA).length, 2);
});

function conRacha(hora) {
  const s = estado({}, 'casa', hora);
  s.streak = Object.assign(s.streak, { current: 12, best: 12, lastDay: '2026-10-26', countedDay: '2026-10-26' });
  return s;
}

test('racha 12 y nada hecho con hora 16:00: 16 grabar, 19 repetir, 22 racha', () => {
  const plan = planAvisos(conRacha('16:00'), at(HOY, 10), FRASES);
  const hoy = deDia(plan, HOY);
  assert.deepStrictEqual(hoy.map((a) => a.id), ['aviso-2026-10-27-1600', 'aviso-2026-10-27-1900', 'aviso-2026-10-27-2200']);
  assert.deepStrictEqual(hoy.map((a) => a.tipo), ['grabar', 'repetir', 'racha']);
  assert.strictEqual(hoy[2].cuerpo, 'Tu racha de 12 días se acaba hoy.\n' + MINIMO_TEXT);
  assert.strictEqual(hoy[2].misionId, null);
  assert.strictEqual(hoy[2].titulo, 'Caballo Blanco');
  // Mañana no hay aviso de racha: la de 22:00 es una repetición normal.
  assert.deepStrictEqual(deDia(plan, MANANA).map((a) => a.tipo), ['grabar', 'repetir', 'repetir']);
});

test('racha con hora 18:00: el aviso de racha se suma a las 22:00', () => {
  const hoy = deDia(planAvisos(conRacha('18:00'), at(HOY, 10), FRASES), HOY);
  assert.deepStrictEqual(hoy.map((a) => a.fecha), ['2026-10-27T18:00', '2026-10-27T21:00', '2026-10-27T22:00']);
  assert.deepStrictEqual(hoy.map((a) => a.tipo), ['grabar', 'repetir', 'racha']);
});

test('racha: con algo hecho, o pasadas las 22:00, no sale', () => {
  const s = completeMission(conRacha('16:00'), 'p1:metricas', at(HOY, 11));
  const hoy = deDia(planAvisos(s, at(HOY, 12), FRASES), HOY);
  assert.deepStrictEqual(hoy.map((a) => a.tipo), ['grabar', 'repetir', 'repetir']);
  assert.strictEqual(deDia(planAvisos(conRacha('16:00'), at(HOY, 22, 30), FRASES), HOY).length, 0);
});

test('con hora 22:30 sale un solo aviso por día', () => {
  const plan = planAvisos(estado({}, 'casa', '22:30'), at(HOY, 10), FRASES);
  assert.deepStrictEqual(plan.map((a) => a.id), ['aviso-2026-10-27-2230', 'aviso-2026-10-28-2230']);
  assert.deepStrictEqual(plan.map((a) => a.tipo), ['grabar', 'grabar']);
});

test('producto de calle: la línea 2 empieza por "Solo 3 tomas"', () => {
  const plan = planAvisos(estado({}, 'calle'), at(HOY, 10), FRASES);
  assert.strictEqual(plan.length, 4);
  for (const a of plan) assert.ok(linea(a, 1).startsWith(CALLE_PREFIJO), linea(a, 1));
  assert.ok(linea(plan[1], 1).startsWith(CALLE_PREFIJO + 'Te quedan 3 vídeos hoy · '));
});

test('modo primer vídeo: la frase es de imperfecto o accion y la misión es el ensayo', () => {
  const s = estado({ videos: 0 });
  const plan = planAvisos(s, at(HOY, 10), FRASES);
  assert.strictEqual(plan.length, 4);
  for (const a of plan) {
    const q = fraseDe(a);
    assert.ok(['imperfecto', 'accion'].includes(q.categoria), q.categoria);
    assert.strictEqual(a.misionId, 'p1:primer:1');
  }
  assert.ok(linea(plan[1], 1).startsWith('Te quedan 1 vídeo hoy · '));
});

test('usa extra: el texto coincide con la misión que ve la app (técnicas)', () => {
  const extra = { tecnicas: TECNICAS, encuentros: [] };
  // Busca un día con técnica en la misión.
  let found = false;
  for (let i = 0; i < 20 && !found; i++) {
    const day = '2026-11-' + String(i + 1).padStart(2, '0');
    const s = estado({ testStartDay: '2026-10-20' }, 'casa', '18:00', at(day, 10));
    const v = pendingMissions(s, at(day, 10), extra).find((m) => m.kind === 'video');
    if (!v.tecnica) continue;
    found = true;
    const a = planAvisos(s, at(day, 10), FRASES, extra)[0];
    assert.strictEqual(linea(a, 1), v.text);
    assert.notStrictEqual(linea(planAvisos(s, at(day, 10), FRASES)[0], 1), v.text);
  }
  assert.ok(found);
});

test('cambio de hora 25-10-2026: siguen a las 18:00 y 21:00 en hora local', () => {
  const s = estado({ testStartDay: '2026-10-16' }, 'casa', '18:00', at('2026-10-25', 10));
  const plan = planAvisos(s, at('2026-10-25', 10), FRASES);
  assert.deepStrictEqual(plan.map((a) => a.fecha), [
    '2026-10-25T18:00', '2026-10-25T21:00', '2026-10-26T18:00', '2026-10-26T21:00',
  ]);
  // Antes de las 18:00 locales del 25 ya no sale 18:00, después sí; la comparación con now es en hora local.
  assert.deepStrictEqual(deDia(planAvisos(s, at('2026-10-25', 17, 59), FRASES), '2026-10-25').length, 2);
  assert.deepStrictEqual(deDia(planAvisos(s, at('2026-10-25', 18, 0), FRASES), '2026-10-25').length, 1);
});

test('activos false da []', () => {
  const s = configurarAvisos(estado(), false, '18:00');
  assert.deepStrictEqual(planAvisos(s, at(HOY, 10), FRASES), []);
});
