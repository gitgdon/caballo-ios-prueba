import SwiftUI
import UserNotifications

/// Pestaña Más: mi porqué, la frase de hoy, técnicas y ganchos, avisos, reto, ajustes y créditos,
/// al estilo de los Ajustes de iOS.
struct Mas: View {
    @ObservedObject var modelo: Modelo
    @State private var textoPorque = ""
    @State private var tarjetaActiva = Actividad.activada
    @FocusState private var escribiendo: Bool

    private static let maximo = 80

    var body: some View {
        NavigationStack {
            lista
                .scrollContentBackground(.hidden)
                .background(Tema.fondo)
                .navigationTitle("Más")
        }
        .onAppear { if textoPorque.isEmpty { textoPorque = modelo.vista?.porqueGuardado ?? "" } }
    }

    private var lista: some View {
        List {
            seccionPorque
            if let f = modelo.vista?.frase { seccionFrase(f) }
            if let v = modelo.vista { seccionBancos(v) }
            seccionCalendario
            SeccionAvisos(modelo: modelo)
            if let r = modelo.vista?.reto { SeccionReto(modelo: modelo, reto: r) }
            seccionAjustes
            Section("Créditos") {
                Text("Iconos: Phosphor Icons (MIT)")
                    .foregroundStyle(Tema.texto)
            }
            .listRowBackground(Tema.superficie)
        }
        .listStyle(.insetGrouped)
    }

    private var guardado: String { modelo.vista?.porqueGuardado ?? "" }

    private func guardar() {
        modelo.hacer("porque", [textoPorque])
        textoPorque = modelo.vista?.porqueGuardado ?? ""
        escribiendo = false
    }

    private var seccionPorque: some View {
        Section {
            TextField("Tu razón para seguir (máx. 80)", text: $textoPorque)
                .focused($escribiendo)
                .foregroundStyle(Tema.texto)
                .frame(minHeight: 44)
                .submitLabel(.done)
                .onSubmit { guardar() }
                .onChange(of: textoPorque) { _, nuevo in
                    if nuevo.count > Self.maximo { textoPorque = String(nuevo.prefix(Self.maximo)) }
                }
                .accessibilityLabel("Mi porqué")
            Button("Guardar") { guardar() }
                .foregroundStyle(Tema.acento)
                .frame(minHeight: 44)
                .disabled(textoPorque == guardado)
                .accessibilityLabel("Guardar mi porqué")
        } header: {
            Text("✍️ Mi porqué")
        } footer: {
            Text("\(textoPorque.count)/\(Self.maximo)")
        }
        .listRowBackground(Tema.superficie)
    }

    private func seccionFrase(_ f: Vista.Frase) -> some View {
        Section("Frase de hoy") {
            VStack(alignment: .leading, spacing: Espacio.s) {
                Text(f.texto)
                    .font(.body.italic())
                    .foregroundStyle(Tema.texto)
                Text("— " + f.autor)
                    .font(.subheadline.bold())
                    .foregroundStyle(Tema.texto)
                if f.detalle != f.texto {
                    Text(f.detalle)
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSuave)
                }
                Text("Vídeo: \(f.video)")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSuave)
            }
            .padding(.vertical, Espacio.xs)
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(Tema.superficie)
    }

    private func seccionBancos(_ v: Vista) -> some View {
        Section {
            NavigationLink {
                ListaTecnicas(tecnicas: v.tecnicas)
            } label: {
                filaEnlace("Técnicas", detalle: "\(v.tecnicas.filter(\.desbloqueada).count) de \(v.tecnicas.count)")
            }
            NavigationLink {
                ListaGanchos(ganchos: v.ganchos, productos: v.productos)
            } label: {
                filaEnlace("Mis ganchos", detalle: v.ganchos.isEmpty ? nil : "\(v.ganchos.count)")
            }
        }
        .listRowBackground(Tema.superficie)
    }

    private var seccionCalendario: some View {
        Section {
            NavigationLink {
                Calendario(modelo: modelo)
            } label: {
                filaEnlace("Calendario", detalle: nil)
            }
        }
        .listRowBackground(Tema.superficie)
    }

    private func filaEnlace(_ titulo: String, detalle: String?) -> some View {
        HStack {
            Text(titulo)
                .foregroundStyle(Tema.texto)
            Spacer()
            if let detalle {
                Text(detalle)
                    .foregroundStyle(Tema.textoSuave)
            }
        }
        .frame(minHeight: 44)
    }

    private var seccionAjustes: some View {
        Section {
            Toggle("Tarjeta en la pantalla de bloqueo", isOn: Binding(
                get: { tarjetaActiva },
                set: { nuevo in
                    tarjetaActiva = nuevo
                    Actividad.activada = nuevo
                    modelo.refrescar()
                }
            ))
            .tint(Tema.acento)
            .foregroundStyle(Tema.texto)
            .frame(minHeight: 44)
        } header: {
            Text("Ajustes")
        } footer: {
            Text("Incluye el 🐴 de la isla dinámica: iOS no deja mostrar una sin la otra.")
        }
        .listRowBackground(Tema.superficie)
    }
}

