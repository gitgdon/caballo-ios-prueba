'use strict';
const test = require('node:test');
const assert = require('node:assert');
const {
  newState, createProduct, rollDay, normalizeState, parseState, pickDailyQuote, planAvisos, configurarAvisos,
  pendingMissions, completeMission, skipToday, startMinimo,
  FRASE_CATEGORIAS, PALABRAS_DINERO, frasesParaEmpujar, alternarFavorita, configurarFrases, planFrases,
  frasesDeHoyEnviadas, recortarFrases,
} = require('../Resources/core.js');
const { FRASES } = require('../Resources/frases.js');
const { TECNICAS } = require('../Resources/tecnicas.js');

const at = (day, hour, min = 0) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, min, 0);
};

const HOY = '2026-10-27';
const MANANA = '2026-10-28';
const EXTRA = { tecnicas: TECNICAS };
const DEFECTO = { activos: true, cadaHoras: 3, desde: '10:00', hasta: '22:00', soloFavoritas: false, sonido: false };

const sinTildes = (t) => t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
const horas = (plan, day) => plan.filter((f) => f.fecha.startsWith(day)).map((f) => f.fecha.slice(11));
const fraseDe = (f) => FRASES.find((q) => q.id === f.fraseId);

// Día sin avisos de misión: sin productos.
const vacio = (now = at(HOY, 9)) => rollDay(newState(), now);

// Producto en día 10 del test con vídeos pendientes: hay avisos de misión a la hora dada.
function conMision(hora, now = at(HOY, 9)) {
  let s = createProduct(newState(), { name: 'Lámpara', place: 'casa' });
  Object.assign(s.products[0], { status: 'test', testStartDay: '2026-10-18', videos: 1 });
  s = rollDay(s, now);
  return configurarAvisos(s, true, hora);
}

test('constantes y estado: favoritas y frasesConfig por defecto, también en un estado de la ronda 3', () => {
  assert.deepStrictEqual(FRASE_CATEGORIAS, ['accion', 'disciplina', 'imperfecto', 'verguenza']);
  assert.deepStrictEqual(PALABRAS_DINERO, ['€', 'euro', 'dinero', 'millon', 'millonario', 'rico', 'factur', 'ganar', 'sueldo']);
  assert.deepStrictEqual(newState().favoritas, []);
  assert.deepStrictEqual(newState().frasesConfig, DEFECTO);
  const viejo = newState();
  delete viejo.favoritas;
  delete viejo.frasesConfig;
  assert.deepStrictEqual(normalizeState(JSON.parse(JSON.stringify(viejo))).favoritas, []);
  const s = parseState(JSON.stringify(viejo));
  assert.deepStrictEqual(s.favoritas, []);
  assert.deepStrictEqual(s.frasesConfig, DEFECTO);
  assert.deepStrictEqual(s.avisos, { activos: true, hora: '18:00' });
  const parcial = parseState(JSON.stringify(Object.assign(newState(), { frasesConfig: { cadaHoras: 2 } })));
  assert.deepStrictEqual(parcial.frasesConfig, Object.assign({}, DEFECTO, { cadaHoras: 2 }));
});

test('frasesParaEmpujar: solo las 4 categorías y ninguna de dinero en el texto', () => {
  const pool = frasesParaEmpujar(FRASES, newState());
  assert.ok(pool.length > 100);
  for (const q of pool) {
    assert.ok(FRASE_CATEGORIAS.includes(q.categoria), q.id);
    const t = sinTildes(q.texto);
    assert.ok(!t.includes('dinero') && !t.includes('€'), q.id);
    for (const p of PALABRAS_DINERO) assert.ok(!t.includes(p), q.id + ' ' + p);
  }
  // Las de dinero existen en esas categorías y quedan fuera; las demás entran todas.
  const enCats = FRASES.filter((q) => FRASE_CATEGORIAS.includes(q.categoria));
  assert.ok(enCats.length > pool.length);
});

test('frasesParaEmpujar: sin mayúsculas ni acentos, y solo sobre el texto', () => {
  const qs = [
    { id: 'a', categoria: 'accion', texto: 'Un MILLÓN de excusas', detalle: '' },
    { id: 'b', categoria: 'accion', texto: 'Se FACTURA solo', detalle: '' },
    { id: 'c', categoria: 'accion', texto: 'Graba hoy', detalle: 'Esto va de dinero y €' },
    { id: 'd', categoria: 'disciplina', texto: 'Cuesta 5 €', detalle: '' },
    { id: 'e', categoria: 'desde-cero', texto: 'Empieza', detalle: '' },
    { id: 'f', categoria: 'verguenza', texto: 'Euros no, vídeos', detalle: '' },
  ];
  assert.deepStrictEqual(frasesParaEmpujar(qs, newState()).map((q) => q.id), ['c']);
});

