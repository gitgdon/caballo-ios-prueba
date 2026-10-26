import SwiftUI

/// Pestaña Hoy: historias arriba, la misión de ahora en grande y el resto en lista.
struct Hoy: View {
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var hojaSaltar = false

    var body: some View {
        ScrollView {
            if let v = modelo.vista {
                VStack(alignment: .leading, spacing: Espacio.m) {
                    cabecera(v)
                    FilaHistorias(vista: v, aviso: $modelo.aviso)
                    contenido(v)
                }
                .padding(.bottom, Espacio.xl)
            }
        }
        .background(Tema.fondo)
        .sheet(isPresented: $hojaSaltar) {
            HojaSaltar(modelo: modelo)
                .presentationDetents([.medium, .large])
                .presentationBackground(Tema.fondo)
                .avisoLogro(texto: $modelo.aviso)
        }
    }

    private func cabecera(_ v: Vista) -> some View {
        HStack {
            Text("Hoy")
                .font(.largeTitle.bold())
                .foregroundStyle(Tema.texto)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Caballo(humor: v.humor, lado: 34)
        }
        .padding(.horizontal, Espacio.l)
        .padding(.top, Espacio.s)
    }

    @ViewBuilder private func contenido(_ v: Vista) -> some View {
        if !v.hayProductos {
            Tarjeta { HojaNuevoProducto { nombre, lugar in modelo.hacer("nuevo", [nombre, lugar]) } }
                .padding(.horizontal, Espacio.l)
        } else if let d = v.decisiones.first {
            HojaDecision(producto: d, modelo: modelo, hojaNuevo: $hojaNuevo)
                .id(d.id)
                .padding(.horizontal, Espacio.l)
        } else {
            misiones(v)
            acciones(v)
        }
    }

    private func misiones(_ v: Vista) -> some View {
        VStack(spacing: Espacio.m) {
            MisionPrincipal(mision: v.pendientes.first,
                            lineaProducto: v.lineaProducto,
                            textoVacio: "Día cerrado. Descansa, jinete.") {
                if let m = v.pendientes.first { modelo.hacer("hecho", [m.id]) }
            }
            if v.pendientes.count > 1 {
                Tarjeta {
                    Text("TAMBIÉN HOY")
                        .font(.caption.bold())
                        .foregroundStyle(Tema.textoSuave)
                    ForEach(v.pendientes.dropFirst()) { m in
                        FilaMision(mision: m) { modelo.hacer("hecho", [m.id]) }
                    }
                }
            }
        }
        .padding(.horizontal, Espacio.l)
    }

    private func acciones(_ v: Vista) -> some View {
        VStack(spacing: Espacio.s) {
            if v.puedeMinimo {
                Button("😮‍💨 Hoy no tengo ganas") { modelo.hacer("minimo") }
                    .buttonStyle(.secundario)
                    .accessibilityLabel("Hoy no tengo ganas: hacer lo mínimo")
            }
            Button("Saltar hoy") { hojaSaltar = true }
                .buttonStyle(.fantasma)
                .accessibilityLabel("Saltar hoy")
        }
        .padding(.horizontal, Espacio.l)
    }
}

/// Las historias de arriba y su visor a pantalla completa.
private struct FilaHistorias: View {
    let vista: Vista
    /// El aviso se repite encima del visor para que no caduque tapado.
    @Binding var aviso: String?
    @AppStorage("medallaVista") private var medallaVista = 0
    @AppStorage("historiasVistas") private var historiasVistas = ""
    @State private var visor: VisorAbierto?

    private static let medallas = [7, 30, 100, 365]

    private enum Tipo: String, Hashable { case frase, racha, nivel, producto, medalla }

    private struct VisorAbierto: Identifiable {
        let id = UUID()
        let paginas: [PaginaHistoria]
        let inicio: Int
    }

    private static var hoy: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    /// "yyyy-MM-dd:frase,racha": las historias vistas hoy. Cada una brilla hasta que se abre.
    private var vistasHoy: [String] {
        let partes = historiasVistas.split(separator: ":", maxSplits: 1).map(String.init)
        guard partes.count == 2, partes[0] == Self.hoy else { return [] }
        return partes[1].split(separator: ",").map(String.init)
    }

    private func nueva(_ t: Tipo) -> Bool { !vistasHoy.contains(t.rawValue) }

    private func marcarVista(_ t: Tipo) {
        var vistas = vistasHoy
        if !vistas.contains(t.rawValue) { vistas.append(t.rawValue) }
        historiasVistas = Self.hoy + ":" + vistas.joined(separator: ",")
    }

    private var medallaNueva: Int? {
        guard let m = vista.medallas.max(), m > medallaVista else { return nil }
        return m
    }

    private var siguienteMedalla: Int? { Self.medallas.first { $0 > vista.racha } }

