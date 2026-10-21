import AppIntents
import Foundation
import WidgetKit

/// Número compartido entre la app y el widget a través del App Group.
enum Contador {
    static let grupo = "group.com.caballoblanco.prueba"

    static var valor: Int {
        get { UserDefaults(suiteName: grupo)?.integer(forKey: "contador") ?? 0 }
        set { UserDefaults(suiteName: grupo)?.set(newValue, forKey: "contador") }
    }
}

/// Lo que ejecuta el botón del widget sin abrir la app.
struct SumarIntent: AppIntent {
    static var title: LocalizedStringResource = "Sumar uno"

    func perform() async throws -> some IntentResult {
        Contador.valor += 1
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
