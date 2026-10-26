import SwiftUI

/// El caballo (icono Phosphor "horse", vectorial) según su estado: radiante, normal o barro.
struct Caballo: View {
    let humor: String
    let lado: CGFloat

    private var color: Color {
        switch humor {
        case "radiante": return Tema.Anillo.xp
        case "barro": return Tema.textoSuave.opacity(0.7)
        default: return Tema.texto
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(Tema.superficie2)
            Image("caballo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: lado * 0.58, height: lado * 0.58)
                .foregroundStyle(color)
                .shadow(color: humor == "radiante" ? Tema.Anillo.xp.opacity(0.45) : .clear, radius: 10)
        }
        .frame(width: lado, height: lado)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tu caballo: \(humor)")
    }
}
