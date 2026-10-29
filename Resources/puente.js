// Puente entre Swift y el juego (core.js + frases.js + tecnicas.js). Todo entra y sale como texto JSON.

// Técnicas y encuentros para las misiones; se pasan a toda llamada del juego que calcula misiones.
var EXTRA_PUENTE = { tecnicas: TECNICAS, encuentros: ENCUENTROS };

// Swift manda los argumentos como texto: '' o algo que no es número da NaN (el juego lo ignora).
function numeroPuente(x) {
  if (typeof x === 'number') return x;
  return typeof x === 'string' && x.trim() !== '' ? Number(x) : NaN;
}

// Lo que Swift lee como Int: siempre un entero seguro, aunque el estado guardado venga roto.
function enteroPuente(x) {
  if (typeof x !== 'number' || !Number.isFinite(x)) return 0;
  return Math.round(Math.max(-Number.MAX_SAFE_INTEGER, Math.min(Number.MAX_SAFE_INTEGER, x)));
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
    nivel: enteroPuente(info.level), rango: info.rank, xp: enteroPuente(info.xpInLevel), xpSig: enteroPuente(info.xpForNext),
    racha: enteroPuente(streakNow(s, now)), escudos: enteroPuente(s.shields), humor: horseMood(s, now),
    mision: m ? { id: m.id, texto: m.text, bloque: m.block, tipo: m.kind, xp: enteroPuente(m.xp) } : null,
    frase: q ? { texto: q.texto, autor: q.autor, detalle: q.detalle || q.texto, video: q.video.titulo } : null,
    porque: whyToShow(s, now),
    producto: p ? {
      n: enteroPuente(Number(p.id.slice(1))), nombre: p.name,
      dia: p.status === 'test' ? enteroPuente(testDay(p, hoy)) : 0,
      ganadores: enteroPuente(p.winners), videos: enteroPuente(p.videos), bajon: inBajon(p, hoy),
    } : null,
    hayProductos: activos.length > 0,
    pendientes: pendingMissions(s, now, EXTRA_PUENTE).filter(function (x) { return x.kind !== 'decision'; })
      .map(function (x) { return { id: x.id, texto: x.text, bloque: x.block, tipo: x.kind, xp: enteroPuente(x.xp) }; }),
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
        dia: x.status === 'test' ? enteroPuente(testDay(x, hoy)) : 0,
        videos: enteroPuente(x.videos), ganadores: enteroPuente(x.winners),
        copia: x.copia === true || x.copia === false ? x.copia : null,
        visitasMax: enteroPuente(x.visitas.reduce(function (n, v) { return Math.max(n, enteroPuente(v.visitas)); }, 0)),
        vendido: x.sold === true,
      };
    }),
    medallas: (s.medals || []).map(enteroPuente),
    reto: (function (r) {
      r.meta = enteroPuente(r.meta); r.facturado = enteroPuente(r.facturado);
      r.diasQuedan = enteroPuente(r.diasQuedan); r.videos = enteroPuente(r.videos);
      r.progreso = Number.isFinite(r.progreso) ? Math.max(0, Math.min(1, r.progreso)) : 0;
      return r;
    })(retoInfo(s, now)),
    ultimoTotal: enteroPuente(s.ultimoTotal),
    tecnicas: TECNICAS.slice().sort(function (a, b) { return a.nivel - b.nivel; }).map(function (t) {
      var abierta = t.nivel <= info.level;
      return { id: t.id, nivel: enteroPuente(t.nivel), titulo: t.titulo, texto: abierta ? t.texto : '', mision: abierta ? t.mision : '', desbloqueada: abierta };
    }),
    tecnicasNuevas: Math.max(0, enteroPuente(desbloqueadas - s.tecnicasVistas)),
    secretas: s.secretas.map(function (id) { return { id: String(id), nombre: SECRETAS[id] || String(id) }; }),
    ganchos: s.ganchos.map(function (g) {
      return { texto: String(g.texto), producto: String(g.producto), visitas: enteroPuente(g.visitas), dia: String(g.dia) };
    }),
    avisos: { activos: s.avisos.activos, hora: s.avisos.hora },
    primerVideo: primerVideoActivo(s, now),
    consejo: { texto: consejo.texto, autor: consejo.autor },
    favoritas: s.favoritas.filter(function (id) { return typeof id === 'string'; }),
    frasesConfig: (function (c) {
      return {
        activos: typeof c.activos === 'boolean' ? c.activos : true, cadaHoras: enteroPuente(c.cadaHoras),
        desde: String(c.desde), hasta: String(c.hasta), soloFavoritas: c.soloFavoritas === true, sonido: c.sonido === true,
      };
    })(frasesConfigValida(s)),
    misTecnicas: s.misTecnicas.filter(function (m) { return m && typeof m === 'object'; }).map(function (m) {
      return {
        id: String(m.id), texto: m.texto == null ? '' : String(m.texto),
        producto: m.producto == null ? null : String(m.producto), dia: m.dia == null ? '' : String(m.dia),
      };
    }),
    fraseIds: FRASES.map(function (f) { return f.id; }),
    enviadasHoy: frasesDeHoyEnviadas(s, now, FRASES, EXTRA_PUENTE),
    empujar: frasesParaEmpujar(FRASES, s).map(function (f) { return f.id; }),
  });
}

