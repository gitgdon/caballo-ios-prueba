import SwiftUI

/// Estilos de botón: .principal (52), .secundario, .fantasma y .peligro (44).
struct EstiloBoton: ButtonStyle {
    enum Variante { case principal, secundario, fantasma, peligro }
    let variante: Variante
    @Environment(\.isEnabled) private var activo

    private var alto: CGFloat { variante == .principal ? 52 : 44 }

    private var fondo: Color {
        switch variante {
        case .principal: return Tema.acento
        case .secundario: return Tema.superficie2
        case .fantasma: return .clear
        case .peligro: return Tema.peligro
        }
    }

    private var texto: Color {
        switch variante {
        case .principal: return Tema.sobreAcento
        case .secundario: return Tema.texto
        case .fantasma: return Tema.acento
        case .peligro: return Tema.sobreAcento
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(texto)
            .frame(maxWidth: .infinity, minHeight: alto)
            .background(fondo, in: RoundedRectangle(cornerRadius: Radio.md))
            .contentShape(RoundedRectangle(cornerRadius: Radio.md))
            .opacity(activo ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

extension ButtonStyle where Self == EstiloBoton {
    static var principal: EstiloBoton { EstiloBoton(variante: .principal) }
    static var secundario: EstiloBoton { EstiloBoton(variante: .secundario) }
    static var fantasma: EstiloBoton { EstiloBoton(variante: .fantasma) }
    static var peligro: EstiloBoton { EstiloBoton(variante: .peligro) }
}

#Preview("Botones claro") {
    VStack(spacing: Espacio.m) {
        Button("Principal") {}.buttonStyle(.principal)
        Button("Secundario") {}.buttonStyle(.secundario)
        Button("Fantasma") {}.buttonStyle(.fantasma)
        Button("Peligro") {}.buttonStyle(.peligro)
        Button("Desactivado") {}.buttonStyle(.principal).disabled(true)
    }
    .padding().background(Tema.fondo)
}

#Preview("Botones oscuro") {
    VStack(spacing: Espacio.m) {
        Button("Principal") {}.buttonStyle(.principal)
        Button("Secundario") {}.buttonStyle(.secundario)
        Button("Fantasma") {}.buttonStyle(.fantasma)
        Button("Peligro") {}.buttonStyle(.peligro)
    }
    .padding().background(Tema.fondo).preferredColorScheme(.dark)
}