/// Avisos locales: interruptor y hora de grabar.
private struct SeccionAvisos: View {
    @ObservedObject var modelo: Modelo
    @Environment(\.scenePhase) private var fase
    @State private var denegado = false

    private var ajustes: AjustesAvisos { modelo.vista?.avisos ?? AjustesAvisos(activos: true, hora: "18:00") }

    private func guardar(activos: Bool, hora: String) {
        modelo.hacer("avisosConfig", [activos ? "1" : "0", hora])
    }

    /// "HH:mm" → hoy a esa hora.
    private static func fecha(_ hora: String) -> Date {
        let partes = hora.split(separator: ":").compactMap { Int($0) }
        let h = partes.count == 2 ? partes[0] : 18
        let m = partes.count == 2 ? partes[1] : 0
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
    }

    private static func hora(_ fecha: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: fecha)
        return String(format: "%02d:%02d", c.hour ?? 18, c.minute ?? 0)
    }

    private var activos: Binding<Bool> {
        Binding(get: { ajustes.activos }, set: { guardar(activos: $0, hora: ajustes.hora) })
    }

    private var horaGrabar: Binding<Date> {
        Binding(get: { Self.fecha(ajustes.hora) }, set: { guardar(activos: ajustes.activos, hora: Self.hora($0)) })
    }

    var body: some View {
        Section {
            Toggle("Avisos", isOn: activos)
                .tint(Tema.acento)
                .foregroundStyle(Tema.texto)
                .frame(minHeight: 44)
            DatePicker("Hora de grabar", selection: horaGrabar, displayedComponents: .hourAndMinute)
                .tint(Tema.acento)
                .foregroundStyle(Tema.texto)
                .frame(minHeight: 44)
        } header: {
            Text("Avisos")
        } footer: {
            VStack(alignment: .leading, spacing: Espacio.xs) {
                Text("Si no has hecho los vídeos, vuelve cada 3 h hasta las 22:00. Al marcar el último, paran.")
                if denegado {
                    Text("Actívalos en Ajustes de iOS → Caballo Blanco → Notificaciones")
                }
            }
        }
        .listRowBackground(Tema.superficie)
        .task { await comprobarPermiso() }
        .onChange(of: fase) { _, nueva in
            if nueva == .active { Task { await comprobarPermiso() } }
        }
    }

    private func comprobarPermiso() async {
        let estado = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        denegado = estado == .denied
    }
}

/// Reto: meta y fecha editables; tras vencer o cumplirlo, empezar otro.
private struct SeccionReto: View {
    @ObservedObject var modelo: Modelo
    let reto: Reto
    @State private var textoMeta = ""
    @FocusState private var escribiendo: Bool

    /// Duración del reto nuevo; luego la fecha se cambia aquí mismo.
    private static let diasRetoNuevo = 90

    private static let formatoDia: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var metaNueva: Int? {
        guard let v = importe(textoMeta), v >= 1, v <= 9_007_199_254_740_991 else { return nil }
        return Int(v.rounded())
    }

    private var metaGuardable: Bool { metaNueva != nil && metaNueva != reto.meta }

    private var fin: Binding<Date> {
        Binding(get: { Self.formatoDia.date(from: reto.fin) ?? .now },
                set: { modelo.hacer("reto", [String(reto.meta), Self.formatoDia.string(from: $0)]) })
    }

    private func guardarMeta() {
        guard let m = metaNueva else { return }
        modelo.hacer("reto", [String(m), reto.fin])
        textoMeta = miles(m)
        escribiendo = false
    }

    private func empezarNuevo() {
        let dia = Calendar.current.date(byAdding: .day, value: Self.diasRetoNuevo, to: .now) ?? .now
        modelo.hacer("retoNuevo", [String(metaNueva ?? reto.meta), Self.formatoDia.string(from: dia)])
    }

    var body: some View {
        Section {
            campoMeta
            Button("Guardar meta", action: guardarMeta)
                .foregroundStyle(metaGuardable ? Tema.acento : Tema.textoSuave)
                .frame(minHeight: 44)
                .disabled(!metaGuardable)
                .accessibilityLabel("Guardar la meta del reto")
            DatePicker("Fecha", selection: fin, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                .tint(Tema.acento)
                .foregroundStyle(Tema.texto)
                .frame(minHeight: 44)
            if reto.vencido || reto.cumplido {
                Button("Empezar reto nuevo", action: empezarNuevo)
                    .foregroundStyle(Tema.acento)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Empezar reto nuevo")
            }
        } header: {
            Text("Reto")
        }
        .listRowBackground(Tema.superficie)
    }

    private var campoMeta: some View {
        HStack(spacing: Espacio.s) {
            Text("Meta")
                .foregroundStyle(Tema.texto)
            TextField("10.000", text: $textoMeta)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($escribiendo)
                .foregroundStyle(Tema.texto)
                .accessibilityLabel("Meta del reto en euros")
            Text("€")
                .foregroundStyle(Tema.textoSuave)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .onAppear { if textoMeta.isEmpty { textoMeta = miles(reto.meta) } }
    }
}
