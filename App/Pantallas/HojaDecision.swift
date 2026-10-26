import SwiftUI

/// La pregunta del día 14 (o tras un 10k sin ventas), paso a paso.
struct HojaDecision: View {
    let producto: Vista.Ref
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var vendio = false
    @State private var poco = false

    var body: some View {
        Tarjeta {
            Text("DECISIÓN")
                .font(.caption.bold())
                .foregroundStyle(Tema.textoSuave)
            if !vendio {
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
}
