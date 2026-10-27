import SwiftUI

/// El caballo (icono Phosphor "horse", vectorial) según su estado: radiante, normal o barro.
/// Con `rango`, el círculo lleva el borde (y en Leyenda el halo) de ese rango; sin él, se ve como siempre.
struct Caballo: View {
    let humor: String
    let lado: CGFloat
    var rango: String? = nil

    private var color: Color {
        switch humor {
        case "radiante": return Tema.Anillo.xp
        case "barro": return Tema.textoSuave.opacity(0.7)
        default: return Tema.texto
        }
    }

    private var borde: Color? {
        switch rango {
        case "Jinete novato": return Tema.Rango.novato
        case "Jinete": return Tema.Rango.jinete
        case "Explorador": return Tema.Rango.explorador
        case "Forajido": return Tema.Rango.forajido
        case "Leyenda": return Tema.Rango.leyenda
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(Tema.superficie2)
                .shadow(color: rango == "Leyenda" ? Tema.Rango.halo.opacity(0.7) : .clear, radius: lado * 0.2)
            if let borde {
                Circle().strokeBorder(borde, lineWidth: max(2, lado * 0.06))
            }
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
        .accessibilityLabel("Tu caballo: \(humor == "barro" ? "con barro" : humor)" + (rango.map { ", \($0)" } ?? ""))
    }
}
