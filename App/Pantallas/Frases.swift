import SwiftUI

/// Las 477 frases agrupadas por categoría, con su texto de búsqueda ya normalizado.
struct CatalogoFrases {
    struct Seccion: Identifiable {
        let id: String, titulo: String, frases: [FraseCompleta]
    }

    let todas: [FraseCompleta]
    let porId: [String: FraseCompleta]
    let secciones: [Seccion]
    /// id → texto y autor sin acentos ni mayúsculas.
    let claves: [String: String]

    /// Orden y nombre de cada categoría de frases.js.
    private static let categorias: [(String, String)] = [
        ("accion", "Acción"), ("disciplina", "Disciplina"), ("verguenza", "Vergüenza"),
        ("imperfecto", "Imperfecto"), ("constancia", "Constancia"), ("desde-cero", "Desde cero"),
        ("sin-resultados", "Sin resultados"), ("dinero", "Dinero"), ("estatus", "Estatus"),
        ("sacrificio", "Sacrificio"), ("ser-el-mejor", "Ser el mejor"), ("otros", "Otros"),
    ]

    init(_ frases: [FraseCompleta]) {
        todas = frases
        porId = Dictionary(frases.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        claves = Dictionary(frases.map { ($0.id, normalizar($0.texto + " " + $0.autor)) }, uniquingKeysWith: { a, _ in a })
        let grupos = Dictionary(grouping: frases, by: \.categoria)
        let conocidas = Set(Self.categorias.map(\.0))
        // Una categoría nueva que no esté en la lista va a "Otros".
        let sueltas = frases.filter { !conocidas.contains($0.categoria) }
        secciones = Self.categorias.compactMap { categoria -> Seccion? in
            let (id, titulo) = categoria
            let lista = (grupos[id] ?? []) + (id == "otros" ? sueltas : [])
            return lista.isEmpty ? nil : Seccion(id: id, titulo: titulo, frases: lista)
        }
    }

    /// Frases cuyo texto o autor contienen la búsqueda (sin acentos ni mayúsculas).
    func buscar(_ texto: String) -> [FraseCompleta] {
        let q = normalizar(texto.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return [] }
        return todas.filter { claves[$0.id]?.contains(q) ?? false }
    }
}

/// Apartado Frases (Más): "Dame una frase", las que llegaron hoy, favoritas y todas por categoría, con buscador.
struct Frases: View {
    @ObservedObject var modelo: Modelo
    @State private var busqueda = ""
    @State private var mostrada: FraseCompleta?
    @State private var detalle: FraseCompleta?

    private var catalogo: CatalogoFrases { modelo.catalogo }
    private var favoritas: Set<String> { Set(modelo.vista?.favoritas ?? []) }

    var body: some View {
        ScrollViewReader { proxy in
            lista
                .scrollContentBackground(.hidden)
                .background(Tema.fondo)
                .navigationTitle("Frases")
                .searchable(text: $busqueda, prompt: "Buscar por texto o autor")
                .navigationDestination(item: $detalle) { f in DetalleFrase(modelo: modelo, frase: f) }
                .onAppear { abrirPedida(proxy) }
                .onChange(of: modelo.fraseAbierta) { _, _ in abrirPedida(proxy) }
        }
    }

