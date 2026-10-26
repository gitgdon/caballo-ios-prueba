import SwiftUI

/// Formulario de nuevo producto: nombre y dónde se graba. Va en línea (sin productos) o en hoja.
struct HojaNuevoProducto: View {
    let crear: (String, String) -> Void
    @State private var nombre = ""
    @State private var enCalle = false

    private var limpio: String { nombre.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.m) {
            Text("Nuevo producto")
                .font(.headline)
                .foregroundStyle(Tema.texto)
            campo
            Picker("¿Dónde lo grabas?", selection: $enCalle) {
                Text("En casa").tag(false)
                Text("En la calle").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("¿Dónde lo grabas?")
            Button("Empezar") {
                if !limpio.isEmpty { crear(limpio, enCalle ? "calle" : "casa") }
            }
            .buttonStyle(.principal)
            .disabled(limpio.isEmpty)
            .accessibilityLabel("Empezar el producto")
        }
    }

    private var campo: some View {
        TextField("¿Qué producto vas a probar?", text: $nombre)
            .font(.body)
            .foregroundStyle(Tema.texto)
            .padding(.horizontal, Espacio.m)
            .frame(minHeight: 44)
            .background(Tema.superficie2, in: RoundedRectangle(cornerRadius: Radio.sm))
            .overlay(RoundedRectangle(cornerRadius: Radio.sm).stroke(Tema.bordeCampo, lineWidth: 1))
            .accessibilityLabel("Nombre del producto")
    }
}

#Preview("Nuevo producto") {
    Tarjeta { HojaNuevoProducto { _, _ in } }
        .padding().background(Tema.fondo)
}
