'use strict';

const pad = (n) => String(n).padStart(2, '0');

function dayKey(date) {
  return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate());
}

function utcOf(day) {
  const [y, m, d] = day.split('-').map(Number);
  return Date.UTC(y, m - 1, d);
}

function addDays(day, n) {
  const t = new Date(utcOf(day) + n * 86400000);
  return t.getUTCFullYear() + '-' + pad(t.getUTCMonth() + 1) + '-' + pad(t.getUTCDate());
}

function daysBetween(a, b) {
  return Math.round((utcOf(b) - utcOf(a)) / 86400000);
}

function blockOf(date) {
  const h = date.getHours();
  if (h < 14) return 'mañana';
  if (h < 20) return 'tarde';
  return 'noche';
}

function rankOf(level) {
  if (level <= 2) return 'Jinete novato';
  if (level <= 5) return 'Jinete';
  if (level <= 9) return 'Explorador';
  if (level <= 14) return 'Forajido';
  return 'Leyenda';
}

function levelInfo(xp) {
  let level = 1;
  while (xp >= 50 * (level + 1) * level) level++;
  return {
    level,
    rank: rankOf(level),
    xpInLevel: xp - 50 * level * (level - 1),
    xpForNext: 100 * level,
  };
}

function newState() {
  return {
    version: 1,
    xp: 0,
    streetStep: 0,
    streetVideos: 0,
    productsStarted: 0,
    lastActiveDay: null,
    shields: 1,
    lastSkipDay: null,
    why: null,
    products: [],
    today: { day: null, done: [], skipped: false, videos: 0, recordNotified: false, minimo: false },
    streak: { current: 0, best: 0, lastDay: null, countedDay: null, startDay: null, recordAlertStart: null },
    medals: [],
    records: { bestVideosDay: 0 },
    quote: { day: null, id: null },
    usedQuotes: [],
    secretas: [],
    tecnicasVistas: 0,
    ganchos: [],
    avisos: { activos: true, hora: '18:00' },
    movimientos: [],
    ultimoTotal: 0,
  };
}

function normalizeState(s) {
  const d = newState();
  if (s.shields === undefined) s.shields = d.shields;
  if (s.lastSkipDay === undefined) s.lastSkipDay = d.lastSkipDay;
  if (s.why === undefined) s.why = d.why;
  s.streak = Object.assign(d.streak, s.streak);
  s.medals = s.medals || d.medals;
  s.records = Object.assign(d.records, s.records);
  s.quote = Object.assign(d.quote, s.quote);
  s.usedQuotes = s.usedQuotes || d.usedQuotes;
  s.secretas = s.secretas || d.secretas;
  if (s.tecnicasVistas === undefined) s.tecnicasVistas = d.tecnicasVistas;
  s.ganchos = s.ganchos || d.ganchos;
  s.avisos = Object.assign(d.avisos, s.avisos);
  s.avisos.hora = horaValida(s.avisos.hora);
  s.today = Object.assign(d.today, s.today);
  if (!Array.isArray(s.movimientos)) s.movimientos = d.movimientos;
  // Último total de la tienda apuntado (nunca se reinicia). Un estado anterior lo toma del reto.
  if (s.ultimoTotal === undefined) s.ultimoTotal = (s.reto && enteroValido(s.reto.facturado)) || 0;
  s.ultimoTotal = enteroValido(s.ultimoTotal) || 0;
  if (s.reto && s.reto.baseFacturacion === undefined) s.reto.baseFacturacion = 0;
  for (const p of s.products || []) {
    if (p.discardedDay === undefined) p.discardedDay = null;
    if (p.videos === undefined) p.videos = 0;
    if (p.winners === undefined) p.winners = 0;
    if (p.bajonAvisado === undefined) p.bajonAvisado = false;
    if (p.tecnicasPracticadas === undefined) p.tecnicasPracticadas = [];
    if (p.copia === undefined) p.copia = null;
    if (p.visitas === undefined) p.visitas = [];
    if (p.siguienteCambio === undefined) p.siguienteCambio = null;
  }
  return s;
}

function parseState(text) {
  if (text == null) return newState();
  try {
    const s = JSON.parse(text);
    if (s && typeof s === 'object' && s.version === 1) return normalizeState(s);
  } catch (e) {}
  return newState();
}

