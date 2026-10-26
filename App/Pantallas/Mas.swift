import SwiftUI

/// Pestaña Más: mi porqué, la frase de hoy, ajustes y créditos, al estilo de los Ajustes de iOS.
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
        .onAppear { textoPorque = modelo.vista?.porqueGuardado ?? "" }
    }

    private var lista: some View {
        List {
            seccionPorque
            if let f = modelo.vista?.frase { seccionFrase(f) }
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
