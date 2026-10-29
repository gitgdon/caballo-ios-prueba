import Foundation
import JavaScriptCore

/// Lo que muestran la app y los widgets, calculado por el juego (core.js).
struct Vista: Decodable {
    struct Mision: Decodable, Identifiable {
        let id: String; let texto: String; let bloque: String; let tipo: String
        var xp: Int = 0
        enum CodingKeys: String, CodingKey { case id, texto, bloque, tipo, xp }
    }
    struct Frase: Decodable { let texto: String; let autor: String; let detalle: String; let video: String }
    struct Producto: Decodable { let n: Int; let nombre: String; let dia: Int; let ganadores: Int; let videos: Int; let bajon: Bool }
    struct Ref: Decodable, Identifiable { let id: String; let nombre: String }
    struct ProductoFila: Decodable, Identifiable {
        let id: String, nombre: String, estado: String, lugar: String
        let dia: Int, videos: Int, ganadores: Int
        /// true / false según "¿es copia de algo que ya vende?"; nil si no se contestó.
        let copia: Bool?, visitasMax: Int, vendido: Bool

        enum CodingKeys: String, CodingKey { case id, nombre, estado, lugar, dia, videos, ganadores, copia, visitasMax, vendido }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            nombre = try c.decode(String.self, forKey: .nombre)
            estado = try c.decode(String.self, forKey: .estado)
            lugar = try c.decode(String.self, forKey: .lugar)
            dia = try c.decode(Int.self, forKey: .dia)
            videos = try c.decode(Int.self, forKey: .videos)
            ganadores = try c.decode(Int.self, forKey: .ganadores)
            copia = try c.decodeIfPresent(Bool.self, forKey: .copia)
            visitasMax = try c.decodeIfPresent(Int.self, forKey: .visitasMax) ?? 0
            vendido = try c.decodeIfPresent(Bool.self, forKey: .vendido) ?? false
        }
    }

    let nivel: Int, rango: String, xp: Int, xpSig: Int
    let racha: Int, escudos: Int, humor: String
    let mision: Mision?, frase: Frase?, porque: String?, producto: Producto?
    let hayProductos: Bool, pendientes: [Mision], decisiones: [Ref], vendibles: [Ref]
    let puedeMinimo: Bool, efectoSaltar: String, puedeNuevo: Bool
    let bajon: [String], textoBajon: String?, porqueGuardado: String?, fraseSaltar: String?
    let productos: [ProductoFila], medallas: [Int]
    let reto: Reto?, tecnicas: [Tecnica], tecnicasNuevas: Int
    let secretas: [Secreta], ganchos: [Gancho], avisos: AjustesAvisos
    let primerVideo: Bool, consejo: Consejo?
    /// Último total de la tienda apuntado (no se reinicia con un reto nuevo).
    let ultimoTotal: Int
    /// Ids de las frases favoritas.
    let favoritas: [String]
    let frasesConfig: FrasesConfig
    let misTecnicas: [MiTecnica]
    /// Todos los ids de frase, en el orden de FRASES.
    let fraseIds: [String]
    /// Avisos de frase que ya salieron hoy, el más reciente primero.
    let enviadasHoy: [FraseEnviada]
    /// Ids para "Dame una frase" (categorías que empujan, sin dinero; o las favoritas).
    let empujar: [String]

    enum CodingKeys: String, CodingKey {
        case nivel, rango, xp, xpSig, racha, escudos, humor, mision, frase, porque, producto
        case hayProductos, pendientes, decisiones, vendibles, puedeMinimo, efectoSaltar, puedeNuevo
        case bajon, textoBajon, porqueGuardado, fraseSaltar, productos, medallas
        case reto, tecnicas, tecnicasNuevas, secretas, ganchos, avisos, primerVideo, consejo, ultimoTotal
        case favoritas, frasesConfig, misTecnicas, fraseIds, enviadasHoy, empujar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nivel = try c.decode(Int.self, forKey: .nivel)
        rango = try c.decode(String.self, forKey: .rango)
        xp = try c.decode(Int.self, forKey: .xp)
        xpSig = try c.decode(Int.self, forKey: .xpSig)
        racha = try c.decode(Int.self, forKey: .racha)
        escudos = try c.decode(Int.self, forKey: .escudos)
        humor = try c.decode(String.self, forKey: .humor)
        mision = try c.decodeIfPresent(Mision.self, forKey: .mision)
        frase = try c.decodeIfPresent(Frase.self, forKey: .frase)
        porque = try c.decodeIfPresent(String.self, forKey: .porque)
        producto = try c.decodeIfPresent(Producto.self, forKey: .producto)
        hayProductos = try c.decode(Bool.self, forKey: .hayProductos)
        pendientes = try c.decode([Mision].self, forKey: .pendientes)
        decisiones = try c.decode([Ref].self, forKey: .decisiones)
        vendibles = try c.decode([Ref].self, forKey: .vendibles)
        puedeMinimo = try c.decode(Bool.self, forKey: .puedeMinimo)
        efectoSaltar = try c.decode(String.self, forKey: .efectoSaltar)
        puedeNuevo = try c.decode(Bool.self, forKey: .puedeNuevo)
        bajon = try c.decode([String].self, forKey: .bajon)
        textoBajon = try c.decodeIfPresent(String.self, forKey: .textoBajon)
        porqueGuardado = try c.decodeIfPresent(String.self, forKey: .porqueGuardado)
        fraseSaltar = try c.decodeIfPresent(String.self, forKey: .fraseSaltar)
        productos = try c.decodeIfPresent([ProductoFila].self, forKey: .productos) ?? []
        medallas = try c.decodeIfPresent([Int].self, forKey: .medallas) ?? []
        reto = try c.decodeIfPresent(Reto.self, forKey: .reto)
        tecnicas = try c.decodeIfPresent([Tecnica].self, forKey: .tecnicas) ?? []
        tecnicasNuevas = try c.decodeIfPresent(Int.self, forKey: .tecnicasNuevas) ?? 0
        secretas = try c.decodeIfPresent([Secreta].self, forKey: .secretas) ?? []
        ganchos = try c.decodeIfPresent([Gancho].self, forKey: .ganchos) ?? []
        avisos = try c.decodeIfPresent(AjustesAvisos.self, forKey: .avisos) ?? AjustesAvisos(activos: true, hora: "18:00")
        primerVideo = try c.decodeIfPresent(Bool.self, forKey: .primerVideo) ?? false
        consejo = try c.decodeIfPresent(Consejo.self, forKey: .consejo)
        ultimoTotal = try c.decodeIfPresent(Int.self, forKey: .ultimoTotal) ?? 0
        favoritas = try c.decodeIfPresent([String].self, forKey: .favoritas) ?? []
        frasesConfig = try c.decodeIfPresent(FrasesConfig.self, forKey: .frasesConfig) ?? .porDefecto
        misTecnicas = try c.decodeIfPresent([MiTecnica].self, forKey: .misTecnicas) ?? []
        fraseIds = try c.decodeIfPresent([String].self, forKey: .fraseIds) ?? []
        enviadasHoy = try c.decodeIfPresent([FraseEnviada].self, forKey: .enviadasHoy) ?? []
        empujar = try c.decodeIfPresent([String].self, forKey: .empujar) ?? []
    }

    var lineaNivel: String {
        "Nv \(nivel) · \(rango)" + (racha > 0 ? " · 🔥\(racha)" : "") + (escudos > 0 ? " · 🛡️\(escudos)" : "")
    }

    var lineaProducto: String? {
        guard let p = producto else { return nil }
        return "Producto \(p.n)\(p.n <= 30 ? "/30" : "")"
            + (p.dia > 0 ? " · Día \(p.dia)/14" : "")
            + (p.videos > 0 ? " · 🟢\(p.ganadores)/\(p.videos)" : "")
            + (p.bajon ? " · 🧗 bajón" : "")
    }
}