const XP_BASE = 10;
const XP_VIDEO_CASA = 20;
const XP_VIDEO_CALLE = [20, 30, 40];
const XP_TEST_COMPLETO = 100;
const STREET_STEPS = [
  'en una calle vacía (a primera hora o de noche)',
  'en una calle tranquila',
  'en una calle con algo de gente',
];
const STREET_VIDEOS_PER_STEP = 5;
const VIDEOS_WEEK1 = [1, 1, 2, 2, 2, 3, 3];
const PLATFORMS = { tiktok: 'TikTok', instagram: 'Instagram', youtube: 'YouTube Shorts' };
const BLOCKS = ['mañana', 'tarde', 'noche'];
const MEDALS = [7, 30, 100, 365];
const SHIELDS_MAX = 3;
const SHIELD_EVERY = 7;
const MINIMO_TEXT = 'Haz lo mínimo: graba 1 vídeo corto o 1 toma de prueba, aunque sea en casa';
const XP_GANADOR = 50;
const BAJON_TEXT = '🧗 Entras en los días 8–14: aquí es donde más gente lo deja. Los resultados tardan 2–4 semanas en llegar. Sigue.';
const VIDEO_BLOCKS = { 1: ['tarde'], 2: ['tarde', 'noche'], 3: ['mañana', 'tarde', 'noche'] };
const PRIMER_ENSAYO_TEXT = 'Graba 3 tomas en casa o en el portal, sin publicarlas';
const PRIMER_PUBLICA_TEXT = 'Publica una, aunque no te guste';
const SECRETAS = {
  'primer-video': 'Primer vídeo',
  'primera-calle': 'Primer vídeo en la calle',
  'semana-sin-saltar': 'Una semana sin saltar',
  'reto-cumplido': 'Reto cumplido',
};

const RETO_META = 10000;
const RETO_FIN = '2026-12-31';
const GANCHO_PREFIJO = '· reutiliza tu gancho «';
const GANCHO_MAX = 60;

function clone(x) {
  return JSON.parse(JSON.stringify(x));
}

function createProduct(state, { name, place, copia }) {
  const s = clone(state);
  s.productsStarted += 1;
  s.products.push({
    id: 'p' + s.productsStarted,
    name,
    place,
    status: 'preparacion',
    accounts: { tiktok: false, instagram: false, youtube: false },
    testStartDay: null,
    sold: false,
    viralPlatforms: [],
    salesLevel: null,
    discardedDay: null,
    videos: 0,
    winners: 0,
    bajonAvisado: false,
    tecnicasPracticadas: [],
    copia: copia === true || copia === false ? copia : null,
    visitas: [],
    siguienteCambio: null,
  });
  return s;
}

function testDay(product, today) {
  if (!product.testStartDay) return 0;
  const n = daysBetween(product.testStartDay, today) + 1;
  return n < 1 ? 0 : n;
}

function rollDay(state, now) {
  const s = clone(state);
  const day = dayKey(now);
  if (s.today.day !== day) s.today = { day, done: [], skipped: false, videos: 0, recordNotified: false, minimo: false };
  if (!s.reto) s.reto = retoDe(s, day);
  for (const p of s.products) {
    if (p.status === 'test' && testDay(p, day) > 14) p.status = 'decision';
  }
  return s;
}

function totalVideos(state) {
  return state.products.reduce((n, p) => n + p.videos, 0);
}

// Primer producto en test con misiones de vídeo hoy, mientras no se haya publicado ningún vídeo.
function primerVideoProduct(state, day) {
  if (totalVideos(state) > 0) return null;
  return state.products.find((p) => p.status === 'test' && testDay(p, day) >= 1) || null;
}

function primerVideoActivo(state, now) {
  const day = now ? dayKey(now) : state.today.day;
  return day ? primerVideoProduct(state, day) !== null : false;
}

function tecnicasDesbloqueadas(state, tecnicas) {
  const level = levelInfo(state.xp).level;
  return tecnicas.filter((t) => t.nivel <= level).sort((a, b) => a.nivel - b.nivel);
}

function marcarTecnicasVistas(state, tecnicas) {
  const s = clone(state);
  s.tecnicasVistas = tecnicasDesbloqueadas(s, tecnicas).length;
  return s;
}

