import AppIntents
import Foundation
import WidgetKit

/// Número compartido entre la app y el widget a través del App Group.
enum Contador {
    static let grupoOriginal = "group.com.caballoblanco.prueba"

    /// Al firmar desde Windows, la herramienta puede renombrar el App Group (le añade el
    /// identificador del equipo). El nombre real está en el perfil instalado dentro del
    /// propio bundle (`embedded.mobileprovision`), que tienen tanto la app como el widget.
    static let grupo: String = grupoDelPerfil() ?? grupoOriginal

    static var valor: Int {
        get { UserDefaults(suiteName: grupo)?.integer(forKey: "contador") ?? 0 }
        set { UserDefaults(suiteName: grupo)?.set(newValue, forKey: "contador") }
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

/// Lo que ejecuta el botón del widget sin abrir la app.
struct SumarIntent: AppIntent {
    static var title: LocalizedStringResource = "Sumar uno"

    func perform() async throws -> some IntentResult {
        Contador.valor += 1
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