extension Vista.Mision {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        texto = try c.decode(String.self, forKey: .texto)
        bloque = try c.decode(String.self, forKey: .bloque)
        tipo = try c.decode(String.self, forKey: .tipo)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
    }
}

/// Reto de facturación (retoInfo de core.js).
struct Reto: Decodable {
    let meta: Int, fin: String, facturado: Int
    /// De 0 a 1.
    let progreso: Double
    let diasQuedan: Int, vencido: Bool, videos: Int, cumplido: Bool
}

/// Técnica de nivel; `texto` y `mision` vienen vacíos mientras está bloqueada.
struct Tecnica: Decodable, Identifiable {
    let id: String, nivel: Int, titulo: String, texto: String, mision: String, desbloqueada: Bool
}

/// Medalla oculta ganada.
struct Secreta: Decodable, Identifiable {
    let id: String, nombre: String
}

/// Gancho guardado: `producto` es el id ("p1"), `dia` "YYYY-MM-DD".
struct Gancho: Decodable, Hashable {
    let texto: String, producto: String, visitas: Int, dia: String
}

/// `hora` en formato "HH:MM".
struct AjustesAvisos: Decodable {
    let activos: Bool, hora: String
}

struct Consejo: Decodable {
    let texto: String, autor: String
}

/// Tramo de visitas recién apuntado: dónde se pierde la gente y qué cambiar.
struct Fase: Decodable {
    let fase: String, donde: String, cambio: String
}

