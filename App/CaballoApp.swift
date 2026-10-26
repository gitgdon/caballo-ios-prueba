import SwiftUI
import WidgetKit

@main
struct CaballoApp: App {
    var body: some Scene {
        WindowGroup { Inicio() }
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

private let marron = Color(red: 0.23, green: 0.16, blue: 0.11)
private let dorado = Color(red: 0.85, green: 0.55, blue: 0.25)

struct Inicio: View {
    @StateObject private var modelo = Modelo()
    @Environment(\.scenePhase) private var fase
    @State private var hojaNuevo = false
    @State private var confirmarSaltar = false
    @State private var productoPara: String?
    @State private var plataformaPara: String?
    @State private var editandoPorque = false
    @State private var textoPorque = ""
    @State private var tarjetaActiva = Actividad.activada

    var body: some View {
        ZStack {
            LinearGradient(colors: [marron, dorado], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                if let v = modelo.vista {
                    VStack(spacing: 14) {
                        cabecera(v)
                        frase(v)
                        if !v.hayProductos {
                            Tarjeta { NuevoProducto { nombre, lugar in modelo.hacer("nuevo", [nombre, lugar]) } }
                        } else if let d = v.decisiones.first {
                            Decision(producto: d, modelo: modelo, hojaNuevo: $hojaNuevo).id(d.id)
                        } else {
                            misiones(v)
                            acciones(v)
                        }
                        ajustes
                    }
                    .padding()
                }
            }
            .foregroundStyle(.white)
        }
        .onAppear { modelo.refrescar() }
        .onChange(of: fase) { _, nueva in if nueva == .active { modelo.refrescar() } }
        .sheet(isPresented: $hojaNuevo) {
            NuevoProducto { nombre, lugar in
                modelo.hacer("nuevo", [nombre, lugar])
                hojaNuevo = false
            }
            .padding()
            .presentationDetents([.medium])
        }
        .alert("Caballo Blanco", isPresented: Binding(get: { modelo.aviso != nil }, set: { if !$0 { modelo.aviso = nil } })) {
            Button("Vale") { modelo.aviso = nil }
        } message: { Text(modelo.aviso ?? "") }
        .confirmationDialog("¿Empezar otro producto en paralelo?", isPresented: $modelo.ofrecerParalelo, titleVisibility: .visible) {
            Button("Sí") { hojaNuevo = true }
            Button("No", role: .cancel) {}
        }
        .alert("✍️ Mi porqué", isPresented: $editandoPorque) {
            TextField("Tu razón para seguir (máx. 80)", text: $textoPorque)
            Button("Guardar") { modelo.hacer("porque", [textoPorque]) }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func cabecera(_ v: Vista) -> some View {
        Tarjeta {
            HStack(spacing: 14) {
                Caballo(humor: v.humor, lado: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nivel \(v.nivel) · \(v.rango)").font(.title3.bold())
                    ProgressView(value: Double(v.xp), total: Double(max(v.xpSig, 1))).tint(.white)
                    Text("\(v.xp) / \(v.xpSig) XP").font(.caption).opacity(0.8)
                    Text("🔥 \(v.racha) días" + (v.escudos > 0 ? "   🛡️ \(v.escudos)" : "")).font(.subheadline.bold())
                }
            }
            if let linea = v.lineaProducto { Text(linea).font(.caption).opacity(0.85) }
        }
    }

    @ViewBuilder private func frase(_ v: Vista) -> some View {
        if let porque = v.porque {
            Tarjeta { Text("💭 " + porque).font(.body.italic()) }
        } else if let f = v.frase {
            Button {
                modelo.aviso = "\(f.autor)\n\n\(f.detalle)\n\nVídeo: \(f.video)"
            } label: {
                Tarjeta {
                    Text(f.texto).font(.body.italic()).multilineTextAlignment(.leading)
                    Text("💬 Toca para ver de quién es").font(.caption2).opacity(0.7)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func misiones(_ v: Vista) -> some View {
        Tarjeta {
            Text("Misiones de hoy").font(.headline)
            if v.pendientes.isEmpty {
                Text("Día cerrado. Descansa, jinete.").opacity(0.85)
            }
            ForEach(v.pendientes) { m in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.bloque.uppercased()).font(.caption2.bold()).opacity(0.7)
                        Text(m.texto).font(.subheadline)
                    }
                    Spacer()
                    Button("✅ Hecho") { modelo.hacer("hecho", [m.id]) }
                        .buttonStyle(.borderedProminent).tint(.green)
                }
            }
        }
    }

    private func acciones(_ v: Vista) -> some View {
        Tarjeta {
            if v.puedeMinimo {
                Button("😮‍💨 Hoy no tengo ganas") { modelo.hacer("minimo") }
            }
            Button("Saltar hoy") { confirmarSaltar = true }
                .confirmationDialog("¿Seguro?", isPresented: $confirmarSaltar, titleVisibility: .visible) {
                    if v.puedeMinimo { Button("😮‍💨 Mejor hago lo mínimo") { modelo.hacer("minimo") } }
                    Button("Saltar igualmente", role: .destructive) { modelo.hacer("saltar") }
                    Button("Vale, voy a hacer algo", role: .cancel) {}
                } message: { Text(mensajeSaltar(v)) }
            DisclosureGroup("Más…") {
                VStack(alignment: .leading, spacing: 12) {
                    if !v.vendibles.isEmpty {
                        Button("🟢 Un vídeo ha funcionado") { conProducto(v, "ganador") }
                        Button("🔥 Un vídeo ha pasado de 10k") { conProducto(v, "viral") }
                        Button("💰 He vendido") { conProducto(v, "vendido") }
                    }
                    if v.puedeNuevo { Button("➕ Nuevo producto") { hojaNuevo = true } }
                    Button("✍️ Mi porqué") {
                        textoPorque = v.porqueGuardado ?? ""
                        editandoPorque = true
                    }
                }
                .padding(.top, 8)
            }
            .tint(.white)
            .confirmationDialog("¿Qué producto?", isPresented: Binding(get: { productoPara != nil }, set: { if !$0 { productoPara = nil } })) {
                ForEach(v.vendibles) { p in
                    Button(p.nombre) { if let a = productoPara { ejecutar(a, p.id) } }
                }
            }
            .confirmationDialog("¿En qué plataforma?", isPresented: Binding(get: { plataformaPara != nil }, set: { if !$0 { plataformaPara = nil } })) {
                Button("TikTok") { viral("tiktok") }
                Button("Instagram") { viral("instagram") }
                Button("YouTube Shorts") { viral("youtube") }
            }
        }
        .buttonStyle(.plain)
    }

    private var ajustes: some View {
        Tarjeta {
            Toggle("Tarjeta en la pantalla de bloqueo", isOn: Binding(
                get: { tarjetaActiva },
                set: { nuevo in
                    tarjetaActiva = nuevo
                    Actividad.activada = nuevo
                    modelo.refrescar()
                }
            ))
            .tint(.green)
            Text("Incluye el 🐴 de la isla dinámica: iOS no deja mostrar una sin la otra.")
                .font(.caption).opacity(0.75)
        }
    }

    private func mensajeSaltar(_ v: Vista) -> String {
        let aviso: String? = switch v.efectoSaltar {
        case "escudo": "Gastarás 1 escudo 🛡️ (te quedarán \(v.escudos - 1))"
        case "pierde": "No tienes escudos 🛡️: tu racha se perderá"
        default: nil
        }
        return [aviso, v.fraseSaltar].compactMap { $0 }.joined(separator: "\n\n")
    }

    private func conProducto(_ v: Vista, _ accion: String) {
        if v.vendibles.count == 1 { ejecutar(accion, v.vendibles[0].id) } else { productoPara = accion }
    }

    private func ejecutar(_ accion: String, _ id: String) {
        productoPara = nil
        if accion == "viral" { plataformaPara = id } else { modelo.hacer(accion, [id]) }
    }

    private func viral(_ plataforma: String) {
        if let id = plataformaPara { modelo.hacer("viral", [id, plataforma]) }
        plataformaPara = nil
    }
}

struct NuevoProducto: View {
    let crear: (String, String) -> Void
    @State private var nombre = ""
    @State private var enCalle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nuevo producto").font(.headline)
            TextField("¿Qué producto vas a probar?", text: $nombre)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.primary)
            Picker("¿Dónde lo grabas?", selection: $enCalle) {
                Text("En casa").tag(false)
                Text("En la calle").tag(true)
            }
            .pickerStyle(.segmented)
            Button("Empezar") {
                let limpio = nombre.trimmingCharacters(in: .whitespaces)
                if !limpio.isEmpty { crear(limpio, enCalle ? "calle" : "casa") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

/// La pregunta del día 14 (o tras un 10k sin ventas), paso a paso.
struct Decision: View {
    let producto: Vista.Ref
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var vendio = false
    @State private var poco = false

    var body: some View {
        Tarjeta {
            if !vendio {
                Text("¿Ha vendido \(producto.nombre)?").font(.headline)
                HStack {
                    Button("No") { modelo.hacer("decidir", [producto.id, "descartar"]) }
                        .buttonStyle(.bordered)
                    Button("Sí") {
                        modelo.hacer("vendido", [producto.id])
                        vendio = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !poco {
                Text("¿Cuánto has vendido?").font(.headline)
                HStack {
                    Button("Mucho") { modelo.hacer("decidir", [producto.id, "mucho"]) }
                    Button("Normal") {
                        modelo.hacer("decidir", [producto.id, "normal"])
                        modelo.ofrecerParalelo = true
                    }
                    Button("Poco") { poco = true }
                }
                .buttonStyle(.bordered)
            } else {
                Text("¿Qué hacemos con \(producto.nombre)?").font(.headline)
                Button("Mantener y empezar otro en paralelo") {
                    modelo.hacer("decidir", [producto.id, "poco"])
                    hojaNuevo = true
                }
                .buttonStyle(.borderedProminent)
                Button("Dejarlo") { modelo.hacer("decidir", [producto.id, "descartar"]) }
                    .buttonStyle(.bordered)
            }
        }
    }
}
