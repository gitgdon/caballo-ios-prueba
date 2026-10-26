import AppIntents
import WidgetKit

/// El botón ✅ del widget y de la tarjeta de la pantalla de bloqueo: marca la misión sin abrir la app.
/// Es un LiveActivityIntent para que se ejecute en la app (en segundo plano) y pueda
/// actualizar también la tarjeta, no solo los widgets.
struct HechoIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Misión hecha"

    @Parameter(title: "Misión")
    var misionId: String

    init() {}

    init(misionId: String) {
        self.misionId = misionId
    }

    func perform() async throws -> some IntentResult {
        let juego = Juego()
        juego.accion("hecho", [misionId])
        WidgetCenter.shared.reloadAllTimelines()
        await Actividad.actualizar(juego.vista())
        return .result()
    }
}