function missionsForDay(state, now, extra) {
  const day = dayKey(now);
  const out = [];
  const primer = primerVideoProduct(state, day);
  const doneToday = state.today.day === day ? state.today.done : [];
  const enTest = state.products.find((p) => p.status === 'test' && testDay(p, day) >= 1);
  const encuentros = extra && extra.encuentros && extra.encuentros.length ? extra.encuentros : null;
  const hRaro = hashDay(day + ':raro');
  for (const p of state.products) {
    const m = (id, block, kind, text, xp) => ({ id: p.id + ':' + id, productId: p.id, block, kind, text, xp });
    const list = [];
    if (p.status === 'preparacion') {
      Object.keys(PLATFORMS).filter((k) => !p.accounts[k]).forEach((k, i) => {
        list.push(m('cuenta:' + k, BLOCKS[i], 'cuenta', 'Crea la cuenta de ' + PLATFORMS[k] + ' de ' + p.name, XP_BASE));
      });
    } else if (p.status === 'test' || p.status === 'vendiendo') {
      const d = testDay(p, day);
      if (p.status === 'test' && d === 0) continue;
      const n = p.status === 'vendiendo' || d >= 8 ? 3 : VIDEOS_WEEK1[d - 1];
      const blocks = VIDEO_BLOCKS[n];
      let suffix = '';
      if (p.place === 'calle') suffix += ' ' + STREET_STEPS[state.streetStep];
      if (p.viralPlatforms.length) {
        suffix += ' · replica el estilo viral en ' + p.viralPlatforms.map((k) => PLATFORMS[k]).join(', ');
      }
      const xp = p.place === 'calle' ? XP_VIDEO_CALLE[state.streetStep] : XP_VIDEO_CASA;
      if (p.sold) {
        list.push(m('pedidos', 'mañana', 'pedidos', 'Gestiona los pedidos de ' + p.name, XP_BASE));
      } else if (!blocks.includes('mañana')) {
        list.push(m('ligera', 'mañana', 'ligera', 'Responde comentarios y revisa las cuentas de ' + p.name, XP_BASE));
      }
      if (p === primer) {
        list.push(m('primer:1', blocks[0], 'ensayo', PRIMER_ENSAYO_TEXT, XP_BASE));
        if (doneToday.includes(p.id + ':primer:1')) list.push(m('primer:2', blocks[0], 'video', PRIMER_PUBLICA_TEXT, xp));
      } else if (!primer) {
        blocks.forEach((b, i) => {
          list.push(m('video:' + (i + 1), b, 'video', 'Graba y sube 1 vídeo de ' + p.name + suffix, xp));
        });
      }
      if (p === enTest && !primer && encuentros && hRaro % 7 === 0) {
        const e = encuentros[Math.floor(hRaro / 7) % encuentros.length];
        list.push(Object.assign(m('raro:' + e.id, 'tarde', 'raro', e.texto, e.xp), { video: e.video }));
      }
      if (p.status === 'vendiendo' || d >= 8) {
        list.push(m('metricas', 'noche', 'metricas', 'Revisa las métricas de ' + p.name, XP_BASE));
      }
    } else if (p.status === 'decision') {
      list.push(m('decision', 'mañana', 'decision', 'Decide: ¿ha vendido ' + p.name + '?', 0));
    }
    list.sort((a, b) => BLOCKS.indexOf(a.block) - BLOCKS.indexOf(b.block));
    out.push(...list);
  }
  for (const p of state.products) {
    if (!p.siguienteCambio) continue;
    const v = out.find((x) => x.productId === p.id && x.id.split(':')[1] === 'video' && !doneToday.includes(x.id));
    if (v) {
      v.text += ' ' + p.siguienteCambio;
      v.cambio = true;
    }
  }
  const tecs = extra && extra.tecnicas ? tecnicasDesbloqueadas(state, extra.tecnicas) : [];
  const hTec = hashDay(day + ':tec');
  const firstVideo = out.find((x) => x.id.split(':')[1] === 'video' && !doneToday.includes(x.id));
  const hGancho = hashDay(day + ':gancho');
  const ganchos = state.ganchos || [];
  if (firstVideo && !firstVideo.cambio && ganchos.length && hGancho % 4 === 0) {
    const g = ganchos[Math.floor(hGancho / 4) % ganchos.length];
    const room = GANCHO_MAX - Array.from(GANCHO_PREFIJO).length - 1;
    firstVideo.text += ' ' + GANCHO_PREFIJO + Array.from(g.texto).slice(0, room).join('') + '»';
  } else if (tecs.length && hTec % 2 === 0 && firstVideo && !firstVideo.cambio) {
    const t = tecs[Math.floor(hTec / 2) % tecs.length];
    firstVideo.text += ' ' + t.variante;
    firstVideo.tecnica = t.id;
  }
  if (state.today.day === day && state.today.minimo) {
    const dec = out.filter((m) => m.kind === 'decision');
    dec.push({ id: 'minimo', productId: null, block: blockOf(now), kind: 'minimo', text: MINIMO_TEXT, xp: XP_BASE });
    return dec;
  }
  return out;
}

function pendingMissions(state, now, extra) {
  if (state.today.skipped) return [];
  const done = state.today.day === dayKey(now) ? state.today.done : [];
  return missionsForDay(state, now, extra).filter((m) => !done.includes(m.id));
}

function currentMission(state, now, extra) {
  return pendingMissions(state, now, extra)[0] || null;
}

function ganarSecreta(s, id) {
  if (!s.secretas.includes(id)) s.secretas.push(id);
}

function findProduct(s, id) {
  return s.products.find((p) => p.id === id);
}

function markActive(s, d) {
  const st = s.streak;
  if (st.countedDay === d) return;
  st.current = st.lastDay === d || st.lastDay === addDays(d, -1) ? st.current + 1 : 1;
  if (st.current === 1) st.startDay = d;
  st.countedDay = d;
  st.lastDay = d;
  if (st.current > st.best && st.best >= 1 && st.recordAlertStart !== st.startDay) st.recordAlertStart = st.startDay;
  st.best = Math.max(st.best, st.current);
  if (st.current % SHIELD_EVERY === 0 && s.shields < SHIELDS_MAX) s.shields += 1;
  if (MEDALS.includes(st.current) && !s.medals.includes(st.current)) s.medals.push(st.current);
  if (st.current === 7 && (s.lastSkipDay === null || s.lastSkipDay < st.startDay)) ganarSecreta(s, 'semana-sin-saltar');
}

