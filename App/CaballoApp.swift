import Combine
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
        if let atajo = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem { _ = abrirFraseDesdeAtajo(atajo) }
        return true
    }

    /// Con escenas, iOS manda la acción rápida del icono al delegado de la escena.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuracion = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuracion.delegateClass = DelegadoEscena.self
        return configuracion
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(abrirFraseDesdeAtajo(shortcutItem))
    }
}

/// Acción rápida "Dame una frase": con la app cerrada (al conectar la escena) o abierta.
final class DelegadoEscena: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let atajo = connectionOptions.shortcutItem { _ = abrirFraseDesdeAtajo(atajo) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(abrirFraseDesdeAtajo(shortcutItem))
    }
}

/// Tipo de la acción rápida del icono (UIApplicationShortcutItems en project.yml).
private let atajoFrase = "com.caballoblanco.frase"

private func abrirFraseDesdeAtajo(_ atajo: UIApplicationShortcutItem) -> Bool {
    guard atajo.type == atajoFrase else { return false }
    pedirFrase("azar")
    return true
}

/// Deja la frase para que `Modelo.refrescar()` la abra (también si la app arranca en ese momento).
private func pedirFrase(_ id: String) {
    UserDefaults(suiteName: Juego.grupo)?.set(id, forKey: "abrirFrase")
    NotificationCenter.default.post(name: Avisos.cambioFuera, object: nil)
}

