import SwiftUI
import WidgetKit

@main
struct CaballoApp: App {
    var body: some Scene {
        WindowGroup { Raiz() }
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
    }

    func hacer(_ nombre: String, _ args: [String] = []) {
        if let r = juego.accion(nombre, args) {
            var mensajes = r.logros
            if let g = r.ganador { mensajes.insert(g, at: 0) }
            if let c = r.checkpoint { mensajes.insert(c, at: 0) }
            if !mensajes.isEmpty { aviso = mensajes.joined(separator: "\n") }
        }
        vista = juego.vista()
        actualizarFuera()
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
        .onChange(of: fase) { _, nueva in if nueva == .active { modelo.refrescar() } }
        .sheet(isPresented: $hojaNuevo) {
            HojaNuevoProducto { nombre, lugar in
                modelo.hacer("nuevo", [nombre, lugar])
                hojaNuevo = false
            }
            .padding(Espacio.l)
            .presentationDetents([.medium])
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
