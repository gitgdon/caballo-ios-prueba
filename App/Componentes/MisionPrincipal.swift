import SwiftUI

/// Tarjeta grande de la misión del momento.
struct MisionPrincipal: View {
    let mision: Vista.Mision?
    let lineaProducto: String?
    let textoVacio: String
    let hecho: () -> Void

    var body: some View {
        Tarjeta {
            if let mision {
                Text("MISIÓN DE LA \(mision.bloque.uppercased())")
                    .font(.caption.bold())
                    .foregroundStyle(Tema.textoSuave)
                Text(mision.texto)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tema.texto)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                if let lineaProducto {
                    Text(lineaProducto)
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSuave)
                }
                if mision.tipo != "decision" {
                    Button(action: hecho) { Text("✓  Hecho") }
                        .buttonStyle(.principal)
                        .padding(.top, Espacio.s)
                        .accessibilityLabel("Marcar como hecha")
                }
            } else {
                Text(textoVacio)
                    .font(.body)
                    .foregroundStyle(Tema.texto)
            }
        }
    }
}
