import SwiftUI

struct PaginaHistoria: Identifiable {
    let id: String
    let titulo: String
    let grande: String
    let pie: String?
}

/// Visor a pantalla completa. Sin avance automático.
struct VisorHistorias: View {
    let paginas: [PaginaHistoria]
    @State private var indice: Int
    @Environment(\.dismiss) private var cerrar
    @Environment(\.colorScheme) private var esquema

    init(paginas: [PaginaHistoria], inicio: Int) {
        self.paginas = paginas
        _indice = State(initialValue: max(0, min(inicio, max(paginas.count - 1, 0))))
    }

    private func siguiente() {
        if indice < paginas.count - 1 { indice += 1 } else { cerrar() }
    }

    private func anterior() {
        if indice > 0 { indice -= 1 }
    }

    var body: some View {
        ZStack {
            fondo
            if paginas.indices.contains(indice) {
                contenido(paginas[indice])
            }
            zonasTactiles
            VStack(spacing: Espacio.m) {
                barras
                HStack {
                    Spacer()
                    Button(action: { cerrar() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Tema.texto)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Cerrar")
                }
                Spacer()
            }
            .padding(.horizontal, Espacio.l)
            .padding(.top, Espacio.s)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { valor in
                if valor.translation.height > 80 && abs(valor.translation.width) < valor.translation.height { cerrar() }
            })
    }

    private func contenido(_ pagina: PaginaHistoria) -> some View {
        VStack(spacing: Espacio.l) {
            Text(pagina.titulo)
                .font(.headline)
                .foregroundStyle(Tema.texto)
            Text(pagina.grande)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Tema.texto)
                .multilineTextAlignment(.center)
            if let pie = pagina.pie {
                Text(pie)
                    .font(.footnote)
                    .foregroundStyle(Tema.texto.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Espacio.xl)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var fondo: some View {
        if esquema == .dark {
            ZStack {
                Tema.fondo
                RadialGradient(colors: [Tema.Anillo.xp.opacity(0.25), .clear],
                               center: .top, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        } else {
            Rectangle().fill(Tema.degradadoMarca).ignoresSafeArea()
        }
    }

    private var barras: some View {
        HStack(spacing: Espacio.xs) {
            ForEach(paginas.indices, id: \.self) { i in
                Capsule()
                    .fill(Tema.texto.opacity(i <= indice ? 0.9 : 0.25))
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private var zonasTactiles: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Button(action: anterior) { Color.clear.contentShape(Rectangle()) }
                    .frame(width: geo.size.width / 3)
                    .accessibilityLabel("Anterior")
                Spacer(minLength: 0)
                Button(action: siguiente) { Color.clear.contentShape(Rectangle()) }
                    .frame(width: geo.size.width / 3)
                    .accessibilityLabel("Siguiente")
            }
        }
        .padding(.top, 72)
    }
}

#Preview("Visor claro") {
    VisorHistorias(paginas: [
        PaginaHistoria(id: "a", titulo: "Frase", grande: "Lo que repites, lo construyes.", pie: "Autor"),
        PaginaHistoria(id: "b", titulo: "Racha", grande: "12 días", pie: nil),
    ], inicio: 0)
}

#Preview("Visor oscuro") {
    VisorHistorias(paginas: [
        PaginaHistoria(id: "a", titulo: "Frase", grande: "Lo que repites, lo construyes.", pie: "Autor"),
    ], inicio: 0)
    .preferredColorScheme(.dark)
}