/// Un aviso planificado. `fecha` es hora local "YYYY-MM-DDTHH:MM"; `tipo` es grabar, repetir, racha o frase.
/// `misionId` solo en los de misión; `fraseId` solo en los de frase.
struct AvisoPlan: Decodable, Identifiable {
    let id: String, fecha: String, titulo: String, cuerpo: String
    let misionId: String?
    let tipo: String
    let fraseId: String?
}

/// Ajustes de los avisos de frases. `desde`/`hasta` "HH:MM" (hasta inclusiva); `cadaHoras` de 1 a 6.
struct FrasesConfig: Decodable, Equatable {
    let activos: Bool, cadaHoras: Int, desde: String, hasta: String, soloFavoritas: Bool, sonido: Bool

    static let porDefecto = FrasesConfig(activos: true, cadaHoras: 3, desde: "10:00", hasta: "22:00", soloFavoritas: false, sonido: false)
}

/// Técnica propia (nota). `producto` es el id ("p1") o nil; puede ser de un producto ya borrado.
struct MiTecnica: Decodable, Identifiable, Hashable {
    let id: String, texto: String, producto: String?, dia: String
}

/// Aviso de frase que ya salió hoy; `fecha` es hora local "YYYY-MM-DDTHH:MM".
struct FraseEnviada: Decodable, Identifiable, Hashable {
    let fraseId: String, fecha: String
    var id: String { fecha }
}

/// Una frase de FRASES completa; `video` es el título del vídeo.
struct FraseCompleta: Decodable, Identifiable, Hashable {
    let id: String, texto: String, autor: String, categoria: String, detalle: String, video: String
}

/// Última acción que se puede deshacer. `origen` es "app", "widget" o "aviso".
struct Deshacer: Equatable {
    let nombre: String, origen: String, hora: Date
}

/// Calendario de dinero de un mes (calendarioMes de core.js): un día por cada día del mes.
/// Importes en euros como Double: los ingresos son enteros y los gastos pueden llevar céntimos.
struct CalendarioMes: Decodable {
    /// `indice` es la posición en el estado (para "borrarMovimiento"); `tipo` es ingreso o gasto.
    struct Movimiento: Decodable, Identifiable {
        let indice: Int, tipo: String, importe: Double, concepto: String
        var id: Int { indice }
    }
    /// `dia` es "YYYY-MM-DD"; neto = ingresos − gastos.
    struct Dia: Decodable, Identifiable {
        let dia: String, ingresos: Double, gastos: Double, neto: Double, movimientos: [Movimiento]
        var id: String { dia }
    }
    let mes: String, dias: [Dia], total: Double, verdes: Int, rojos: Int
}

struct Resultado: Decodable {
    let estado: String
    let logros: [String]
    let ganador: String?
    let checkpoint: String?
    let fase: Fase?
    let pideGancho: Bool

    enum CodingKeys: String, CodingKey { case estado, logros, ganador, checkpoint, fase, pideGancho }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estado = try c.decode(String.self, forKey: .estado)
        logros = try c.decode([String].self, forKey: .logros)
        ganador = try c.decodeIfPresent(String.self, forKey: .ganador)
        checkpoint = try c.decodeIfPresent(String.self, forKey: .checkpoint)
        fase = try c.decodeIfPresent(Fase.self, forKey: .fase)
        pideGancho = try c.decodeIfPresent(Bool.self, forKey: .pideGancho) ?? false
    }
}

/// Ejecuta el juego de siempre (core.js + frases.js) con el motor JavaScript del iPhone
/// y guarda la partida en el App Group que comparten la app y los widgets.
final class Juego {
    static let grupoOriginal = "group.com.caballoblanco.prueba"
    /// Al firmar desde Windows el App Group se renombra; el nombre real está en el perfil instalado.
    static let grupo: String = grupoDelPerfil() ?? grupoOriginal

