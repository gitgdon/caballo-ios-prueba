// Puente entre Swift y el juego (core.js + frases.js + tecnicas.js). Todo entra y sale como texto JSON.

// Técnicas y encuentros para las misiones; se pasan a toda llamada del juego que calcula misiones.
var EXTRA_PUENTE = { tecnicas: TECNICAS, encuentros: ENCUENTROS };

// Swift manda los argumentos como texto: '' o algo que no es número da NaN (el juego lo ignora).
function numeroPuente(x) {
  if (typeof x === 'number') return x;
  return typeof x === 'string' && x.trim() !== '' ? Number(x) : NaN;
}

function preparar(json) {
  var now = new Date();
  return JSON.stringify(pickDailyQuote(rollDay(parseState(json), now), now, FRASES, EXTRA_PUENTE));
}

function vista(json) {
  var now = new Date();
  var hoy = dayKey(now);
  var s = parseState(json);
  var info = levelInfo(s.xp);
  var m = currentMission(s, now, EXTRA_PUENTE);
  var p = m && m.productId ? s.products.find(function (x) { return x.id === m.productId; }) : null;
  var q = currentQuote(s, FRASES);
  var activos = activeProducts(s);
  var bajon = bajonProducts(s, now);
  var ref = function (x) { return { id: x.id, nombre: x.name }; };
  var sq = skipQuote(FRASES, now);
  var desbloqueadas = tecnicasDesbloqueadas(s, TECNICAS).length;
  var consejo = CONSEJOS[hashDay(hoy + ':consejo') % CONSEJOS.length];
  return JSON.stringify({
    nivel: info.level, rango: info.rank, xp: info.xpInLevel, xpSig: info.xpForNext,
    racha: streakNow(s, now), escudos: s.shields, humor: horseMood(s, now),
    mision: m ? { id: m.id, texto: m.text, bloque: m.block, tipo: m.kind, xp: m.xp } : null,
    frase: q ? { texto: q.texto, autor: q.autor, detalle: q.detalle || q.texto, video: q.video.titulo } : null,
    porque: whyToShow(s, now),
    producto: p ? {
      n: Number(p.id.slice(1)), nombre: p.name,
      dia: p.status === 'test' ? testDay(p, hoy) : 0,
      ganadores: p.winners || 0, videos: p.videos || 0, bajon: inBajon(p, hoy),
    } : null,
    hayProductos: activos.length > 0,
    pendientes: pendingMissions(s, now, EXTRA_PUENTE).filter(function (x) { return x.kind !== 'decision'; })
      .map(function (x) { return { id: x.id, texto: x.text, bloque: x.block, tipo: x.kind, xp: x.xp }; }),
    decisiones: productsInDecision(s).map(ref),
    vendibles: activos.filter(function (x) { return x.status === 'test' || x.status === 'vendiendo'; }).map(ref),
    puedeMinimo: canStartMinimo(s, now, EXTRA_PUENTE),
    efectoSaltar: skipEffect(s, now),
    puedeNuevo: !activos.some(function (x) { return x.salesLevel === 'mucho'; }),
    bajon: bajon.map(function (x) { return x.id; }),
    textoBajon: bajon.length ? bajonText(bajon) : null,
    porqueGuardado: s.why || null,
    fraseSaltar: sq ? sq.texto : null,
    productos: s.products.map(function (x) {
      return {
        id: x.id, nombre: x.name, estado: x.status, lugar: x.place,
        dia: x.status === 'test' ? testDay(x, hoy) : 0,
        videos: x.videos || 0, ganadores: x.winners || 0,
        copia: x.copia === true || x.copia === false ? x.copia : null,
        visitasMax: x.visitas.reduce(function (n, v) { return Math.max(n, v.visitas); }, 0),
        vendido: x.sold === true,
      };
    }),
    medallas: s.medals || [],
    reto: retoInfo(s, now),
    tecnicas: TECNICAS.slice().sort(function (a, b) { return a.nivel - b.nivel; }).map(function (t) {
      var abierta = t.nivel <= info.level;
      return { id: t.id, nivel: t.nivel, titulo: t.titulo, texto: abierta ? t.texto : '', mision: abierta ? t.mision : '', desbloqueada: abierta };
    }),
    tecnicasNuevas: Math.max(0, desbloqueadas - s.tecnicasVistas),
    secretas: s.secretas.map(function (id) { return { id: id, nombre: SECRETAS[id] }; }),
    ganchos: s.ganchos,
    avisos: { activos: s.avisos.activos, hora: s.avisos.hora },
    primerVideo: primerVideoActivo(s, now),
    consejo: { texto: consejo.texto, autor: consejo.autor },
  });
}