test('frasesParaEmpujar: con soloFavoritas y 3 favoritas devuelve esas 3; con 2, las categorías', () => {
  const dinero = FRASES.find((q) => sinTildes(q.texto).includes('dinero'));
  const otra = FRASES.find((q) => !FRASE_CATEGORIAS.includes(q.categoria));
  const tres = [dinero.id, otra.id, 'f010'];
  let s = configurarFrases(newState(), { soloFavoritas: true });
  for (const id of tres) s = alternarFavorita(s, id);
  assert.deepStrictEqual(frasesParaEmpujar(FRASES, s).map((q) => q.id).sort(), tres.slice().sort());
  const dos = alternarFavorita(s, 'f010');
  assert.deepStrictEqual(dos.favoritas, [dinero.id, otra.id]);
  assert.deepStrictEqual(frasesParaEmpujar(FRASES, dos), frasesParaEmpujar(FRASES, newState()));
  // Sin soloFavoritas, las favoritas no cambian nada.
  const sinSolo = configurarFrases(s, { soloFavoritas: false });
  assert.deepStrictEqual(frasesParaEmpujar(FRASES, sinSolo), frasesParaEmpujar(FRASES, newState()));
});

test('alternarFavorita añade y quita sin mutar', () => {
  const s0 = newState();
  const s1 = alternarFavorita(s0, 'f001');
  assert.deepStrictEqual(s0.favoritas, []);
  assert.deepStrictEqual(s1.favoritas, ['f001']);
  assert.deepStrictEqual(alternarFavorita(alternarFavorita(s1, 'f002'), 'f001').favoritas, ['f002']);
});

test('configurarFrases valida y, si algo no es válido, se queda el valor anterior', () => {
  const s0 = newState();
  const s = configurarFrases(s0, { activos: false, cadaHoras: 2, desde: '08:30', hasta: '21:00', soloFavoritas: true, sonido: true });
  assert.deepStrictEqual(s0.frasesConfig, DEFECTO);
  assert.deepStrictEqual(s.frasesConfig, { activos: false, cadaHoras: 2, desde: '08:30', hasta: '21:00', soloFavoritas: true, sonido: true });
  for (const c of [0, 7, 2.5, '3', null]) assert.strictEqual(configurarFrases(s, { cadaHoras: c }).frasesConfig.cadaHoras, 2, String(c));
  assert.strictEqual(configurarFrases(s, { cadaHoras: 1 }).frasesConfig.cadaHoras, 1);
  assert.strictEqual(configurarFrases(s, { cadaHoras: 6 }).frasesConfig.cadaHoras, 6);
  const igual = configurarFrases(s, { desde: '21:00' }).frasesConfig;
  assert.deepStrictEqual([igual.desde, igual.hasta], ['08:30', '21:00']);
  const despues = configurarFrases(s, { desde: '22:00', hasta: '09:00' }).frasesConfig;
  assert.deepStrictEqual([despues.desde, despues.hasta], ['08:30', '21:00']);
  assert.strictEqual(configurarFrases(s, { hasta: '25:00' }).frasesConfig.hasta, '21:00');
  assert.strictEqual(configurarFrases(s, { desde: '25:00' }).frasesConfig.desde, '08:30');
  assert.strictEqual(configurarFrases(s, { activos: 'no', sonido: 1 }).frasesConfig.activos, false);
  assert.strictEqual(configurarFrases(s, { activos: 'no', sonido: 1 }).frasesConfig.sonido, true);
  const ambas = configurarFrases(s, { desde: '00:00', hasta: '23:00' }).frasesConfig;
  assert.deepStrictEqual([ambas.desde, ambas.hasta], ['00:00', '23:00']);
});

test('planFrases por defecto a las 09:00 sin avisos de misión: 10, 13, 16, 19 y 22 de hoy y mañana', () => {
  const s = vacio();
  const now = at(HOY, 9);
  assert.deepStrictEqual(planAvisos(s, now, FRASES, EXTRA), []);
  const plan = planFrases(s, now, FRASES, EXTRA);
  const h = ['10:00', '13:00', '16:00', '19:00', '22:00'];
  assert.deepStrictEqual(horas(plan, HOY), h);
  assert.deepStrictEqual(horas(plan, MANANA), h);
  assert.strictEqual(plan.length, 10);
  assert.deepStrictEqual(plan[0].id, 'frase-2026-10-27T10:00');
  assert.deepStrictEqual(plan[9].id, 'frase-2026-10-28T22:00');
  assert.strictEqual(new Set(plan.map((f) => f.id)).size, plan.length);
  const empujan = frasesParaEmpujar(FRASES, s).map((q) => q.id);
  for (const f of plan) {
    assert.strictEqual(f.id, 'frase-' + f.fecha);
    assert.strictEqual(f.titulo, 'Caballo Blanco');
    assert.strictEqual(f.tipo, 'frase');
    const q = fraseDe(f);
    assert.ok(q && empujan.includes(q.id), f.id);
    assert.strictEqual(f.cuerpo, '"' + q.texto + '" — ' + q.autor);
  }
});