    private var lista: some View {
        let favs = favoritas
        return List {
            if busqueda.trimmingCharacters(in: .whitespaces).isEmpty {
                seccionDame(favs)
                SeccionesFrases(modelo: modelo, favs: favs, abrir: { detalle = $0 })
            } else {
                resultados(favs)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func seccionDame(_ favs: Set<String>) -> some View {
        Section {
            Button("Dame una frase", action: darFrase)
                .buttonStyle(.principal)
                .accessibilityLabel(mostrada == nil ? "Dame una frase" : "Dame otra frase")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .id("arriba")
            if let f = mostrada {
                TarjetaFrase(frase: f, favorita: favs.contains(f.id),
                             abrir: { detalle = f },
                             alternar: { modelo.hacer("favorita", [f.id]) })
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func resultados(_ favs: Set<String>) -> some View {
        let encontradas = catalogo.buscar(busqueda)
        return Section("Resultados") {
            if encontradas.isEmpty {
                Text("Ninguna frase coincide")
                    .foregroundStyle(Tema.textoSuave)
                    .frame(minHeight: 44)
            }
            ForEach(encontradas) { f in
                FilaFrase(frase: f, favorita: favs.contains(f.id),
                          abrir: { detalle = f },
                          alternar: { modelo.hacer("favorita", [f.id]) })
            }
        }
        .listRowBackground(Tema.superficie)
    }

    /// Al azar de las que empujan a actuar, sin repetir las 5 últimas de la sesión.
    private func darFrase() {
        let empujar = modelo.vista?.empujar ?? []
        let ids = empujar.isEmpty ? catalogo.todas.map(\.id) : empujar
        let recientes = modelo.frasesMostradas
        let libres = ids.filter { !recientes.contains($0) }
        let otras = ids.filter { $0 != mostrada?.id }
        guard let id = (libres.isEmpty ? otras : libres).randomElement() ?? ids.randomElement(),
              let f = catalogo.porId[id] else { return }
        mostrada = f
        modelo.frasesMostradas = Array((recientes.filter { $0 != id } + [id]).suffix(5))
    }

    /// Frase pedida desde un aviso (su id) o desde el icono ("azar").
    private func abrirPedida(_ proxy: ScrollViewProxy) {
        guard let pedida = modelo.fraseAbierta else { return }
        modelo.fraseAbierta = nil
        busqueda = ""
        if pedida == "azar" {
            detalle = nil
            darFrase()
            proxy.scrollTo("arriba", anchor: .top)
        } else if let f = catalogo.porId[pedida] {
            detalle = f
        }
    }
}

/// Te llegaron hoy, Favoritas y una sección por categoría.
private struct SeccionesFrases: View {
    @ObservedObject var modelo: Modelo
    let favs: Set<String>
    let abrir: (FraseCompleta) -> Void

    private var catalogo: CatalogoFrases { modelo.catalogo }

    var body: some View {
        let enviadas = modelo.vista?.enviadasHoy ?? []
        if !enviadas.isEmpty {
            Section("Te llegaron hoy") {
                ForEach(enviadas) { e in
                    if let f = catalogo.porId[e.fraseId] { fila(f, hora: String(e.fecha.suffix(5))) }
                }
            }
            .listRowBackground(Tema.superficie)
        }
        Section {
            let ids = modelo.vista?.favoritas ?? []
            ForEach(ids, id: \.self) { id in
                if let f = catalogo.porId[id] { fila(f) }
            }
        } header: {
            Text("Favoritas")
        } footer: {
            if favs.isEmpty { Text("Toca la estrella de una frase para guardarla aquí.") }
        }
        .listRowBackground(Tema.superficie)
        ForEach(catalogo.secciones) { s in
            Section(s.titulo) {
                ForEach(s.frases) { f in fila(f) }
            }
            .listRowBackground(Tema.superficie)
        }
    }

    private func fila(_ f: FraseCompleta, hora: String? = nil) -> some View {
        FilaFrase(frase: f, favorita: favs.contains(f.id), hora: hora,
                  abrir: { abrir(f) },
                  alternar: { modelo.hacer("favorita", [f.id]) })
    }
}

/// Estrella de favorita, 44×44.
private struct BotonEstrella: View {
    let favorita: Bool
    let alternar: () -> Void

    var body: some View {
        Button(action: alternar) {
            Image(systemName: favorita ? "star.fill" : "star")
                .foregroundStyle(favorita ? Tema.acento : Tema.textoSuave)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(favorita ? "Quitar de favoritas" : "Añadir a favoritas")
    }
}

/// Fila ligera: texto, autor (y hora si llegó hoy) y estrella.
private struct FilaFrase: View {
    let frase: FraseCompleta
    let favorita: Bool
    var hora: String? = nil
    let abrir: () -> Void
    let alternar: () -> Void

    var body: some View {
        HStack(spacing: Espacio.s) {
            Button(action: abrir) {
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    Text(frase.texto)
                        .foregroundStyle(Tema.texto)
                        .lineLimit(3)
                    Text(hora.map { "\($0) · \(frase.autor)" } ?? frase.autor)
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSuave)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(frase.texto). \(frase.autor)")
            .accessibilityHint("Abre la frase")
            BotonEstrella(favorita: favorita, alternar: alternar)
        }
    }
}

/// Tarjeta grande de "Dame una frase".
private struct TarjetaFrase: View {
    let frase: FraseCompleta
    let favorita: Bool
    let abrir: () -> Void
    let alternar: () -> Void

    var body: some View {
        Tarjeta {
            Button(action: abrir) {
                VStack(alignment: .leading, spacing: Espacio.s) {
                    Text(frase.texto)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Tema.texto)
                        .multilineTextAlignment(.leading)
                    Text("— " + frase.autor)
                        .font(.subheadline.bold())
                        .foregroundStyle(Tema.textoSuave)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(frase.texto). \(frase.autor)")
            .accessibilityHint("Abre la frase")
            HStack {
                Spacer()
                BotonEstrella(favorita: favorita, alternar: alternar)
            }
        }
        .padding(.top, Espacio.s)
    }
}

/// Detalle de una frase: texto, detalle, autor, vídeo de origen y estrella.
struct DetalleFrase: View {
    @ObservedObject var modelo: Modelo
    let frase: FraseCompleta

    private var favorita: Bool { modelo.vista?.favoritas.contains(frase.id) ?? false }

    var body: some View {
        ScrollView {
            Tarjeta {
                Text(frase.texto)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Tema.texto)
                Text("— " + frase.autor)
                    .font(.subheadline.bold())
                    .foregroundStyle(Tema.texto)
                if frase.detalle != frase.texto {
                    Text(frase.detalle)
                        .font(.body)
                        .foregroundStyle(Tema.textoSuave)
                }
                if !frase.video.isEmpty {
                    Text("Vídeo: \(frase.video)")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSuave)
                }
            }
            .accessibilityElement(children: .combine)
            .padding(Espacio.l)
        }
        .background(Tema.fondo)
        .navigationTitle("Frase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BotonEstrella(favorita: favorita) { modelo.hacer("favorita", [frase.id]) }
            }
        }
    }
}