function avisos(json) {
  return JSON.stringify(planAvisos(parseState(json), new Date(), FRASES, EXTRA_PUENTE));
}

// La misión del aviso si sigue pendiente; si no, la siguiente de vídeo o ensayo; si no hay, ninguna.
function misionDelAviso(s, id, now) {
  var pendientes = pendingMissions(rollDay(s, now), now, EXTRA_PUENTE);
  if (pendientes.some(function (x) { return x.id === id; })) return id;
  var siguiente = pendientes.find(function (x) { return x.kind === 'video' || x.kind === 'ensayo'; });
  return siguiente ? siguiente.id : null;
}

// avisoCopia(a, b, c) es la de core.js tal cual (texto o null); Swift la llama directamente.
function recomendacion(a, b, c) {
  return recomendacionDia14(a, b, c);
}

function accion(json, nombre, argsJson) {
  var now = new Date();
  var s = parseState(json);
  var antes = s;
  var a = JSON.parse(argsJson || '[]');
  var fase = null;
  var gancho = false;
  switch (nombre) {
    case 'hecho': s = completeMission(s, a[0], now, EXTRA_PUENTE); break;
    case 'minimo': s = startMinimo(s, now, EXTRA_PUENTE); break;
    case 'saltar': s = skipToday(s, now); break;
    case 'ganador': s = markWinner(s, a[0], now); break;
    case 'viral': s = markViral(s, a[0], a[1], now); break;
    case 'vendido': s = markSold(s, a[0], now); break;
    case 'nuevo': s = createProduct(s, { name: a[0], place: a[1], copia: a[2] === 'si' ? true : a[2] === 'no' ? false : null }); break;
    case 'decidir': s = decide(s, a[0], a[1], now); break;
    case 'porque': s = setWhy(s, a[0]); break;
    case 'bajonVisto': s = markBajonAvisado(s, a); break;
    case 'facturacion': s = apuntarFacturacion(s, numeroPuente(a[0]), now); break;
    case 'reto': s = editarReto(s, numeroPuente(a[0]), a[1]); break;
    case 'retoNuevo': s = nuevoReto(s, numeroPuente(a[0]), a[1], now); break;
    case 'visitas': {
      var n = numeroPuente(a[1]);
      s = apuntarVisitas(s, a[0], n, now);
      if (s.products.some(function (x) { return x.id === a[0]; }) && Number.isFinite(n) && n >= 0) {
        var f = faseDeVisitas(n);
        fase = { fase: f.fase, donde: f.donde, cambio: f.cambio };
        gancho = pideGancho(n);
      }
      break;
    }
    case 'gancho': s = guardarGancho(s, a[0], a[1], numeroPuente(a[2]), now); break;
    case 'tecnicaVista': s = marcarTecnicasVistas(s, TECNICAS); break;
    case 'avisosConfig': s = configurarAvisos(s, a[0] === '1' ? true : a[0] === '0' ? false : undefined, a[1]); break;
    case 'hechoAviso': {
      var id = misionDelAviso(s, a[0], now);
      if (id) s = completeMission(s, id, now, EXTRA_PUENTE);
      break;
    }
  }
  var producto = s.products.find(function (x) { return x.id === a[0]; });
  var descarte = nombre === 'decidir' && a[1] === 'descartar';
  var resumen = descarte ? resumenDescarte(s, a[0]) : null;
  return JSON.stringify({
    estado: JSON.stringify(s),
    logros: achievements(antes, s),
    ganador: (nombre === 'ganador' || nombre === 'viral') && producto ? winnerText(producto) : null,
    checkpoint: descarte ? checkpointText(s) + (resumen ? '\n' + resumen : '') : null,
    fase: fase,
    pideGancho: gancho,
  });
}
