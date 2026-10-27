import SwiftUI

/// Formulario de nuevo producto: nombre, dónde se graba y si es copia de algo viral. Va en línea (sin productos) o en hoja.
/// `crear` recibe nombre, lugar ("casa"/"calle") y copia ("si", "no" o "" si se salta).
struct HojaNuevoProducto: View {
    @ObservedObject var modelo: Modelo
    let crear: (String, String, String) -> Void
    @State private var nombre = ""
    @State private var enCalle = false
    @State private var copia: Copia?
    @State private var porQue = false
    @State private var pidenEnlace = false
    @State private var margen = false

    private enum Copia: String { case si, no, saltar }

    private var limpio: String { nombre.trimmingCharacters(in: .whitespaces) }

    /// "si" / "no" para el juego; saltar o sin contestar va vacío.
    private var copiaArg: String {
        switch copia {
        case .si: return "si"
        case .no: return "no"
        default: return ""
        }
    }

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
            preguntaViral
            Button("Empezar") {
                if !limpio.isEmpty { crear(limpio, enCalle ? "calle" : "casa", copiaArg) }
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

    private var preguntaViral: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            Text("¿Lo has visto viral en otra cuenta?")
                .font(.subheadline.bold())
                .foregroundStyle(Tema.texto)
            Picker("¿Lo has visto viral en otra cuenta?", selection: $copia) {
                Text("Sí").tag(Copia?.some(.si))
                Text("No").tag(Copia?.some(.no))
                Text("Saltar").tag(Copia?.some(.saltar))
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("¿Lo has visto viral en otra cuenta?")
            if copia == .si {
                comprobaciones
            } else if copia == .no {
                Text("Es un experimento: el test de 14 días es la prueba")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSuave)
            }
        }
    }

    @ViewBuilder private var comprobaciones: some View {
        comprobacion("Sé por qué funcionó", $porQue)
        comprobacion("La gente pide el enlace", $pidenEnlace)
        comprobacion("Tiene margen", $margen)
        if let aviso = modelo.avisoCopia(porQue, pidenEnlace, margen) {
            Text(aviso)
                .font(.footnote)
                .foregroundStyle(Tema.aviso)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func comprobacion(_ titulo: String, _ valor: Binding<Bool>) -> some View {
        Toggle(titulo, isOn: valor)
            .font(.body)
            .foregroundStyle(Tema.texto)
            .tint(Tema.acento)
            .frame(minHeight: 44)
            .accessibilityLabel(titulo)
    }
}

#Preview("Nuevo producto") {
    Tarjeta { HojaNuevoProducto(modelo: Modelo()) { _, _, _ in } }
        .padding().background(Tema.fondo)
}