test('planFrases: solo horas posteriores a now, y estable al recalcular durante el día', () => {
  const s = vacio();
  const temprano = planFrases(s, at(HOY, 9), FRASES, EXTRA);
  const tarde = planFrases(s, at(HOY, 16), FRASES, EXTRA);
  assert.deepStrictEqual(horas(tarde, HOY), ['19:00', '22:00']);
  const resto = temprano.filter((f) => f.fecha > HOY + 'T16:00');
  assert.deepStrictEqual(tarde, resto);
  // Elegir la frase del día en la app no cambia el plan.
  const conFrase = pickDailyQuote(s, at(HOY, 9), FRASES, EXTRA);
  assert.deepStrictEqual(planFrases(conFrase, at(HOY, 9), FRASES, EXTRA), temprano);
});

test('hasta es inclusiva y cadaHoras marca el paso', () => {
  // Sin avisos de misión: si no, las 17:30 y las 21:30 caen cerca de los avisos de 18:00 y 21:00.
  const s = configurarFrases(configurarAvisos(vacio(), false, '18:00'), { cadaHoras: 4, desde: '09:30', hasta: '21:30' });
  assert.deepStrictEqual(horas(planFrases(s, at(HOY, 0), FRASES, EXTRA), HOY), ['09:30', '13:30', '17:30', '21:30']);
});

test('se salta la frase a menos de 45 minutos de un aviso de misión, antes o después', () => {
  // Aviso de misión a las 18:15 (y 21:15): las 19:00 está a 45 min, sale.
  const a = conMision('18:15');
  assert.deepStrictEqual(planAvisos(a, at(HOY, 9), FRASES, EXTRA).map((x) => x.fecha.slice(11)), ['18:15', '21:15', '18:15', '21:15']);
  assert.deepStrictEqual(horas(planFrases(a, at(HOY, 9), FRASES, EXTRA), HOY), ['10:00', '13:00', '16:00', '19:00', '22:00']);
  // Aviso a las 18:46 (y 21:46): las 19:00 y las 22:00 caen a 14 min, se saltan.
  const b = conMision('18:46');
  assert.deepStrictEqual(horas(planFrases(b, at(HOY, 9), FRASES, EXTRA), HOY), ['10:00', '13:00', '16:00']);
  assert.deepStrictEqual(horas(planFrases(b, at(HOY, 9), FRASES, EXTRA), MANANA), ['10:00', '13:00', '16:00']);
  // Aviso a las 16:30 (y 19:30): las 16:00 y las 19:00 caen 30 min antes, se saltan.
  const c = conMision('16:30');
  assert.deepStrictEqual(horas(planFrases(c, at(HOY, 9), FRASES, EXTRA), HOY), ['10:00', '13:00', '22:00']);
  // Aviso a las 18:00 (y 21:00): ninguna frase a menos de 45 min.
  const d = conMision('18:00');
  assert.deepStrictEqual(horas(planFrases(d, at(HOY, 9), FRASES, EXTRA), HOY), ['10:00', '13:00', '16:00', '19:00', '22:00']);
});

test('el salto tiene en cuenta avisos de misión ya pasados', () => {
  // A las 18:50 el aviso de 18:46 ya salió, pero las 19:00 sigue saltándose.
  const b = conMision('18:46', at(HOY, 18, 50));
  assert.deepStrictEqual(horas(planFrases(b, at(HOY, 18, 50), FRASES, EXTRA), HOY), []);
});

test('cada 1 h de 00:00 a 23:00 con avisos de misión: el total es como mucho 60', () => {
  for (const hora of ['00:00', '00:30', '07:20', '18:00']) {
    for (const now of [at(HOY, 0), at(HOY, 0, 30), at(HOY, 12)]) {
      const s = configurarFrases(conMision(hora, now), { cadaHoras: 1, desde: '00:00', hasta: '23:00' });
      const avisos = planAvisos(s, now, FRASES, EXTRA);
      const frases = planFrases(s, now, FRASES, EXTRA);
      assert.ok(avisos.length > 0);
      assert.ok(avisos.length + frases.length <= 60, hora + ' ' + (avisos.length + frases.length));
      assert.strictEqual(new Set(frases.map((f) => f.id)).size, frases.length);
    }
  }
});