function countVideo(s, p) {
  if (totalVideos(s) === 0) ganarSecreta(s, 'primer-video');
  if (p.place === 'calle' && s.products.every((q) => q.place !== 'calle' || q.videos === 0)) ganarSecreta(s, 'primera-calle');
  p.videos += 1;
  s.today.videos += 1;
  if (s.today.videos > s.records.bestVideosDay) {
    if (s.records.bestVideosDay >= 1 && !s.today.recordNotified) s.today.recordNotified = true;
    s.records.bestVideosDay = s.today.videos;
  }
}

function completeMission(state, missionId, now, extra) {
  const s = rollDay(state, now);
  const mission = pendingMissions(s, now, extra).find((m) => m.id === missionId);
  if (!mission || mission.kind === 'decision') return s;
  const p = mission.productId ? findProduct(s, mission.productId) : null;
  s.today.done.push(mission.id);
  s.xp += mission.xp;
  s.lastActiveDay = dayKey(now);
  markActive(s, dayKey(now));
  if (mission.kind === 'minimo' || mission.kind === 'ensayo') return s;
  if (mission.kind === 'video' || (mission.kind === 'raro' && mission.video)) countVideo(s, p);
  if (mission.id === p.id + ':primer:2') s.today.done.push(p.id + ':video:1');
  if (mission.cambio && p) p.siguienteCambio = null;
  if (mission.tecnica && !p.tecnicasPracticadas.includes(mission.tecnica)) p.tecnicasPracticadas.push(mission.tecnica);
  if (mission.kind === 'cuenta') {
    p.accounts[mission.id.split(':')[2]] = true;
    if (Object.values(p.accounts).every(Boolean)) {
      p.status = 'test';
      p.testStartDay = addDays(dayKey(now), 1);
    }
  } else if (mission.kind === 'video' && p.place === 'calle') {
    s.streetVideos += 1;
    if (s.streetVideos >= STREET_VIDEOS_PER_STEP && s.streetStep < 2) {
      s.streetStep += 1;
      s.streetVideos = 0;
    }
  }
  return s;
}

function markSold(state, productId, now) {
  const s = rollDay(state, now);
  findProduct(s, productId).sold = true;
  return s;
}

function markViral(state, productId, platform, now) {
  const s = rollDay(state, now);
  const p = findProduct(s, productId);
  if (!p.viralPlatforms.includes(platform)) p.viralPlatforms.push(platform);
  p.winners += 1;
  s.xp += XP_GANADOR;
  if (!p.sold) p.status = 'decision';
  return s;
}

function markWinner(state, productId, now) {
  const s = rollDay(state, now);
  findProduct(s, productId).winners += 1;
  s.xp += XP_GANADOR;
  return s;
}

function decide(state, productId, outcome, now) {
  const s = rollDay(state, now);
  const p = findProduct(s, productId);
  s.xp += XP_TEST_COMPLETO;
  s.lastActiveDay = dayKey(now);
  markActive(s, dayKey(now));
  if (outcome === 'descartar') {
    p.status = 'descartado';
    p.discardedDay = dayKey(now);
  } else {
    p.status = 'vendiendo';
    p.salesLevel = outcome;
  }
  return s;
}

function skipToday(state, now) {
  const s = rollDay(state, now);
  if (s.today.skipped) return s;
  const effect = skipEffect(s, now);
  s.today.skipped = true;
  const day = dayKey(now);
  s.lastActiveDay = day;
  s.lastSkipDay = day;
  if (effect === 'escudo') {
    s.shields -= 1;
    s.streak.lastDay = day;
  }
  return s;
}

function skipEffect(state, now) {
  const day = dayKey(now);
  const st = state.streak;
  if ((state.today.day === day && state.today.skipped) || st.current <= 0 || st.lastDay !== addDays(day, -1)) return 'nada';
  return state.shields > 0 ? 'escudo' : 'pierde';
}

function canStartMinimo(state, now, extra) {
  const t = state.today;
  return t.day === dayKey(now) && !t.skipped && !t.minimo && t.done.length === 0 &&
    pendingMissions(state, now, extra).some((m) => m.kind !== 'decision');
}

function startMinimo(state, now, extra) {
  const s = rollDay(state, now);
  if (canStartMinimo(s, now, extra)) s.today.minimo = true;
  return s;
}

function winnerText(p) {
  return '🟢 Ganador ' + p.winners + (p.videos ? ' de ' + p.videos : '') + '. Lo normal es 1–2 de cada 10: vas bien';
}

function setWhy(state, text) {
  const s = clone(state);
  const t = Array.from(String(text == null ? '' : text).trim()).slice(0, 80).join('');
  s.why = t === '' ? null : t;
  return s;
}

function whyToShow(state, now) {
  if (!state.why) return null;
  const yesterday = addDays(dayKey(now), -1);
  return horseMood(state, now) === 'barro' || state.lastSkipDay === yesterday ? state.why : null;
}

function inBajon(p, today) {
  const d = testDay(p, today);
  return p.status === 'test' && p.sold !== true && d >= 8 && d <= 14;
}

function bajonProducts(state, now) {
  const day = dayKey(now);
  return state.products.filter((p) => inBajon(p, day) && !p.bajonAvisado);
}

