'use strict';
const test = require('node:test');
const assert = require('node:assert');
const c = require('../Resources/core.js');
const { TECNICAS, ENCUENTROS } = require('../Resources/tecnicas.js');
const {
  newState, createProduct, rollDay, missionsForDay, pendingMissions, completeMission, achievements,
  totalVideos, primerVideoActivo, tecnicasDesbloqueadas, marcarTecnicasVistas, startMinimo, skipToday,
  parseState, hashDay, addDays, XP_BASE, SECRETAS,
} = c;

const at = (day, hour) => {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d, hour, 0, 0);
};
const EXTRA = { tecnicas: TECNICAS, encuentros: ENCUENTROS };

function enTest(startDay, patch = {}, place = 'casa') {
  const s = createProduct(newState(), { name: 'P1', place });
  Object.assign(s.products[0], { status: 'test', testStartDay: startDay }, patch);
  return s;
}
function findDay(from, ok) {
  for (let i = 0; i < 400; i++) {
    const d = addDays(from, i);
    if (ok(d)) return d;
  }
  throw new Error('no hay día');
}
const esRaro = (d) => hashDay(d + ':raro') % 7 === 0;
const esTec = (d) => hashDay(d + ':tec') % 2 === 0;

test('SECRETAS', () => {
  assert.deepStrictEqual(SECRETAS, {
    'primer-video': 'Primer vídeo', 'primera-calle': 'Primer vídeo en la calle',
    'semana-sin-saltar': 'Una semana sin saltar', 'reto-cumplido': 'Reto cumplido',
  });
});

test('estado nuevo y partida antigua reciben secretas, tecnicasVistas y tecnicasPracticadas', () => {
  const n = newState();
  assert.deepStrictEqual(n.secretas, []);
  assert.strictEqual(n.tecnicasVistas, 0);
  assert.deepStrictEqual(createProduct(n, { name: 'P', place: 'casa' }).products[0].tecnicasPracticadas, []);
  const old = JSON.parse(JSON.stringify(createProduct(n, { name: 'P', place: 'casa' })));
  delete old.secretas;
  delete old.tecnicasVistas;
  delete old.products[0].tecnicasPracticadas;
  const s = parseState(JSON.stringify(old));
  assert.deepStrictEqual(s.secretas, []);
  assert.strictEqual(s.tecnicasVistas, 0);
  assert.deepStrictEqual(s.products[0].tecnicasPracticadas, []);
});

// ── Tu primer vídeo ──

test('primer vídeo: día 3 con 0 vídeos cambia los vídeos por el ensayo', () => {
  const now = at('2026-10-21', 9);
  const s = rollDay(enTest('2026-10-19'), now);
  assert.strictEqual(totalVideos(s), 0);
  assert.strictEqual(primerVideoActivo(s, now), true);
  const m = missionsForDay(s, now);
  assert.ok(!m.some((x) => x.kind === 'video'));
  const p1 = m.find((x) => x.id === 'p1:primer:1');
  assert.ok(p1);
  assert.strictEqual(p1.kind, 'ensayo');
  assert.strictEqual(p1.text, 'Graba 3 tomas en casa o en el portal, sin publicarlas');
  assert.strictEqual(p1.xp, XP_BASE);
  assert.ok(!m.some((x) => x.id === 'p1:primer:2'));
  assert.ok(m.some((x) => x.id === 'p1:ligera'), 'las demás misiones no cambian');
});

test('primer vídeo: el ensayo da XP base y racha, sin contar vídeo; luego sale publicar', () => {
  const now = at('2026-10-21', 9);
  let s = enTest('2026-10-19');
  s = completeMission(s, 'p1:primer:1', now);
  assert.strictEqual(s.xp, XP_BASE);
  assert.strictEqual(s.streak.current, 1);
  assert.strictEqual(totalVideos(s), 0);
  assert.strictEqual(s.today.videos, 0);
  const p2 = pendingMissions(s, now).find((x) => x.id === 'p1:primer:2');
  assert.ok(p2);
  assert.strictEqual(p2.kind, 'video');
  assert.strictEqual(p2.text, 'Publica una, aunque no te guste');
});

test('primer vídeo: publicar lo cierra, da la medalla oculta y no pide un vídeo de más', () => {
  const now = at('2026-10-21', 9);
  let s = completeMission(enTest('2026-10-19'), 'p1:primer:1', now);
  const before = s;
  s = completeMission(s, 'p1:primer:2', now);
  assert.strictEqual(totalVideos(s), 1);
  assert.strictEqual(s.today.videos, 1);
  assert.ok(s.secretas.includes('primer-video'));
  assert.ok(achievements(before, s).includes('🏅 Medalla oculta: Primer vídeo'));
  assert.ok(s.today.done.includes('p1:video:1'));
  assert.strictEqual(primerVideoActivo(s, now), false);
  assert.deepStrictEqual(pendingMissions(s, now).filter((x) => x.kind === 'video').map((x) => x.id), ['p1:video:2']);
});

