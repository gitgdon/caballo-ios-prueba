import ActivityKit
import Foundation

/// La tarjeta grande de la pantalla de bloqueo (Actividad en directo).
struct CaballoAtributos: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var frase: String
        var mision: String
        var misionId: String?
        var bloque: String
        var nivel: String
        var racha: Int
        var humor: String
        var producto: String?
    }

    /// Día en que se encendió; iOS la apaga a las 8 horas, así que se reenciende cada día.
    var dia: String
}

enum Actividad {
    static func contenido(_ v: Vista) -> CaballoAtributos.ContentState {
        let mision = v.mision
        return CaballoAtributos.ContentState(
            frase: v.porque.map { "💭 " + $0 } ?? v.frase?.texto ?? "",
            mision: mision?.texto ?? (v.hayProductos ? "Día cerrado. Descansa, jinete." : "Abre la app y empieza tu primer producto"),
            misionId: mision?.tipo == "decision" ? nil : mision?.id,
            bloque: mision?.bloque ?? "",
            nivel: v.lineaNivel,
            racha: v.racha,
            humor: v.humor,
            producto: v.lineaProducto
        )
    }

    private static var hoy: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    /// El interruptor de la app (por defecto encendida). Apagarla quita también la isla dinámica.
    static var activada: Bool {
        get { UserDefaults(suiteName: Juego.grupo)?.object(forKey: "actividadActivada") as? Bool ?? true }
        set { UserDefaults(suiteName: Juego.grupo)?.set(newValue, forKey: "actividadActivada") }
    }

    static func apagar() async {
        for a in Activity<CaballoAtributos>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }

    /// Actualiza la tarjeta si existe y es de hoy; si no, la (re)enciende.
    /// Encenderla solo funciona con la app abierta o desde un botón de la propia tarjeta/widget.
    static func actualizar(_ v: Vista?) async {
        guard activada else { await apagar(); return }
        guard let v, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let nuevo = ActivityContent(state: contenido(v), staleDate: nil)
        let actuales = Activity<CaballoAtributos>.activities
        if let a = actuales.first(where: { $0.attributes.dia == hoy && $0.activityState == .active }) {
            await a.update(nuevo)
            return
        }
        for a in actuales { await a.end(nil, dismissalPolicy: .immediate) }
        _ = try? Activity.request(attributes: CaballoAtributos(dia: hoy), content: nuevo, pushType: nil)
    }
}