function avisos(json) {
  return JSON.stringify(planAvisos(parseState(json), new Date(), FRASES, EXTRA_PUENTE));
}

// Avisos de frases de hoy y mañana (planFrases de core.js).
function avisosFrases(json) {
  return JSON.stringify(planFrases(parseState(json), new Date(), FRASES, EXTRA_PUENTE));
}

// Todas las frases para el apartado Frases (Swift la lee una vez). `video` es el título del vídeo.
function frasesTodas() {
  return JSON.stringify(FRASES.map(function (f) {
    return {
      id: f.id, texto: f.texto, autor: f.autor, categoria: f.categoria,
      detalle: f.detalle || f.texto, video: f.video && f.video.titulo ? f.video.titulo : '',
    };
  }));
}

// Cambios de frasesConfig mandados como texto JSON; si no es un objeto, no cambia nada.
function cambiosFrases(texto) {
  try {
    var c = JSON.parse(texto);
    return c && typeof c === 'object' && !Array.isArray(c) ? c : null;
  } catch (e) {
    return null;
  }
}

// Calendario de dinero del mes 'YYYY-MM' (calendarioMes de core.js); 'null' si el mes no es válido.
function calendario(json, mes) {
  return JSON.stringify(calendarioMes(parseState(json), mes));
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
  // Un producto borrado puede seguir en una hoja abierta: sobre él, ganador/viral/vendido/decidir no hacen nada.
  var existe = s.products.some(function (x) { return x.id === a[0]; });
  switch (nombre) {
    case 'hecho': s = completeMission(s, a[0], now, EXTRA_PUENTE); break;
    case 'minimo': s = startMinimo(s, now, EXTRA_PUENTE); break;
    case 'saltar': s = skipToday(s, now); break;
    case 'ganador': if (existe) s = markWinner(s, a[0], now); break;
    case 'viral': if (existe) s = markViral(s, a[0], a[1], now); break;
    case 'vendido': if (existe) s = markSold(s, a[0], now); break;
    case 'nuevo': s = createProduct(s, { name: a[0], place: a[1], copia: a[2] === 'si' ? true : a[2] === 'no' ? false : null }); break;
    case 'decidir': if (existe) s = decide(s, a[0], a[1], now); break;
    case 'porque': s = setWhy(s, a[0]); break;
    case 'bajonVisto': s = markBajonAvisado(s, a); break;
    case 'facturacion': s = apuntarFacturacion(s, numeroPuente(a[0]), now); break;
    case 'reto': s = editarReto(s, numeroPuente(a[0]), a[1]); break;
    case 'retoNuevo': s = nuevoReto(s, numeroPuente(a[0]), a[1], now); break;
    case 'gasto': s = anadirGasto(s, numeroPuente(a[0]), a[1], now); break;
    case 'borrarMovimiento': s = borrarMovimiento(s, numeroPuente(a[0])); break;
    case 'visitas': {
      var n = enteroValido(numeroPuente(a[1]));
      s = apuntarVisitas(s, a[0], n, now);
      if (s.products.some(function (x) { return x.id === a[0]; }) && n !== null) {
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
    case 'favorita': if (typeof a[0] === 'string' && a[0]) s = alternarFavorita(s, a[0]); break;
    case 'frasesConfig': {
      var cambios = cambiosFrases(a[0]);
      if (cambios) s = configurarFrases(s, cambios);
      break;
    }
    case 'borrarProducto': s = borrarProducto(s, a[0], now); break;
    case 'renombrarProducto': s = renombrarProducto(s, a[0], a[1]); break;
    case 'editarGasto': s = editarGasto(s, numeroPuente(a[0]), numeroPuente(a[1]), a[2]); break;
    case 'editarGancho': s = editarGancho(s, numeroPuente(a[0]), a[1]); break;
    case 'borrarGancho': s = borrarGancho(s, numeroPuente(a[0])); break;
    case 'miTecnica': s = anadirMiTecnica(s, a[0], a[1] ? a[1] : null, now); break;
    case 'editarMiTecnica': s = editarMiTecnica(s, a[0], a[1]); break;
    case 'borrarMiTecnica': s = borrarMiTecnica(s, a[0]); break;
  }
  var producto = s.products.find(function (x) { return x.id === a[0]; });
  // Sin checkpoint si el producto ya no existía (borrado): no se descartó nada.
  var descarte = nombre === 'decidir' && a[1] === 'descartar' && existe;
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
