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
                Text(mision.etiquetaEspecial ?? "MISIÓN DE LA \(mision.bloque.uppercased())")
                    .font(.caption.bold())
                    .foregroundStyle(mision.tipo == "raro" ? Tema.acento : Tema.textoSuave)
                if let paso = mision.pasoPrimerVideo { PasosPrimerVideo(paso: paso) }
                Text(mision.texto)
                    .font(.title2.bold())
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
                if let lineaProducto {
                    Text(lineaProducto)
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSuave)
                }
            }
        }
    }
}

extension Vista.Mision {
    /// 1 o 2 mientras dura "Tu primer vídeo" (ensayo y luego publicar); nil en otra misión.
    var pasoPrimerVideo: Int? {
        if tipo == "ensayo" { return 1 }
        if id.hasSuffix(":primer:2") { return 2 }
        return nil
    }

    /// Etiqueta que sustituye a la del bloque en el primer vídeo y en los encuentros raros.
    var etiquetaEspecial: String? {
        if let paso = pasoPrimerVideo { return "TU PRIMER VÍDEO · PASO \(paso) DE 2" }
        if tipo == "raro" { return "✦ ENCUENTRO RARO · +\(xp) XP" }
        return nil
    }
}

/// Barra de 2 pasos de "Tu primer vídeo".
struct PasosPrimerVideo: View {
    let paso: Int

    var body: some View {
        HStack(spacing: Espacio.xs) {
            ForEach(1...2, id: \.self) { i in
                Capsule()
                    .fill(i <= paso ? Tema.acento : Tema.borde)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Misión claro") {
    MisionPrincipal(mision: Vista.Mision(id: "m1", texto: "Graba 1 vídeo", bloque: "tarde", tipo: "normal"),
                    lineaProducto: "Producto 1 · día 3", textoVacio: "Día cerrado. Descansa, jinete.", hecho: {})
        .padding().background(Tema.fondo)
}

#Preview("Misión oscuro") {
    MisionPrincipal(mision: nil, lineaProducto: nil, textoVacio: "Día cerrado. Descansa, jinete.", hecho: {})
        .padding().background(Tema.fondo).preferredColorScheme(.dark)
}