function markBajonAvisado(state, ids) {
  const s = clone(state);
  for (const p of s.products) if (ids.includes(p.id)) p.bajonAvisado = true;
  return s;
}

function bajonText(products) {
  return products.map((p) => p.name).join(', ') + ': ' + BAJON_TEXT;
}

function productsInDecision(state) {
  return state.products.filter((p) => p.status === 'decision');
}

function activeProducts(state) {
  return state.products.filter((p) => p.status !== 'descartado');
}

function horseMood(state, now) {
  const day = dayKey(now);
  if (state.today.day === day && state.today.done.length > 0) return 'radiante';
  if (state.lastActiveDay && daysBetween(state.lastActiveDay, day) >= 3) return 'barro';
  return 'normal';
}

function streakNow(state, now) {
  const day = dayKey(now);
  const last = state.streak.lastDay;
  return last === day || last === addDays(day, -1) ? state.streak.current : 0;
}

function achievements(before, after) {
  const out = [];
  for (const m of after.medals) {
    if (!before.medals.includes(m)) out.push('🏅 Medalla: ' + m + ' días seguidos');
  }
  if (after.streak.recordAlertStart !== before.streak.recordAlertStart) {
    out.push('🏆 Nuevo récord: racha de ' + after.streak.current + ' días');
  }
  if (!before.today.recordNotified && after.today.recordNotified) {
    out.push('🏆 Nuevo récord: ' + after.records.bestVideosDay + ' vídeos en un día');
  }
  for (const id of after.secretas || []) {
    if (!(before.secretas || []).includes(id)) out.push('🏅 Medalla oculta: ' + SECRETAS[id]);
  }
  if (after.reto && after.reto.cumplido && !(before.reto && before.reto.cumplido)) out.push('🎯 ¡Reto cumplido!');
  if (after.shields > before.shields) out.push('🛡️ Escudo ganado (tienes ' + after.shields + ')');
  const b = levelInfo(before.xp);
  const a = levelInfo(after.xp);
  if (a.level > b.level || a.rank !== b.rank) out.push('¡Nivel ' + a.level + '! Ahora eres ' + a.rank);
  return out;
}

function checkpointText(state) {
  const n = state.productsStarted + 1;
  return '🏁 Checkpoint guardado. Producto ' + n + (n > 30 ? '' : '/30') + ' desbloqueado';
}

// Total de la tienda cuando empieza un reto: el reto cuenta lo facturado a partir de ahí.
function baseFacturacionDe(s) {
  return enteroValido(s.ultimoTotal) || 0;
}

function retoDe(s, day) {
  return { meta: RETO_META, fin: RETO_FIN, inicio: day, base: totalVideos(s), facturado: 0, cumplido: false, baseFacturacion: baseFacturacionDe(s) };
}

// Cantidad entera que Swift puede leer como Int: número finito, ≥ 0 y ≤ MAX_SAFE_INTEGER, redondeado; si no, null.
function enteroValido(n) {
  return typeof n === 'number' && Number.isFinite(n) && n >= 0 && n <= Number.MAX_SAFE_INTEGER ? Math.round(n) : null;
}

function retoValido(meta, fin) {
  const m = enteroValido(meta);
  return m !== null && m > 0 &&
    typeof fin === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(fin) && addDays(fin, 0) === fin;
}

function retoInfo(state, now) {
  const hoy = dayKey(now);
  const r = state.reto || retoDe(state, hoy);
  return {
    meta: r.meta,
    fin: r.fin,
    facturado: r.facturado,
    progreso: Math.min(1, r.facturado / r.meta),
    diasQuedan: Math.max(0, daysBetween(hoy, r.fin)),
    vencido: hoy > r.fin,
    videos: totalVideos(state) - r.base,
    cumplido: r.cumplido,
  };
}

function apuntarFacturacion(state, total, now) {
  const s = clone(state);
  const t = enteroValido(total);
  if (t === null) return s;
  if (!s.reto) s.reto = retoDe(s, dayKey(now));
  // El día recibe la diferencia con el último total de la tienda (negativa si se corrige a la baja).
  const ultimo = enteroValido(s.ultimoTotal);
  const antes = ultimo !== null ? ultimo : enteroValido(s.reto.facturado) || 0;
  if (t !== antes) {
    if (!Array.isArray(s.movimientos)) s.movimientos = [];
    s.movimientos.push({ dia: dayKey(now), tipo: 'ingreso', importe: t - antes, concepto: 'Facturación' });
  }
  s.ultimoTotal = t;
  // El reto cuenta solo lo facturado desde que empezó.
  s.reto.facturado = Math.max(0, t - (enteroValido(s.reto.baseFacturacion) || 0));
  // Solo cuenta como cumplido dentro del plazo (el día de fin incluido).
  if (!s.reto.cumplido && s.reto.facturado >= s.reto.meta && dayKey(now) <= s.reto.fin) {
    s.reto.cumplido = true;
    ganarSecreta(s, 'reto-cumplido');
  }
  return s;
}

