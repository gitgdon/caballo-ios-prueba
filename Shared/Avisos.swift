import Foundation
import UserNotifications

/// Avisos locales del día (planAvisos de core.js), con el botón "Hecho" en la notificación.
enum Avisos {
    static let categoria = "MISION"
    static let accionHecho = "HECHO"
    /// El aviso de racha no lleva "Hecho": marcaría un vídeo que no se ha hecho.
    static let categoriaRacha = "RACHA"
    private static let prefijo = "aviso-"

    /// La acción "Hecho" se ejecuta sin abrir la app.
    static func registrarCategoria() {
        let hecho = UNNotificationAction(identifier: accionHecho, title: "Hecho", options: [])
        let cat = UNNotificationCategory(identifier: categoria, actions: [hecho], intentIdentifiers: [], options: [])
        let racha = UNNotificationCategory(identifier: categoriaRacha, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat, racha])
    }

    static func pedirPermisoSiHaceFalta() async {
        let centro = UNUserNotificationCenter.current()
        guard await centro.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await centro.requestAuthorization(options: [.alert, .sound])
    }

    /// Se avisa cuando una misión se marca fuera de la app (notificación o widget), para que la app se refresque.
    static let cambioFuera = Notification.Name("CaballoBlanco.cambioFuera")

    /// Programa los avisos del plan actual de este juego.
    static func reprogramar(_ juego: Juego) async {
        await reprogramar(juego.avisos())
    }

    /// Primero añade los avisos del plan (el mismo id sustituye al anterior) y después quita los pendientes
    /// que ya no están en él: si iOS cierra el proceso a medias, no se queda sin avisos.
    /// Sin permiso, el plan no se programa y se quitan todos.
    static func reprogramar(_ plan: [AvisoPlan]) async {
        let centro = UNUserNotificationCenter.current()
        var puestos: Set<String> = []

        switch await centro.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            for aviso in plan {
                guard let cuando = componentes(aviso.fecha) else { continue }
                let contenido = UNMutableNotificationContent()
                contenido.title = aviso.titulo
                contenido.body = aviso.cuerpo
                contenido.sound = .default
                contenido.categoryIdentifier = aviso.tipo == "racha" ? categoriaRacha : categoria
                if let m = aviso.misionId { contenido.userInfo = ["misionId": m] }
                let disparo = UNCalendarNotificationTrigger(dateMatching: cuando, repeats: false)
                let id = aviso.id.hasPrefix(prefijo) ? aviso.id : prefijo + aviso.id
                do {
                    try await centro.add(UNNotificationRequest(identifier: id, content: contenido, trigger: disparo))
                    puestos.insert(id)
                } catch {}
            }
        default: break
        }

        let sobran = await centro.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(prefijo) && !puestos.contains($0) }
        centro.removePendingNotificationRequests(withIdentifiers: sobran)
    }

    /// "YYYY-MM-DDTHH:MM" en hora local → componentes; nil si no se entiende.
    private static func componentes(_ fecha: String) -> DateComponents? {
        let partes = fecha.split(separator: "T")
        guard partes.count == 2 else { return nil }
        let dia = partes[0].split(separator: "-").compactMap { Int($0) }
        let hora = partes[1].split(separator: ":").compactMap { Int($0) }
        guard dia.count == 3, hora.count == 2 else { return nil }
        return DateComponents(year: dia[0], month: dia[1], day: dia[2], hour: hora[0], minute: hora[1])
    }
}
