import SwiftUI

/// Círculo de 64 pt con anillo de progreso y etiqueta debajo.
struct Historia<Contenido: View>: View {
    let titulo: String
    let progreso: Double
    let color: Color
    let nueva: Bool
    let contenido: Contenido
    let accion: () -> Void

    init(titulo: String, progreso: Double, color: Color, nueva: Bool,
         @ViewBuilder contenido: () -> Contenido, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.progreso = progreso
        self.color = color
        self.nueva = nueva
        self.contenido = contenido()
        self.accion = accion
    }

    private let lado: CGFloat = 64
    private let grosor: CGFloat = 4
    private let hueco: CGFloat = 3

    var body: some View {
        Button(action: accion) {
            VStack(spacing: Espacio.xs) {
                ZStack {
                    Circle().stroke(Tema.borde, lineWidth: grosor)
                    Circle()
                        .trim(from: 0, to: max(0, min(1, progreso)))
                        .stroke(color, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .opacity(nueva ? 1 : 0.4)
                    contenido
                        .frame(width: lado - 2 * (grosor + hueco), height: lado - 2 * (grosor + hueco))
                        .background(Tema.superficie2, in: Circle())
                }
                .frame(width: lado, height: lado)
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(Tema.textoSuave)
                    .lineLimit(1)
            }
            .frame(minWidth: 64, minHeight: 44)
        }
        .buttonStyle(EstiloHistoria())
        .accessibilityLabel(titulo)
    }
}

private struct EstiloHistoria: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview("Historias claro") {
    HStack(spacing: Espacio.l) {
        Historia(titulo: "Racha", progreso: 0.6, color: Tema.Anillo.racha, nueva: true,
                 contenido: { Text("12").font(.system(.title3, design: .rounded).bold()).foregroundStyle(Tema.texto) },
                 accion: {})
        Historia(titulo: "Nivel", progreso: 0.4, color: Tema.Anillo.xp, nueva: false,
                 contenido: { Caballo(humor: "normal", lado: 36) },
                 accion: {})
    }
    .padding().background(Tema.fondo)
}

#Preview("Historias oscuro") {
    HStack(spacing: Espacio.l) {
        Historia(titulo: "Racha", progreso: 0.6, color: Tema.Anillo.racha, nueva: true,
                 contenido: { Text("12").font(.system(.title3, design: .rounded).bold()).foregroundStyle(Tema.texto) },
                 accion: {})
    }
    .padding().background(Tema.fondo).preferredColorScheme(.dark)
}