    private let ctx: JSContext = JSContext()

    init() {
        ctx.exceptionHandler = { _, error in print("JS:", error?.toString() ?? "?") }
        for nombre in ["frases", "tecnicas", "core", "puente"] {
            if let url = Bundle.main.url(forResource: nombre, withExtension: "js"),
               let codigo = try? String(contentsOf: url, encoding: .utf8) {
                ctx.evaluateScript(codigo, withSourceURL: url)
            }
        }
    }

    private var estado: String? {
        get { UserDefaults(suiteName: Self.grupo)?.string(forKey: "estado") }
        set { UserDefaults(suiteName: Self.grupo)?.set(newValue, forKey: "estado") }
    }

    /// Cambia de día si toca y elige la frase de hoy; guarda solo si algo cambió.
    @discardableResult
    func preparar() -> Vista? {
        let antes = estado
        if let nuevo = llamar("preparar", [antes ?? NSNull()]), nuevo != antes { estado = nuevo }
        return vista()
    }

    func vista() -> Vista? {
        guard let json = llamar("vista", [estado ?? NSNull()]) else { return nil }
        return try? JSONDecoder().decode(Vista.self, from: Data(json.utf8))
    }

    /// `origen`: "app", "widget" o "aviso". Las acciones de `deshacibles` que cambian el estado se pueden deshacer.
    @discardableResult
    func accion(_ nombre: String, _ args: [String] = [], origen: String = "app") -> Resultado? {
        let antes = estado
        let argsJson = (try? JSONSerialization.data(withJSONObject: args)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        guard let json = llamar("accion", [antes ?? NSNull(), nombre, argsJson]),
              let r = try? JSONDecoder().decode(Resultado.self, from: Data(json.utf8)) else { return nil }
        estado = r.estado
        if Self.deshacibles.contains(nombre), r.estado != antes {
            guardarCopia(CopiaDeshacer(antes: antes, despues: r.estado, nombre: nombre, origen: origen,
                                       hora: ISO8601DateFormatter().string(from: Date())))
        }
        return r
    }

    /// Acciones que ofrecen deshacer.
    static let deshacibles: Set<String> = [
        "hecho", "hechoAviso", "minimo", "saltar", "ganador", "viral", "vendido", "nuevo", "decidir",
        "facturacion", "gasto", "borrarMovimiento", "editarGasto", "visitas", "gancho", "editarGancho", "borrarGancho",
        "miTecnica", "editarMiTecnica", "borrarMiTecnica", "renombrarProducto", "borrarProducto", "reto", "retoNuevo",
    ]

    /// La última acción, solo si el estado guardado sigue siendo el de justo después; si no, se olvida.
    func deshacible() -> Deshacer? {
        guard let c = copia() else { return nil }
        guard estado == c.despues, let hora = ISO8601DateFormatter().date(from: c.hora) else {
            guardarCopia(nil)
            return nil
        }
        return Deshacer(nombre: c.nombre, origen: c.origen, hora: hora)
    }

    /// Vuelve al estado de antes de la última acción (si `deshacible()` la ofrece).
    @discardableResult
    func deshacer() -> Bool {
        guard deshacible() != nil, let c = copia() else { return false }
        estado = c.antes
        guardarCopia(nil)
        return true
    }

    /// Texto de la píldora: "Misión hecha", "Producto borrado"… y " desde el widget" / " desde el aviso".
    static func etiqueta(_ d: Deshacer) -> String {
        let textos: [String: String] = [
            "hecho": "Misión hecha", "hechoAviso": "Misión hecha", "minimo": "Mínimo elegido", "saltar": "Día saltado",
            "ganador": "Ganador apuntado", "viral": "Viral apuntado", "vendido": "Venta apuntada",
            "nuevo": "Producto creado", "decidir": "Decisión tomada", "facturacion": "Facturación apuntada",
            "gasto": "Gasto apuntado", "borrarMovimiento": "Gasto borrado", "editarGasto": "Gasto editado",
            "visitas": "Visitas apuntadas", "gancho": "Gancho guardado", "editarGancho": "Gancho editado",
            "borrarGancho": "Gancho borrado", "miTecnica": "Técnica guardada", "editarMiTecnica": "Técnica editada",
            "borrarMiTecnica": "Técnica borrada", "renombrarProducto": "Producto renombrado",
            "borrarProducto": "Producto borrado", "reto": "Reto cambiado", "retoNuevo": "Reto nuevo",
        ]
        let texto = textos[d.nombre] ?? "Hecho"
        switch d.origen {
        case "widget": return texto + " desde el widget"
        case "aviso": return texto + " desde el aviso"
        default: return texto
        }
    }

    /// Lo que se guarda en el App Group, clave "deshacer". `antes` es nil si no había partida.
    private struct CopiaDeshacer: Codable {
        let antes: String?, despues: String, nombre: String, origen: String, hora: String
    }

    private func copia() -> CopiaDeshacer? {
        guard let texto = UserDefaults(suiteName: Self.grupo)?.string(forKey: "deshacer") else { return nil }
        return try? JSONDecoder().decode(CopiaDeshacer.self, from: Data(texto.utf8))
    }

    private func guardarCopia(_ c: CopiaDeshacer?) {
        let texto = c.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        UserDefaults(suiteName: Self.grupo)?.set(texto, forKey: "deshacer")
    }

    /// Plan de avisos de hoy y mañana (planAvisos de core.js).
    func avisos() -> [AvisoPlan] {
        guard let json = llamar("avisos", [estado ?? NSNull()]),
              let plan = try? JSONDecoder().decode([AvisoPlan].self, from: Data(json.utf8)) else { return [] }
        return plan
    }

    /// Plan de avisos de frases de hoy y mañana (planFrases de core.js); `fraseId` en cada uno.
    func avisosFrases() -> [AvisoPlan] {
        guard let json = llamar("avisosFrases", [estado ?? NSNull()]),
              let plan = try? JSONDecoder().decode([AvisoPlan].self, from: Data(json.utf8)) else { return [] }
        return plan
    }

    /// Las 477 frases, en el orden de FRASES (se leen una vez por Juego).
    func frases() -> [FraseCompleta] {
        if let f = frasesLeidas { return f }
        guard let json = llamar("frasesTodas", []),
              let f = try? JSONDecoder().decode([FraseCompleta].self, from: Data(json.utf8)) else { return [] }
        frasesLeidas = f
        return f
    }

    private var frasesLeidas: [FraseCompleta]?

    /// Calendario de dinero del mes "YYYY-MM"; nil si el mes no es válido.
    func calendario(mes: String) -> CalendarioMes? {
        guard let json = llamar("calendario", [estado ?? NSNull(), mes]) else { return nil }
        return try? JSONDecoder().decode(CalendarioMes.self, from: Data(json.utf8))
    }

    /// Aviso amable (no bloquea) si a la copia le falta alguna de las tres comprobaciones; nil si las cumple.
    func avisoCopia(_ a: Bool, _ b: Bool, _ c: Bool) -> String? {
        llamar("avisoCopia", [booleano(a), booleano(b), booleano(c)])
    }

    /// Recomendación del día 14: "seguir" o "soltar".
    func recomendacion(_ a: Bool, _ b: Bool, _ c: Bool) -> String {
        llamar("recomendacion", [booleano(a), booleano(b), booleano(c)]) ?? "soltar"
    }

    /// Booleano de JavaScript: el juego compara con `=== true`.
    private func booleano(_ b: Bool) -> Any {
        let v: JSValue? = JSValue(bool: b, in: ctx)
        return v.map { $0 as Any } ?? b
    }

    private func llamar(_ funcion: String, _ args: [Any]) -> String? {
        guard let f = ctx.objectForKeyedSubscript(funcion), !f.isUndefined,
              let v = f.call(withArguments: args), !v.isUndefined, !v.isNull else { return nil }
        return v.toString()
    }

    private static func grupoDelPerfil() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let datos = try? Data(contentsOf: url),
              let inicio = datos.range(of: Data("<?xml".utf8)),
              let fin = datos.range(of: Data("</plist>".utf8), in: inicio.lowerBound..<datos.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: datos.subdata(in: inicio.lowerBound..<fin.upperBound), format: nil) as? [String: Any],
              let permisos = plist["Entitlements"] as? [String: Any],
              let grupos = permisos["com.apple.security.application-groups"] as? [String]
        else { return nil }
        return grupos.first { $0.contains("caballoblanco") } ?? grupos.first
    }
}