// Los gastos se guardan redondeados a céntimos; los ingresos son enteros (diferencias de totales enteros).
const centimos = (x) => Math.round(x * 100) / 100;
const GASTO_CONCEPTO_MAX = 40;

// Gasto apuntado a mano (no resta del reto). Ignora importes no finitos, ≤ 0 o mayores que MAX_SAFE_INTEGER.
function anadirGasto(state, importe, concepto, now) {
  const s = clone(state);
  if (typeof importe !== 'number' || !Number.isFinite(importe)) return s;
  const v = centimos(importe);
  if (v <= 0 || v > Number.MAX_SAFE_INTEGER) return s;
  const texto = Array.from(String(concepto == null ? '' : concepto).trim()).slice(0, GASTO_CONCEPTO_MAX).join('').trim();
  if (!Array.isArray(s.movimientos)) s.movimientos = [];
  s.movimientos.push({ dia: dayKey(now), tipo: 'gasto', importe: v, concepto: texto || 'Gasto' });
  return s;
}

// Solo se borran gastos; los ingresos salen de la facturación.
function borrarMovimiento(state, indice) {
  const s = clone(state);
  const m = Array.isArray(s.movimientos) && Number.isInteger(indice) ? s.movimientos[indice] : null;
  if (m && m.tipo === 'gasto') s.movimientos.splice(indice, 1);
  return s;
}

// Un elemento por día del mes 'YYYY-MM' (null si no es un mes válido). neto = ingresos − gastos.
// `indice` de cada movimiento es su posición en state.movimientos (para borrarMovimiento).
function calendarioMes(state, mes) {
  if (typeof mes !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(mes)) return null;
  const [y, m] = mes.split('-').map(Number);
  const n = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const dias = [];
  for (let i = 1; i <= n; i++) dias.push({ dia: mes + '-' + pad(i), ingresos: 0, gastos: 0, neto: 0, movimientos: [] });
  (Array.isArray(state.movimientos) ? state.movimientos : []).forEach((x, indice) => {
    if (!x || typeof x.dia !== 'string' || x.dia.slice(0, 7) !== mes) return;
    if ((x.tipo !== 'ingreso' && x.tipo !== 'gasto') || !Number.isFinite(x.importe)) return;
    const d = dias[Number(x.dia.slice(8)) - 1];
    if (!d || d.dia !== x.dia) return;
    if (x.tipo === 'ingreso') d.ingresos = centimos(d.ingresos + x.importe);
    else d.gastos = centimos(d.gastos + x.importe);
    d.movimientos.push({ indice, tipo: x.tipo, importe: x.importe, concepto: String(x.concepto) });
  });
  let total = 0;
  let verdes = 0;
  let rojos = 0;
  for (const d of dias) {
    d.neto = centimos(d.ingresos - d.gastos);
    total = centimos(total + d.neto);
    if (d.neto > 0) verdes++;
    if (d.neto < 0) rojos++;
  }
  return { mes, dias, total, verdes, rojos };
}

function editarReto(state, meta, fin) {
  const s = clone(state);
  if (!retoValido(meta, fin)) return s;
  if (!s.reto) s.reto = retoDe(s, s.today.day || dayKey(new Date()));
  s.reto.meta = Math.round(meta);
  s.reto.fin = fin;
  return s;
}

function nuevoReto(state, meta, fin, now) {
  const s = clone(state);
  if (!retoValido(meta, fin)) return s;
  s.reto = { meta: Math.round(meta), fin, inicio: dayKey(now), base: totalVideos(s), facturado: 0, cumplido: false, baseFacturacion: baseFacturacionDe(s) };
  return s;
}

function avisoCopia(porQue, pidenEnlace, margen) {
  if (porQue === true && pidenEnlace === true && margen === true) return null;
  const faltan = [];
  if (porQue !== true) faltan.push('sin saber por qué funcionó');
  if (pidenEnlace !== true) faltan.push('sin que la gente pida el enlace');
  if (margen !== true) faltan.push('sin margen');
  return 'Ojo, ' + faltan.join(', ') + ' es más difícil que funcione. Puedes probarlo igual: los 14 días de test son la prueba.';
}

const FASES = [
  { min: 0, fase: 'arranque', donde: 'No arranca', cambio: 'originalidad, luz, lente limpia, clips propios', variante: '· cambia la luz y usa clips propios' },
  { min: 100, fase: 'palabras', donde: 'Te encuentran poco', cambio: 'palabras clave del producto en el texto y los hashtags', variante: '· pon el producto en texto y hashtags' },
  { min: 250, fase: 'gancho', donde: 'Segundos 0–2', cambio: 'el gancho', variante: '· cambia solo el gancho' },
  { min: 2000, fase: 'ritmo', donde: 'Segundos 2–5', cambio: 'algo nuevo cada 2 s', variante: '· algo nuevo cada 2 segundos' },
  { min: 5000, fase: 'cierre', donde: 'El cierre', cambio: 'el final', variante: '· cambia solo el final' },
  { min: 10000, fase: 'interaccion', donde: 'Interacción', cambio: 'una pregunta o sorpresa al final', variante: '· cierra con una pregunta o sorpresa' },
];