/// El botón "Hecho" de la notificación marca la misión sin abrir la app. Tocar un aviso de frase la abre.
final class DelegadoAvisos: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let contenido = response.notification.request.content
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier, contenido.categoryIdentifier == Avisos.categoriaFrase {
            if let fraseId = contenido.userInfo["fraseId"] as? String { pedirFrase(fraseId) }
            return
        }
        guard response.actionIdentifier == Avisos.accionHecho else { return }
        let misionId = contenido.userInfo["misionId"] as? String
        let juego = Juego()
        juego.accion("hechoAviso", [misionId ?? ""], origen: "aviso")
        NotificationCenter.default.post(name: Avisos.cambioFuera, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
        await Actividad.actualizar(juego.vista())
        await Avisos.reprogramar(juego)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Las pestañas de `Raiz`, en su orden.
enum Pestana: Hashable {
    case hoy, productos, mas
}

@MainActor
final class Modelo: ObservableObject {
    private let juego = Juego()
    @Published var vista: Vista?
    @Published var aviso: String?
    @Published var ofrecerParalelo = false
    @Published var pestana: Pestana = .hoy
    /// Frase pedida desde un aviso (su id) o desde el icono ("azar"); la pantalla de Frases la abre y la vacía.
    @Published var fraseAbierta: String?
    /// Las 477 frases agrupadas para la pantalla de Frases; se leen una sola vez.
    var catalogo: CatalogoFrases {
        if let c = catalogoLeido { return c }
        let c = CatalogoFrases(juego.frases())
        // Si la lectura falla, se reintenta la próxima vez.
        if !c.todas.isEmpty { catalogoLeido = c }
        return c
    }
    private var catalogoLeido: CatalogoFrases?
    /// Ids que "Dame una frase" ha mostrado en esta sesión (los 5 últimos).
    var frasesMostradas: [String] = []
    /// Píldora "<qué se hizo> · Deshacer" de abajo.
    @Published var pildora: AvisoDeshacer?
    /// Última acción del widget o de un aviso que ya se ofreció deshacer, para no repetir la píldora.
    private var ofrecidaFuera: Deshacer?

    func refrescar() {
        let grupo = UserDefaults(suiteName: Juego.grupo)
        if let id = grupo?.string(forKey: "abrirFrase") {
            grupo?.removeObject(forKey: "abrirFrase")
            pestana = .mas
            fraseAbierta = id
        }
        vista = juego.preparar()
        if let v = vista, !v.bajon.isEmpty, let texto = v.textoBajon {
            juego.accion("bajonVisto", v.bajon)
            aviso = texto
            vista = juego.vista()
        }
        revisarDeshacer()
        actualizarFuera()
    }

    /// Al abrir la app: si lo último vino del widget o de un aviso hace menos de 10 minutos, se ofrece deshacerlo.
    /// Si ya no hay nada que deshacer, o la píldora habla de otra acción, se quita.
    private func revisarDeshacer() {
        guard let d = juego.deshacible() else {
            pildora = nil
            return
        }
        if d.origen != "app", d != ofrecidaFuera, Date().timeIntervalSince(d.hora) < 600 {
            ofrecidaFuera = d
            pildora = AvisoDeshacer(para: d)
        } else if pildora?.para != d {
            pildora = nil
        }
    }

    /// "Deshacer" de la píldora: vuelve al estado de antes y recarga todo (widgets, tarjeta y los dos planes de avisos).
    /// `refrescar()` llama a `preparar()`, que crea la partida si antes no había ninguna.
    func deshacerUltimo() {
        pildora = nil
        juego.deshacer()
        refrescar()
    }

    /// Widgets y tarjeta de la pantalla de bloqueo.
    private func actualizarFuera() {
        WidgetCenter.shared.reloadAllTimelines()
        let v = vista
        Task { await Actividad.actualizar(v) }
        Task { await reprogramarAvisos() }
    }

    /// Avisos de misiones y de frases de hoy y mañana.
    /// El plan se lee en el hilo principal: el JSContext de `juego` no se comparte entre tareas.
    func reprogramarAvisos() async {
        let plan = juego.avisos() + juego.avisosFrases()
        let sonido = vista?.frasesConfig.sonido ?? false
        await Avisos.reprogramar(plan, sonidoFrases: sonido)
    }

    func hacer(_ nombre: String, _ args: [String] = []) {
        hacerConResultado(nombre, args)
    }

    /// Como `hacer`, pero devuelve el resultado (la fase y el gancho de "visitas").
    @discardableResult
    func hacerConResultado(_ nombre: String, _ args: [String] = []) -> Resultado? {
        let deshacible = Juego.deshacibles.contains(nombre)
        let previa = deshacible ? juego.deshacible() : nil
        let r = juego.accion(nombre, args, origen: "app")
        if let r {
            var mensajes = r.logros
            if let g = r.ganador { mensajes.insert(g, at: 0) }
            if let c = r.checkpoint { mensajes.insert(c, at: 0) }
            if !mensajes.isEmpty { aviso = mensajes.joined(separator: "\n") }
        }
        vista = juego.vista()
        let actual = juego.deshacible()
        if deshacible, let d = actual, d != previa {
            pildora = AvisoDeshacer(para: d)
        } else if pildora != nil, pildora?.para != actual {
            pildora = nil
        }
        actualizarFuera()
        return r
    }

    /// Calendario de dinero del mes "YYYY-MM".
    func calendario(mes: String) -> CalendarioMes? {
        juego.calendario(mes: mes)
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
        TabView(selection: $modelo.pestana) {
            Hoy(modelo: modelo, hojaNuevo: $hojaNuevo)
                .tabItem { Label("Hoy", systemImage: "house.fill") }
                .tag(Pestana.hoy)
            Productos(modelo: modelo, hojaNuevo: $hojaNuevo)
                .tabItem { Label("Productos", systemImage: "square.stack.fill") }
                .tag(Pestana.productos)
            Mas(modelo: modelo)
                .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
                .tag(Pestana.mas)
        }
        .tint(Tema.acento)
        .background(Tema.fondo)
        .onAppear { modelo.refrescar() }
        .task {
            await Avisos.pedirPermisoSiHaceFalta()
            await modelo.reprogramarAvisos()
        }
        .onChange(of: fase) { _, nueva in if nueva == .active { modelo.refrescar() } }
        // "Hecho" desde la notificación o el widget con la app abierta.
        .onReceive(NotificationCenter.default.publisher(for: Avisos.cambioFuera).receive(on: DispatchQueue.main)) { _ in
            modelo.refrescar()
        }
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
            .pildoraDeshacer(modelo)
            .apariencia()
        }
        .confirmationDialog("¿Empezar otro producto en paralelo?", isPresented: $modelo.ofrecerParalelo, titleVisibility: .visible) {
            Button("Sí") { hojaNuevo = true }
            Button("No", role: .cancel) {}
        }
        .avisoLogro(texto: $modelo.aviso)
        .pildoraDeshacer(modelo, sobreBarra: true)
        .apariencia()
    }
}

/// Modo claro u oscuro elegido en Más → Ajustes ("auto" sigue al iPhone). Va en `Raiz` y en cada hoja,
/// porque las hojas no siempre heredan `preferredColorScheme`.
private struct ModificadorApariencia: ViewModifier {
    @AppStorage("apariencia") private var apariencia = "auto"

    func body(content: Content) -> some View {
        content.preferredColorScheme(apariencia == "claro" ? .light : apariencia == "oscuro" ? .dark : nil)
    }
}

extension View {
    func apariencia() -> some View {
        modifier(ModificadorApariencia())
    }
}
