import Foundation
import JavaScriptCore

/// Lo que muestran la app y los widgets, calculado por el juego (core.js).
struct Vista: Decodable {
    struct Mision: Decodable, Identifiable { let id: String; let texto: String; let bloque: String; let tipo: String }
    struct Frase: Decodable { let texto: String; let autor: String; let detalle: String; let video: String }
    struct Producto: Decodable { let n: Int; let nombre: String; let dia: Int; let ganadores: Int; let videos: Int; let bajon: Bool }
    struct Ref: Decodable, Identifiable { let id: String; let nombre: String }

    let nivel: Int, rango: String, xp: Int, xpSig: Int
    let racha: Int, escudos: Int, humor: String
    let mision: Mision?, frase: Frase?, porque: String?, producto: Producto?
    let hayProductos: Bool, pendientes: [Mision], decisiones: [Ref], vendibles: [Ref]
    let puedeMinimo: Bool, efectoSaltar: String, puedeNuevo: Bool
    let bajon: [String], textoBajon: String?, porqueGuardado: String?, fraseSaltar: String?

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

struct Resultado: Decodable {
    let estado: String
    let logros: [String]
    let ganador: String?
    let checkpoint: String?
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
        for nombre in ["frases", "core", "puente"] {
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