function faseDeVisitas(n) {
  let f = FASES[0];
  for (const x of FASES) if (n >= x.min) f = x;
  return { fase: f.fase, donde: f.donde, cambio: f.cambio, variante: f.variante };
}

function apuntarVisitas(state, productId, n, now) {
  const s = clone(state);
  const p = findProduct(s, productId);
  const v = enteroValido(n);
  if (!p || v === null) return s;
  const f = faseDeVisitas(v);
  p.visitas.push({ dia: dayKey(now), visitas: v, fase: f.fase });
  p.siguienteCambio = f.variante;
  return s;
}

function pideGancho(n) {
  return n >= 5000;
}

function guardarGancho(state, productId, texto, n, now) {
  const s = clone(state);
  const v = enteroValido(n);
  if (!findProduct(s, productId) || v === null) return s;
  const t = Array.from(String(texto == null ? '' : texto).trim()).slice(0, 80).join('');
  if (!t) return s;
  s.ganchos.push({ texto: t, producto: productId, visitas: v, dia: dayKey(now) });
  return s;
}

function recomendacionDia14(puedeDiferente, sabesPorQue, ideasNuevas) {
  return puedeDiferente === true && sabesPorQue === true && ideasNuevas === true ? 'seguir' : 'soltar';
}

function resumenDescarte(state, productId) {
  const p = findProduct(state, productId);
  if (!p) return null;
  const v = p.videos;
  const t = p.tecnicasPracticadas.length;
  const k = (state.ganchos || []).filter((g) => g.producto === productId).length;
  return 'Te llevas: ' + v + (v === 1 ? ' vídeo' : ' vídeos') + ' · ' + t + (t === 1 ? ' técnica practicada' : ' técnicas practicadas') +
    ' · ' + k + (k === 1 ? ' gancho guardado' : ' ganchos guardados');
}

function hashDay(day) {
  let h = 5381;
  for (let i = 0; i < day.length; i++) h = (h * 33 + day.charCodeAt(i)) >>> 0;
  return h;
}

function quoteCategories(state, now, extra) {
  const day = dayKey(now);
  const yesterday = addDays(day, -1);
  if (state.products.some((p) => p.discardedDay === day || p.discardedDay === yesterday)) {
    return ['sin-resultados', 'imperfecto', 'desde-cero'];
  }
  if (horseMood(state, now) === 'barro') return ['sin-resultados', 'constancia', 'desde-cero'];
  const streetVideo = missionsForDay(state, now, extra).some(
    (m) => (m.kind === 'video' || m.kind === 'ensayo') && findProduct(state, m.productId).place === 'calle'
  );
  if (streetVideo) return ['verguenza', 'imperfecto', 'accion'];
  return null;
}

