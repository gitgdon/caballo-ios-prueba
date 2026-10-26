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
  s.today = Object.assign(d.today, s.today);
  for (const p of s.products || []) {
    if (p.discardedDay === undefined) p.discardedDay = null;
    if (p.videos === undefined) p.videos = 0;
    if (p.winners === undefined) p.winners = 0;
    if (p.bajonAvisado === undefined) p.bajonAvisado = false;
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

function clone(x) {
  return JSON.parse(JSON.stringify(x));
}

function createProduct(state, { name, place }) {
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
  for (const p of s.products) {
    if (p.status === 'test' && testDay(p, day) > 14) p.status = 'decision';
  }
  return s;
}

function missionsForDay(state, now) {
  const day = dayKey(now);
  const out = [];
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
      blocks.forEach((b, i) => {
        list.push(m('video:' + (i + 1), b, 'video', 'Graba y sube 1 vídeo de ' + p.name + suffix, xp));
      });
      if (p.status === 'vendiendo' || d >= 8) {
        list.push(m('metricas', 'noche', 'metricas', 'Revisa las métricas de ' + p.name, XP_BASE));
      }
    } else if (p.status === 'decision') {
      list.push(m('decision', 'mañana', 'decision', 'Decide: ¿ha vendido ' + p.name + '?', 0));
    }
    list.sort((a, b) => BLOCKS.indexOf(a.block) - BLOCKS.indexOf(b.block));
    out.push(...list);
  }
  if (state.today.day === day && state.today.minimo) {
    const dec = out.filter((m) => m.kind === 'decision');
    dec.push({ id: 'minimo', productId: null, block: blockOf(now), kind: 'minimo', text: MINIMO_TEXT, xp: XP_BASE });
    return dec;
  }
  return out;
}

function pendingMissions(state, now) {
  if (state.today.skipped) return [];
  const done = state.today.day === dayKey(now) ? state.today.done : [];
  return missionsForDay(state, now).filter((m) => !done.includes(m.id));
}

function currentMission(state, now) {
  return pendingMissions(state, now)[0] || null;
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
}

function completeMission(state, missionId, now) {
  const s = rollDay(state, now);
  const mission = pendingMissions(s, now).find((m) => m.id === missionId);
  if (!mission || mission.kind === 'decision') return s;
  const p = mission.productId ? findProduct(s, mission.productId) : null;
  s.today.done.push(mission.id);
  s.xp += mission.xp;
  s.lastActiveDay = dayKey(now);
  markActive(s, dayKey(now));
  if (mission.kind === 'minimo') return s;
  if (mission.kind === 'video') {
    p.videos += 1;
    s.today.videos += 1;
    if (s.today.videos > s.records.bestVideosDay) {
      if (s.records.bestVideosDay >= 1 && !s.today.recordNotified) s.today.recordNotified = true;
      s.records.bestVideosDay = s.today.videos;
    }
  }
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

function canStartMinimo(state, now) {
  const t = state.today;
  return t.day === dayKey(now) && !t.skipped && !t.minimo && t.done.length === 0 &&
    pendingMissions(state, now).some((m) => m.kind !== 'decision');
}

function startMinimo(state, now) {
  const s = rollDay(state, now);
  if (canStartMinimo(s, now)) s.today.minimo = true;
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

function hashDay(day) {
  let h = 5381;
  for (let i = 0; i < day.length; i++) h = (h * 33 + day.charCodeAt(i)) >>> 0;
  return h;
}

function quoteCategories(state, now) {
  const day = dayKey(now);
  const yesterday = addDays(day, -1);
  if (state.products.some((p) => p.discardedDay === day || p.discardedDay === yesterday)) {
    return ['sin-resultados', 'imperfecto', 'desde-cero'];
  }
  if (horseMood(state, now) === 'barro') return ['sin-resultados', 'constancia', 'desde-cero'];
  const streetVideo = missionsForDay(state, now).some(
    (m) => m.kind === 'video' && findProduct(state, m.productId).place === 'calle'
  );
  if (streetVideo) return ['verguenza', 'imperfecto', 'accion'];
  return null;
}

function byId(list) {
  return list.slice().sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

function pickDailyQuote(state, now, quotes) {
  const s = clone(state);
  const day = dayKey(now);
  if (!quotes || quotes.length === 0 || s.quote.day === day) return s;
  let unused = quotes.filter((q) => !s.usedQuotes.includes(q.id));
  if (unused.length === 0) {
    s.usedQuotes = [];
    unused = quotes;
  }
  const cats = quoteCategories(s, now);
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
  };
}
