import SwiftUI

/// Tarjeta del rediseño: superficie, radio lg, sombra en claro y borde en oscuro.
struct Tarjeta<Contenido: View>: View {
    @Environment(\.colorScheme) private var esquema
    @ViewBuilder let contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.s) { contenido }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Espacio.l)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.lg))
            .overlay {
                if esquema == .dark {
                    RoundedRectangle(cornerRadius: Radio.lg).stroke(Tema.borde, lineWidth: 1)
                }
            }
            .shadow(color: esquema == .dark ? .clear : .black.opacity(0.06), radius: 8, y: 2)
    }
}

#Preview("Tarjeta claro") {
    Tarjeta { Text("Hola, jinete").foregroundStyle(Tema.texto) }
        .padding().background(Tema.fondo)
}

#Preview("Tarjeta oscuro") {
    Tarjeta { Text("Hola, jinete").foregroundStyle(Tema.texto) }
        .padding().background(Tema.fondo).preferredColorScheme(.dark)
}
