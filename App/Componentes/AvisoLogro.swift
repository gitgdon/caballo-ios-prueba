import SwiftUI

/// Píldora de logro que baja desde arriba.
struct AvisoLogro: View {
    let texto: String

    var body: some View {
        Text(texto)
            .font(.subheadline)
            .foregroundStyle(Tema.texto)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Espacio.l)
            .padding(.vertical, Espacio.m)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.lg))
            .overlay(RoundedRectangle(cornerRadius: Radio.lg).stroke(Tema.borde, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.horizontal, Espacio.l)
    }
}

private struct ModificadorAvisoLogro: ViewModifier {
    @Binding var texto: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let valor = texto {
                    AvisoLogro(texto: valor)
                        .padding(.top, Espacio.s)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { texto = nil }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Toca para cerrar")
                        .task(id: valor) {
                            // Más tiempo cuanto más largo (el del bajón ronda los 9 s).
                            let segundos = max(3, Double(valor.count) / 15)
                            try? await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
                            if !Task.isCancelled { texto = nil }
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: texto)
    }
}

extension View {
    /// Muestra un aviso de logro arriba; se quita al tocarlo o pasado un tiempo según su largo (mínimo 3 s).
    func avisoLogro(texto: Binding<String?>) -> some View {
        modifier(ModificadorAvisoLogro(texto: texto))
    }
}

#Preview("Aviso claro") {
    AvisoLogro(texto: "Nivel 5\nSubiste de nivel").padding().background(Tema.fondo)
}

#Preview("Aviso oscuro") {
    AvisoLogro(texto: "Nivel 5\nSubiste de nivel").padding().background(Tema.fondo).preferredColorScheme(.dark)
}
