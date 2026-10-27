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

    enum CodingKeys: String, CodingKey {
        case nivel, rango, xp, xpSig, racha, escudos, humor, mision, frase, porque, producto
        case hayProductos, pendientes, decisiones, vendibles, puedeMinimo, efectoSaltar, puedeNuevo
        case bajon, textoBajon, porqueGuardado, fraseSaltar, productos, medallas
        case reto, tecnicas, tecnicasNuevas, secretas, ganchos, avisos, primerVideo, consejo
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

/// Un aviso planificado. `fecha` es hora local "YYYY-MM-DDTHH:MM"; `tipo` es grabar, repetir o racha.
struct AvisoPlan: Decodable, Identifiable {
    let id: String, fecha: String, titulo: String, cuerpo: String
    let misionId: String?
    let tipo: String
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

    @discardableResult
    func accion(_ nombre: String, _ args: [String] = []) -> Resultado? {
        let argsJson = (try? JSONSerialization.data(withJSONObject: args)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        guard let json = llamar("accion", [estado ?? NSNull(), nombre, argsJson]),
              let r = try? JSONDecoder().decode(Resultado.self, from: Data(json.utf8)) else { return nil }
        estado = r.estado
        return r
    }

    /// Plan de avisos de hoy y mañana (planAvisos de core.js).
    func avisos() -> [AvisoPlan] {
        guard let json = llamar("avisos", [estado ?? NSNull()]),
              let plan = try? JSONDecoder().decode([AvisoPlan].self, from: Data(json.utf8)) else { return [] }
        return plan
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
