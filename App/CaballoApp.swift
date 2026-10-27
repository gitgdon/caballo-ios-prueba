import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@main
struct CaballoApp: App {
    @UIApplicationDelegateAdaptor(DelegadoApp.self) private var delegado

    var body: some Scene {
        WindowGroup { Raiz() }
    }
}

final class DelegadoApp: NSObject, UIApplicationDelegate {
    /// El centro de notificaciones guarda su delegado como referencia débil.
    private let avisos = DelegadoAvisos()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Avisos.registrarCategoria()
        UNUserNotificationCenter.current().delegate = avisos
        return true
    }
}

/// El botón "Hecho" de la notificación marca la misión sin abrir la app.
final class DelegadoAvisos: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == Avisos.accionHecho else { return }
        let misionId = response.notification.request.content.userInfo["misionId"] as? String
        let juego = Juego()
        juego.accion("hechoAviso", [misionId ?? ""])
        WidgetCenter.shared.reloadAllTimelines()
        await Actividad.actualizar(juego.vista())
        await Avisos.reprogramar(juego)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

@MainActor
final class Modelo: ObservableObject {
    private let juego = Juego()
    @Published var vista: Vista?
    @Published var aviso: String?
    @Published var ofrecerParalelo = false

    func refrescar() {
        vista = juego.preparar()
        if let v = vista, !v.bajon.isEmpty, let texto = v.textoBajon {
            juego.accion("bajonVisto", v.bajon)
            aviso = texto
            vista = juego.vista()
        }
        actualizarFuera()
    }

    /// Widgets y tarjeta de la pantalla de bloqueo.
    private func actualizarFuera() {
        WidgetCenter.shared.reloadAllTimelines()
        let v = vista
        Task { await Actividad.actualizar(v) }
        Task { await Avisos.reprogramar(Juego()) }
    }

    func hacer(_ nombre: String, _ args: [String] = []) {
        hacerConResultado(nombre, args)
    }

    /// Como `hacer`, pero devuelve el resultado (la fase y el gancho de "visitas").
    @discardableResult
    func hacerConResultado(_ nombre: String, _ args: [String] = []) -> Resultado? {
        let r = juego.accion(nombre, args)
        if let r {
            var mensajes = r.logros
            if let g = r.ganador { mensajes.insert(g, at: 0) }
            if let c = r.checkpoint { mensajes.insert(c, at: 0) }
            if !mensajes.isEmpty { aviso = mensajes.joined(separator: "\n") }
        }
        vista = juego.vista()
        actualizarFuera()
        return r
    }

    /// Aviso amable para una copia a la que le falta alguna comprobación; nil si las cumple.
    func avisoCopia(_ porQue: Bool, _ pidenEnlace: Bool, _ margen: Bool) -> String? {
        juego.avisoCopia(porQue, pidenEnlace, margen)
    }

    /// "seguir" o "soltar" según las tres preguntas del día 14.
    func recomendacion(_ diferente: Bool, _ sabesPorQue: Bool, _ ideas: Bool) -> String {
        juego.recomendacion(diferente, sabesPorQue, ideas)
    }
}

/// Las tres pestañas, con lo que comparten: la hoja de nuevo producto, la oferta de paralelo y los avisos.
struct Raiz: View {
    @StateObject private var modelo = Modelo()
    @Environment(\.scenePhase) private var fase
    @State private var hojaNuevo = false

    var body: some View {
        TabView {
            Hoy(modelo: modelo, hojaNuevo: $hojaNuevo)
                .tabItem { Label("Hoy", systemImage: "house.fill") }
            Productos(modelo: modelo, hojaNuevo: $hojaNuevo)
                .tabItem { Label("Productos", systemImage: "square.stack.fill") }
            Mas(modelo: modelo)
                .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
        }
        .tint(Tema.acento)
        .background(Tema.fondo)
        .onAppear { modelo.refrescar() }
        .task {
            await Avisos.pedirPermisoSiHaceFalta()
            await Avisos.reprogramar(Juego())
        }
        .onChange(of: fase) { _, nueva in if nueva == .active { modelo.refrescar() } }
        .sheet(isPresented: $hojaNuevo) {
            ScrollView {
                HojaNuevoProducto(modelo: modelo) { nombre, lugar, copia in
                    modelo.hacer("nuevo", [nombre, lugar, copia])
                    hojaNuevo = false
                }
                .padding(Espacio.l)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Tema.fondo)
            .avisoLogro(texto: $modelo.aviso)
        }
        .confirmationDialog("¿Empezar otro producto en paralelo?", isPresented: $modelo.ofrecerParalelo, titleVisibility: .visible) {
            Button("Sí") { hojaNuevo = true }
            Button("No", role: .cancel) {}
        }
        .avisoLogro(texto: $modelo.aviso)
    }
}