test('primer vídeo: si no publica, al día siguiente vuelve el paso 1', () => {
  let s = completeMission(enTest('2026-10-19'), 'p1:primer:1', at('2026-10-21', 9));
  const next = at('2026-10-22', 9);
  s = rollDay(s, next);
  const ids = pendingMissions(s, next).map((x) => x.id);
  assert.ok(ids.includes('p1:primer:1'));
  assert.ok(!ids.includes('p1:primer:2'));
});

test('primer vídeo: con varios productos va ligado al primero en test y nadie más pide vídeo', () => {
  const now = at('2026-10-21', 9);
  let s = createProduct(newState(), { name: 'A', place: 'casa' });
  s = createProduct(s, { name: 'B', place: 'casa' });
  s = createProduct(s, { name: 'C', place: 'casa' });
  s = createProduct(s, { name: 'D', place: 'casa' });
  Object.assign(s.products[1], { status: 'test', testStartDay: '2026-10-19' });
  Object.assign(s.products[2], { status: 'test', testStartDay: '2026-10-20' });
  Object.assign(s.products[3], { status: 'vendiendo' });
  const m = missionsForDay(s, now);
  assert.ok(!m.some((x) => x.kind === 'video'));
  assert.deepStrictEqual(m.filter((x) => x.kind === 'ensayo').map((x) => x.id), ['p2:primer:1']);
  s = completeMission(s, 'p2:primer:1', now);
  assert.deepStrictEqual(pendingMissions(s, now).filter((x) => x.kind === 'video').map((x) => x.id), ['p2:primer:2']);
});

test('primer vídeo: sin productos en test no hay modo', () => {
  const s = createProduct(newState(), { name: 'P', place: 'casa' });
  s.products[0].status = 'vendiendo';
  assert.strictEqual(primerVideoActivo(s, at('2026-10-21', 9)), false);
  assert.ok(missionsForDay(s, at('2026-10-21', 9)).some((x) => x.id === 'p1:video:1'));
});

// ── Encuentros raros ──

test('encuentro raro: sale el día que toca, da su XP, cuenta racha y vídeo', () => {
  const d = findDay('2026-10-21', esRaro);
  const now = at(d, 9);
  const s = enTest(d, { videos: 1 });
  const raro = missionsForDay(s, now, EXTRA).filter((x) => x.kind === 'raro');
  assert.strictEqual(raro.length, 1);
  const e = ENCUENTROS.find((x) => raro[0].id === 'p1:raro:' + x.id);
  assert.ok(e, raro[0].id);
  assert.strictEqual(raro[0].xp, e.xp);
  assert.strictEqual(raro[0].text, e.texto);

  const one = (video) => ({ encuentros: [{ id: 'e99', texto: 'Encuentro', xp: 55, video }] });
  for (const video of [true, false]) {
    const after = completeMission(s, 'p1:raro:e99', now, one(video));
    assert.strictEqual(after.xp, 55);
    assert.strictEqual(after.streak.current, 1);
    assert.strictEqual(after.products[0].videos, video ? 2 : 1);
  }
});

test('encuentro raro: no sale otros días, ni sin encuentros, ni en primer vídeo ni en lo mínimo', () => {
  const d = findDay('2026-10-21', esRaro);
  const now = at(d, 9);
  const raros = (s, extra) => missionsForDay(s, now, extra).filter((x) => x.kind === 'raro');
  assert.strictEqual(raros(enTest(d, { videos: 1 })).length, 0);
  assert.strictEqual(raros(enTest(d, { videos: 1 }), { tecnicas: TECNICAS }).length, 0);
  assert.strictEqual(raros(enTest(d, { videos: 0 }), EXTRA).length, 0);
  const minimo = startMinimo(rollDay(enTest(d, { videos: 1 }), now), now, EXTRA);
  assert.strictEqual(minimo.today.minimo, true);
  assert.strictEqual(raros(minimo, EXTRA).length, 0);
  const otro = findDay('2026-10-21', (x) => !esRaro(x));
  assert.strictEqual(missionsForDay(enTest(otro, { videos: 1 }), at(otro, 9), EXTRA).filter((x) => x.kind === 'raro').length, 0);
});

// ── Técnicas ──

test('tecnicasDesbloqueadas y marcarTecnicasVistas', () => {
  const s = newState();
  s.xp = 1000;
  assert.strictEqual(c.levelInfo(s.xp).level, 5);
  assert.deepStrictEqual(tecnicasDesbloqueadas(s, TECNICAS).map((t) => t.id), ['t01', 't02', 't03', 't04', 't05']);
  assert.deepStrictEqual(tecnicasDesbloqueadas(newState(), TECNICAS).map((t) => t.id), ['t01']);
  const v = marcarTecnicasVistas(s, TECNICAS);
  assert.strictEqual(v.tecnicasVistas, 5);
  assert.strictEqual(s.tecnicasVistas, 0);
});

