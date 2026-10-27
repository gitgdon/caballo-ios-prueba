import SwiftUI

/// La pregunta del día 14 (o tras un 10k sin ventas), paso a paso.
struct HojaDecision: View {
    let producto: Vista.Ref
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var vendio = false
    @State private var poco = false
    /// Respuestas a las tres preguntas de revisión (nil sin contestar).
    @State private var respuestas: [Bool?] = [nil, nil, nil]
    @State private var revisado = false

    private static let preguntas = ["¿Puedes hacerlo diferente?", "¿Sabes por qué no vende?", "¿Tienes ideas nuevas?"]

    /// Las preguntas solo salen si el producto tuvo visitas y no se marcó como vendido.
    private var conRevision: Bool {
        guard let fila = modelo.vista?.productos.first(where: { $0.id == producto.id }) else { return false }
        return fila.visitasMax > 0 && !fila.vendido
    }

    /// "seguir" o "soltar" cuando las tres están contestadas.
    private var recomendacion: String? {
        guard respuestas.allSatisfy({ $0 != nil }) else { return nil }
        return modelo.recomendacion(respuestas[0] == true, respuestas[1] == true, respuestas[2] == true)
    }

    var body: some View {
        Tarjeta {
            Text("DECISIÓN")
                .font(.caption.bold())
                .foregroundStyle(Tema.textoSuave)
            if conRevision && !revisado && !vendio {
                pasoRevision
            } else if !vendio {
                pasoVendio
            } else if !poco {
                pasoCuanto
            } else {
                pasoPoco
            }
        }
    }

    private func pregunta(_ texto: String) -> some View {
        Text(texto)
            .font(.title2.bold())
            .foregroundStyle(Tema.texto)
            .padding(.bottom, Espacio.s)
    }

    private var pasoVendio: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            pregunta("¿Ha vendido \(producto.nombre)?")
            Button("Sí") {
                modelo.hacer("vendido", [producto.id])
                vendio = true
            }
            .buttonStyle(.principal)
            .accessibilityLabel("Sí, ha vendido")
            Button("No") { modelo.hacer("decidir", [producto.id, "descartar"]) }
                .buttonStyle(.secundario)
                .accessibilityLabel("No ha vendido")
        }
    }

    private var pasoCuanto: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            pregunta("¿Cuánto has vendido?")
            Button("Mucho") { modelo.hacer("decidir", [producto.id, "mucho"]) }
                .buttonStyle(.secundario)
                .accessibilityLabel("Mucho")
            Button("Normal") {
                modelo.hacer("decidir", [producto.id, "normal"])
                modelo.ofrecerParalelo = true
            }
            .buttonStyle(.secundario)
            .accessibilityLabel("Normal")
            Button("Poco") { poco = true }
                .buttonStyle(.secundario)
                .accessibilityLabel("Poco")
        }
    }

    private var pasoPoco: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            pregunta("¿Qué hacemos con \(producto.nombre)?")
            Button("Mantener y empezar otro en paralelo") {
                modelo.hacer("decidir", [producto.id, "poco"])
                hojaNuevo = true
            }
            .buttonStyle(.principal)
            .accessibilityLabel("Mantener y empezar otro en paralelo")
            Button("Dejarlo") { modelo.hacer("decidir", [producto.id, "descartar"]) }
                .buttonStyle(.secundario)
                .accessibilityLabel("Dejarlo")
        }
    }

    private var pasoRevision: some View {
        VStack(alignment: .leading, spacing: Espacio.m) {
            pregunta("Antes de decidir sobre \(producto.nombre)")
            ForEach(0..<3, id: \.self) { i in
                PreguntaSiNo(texto: Self.preguntas[i], respuesta: $respuestas[i])
            }
            if let r = recomendacion {
                Text(r == "seguir" ? "Te recomendamos seguir" : "Te recomendamos soltarlo")
                    .font(.headline)
                    .foregroundStyle(Tema.texto)
                Button("Continuar") { revisado = true }
                    .buttonStyle(.principal)
                    .accessibilityLabel("Continuar a la decisión")
            }
        }
    }
}

/// Una pregunta con Sí / No; la respuesta elegida va resaltada.
private struct PreguntaSiNo: View {
    let texto: String
    @Binding var respuesta: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) {
            Text(texto)
                .font(.body)
                .foregroundStyle(Tema.texto)
            HStack(spacing: Espacio.s) {
                opcion("Sí", true)
                opcion("No", false)
            }
        }
    }

    @ViewBuilder private func opcion(_ titulo: String, _ valor: Bool) -> some View {
        let elegida = respuesta == valor
        Button(titulo) { respuesta = valor }
            .buttonStyle(elegida ? EstiloBoton(variante: .principal) : EstiloBoton(variante: .secundario))
            .accessibilityLabel("\(texto) \(titulo)")
            .accessibilityAddTraits(elegida ? .isSelected : [])
    }
}
