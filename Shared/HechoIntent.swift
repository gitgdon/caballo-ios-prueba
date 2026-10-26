import AppIntents
import WidgetKit

/// El botón ✅ del widget: marca la misión sin abrir la app.
struct HechoIntent: AppIntent {
    static var title: LocalizedStringResource = "Misión hecha"

    @Parameter(title: "Misión")
    var misionId: String

    init() {}

    init(misionId: String) {
        self.misionId = misionId
    }

    func perform() async throws -> some IntentResult {
        Juego().accion("hecho", [misionId])
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