function byId(list) {
  return list.slice().sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

function pickDailyQuote(state, now, quotes, extra) {
  const s = clone(state);
  const day = dayKey(now);
  if (!quotes || quotes.length === 0 || s.quote.day === day) return s;
  let unused = quotes.filter((q) => !s.usedQuotes.includes(q.id));
  if (unused.length === 0) {
    s.usedQuotes = [];
    unused = quotes;
  }
  const cats = quoteCategories(s, now, extra);
  let candidates = cats ? unused.filter((q) => cats.includes(q.categoria)) : unused;
  if (candidates.length === 0) candidates = unused;
  candidates = byId(candidates);
  const chosen = candidates[hashDay(day) % candidates.length];
  s.quote = { day, id: chosen.id };
  s.usedQuotes.push(chosen.id);
  return s;
}

function currentQuote(state, quotes) {
  return quotes.find((q) => q.id === state.quote.id) || null;
}

function skipQuote(quotes, now) {
  if (!quotes || quotes.length === 0) return null;
  let pool = quotes.filter((q) => q.categoria === 'disciplina' || q.categoria === 'sacrificio');
  if (pool.length === 0) pool = quotes;
  pool = byId(pool);
  return pool[hashDay(dayKey(now)) % pool.length];
}

const AVISO_CATEGORIAS = ['verguenza', 'accion', 'imperfecto'];
const AVISO_TITULO = 'Caballo Blanco';
const AVISO_CALLE = 'Empieza por 3 tomas de prueba sin publicar · ';
const AVISO_TOPE = 22 * 60;
const HORA_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

function horaValida(hora) {
  return typeof hora === 'string' && HORA_RE.test(hora) ? hora : '18:00';
}

function configurarAvisos(state, activos, hora) {
  const s = clone(state);
  s.avisos = Object.assign({ activos: true, hora: '18:00' }, s.avisos);
  if (typeof activos === 'boolean') s.avisos.activos = activos;
  if (typeof hora === 'string' && HORA_RE.test(hora)) s.avisos.hora = hora;
  return s;
}

// Horas del día en minutos: hora, hora + 3 h… hasta las 22:00. Si hora ≥ 22:00, solo esa.
function horasAviso(hora) {
  const [h, m] = hora.split(':').map(Number);
  const out = [h * 60 + m];
  while (out[out.length - 1] + 180 <= AVISO_TOPE) out.push(out[out.length - 1] + 180);
  return out;
}

function avisosDelDia(s, day, dayNow, now, quotes, extra, conRacha) {
  if (s.today.skipped || s.today.minimo) return [];
  const [y, mo, d] = day.split('-').map(Number);
  const slots = horasAviso(horaValida(s.avisos.hora));
  const primera = slots[0];
  const racha = conRacha && s.today.done.length === 0 ? streakNow(s, now) : 0;
  if (racha > 0 && !slots.includes(AVISO_TOPE)) slots.push(AVISO_TOPE);
  slots.sort((a, b) => a - b);
  const videos = pendingMissions(s, dayNow, extra).filter((m) => m.kind === 'video' || m.kind === 'ensayo');
  const cats = primerVideoActivo(s, dayNow) ? ['imperfecto', 'accion'] : AVISO_CATEGORIAS;
  const pool = byId((quotes || []).filter((q) => cats.includes(q.categoria) && q.id !== s.quote.id));
  const start = hashDay(day + ':aviso');
  const out = [];
  slots.forEach((min, i) => {
    if (new Date(y, mo - 1, d, Math.floor(min / 60), min % 60).getTime() <= now.getTime()) return;
    const hhmm = pad(Math.floor(min / 60)) + pad(min % 60);
    const base = { id: 'aviso-' + day + '-' + hhmm, fecha: day + 'T' + hhmm.slice(0, 2) + ':' + hhmm.slice(2), titulo: AVISO_TITULO };
    if (racha > 0 && min === AVISO_TOPE) {
      out.push(Object.assign(base, { cuerpo: 'Tu racha de ' + racha + ' días se acaba hoy.\n' + MINIMO_TEXT, misionId: null, tipo: 'racha' }));
      return;
    }
    if (videos.length === 0) return;
    const m = videos[0];
    const n = videos.length;
    const grabar = min === primera;
    let l2 = grabar ? m.text : (n === 1 ? 'Te queda 1 vídeo hoy · ' : 'Te quedan ' + n + ' vídeos hoy · ') + m.text;
    if (findProduct(s, m.productId).place === 'calle') l2 = AVISO_CALLE + l2;
    const l1 = pool.length ? pool[(start + i) % pool.length].texto + '\n' : '';
    out.push(Object.assign(base, { cuerpo: l1 + l2, misionId: m.id, tipo: grabar ? 'grabar' : 'repetir' }));
  });
  return out;
}

function planAvisos(state, now, quotes, extra) {
  if (state.avisos && state.avisos.activos === false) return [];
  // La frase del día de cada día se calcula aquí (no se lee la guardada), así el plan es el mismo antes y después de que la app la elija.
  const hoy = pickDailyQuote(rollDay(normalizeState(clone(state)), now), now, quotes, extra);
  const manana = addDays(dayKey(now), 1);
  const [y, m, d] = manana.split('-').map(Number);
  const mananaNow = new Date(y, m - 1, d, 0, 1);
  const sManana = pickDailyQuote(rollDay(hoy, mananaNow), mananaNow, quotes, extra);
  return avisosDelDia(hoy, dayKey(now), now, now, quotes, extra, true)
    .concat(avisosDelDia(sManana, manana, mananaNow, now, quotes, extra, false));
}

if (typeof module !== 'undefined') {
  module.exports = {
    dayKey, addDays, daysBetween, blockOf, levelInfo, newState, parseState,
    XP_BASE, XP_VIDEO_CASA, XP_VIDEO_CALLE, XP_TEST_COMPLETO, STREET_STEPS,
    STREET_VIDEOS_PER_STEP, VIDEOS_WEEK1, PLATFORMS,
    createProduct, testDay, rollDay, missionsForDay, pendingMissions, currentMission,
    completeMission, markSold, markViral, decide, skipToday, productsInDecision,
    activeProducts, horseMood, MEDALS, normalizeState, streakNow, achievements, checkpointText,
    quoteCategories, pickDailyQuote, currentQuote, skipQuote,
    SHIELDS_MAX, SHIELD_EVERY, MINIMO_TEXT, canStartMinimo, startMinimo,
    XP_GANADOR, BAJON_TEXT, markWinner, winnerText, setWhy, whyToShow, bajonProducts,
    markBajonAvisado, bajonText, inBajon, skipEffect,
    hashDay, totalVideos, primerVideoActivo, tecnicasDesbloqueadas, marcarTecnicasVistas, SECRETAS,
    PRIMER_ENSAYO_TEXT, PRIMER_PUBLICA_TEXT,
    RETO_META, RETO_FIN, retoInfo, apuntarFacturacion, editarReto, nuevoReto, avisoCopia,
    FASES, faseDeVisitas, apuntarVisitas, pideGancho, guardarGancho, recomendacionDia14, resumenDescarte,
    AVISO_CATEGORIAS, configurarAvisos, planAvisos,
    anadirGasto, borrarMovimiento, calendarioMes,
  };
}
