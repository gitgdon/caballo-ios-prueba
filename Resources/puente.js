// Puente entre Swift y el juego (core.js + frases.js). Todo entra y sale como texto JSON.

function preparar(json) {
  var now = new Date();
  return JSON.stringify(pickDailyQuote(rollDay(parseState(json), now), now, FRASES));
}

function vista(json) {
  var now = new Date();
  var hoy = dayKey(now);
  var s = parseState(json);
  var info = levelInfo(s.xp);
  var m = currentMission(s, now);
  var p = m && m.productId ? s.products.find(function (x) { return x.id === m.productId; }) : null;
  var q = currentQuote(s, FRASES);
  var activos = activeProducts(s);
  var bajon = bajonProducts(s, now);
  var ref = function (x) { return { id: x.id, nombre: x.name }; };
  var sq = skipQuote(FRASES, now);
  return JSON.stringify({
    nivel: info.level, rango: info.rank, xp: info.xpInLevel, xpSig: info.xpForNext,
    racha: streakNow(s, now), escudos: s.shields, humor: horseMood(s, now),
    mision: m ? { id: m.id, texto: m.text, bloque: m.block, tipo: m.kind } : null,
    frase: q ? { texto: q.texto, autor: q.autor, detalle: q.detalle || q.texto, video: q.video.titulo } : null,
    porque: whyToShow(s, now),
    producto: p ? {
      n: Number(p.id.slice(1)), nombre: p.name,
      dia: p.status === 'test' ? testDay(p, hoy) : 0,
      ganadores: p.winners || 0, videos: p.videos || 0, bajon: inBajon(p, hoy),
    } : null,
    hayProductos: activos.length > 0,
    pendientes: pendingMissions(s, now).filter(function (x) { return x.kind !== 'decision'; })
      .map(function (x) { return { id: x.id, texto: x.text, bloque: x.block, tipo: x.kind }; }),
    decisiones: productsInDecision(s).map(ref),
    vendibles: activos.filter(function (x) { return x.status === 'test' || x.status === 'vendiendo'; }).map(ref),
    puedeMinimo: canStartMinimo(s, now),
    efectoSaltar: skipEffect(s, now),
    puedeNuevo: !activos.some(function (x) { return x.salesLevel === 'mucho'; }),
    bajon: bajon.map(function (x) { return x.id; }),
    textoBajon: bajon.length ? bajonText(bajon) : null,
    porqueGuardado: s.why || null,
    fraseSaltar: sq ? sq.texto : null,
  });
}

function accion(json, nombre, argsJson) {
  var now = new Date();
  var s = parseState(json);
  var antes = s;
  var a = JSON.parse(argsJson || '[]');
  switch (nombre) {
    case 'hecho': s = completeMission(s, a[0], now); break;
    case 'minimo': s = startMinimo(s, now); break;
    case 'saltar': s = skipToday(s, now); break;
    case 'ganador': s = markWinner(s, a[0], now); break;
    case 'viral': s = markViral(s, a[0], a[1], now); break;
    case 'vendido': s = markSold(s, a[0], now); break;
    case 'nuevo': s = createProduct(s, { name: a[0], place: a[1] }); break;
    case 'decidir': s = decide(s, a[0], a[1], now); break;
    case 'porque': s = setWhy(s, a[0]); break;
    case 'bajonVisto': s = markBajonAvisado(s, a); break;
  }
  var producto = s.products.find(function (x) { return x.id === a[0]; });
  return JSON.stringify({
    estado: JSON.stringify(s),
    logros: achievements(antes, s),
    ganador: (nombre === 'ganador' || nombre === 'viral') && producto ? winnerText(producto) : null,
    checkpoint: nombre === 'decidir' && a[1] === 'descartar' ? checkpointText(s) : null,
  });
}