test('técnica en la primera misión de vídeo los días que toca', () => {
  const d = findDay('2026-10-21', esTec);
  const now = at(d, 9);
  const s = enTest(d, { videos: 1 });
  s.xp = 1000;
  const des = tecnicasDesbloqueadas(s, TECNICAS);
  const t = des[hashDay(d + ':tec') % des.length];
  const plain = missionsForDay(s, now).filter((x) => x.kind === 'video');
  const vids = missionsForDay(s, now, EXTRA).filter((x) => x.kind === 'video');
  assert.strictEqual(vids[0].text, plain[0].text + ' ' + t.variante);
  assert.strictEqual(vids[0].tecnica, t.id);
  assert.ok(vids.slice(1).every((x) => x.tecnica === undefined));
  assert.ok(plain.every((x) => x.tecnica === undefined));

  const otro = findDay('2026-10-21', (x) => !esTec(x));
  const s2 = enTest(otro, { videos: 1 });
  assert.ok(missionsForDay(s2, at(otro, 9), EXTRA).every((x) => x.tecnica === undefined));
});

test('completar una misión con técnica la apunta en el producto sin repetir', () => {
  const d1 = findDay('2026-10-21', esTec);
  const d2 = findDay(addDays(d1, 1), esTec);
  let s = createProduct(newState(), { name: 'P', place: 'casa' });
  Object.assign(s.products[0], { status: 'vendiendo', videos: 1 });
  s = completeMission(s, 'p1:video:1', at(d1, 9), EXTRA);
  assert.deepStrictEqual(s.products[0].tecnicasPracticadas, ['t01']);
  s = completeMission(s, 'p1:video:1', at(d2, 9), EXTRA);
  assert.deepStrictEqual(s.products[0].tecnicasPracticadas, ['t01']);
  s = completeMission(s, 'p1:video:2', at(d2, 9), EXTRA);
  assert.deepStrictEqual(s.products[0].tecnicasPracticadas, ['t01']);
});

// ── Medallas ocultas ──

test('primera-calle: el primer vídeo de un producto de calle', () => {
  const now = at('2026-10-21', 9);
  let s = completeMission(enTest('2026-10-21', {}, 'calle'), 'p1:primer:1', now);
  s = completeMission(s, 'p1:primer:2', now);
  assert.ok(s.secretas.includes('primer-video'));
  assert.ok(s.secretas.includes('primera-calle'));

  let t = createProduct(newState(), { name: 'Casa', place: 'casa' });
  t = createProduct(t, { name: 'Calle', place: 'calle' });
  Object.assign(t.products[0], { status: 'vendiendo', videos: 3 });
  Object.assign(t.products[1], { status: 'vendiendo' });
  const before = t;
  t = completeMission(t, 'p2:video:1', now);
  assert.deepStrictEqual(t.secretas, ['primera-calle']);
  assert.deepStrictEqual(achievements(before, t).filter((a) => a.includes('oculta')), ['🏅 Medalla oculta: Primer vídeo en la calle']);
  const again = completeMission(t, 'p2:video:2', now);
  assert.deepStrictEqual(again.secretas, ['primera-calle']);
  assert.deepStrictEqual(achievements(t, again).filter((a) => a.includes('oculta')), []);
});

function vendiendo(patch = {}) {
  const s = createProduct(newState(), { name: 'P', place: 'casa' });
  Object.assign(s.products[0], { status: 'vendiendo', videos: 1 }, patch);
  return s;
}

test('semana-sin-saltar: racha 7 sin saltos desde su inicio', () => {
  let s = skipToday(vendiendo(), at('2026-10-20', 9));
  assert.strictEqual(s.lastSkipDay, '2026-10-20');
  for (let i = 0; i < 7; i++) {
    if (i === 6) assert.ok(!s.secretas.includes('semana-sin-saltar'));
    s = completeMission(s, 'p1:video:1', at(addDays('2026-10-21', i), 9));
  }
  assert.strictEqual(s.streak.current, 7);
  assert.deepStrictEqual(s.secretas, ['semana-sin-saltar']);
});

test('semana-sin-saltar: no cuenta si saltó (con escudo) dentro de la racha', () => {
  let s = vendiendo();
  for (let i = 0; i < 8; i++) {
    const now = at(addDays('2026-10-21', i), 9);
    s = i === 2 ? skipToday(s, now) : completeMission(s, 'p1:video:1', now);
  }
  assert.strictEqual(s.streak.current, 7);
  assert.ok(!s.secretas.includes('semana-sin-saltar'));
});

test('ninguna medalla oculta con efecto retroactivo al cargar una partida', () => {
  const old = vendiendo({ place: 'calle', videos: 5 });
  Object.assign(old.streak, { current: 10, best: 10, lastDay: '2026-10-20', countedDay: '2026-10-20', startDay: '2026-10-11' });
  delete old.secretas;
  let s = parseState(JSON.stringify(old));
  assert.deepStrictEqual(s.secretas, []);
  s = completeMission(s, 'p1:video:1', at('2026-10-21', 9));
  assert.strictEqual(s.streak.current, 11);
  assert.deepStrictEqual(s.secretas, []);
});
