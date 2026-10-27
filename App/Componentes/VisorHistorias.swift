import SwiftUI

struct PaginaHistoria: Identifiable {
    let id: String
    let titulo: String
    let grande: String
    let pie: String?
    /// Barra de 0 a 1 bajo el texto grande.
    var progreso: Double? = nil
    /// Texto normal entre lo grande y el pie.
    var cuerpo: String? = nil
    var boton: BotonPagina? = nil
}

/// Botón al pie de una página del visor (p. ej. "Apuntar facturación").
struct BotonPagina {
    let titulo: String
    let etiqueta: String
    let accion: () -> Void
}

/// Visor a pantalla completa. Sin avance automático.
struct VisorHistorias: View {
    let paginas: [PaginaHistoria]
    /// Se llama con el id de cada página que se enseña (también la primera).
    let alMostrar: ((String) -> Void)?
    @State private var indice: Int
    @Environment(\.dismiss) private var cerrar
    @Environment(\.colorScheme) private var esquema

    init(paginas: [PaginaHistoria], inicio: Int, alMostrar: ((String) -> Void)? = nil) {
        self.paginas = paginas
        self.alMostrar = alMostrar
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
                if paginas.indices.contains(indice), let boton = paginas[indice].boton {
                    Button(boton.titulo, action: boton.accion)
                        .buttonStyle(.principal)
                        .accessibilityLabel(boton.etiqueta)
                        .padding(.bottom, Espacio.l)
                }
            }
            .padding(.horizontal, Espacio.l)
            .padding(.top, Espacio.s)
        }
        .onChange(of: indice, initial: true) { _, nuevo in
            if paginas.indices.contains(nuevo) { alMostrar?(paginas[nuevo].id) }
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
                .font(.largeTitle.bold())
                .foregroundStyle(Tema.texto)
                .multilineTextAlignment(.center)
            if let progreso = pagina.progreso {
                BarraVisor(progreso: progreso)
            }
            if let cuerpo = pagina.cuerpo {
                Text(cuerpo)
                    .font(.body)
                    .foregroundStyle(Tema.texto)
                    .multilineTextAlignment(.center)
            }
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

/// Barra de progreso del visor, en el color del texto para que se lea sobre el degradado.
private struct BarraVisor: View {
    let progreso: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.texto.opacity(0.25))
                Capsule().fill(Tema.texto.opacity(0.9))
                    .frame(width: geo.size.width * max(0, min(1, progreso)))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
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