    private var tipos: [Tipo] {
        var t: [Tipo] = []
        if vista.frase != nil || vista.porque != nil { t.append(.frase) }
        t.append(contentsOf: [.racha, .nivel])
        if vista.producto != nil { t.append(.producto) }
        if medallaNueva != nil { t.append(.medalla) }
        return t
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Espacio.m) {
                ForEach(tipos, id: \.self) { t in
                    historia(t)
                }
            }
            .padding(.horizontal, Espacio.l)
            .padding(.vertical, Espacio.xs)
        }
        .fullScreenCover(item: $visor) { abierto in
            VisorHistorias(paginas: abierto.paginas, inicio: abierto.inicio)
                .avisoLogro(texto: $aviso)
        }
    }

    private func abrir(_ t: Tipo) {
        let lista = tipos
        visor = VisorAbierto(paginas: lista.map { pagina($0) }, inicio: lista.firstIndex(of: t) ?? 0)
        marcarVista(t)
        if t == .medalla, let m = medallaNueva { medallaVista = m }
    }

    // MARK: Círculos

    @ViewBuilder private func historia(_ t: Tipo) -> some View {
        switch t {
        case .frase: historiaFrase
        case .racha: historiaRacha
        case .nivel: historiaNivel
        case .producto: historiaProducto
        case .medalla: historiaMedalla
        }
    }

    private var historiaFrase: some View {
        Historia(titulo: "Frase",
                 etiqueta: vista.porque != nil ? "Tu porqué" : "Frase del día",
                 progreso: 1, color: Tema.Anillo.frase, nueva: nueva(.frase),
                 contenido: {
                     Text("“")
                         .font(.system(size: 28, weight: .bold, design: .rounded))
                         .foregroundStyle(Tema.texto)
                 },
                 accion: { abrir(.frase) })
    }

    private var etiquetaRacha: String {
        let base = "Racha: \(vista.racha) días"
        guard let sig = siguienteMedalla else { return base }
        return base + ", \(sig - vista.racha) para la siguiente medalla"
    }

    private var historiaRacha: some View {
        let progreso = siguienteMedalla.map { Double(vista.racha) / Double($0) } ?? 1
        return Historia(titulo: "Racha", etiqueta: etiquetaRacha,
                        progreso: progreso, color: Tema.Anillo.racha, nueva: nueva(.racha),
                        contenido: {
                            Text("\(vista.racha)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Tema.texto)
                                .minimumScaleFactor(0.6)
                        },
                        accion: { abrir(.racha) })
    }

    private var historiaNivel: some View {
        let progreso = Double(vista.xp) / Double(max(vista.xpSig, 1))
        return Historia(titulo: "Nivel \(vista.nivel)",
                        etiqueta: "Nivel \(vista.nivel), \(vista.rango): \(vista.xp) de \(vista.xpSig) XP",
                        progreso: progreso, color: Tema.Anillo.xp, nueva: nueva(.nivel),
                        contenido: { Caballo(humor: vista.humor, lado: 50) },
                        accion: { abrir(.nivel) })
    }

    private var textoProducto: String {
        guard let p = vista.producto else { return "" }
        return p.n <= 30 ? "\(p.n)/30" : "\(p.n)"
    }

    private var historiaProducto: some View {
        let dia = vista.producto?.dia ?? 0
        return Historia(titulo: dia > 0 ? "Día \(dia)" : "Producto",
                        etiqueta: "Producto \(textoProducto)" + (dia > 0 ? ", día \(dia) de 14" : ""),
                        progreso: Double(dia) / 14, color: Tema.Anillo.producto, nueva: nueva(.producto),
                        contenido: {
                            Text(textoProducto)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Tema.texto)
                                .minimumScaleFactor(0.6)
                        },
                        accion: { abrir(.producto) })
    }

    private var historiaMedalla: some View {
        let m = medallaNueva ?? 0
        return Historia(titulo: "Medalla", etiqueta: "Medalla nueva: \(m) días seguidos",
                        progreso: 1, color: Tema.Anillo.xp, nueva: true,
                        contenido: { Text("🏅").font(.title2) },
                        accion: { abrir(.medalla) })
    }

    // MARK: Páginas del visor

    private func pagina(_ t: Tipo) -> PaginaHistoria {
        switch t {
        case .frase: return paginaFrase
        case .racha: return paginaRacha
        case .nivel:
            return PaginaHistoria(id: "nivel", titulo: "Nivel",
                                  grande: "Nivel \(vista.nivel) · \(vista.rango)",
                                  pie: "\(vista.xp) / \(vista.xpSig) XP")
        case .producto: return paginaProducto
        case .medalla:
            return PaginaHistoria(id: "medalla", titulo: "Medalla",
                                  grande: "🏅 \(medallaNueva ?? 0) días seguidos", pie: nil)
        }
    }

    private var paginaFrase: PaginaHistoria {
        if let porque = vista.porque {
            return PaginaHistoria(id: "frase", titulo: "Tu porqué", grande: "💭 " + porque, pie: nil)
        }
        let f = vista.frase
        return PaginaHistoria(id: "frase", titulo: "Frase del día",
                              grande: f?.texto ?? "", pie: f.map { "— " + $0.autor })
    }

    private var paginaRacha: PaginaHistoria {
        let titulo = vista.escudos > 0 ? "Racha · 🛡️ \(vista.escudos)" : "Racha"
        let pie = siguienteMedalla.map { "Siguiente medalla: \($0)" } ?? "Todas las medallas conseguidas"
        return PaginaHistoria(id: "racha", titulo: titulo, grande: "🔥 \(vista.racha) días", pie: pie)
    }

    private var paginaProducto: PaginaHistoria {
        guard let p = vista.producto else {
            return PaginaHistoria(id: "producto", titulo: "Producto", grande: "", pie: nil)
        }
        let grande = "Producto \(textoProducto)" + (p.dia > 0 ? " · Día \(p.dia)/14" : "")
        let pie = "🟢 \(p.ganadores) ganadores de \(p.videos) vídeos" + (p.bajon ? " · 🧗 bajón" : "")
        return PaginaHistoria(id: "producto", titulo: p.nombre, grande: grande, pie: pie)
    }
}