test('activos false → []', () => {
  const s = configurarFrases(vacio(), { activos: false });
  assert.deepStrictEqual(planFrases(s, at(HOY, 9), FRASES, EXTRA), []);
  assert.deepStrictEqual(frasesDeHoyEnviadas(s, at(HOY, 17), FRASES, EXTRA), []);
});

test('ninguna frase se repite en un día, ni es la del día ni la de un aviso de misión', () => {
  for (const hora of ['10:00', '11:20', '18:00']) {
    const s = configurarFrases(conMision(hora, at(HOY, 0, 5)), { cadaHoras: 1, desde: '00:00', hasta: '23:00' });
    const now = at(HOY, 0, 5);
    const avisos = planAvisos(s, now, FRASES, EXTRA);
    const frases = planFrases(s, now, FRASES, EXTRA);
    const hoy = pickDailyQuote(rollDay(s, now), now, FRASES, EXTRA);
    const manana = pickDailyQuote(rollDay(hoy, at(MANANA, 0, 1)), at(MANANA, 0, 1), FRASES, EXTRA);
    const delDia = { [HOY]: hoy.quote.id, [MANANA]: manana.quote.id };
    for (const day of [HOY, MANANA]) {
      const ids = frases.filter((f) => f.fecha.startsWith(day)).map((f) => f.fraseId);
      assert.ok(ids.length > 10);
      assert.strictEqual(new Set(ids).size, ids.length, day);
      assert.ok(!ids.includes(delDia[day]), day);
      const deMision = avisos.filter((a) => a.fecha.startsWith(day)).map((a) => a.cuerpo.split('\n')[0]);
      assert.ok(deMision.length > 0);
      for (const f of frases.filter((x) => x.fecha.startsWith(day))) {
        assert.ok(!deMision.includes(fraseDe(f).texto), f.id);
      }
    }
  }
});

test('con solo favoritas salen solo de las favoritas', () => {
  let s = configurarFrases(vacio(), { soloFavoritas: true, cadaHoras: 6 });
  for (const id of ['f001', 'f002', 'f003', 'f004']) s = alternarFavorita(s, id);
  const plan = planFrases(s, at(HOY, 9), FRASES, EXTRA);
  assert.deepStrictEqual(horas(plan, HOY), ['10:00', '16:00', '22:00']);
  for (const f of plan) assert.ok(['f001', 'f002', 'f003', 'f004'].includes(f.fraseId), f.id);
});

test('frasesDeHoyEnviadas a las 17:00: las de 16:00, 13:00 y 10:00', () => {
  const s = vacio();
  const plan = planFrases(s, at(HOY, 9), FRASES, EXTRA);
  const enviadas = frasesDeHoyEnviadas(s, at(HOY, 17), FRASES, EXTRA);
  assert.deepStrictEqual(enviadas.map((e) => e.fecha), ['2026-10-27T16:00', '2026-10-27T13:00', '2026-10-27T10:00']);
  for (const e of enviadas) {
    assert.deepStrictEqual(Object.keys(e).sort(), ['fecha', 'fraseId']);
    assert.strictEqual(e.fraseId, plan.find((f) => f.fecha === e.fecha).fraseId);
  }
  assert.deepStrictEqual(frasesDeHoyEnviadas(s, at(HOY, 9), FRASES, EXTRA), []);
});

test('dinero: también $, gana, ganancia y pasta; "ganas", "histórico" y "neurona" no cuentan', () => {
  const pool = frasesParaEmpujar(FRASES, newState()).map((q) => q.id);
  assert.ok(pool.length > 100, String(pool.length));
  assert.ok(!pool.includes('f399'));
  assert.ok(!pool.includes('f117'));
  assert.ok(!pool.includes('f061'));
  assert.ok(pool.includes('f327'));
  assert.ok(sinTildes(FRASES.find((q) => q.id === 'f327').texto).includes('ganas'));
  const qs = [
    { id: 'a', categoria: 'accion', texto: '¿Sin ganas? Graba igual', detalle: '' },
    { id: 'b', categoria: 'accion', texto: 'Un día histórico', detalle: '' },
    { id: 'c', categoria: 'accion', texto: 'Cada neurona cuenta', detalle: '' },
    { id: 'd', categoria: 'accion', texto: 'Uno gana y otro no', detalle: '' },
    { id: 'e', categoria: 'accion', texto: 'Hacer pasta rápido', detalle: '' },
    { id: 'f', categoria: 'accion', texto: 'Las GANANCIAS llegan', detalle: '' },
    { id: 'g', categoria: 'accion', texto: 'Cobra 40 $', detalle: '' },
    { id: 'h', categoria: 'accion', texto: 'Ser rico', detalle: '' },
    { id: 'i', categoria: 'accion', texto: 'Mil euros', detalle: '' },
    { id: 'j', categoria: 'accion', texto: 'Ganarás', detalle: '' },
  ];
  assert.deepStrictEqual(frasesParaEmpujar(qs, newState()).map((q) => q.id), ['a', 'b', 'c']);
});

