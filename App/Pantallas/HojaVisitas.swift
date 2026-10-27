import SwiftUI

/// Hoja para apuntar las visitas de un vídeo: dice en qué fase falla y qué cambiar.
/// Si el vídeo llega al cierre o más, pide el gancho para el banco.
struct HojaVisitas: View {
    let producto: Vista.Ref
    @ObservedObject var modelo: Modelo
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var fase: Fase?
    @State private var pideGancho = false
    @State private var guardadas = 0
    @State private var gancho = ""
    @FocusState private var enfocado: Bool

    /// Entero de 0 al más grande que guarda el juego (Number.MAX_SAFE_INTEGER); acepta "1.240".
    private var visitas: Int? {
        guard let v = importe(texto), v == v.rounded(), v <= 9_007_199_254_740_991 else { return nil }
        return Int(v)
    }

    private var ganchoLimpio: String { gancho.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.m) {
                Text("Apuntar visitas")
                    .font(.title2.bold())
                    .foregroundStyle(Tema.texto)
                    .accessibilityAddTraits(.isHeader)
                Text(producto.nombre)
                    .font(.subheadline)
                    .foregroundStyle(Tema.textoSuave)
                if let fase {
                    diagnostico(fase)
                    if pideGancho { preguntaGancho } else { botonListo }
                } else {
                    campoVisitas
                    Button("Guardar", action: guardar)
                        .buttonStyle(.principal)
                        .disabled(visitas == nil)
                        .accessibilityLabel("Guardar visitas")
                }
            }
            .padding(Espacio.l)
        }
        .onAppear { enfocado = true }
    }

    private var campoVisitas: some View {
        TextField("Visitas del vídeo", text: $texto)
            .keyboardType(.numberPad)
            .focused($enfocado)
            .font(.title.bold())
            .foregroundStyle(Tema.texto)
            .padding(.horizontal, Espacio.l)
            .frame(minHeight: 56)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.md))
            .overlay(RoundedRectangle(cornerRadius: Radio.md).stroke(Tema.bordeCampo, lineWidth: 1))
            .accessibilityLabel("Visitas del vídeo")
    }

    private func diagnostico(_ f: Fase) -> some View {
        Tarjeta {
            Text("\(miles(guardadas)) visitas")
                .font(.caption.bold())
                .foregroundStyle(Tema.textoSuave)
            Text("Falla en: \(f.donde)")
                .font(.title3.bold())
                .foregroundStyle(Tema.texto)
                .fixedSize(horizontal: false, vertical: true)
            Text("Cambia: \(f.cambio)")
                .font(.body)
                .foregroundStyle(Tema.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var preguntaGancho: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            Text("¿Qué gancho usaste?")
                .font(.headline)
                .foregroundStyle(Tema.texto)
            TextField("Lo primero que se ve o se oye", text: $gancho)
                .font(.body)
                .foregroundStyle(Tema.texto)
                .padding(.horizontal, Espacio.m)
                .frame(minHeight: 44)
                .background(Tema.superficie2, in: RoundedRectangle(cornerRadius: Radio.sm))
                .overlay(RoundedRectangle(cornerRadius: Radio.sm).stroke(Tema.bordeCampo, lineWidth: 1))
                .accessibilityLabel("Gancho que usaste")
                .onChange(of: gancho) { _, nuevo in
                    if nuevo.count > 80 { gancho = String(nuevo.prefix(80)) }
                }
            Button("Guardar gancho", action: guardarGancho)
                .buttonStyle(.principal)
                .disabled(ganchoLimpio.isEmpty)
                .accessibilityLabel("Guardar gancho")
            Button("Ahora no") { cerrar() }
                .buttonStyle(.fantasma)
                .accessibilityLabel("Ahora no, cerrar")
        }
    }

    private var botonListo: some View {
        Button("Listo") { cerrar() }
            .buttonStyle(.principal)
            .accessibilityLabel("Listo, cerrar")
    }

    private func guardar() {
        guard let v = visitas else { return }
        let r = modelo.hacerConResultado("visitas", [producto.id, String(v)])
        guard let f = r?.fase else { cerrar(); return }
        guardadas = v
        pideGancho = r?.pideGancho ?? false
        fase = f
    }

    private func guardarGancho() {
        guard !ganchoLimpio.isEmpty else { return }
        modelo.hacer("gancho", [producto.id, ganchoLimpio, String(guardadas)])
        cerrar()
    }
}