test('el plan no cambia al hacer una misión, saltar el día o empezar lo mínimo', () => {
  const now = at(HOY, 12);
  for (const racha of [0, 5]) {
    let s = conMision('18:00', at(HOY, 8));
    if (racha) Object.assign(s.streak, { current: racha, best: racha, lastDay: '2026-10-26', countedDay: '2026-10-26', startDay: '2026-10-22' });
    // La app elige la frase del día al abrir.
    s = pickDailyQuote(s, at(HOY, 8), FRASES, EXTRA);
    const plan = planFrases(s, now, FRASES, EXTRA);
    const enviadas = frasesDeHoyEnviadas(s, now, FRASES, EXTRA);
    assert.strictEqual(enviadas.length, 1);
    // Con racha, el aviso de racha de las 22:00 aparta la frase de las 22:00.
    assert.deepStrictEqual(horas(plan, HOY), racha ? ['13:00', '16:00', '19:00'] : ['13:00', '16:00', '19:00', '22:00']);
    const video = pendingMissions(s, now, EXTRA).find((m) => m.kind === 'video').id;
    const despues = [
      completeMission(s, video, now, EXTRA),
      skipToday(s, now),
      startMinimo(s, now, EXTRA),
    ];
    assert.ok(despues[2].today.minimo);
    for (const d of despues) {
      assert.notDeepStrictEqual(planAvisos(d, now, FRASES, EXTRA), planAvisos(s, now, FRASES, EXTRA));
      assert.deepStrictEqual(planFrases(d, now, FRASES, EXTRA), plan, 'racha ' + racha);
      assert.deepStrictEqual(frasesDeHoyEnviadas(d, now, FRASES, EXTRA), enviadas);
    }
  }
});

test('con 3 favoritas y 5 horas, las otras 2 salen de las categorías sin repetir', () => {
  const s0 = configurarAvisos(vacio(), false, '18:00');
  const delDia = pickDailyQuote(s0, at(HOY, 9), FRASES, EXTRA).quote.id;
  const favs = ['f001', 'f002', 'f003', 'f004'].filter((id) => id !== delDia).slice(0, 3);
  let s = configurarFrases(s0, { soloFavoritas: true });
  for (const id of favs) s = alternarFavorita(s, id);
  const plan = planFrases(s, at(HOY, 9), FRASES, EXTRA);
  const empujan = frasesParaEmpujar(FRASES, newState()).map((q) => q.id);
  for (const day of [HOY, MANANA]) {
    const ids = plan.filter((f) => f.fecha.startsWith(day)).map((f) => f.fraseId);
    assert.strictEqual(ids.length, 5, day);
    assert.strictEqual(new Set(ids).size, 5, day);
    assert.deepStrictEqual(ids.filter((id) => favs.includes(id)).sort(), favs.slice().sort(), day);
    for (const id of ids.filter((x) => !favs.includes(x))) assert.ok(empujan.includes(id), id);
  }
});

test('sin frases candidatas ese día no sale ninguna', () => {
  const unica = [{ id: 'x', categoria: 'accion', autor: 'A', texto: 'Graba hoy', detalle: '' }];
  const s = vacio();
  assert.deepStrictEqual(planFrases(s, at(HOY, 9), unica, EXTRA), []);
  assert.deepStrictEqual(planFrases(s, at(HOY, 9), [], EXTRA), []);
});

test('recortarFrases deja las primeras hasta sumar 60 con los avisos de misión', () => {
  const frases = Array.from({ length: 50 }, (_, i) => ({ n: i }));
  assert.deepStrictEqual(recortarFrases(frases, 17), frases.slice(0, 43));
  assert.deepStrictEqual(recortarFrases(frases, 10), frases);
  assert.deepStrictEqual(recortarFrases(frases, 60), []);
  assert.deepStrictEqual(recortarFrases(frases, 70), []);
});
