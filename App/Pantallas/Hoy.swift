import SwiftUI

/// Pestaña Hoy: historias arriba, la misión de ahora en grande y el resto en lista.
struct Hoy: View {
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var hojaSaltar = false
    @State private var visitasPara: Vista.Ref?

    var body: some View {
        ScrollView {
            if let v = modelo.vista {
                VStack(alignment: .leading, spacing: Espacio.m) {
                    cabecera(v)
                    FilaHistorias(vista: v, modelo: modelo)
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
        .sheet(item: $visitasPara) { p in
            HojaVisitas(producto: p, modelo: modelo)
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
            Caballo(humor: v.humor, lado: 34, rango: v.rango)
        }
        .padding(.horizontal, Espacio.l)
        .padding(.top, Espacio.s)
    }

    @ViewBuilder private func contenido(_ v: Vista) -> some View {
        if !v.hayProductos {
            Tarjeta { HojaNuevoProducto(modelo: modelo) { nombre, lugar, copia in modelo.hacer("nuevo", [nombre, lugar, copia]) } }
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
            ForEach(productosMetricas(v)) { p in
                Button("📈 Apuntar visitas de \(p.nombre)") { visitasPara = p }
                    .buttonStyle(.secundario)
                    .accessibilityLabel("Apuntar visitas de \(p.nombre)")
            }
        }
        .padding(.horizontal, Espacio.l)
    }

    /// Productos con la misión de métricas pendiente: su id es "<producto>:metricas".
    private func productosMetricas(_ v: Vista) -> [Vista.Ref] {
        v.pendientes.filter { $0.tipo == "metricas" }.compactMap { m in
            let pid = String(m.id.dropLast(":metricas".count))
            return v.productos.first { $0.id == pid }.map { Vista.Ref(id: $0.id, nombre: $0.nombre) }
        }
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
    /// Para apuntar facturación y marcar técnicas vistas. Su aviso se repite encima del visor
    /// para que no caduque tapado.
    @ObservedObject var modelo: Modelo
    @AppStorage("medallaVista") private var medallaVista = -1
    /// Cuántas medallas ocultas había la última vez que se abrió la historia Medalla.
    @AppStorage("secretasVistas") private var secretasVistas = -1
    @AppStorage("historiasVistas") private var historiasVistas = ""
    @State private var visor: VisorAbierto?
    @State private var hojaFacturacion = false

    private static let medallas = [7, 30, 100, 365]

    private enum Tipo: String, Hashable { case frase, tecnica, reto, medalla, racha, nivel, producto }

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
        guard let m = vista.medallas.max(), medallaVista >= 0, m > medallaVista else { return nil }
        return m
    }

    /// Medallas ocultas ganadas desde la última vez que se abrió la historia Medalla.
    private var secretasNuevas: [Secreta] {
        guard secretasVistas >= 0, vista.secretas.count > secretasVistas else { return [] }
        return Array(vista.secretas.suffix(vista.secretas.count - secretasVistas))
    }

    private var siguienteMedalla: Int? { Self.medallas.first { $0 > vista.racha } }

    /// Las técnicas recién desbloqueadas (las de nivel más alto).
    private var tecnicasNuevas: [Tecnica] {
        Array(vista.tecnicas.filter(\.desbloqueada).suffix(vista.tecnicasNuevas))
    }

    private var tipos: [Tipo] {
        var t: [Tipo] = []
        if vista.frase != nil || vista.porque != nil { t.append(.frase) }
        if vista.tecnicasNuevas > 0 { t.append(.tecnica) }
        if vista.reto != nil { t.append(.reto) }
        if medallaNueva != nil || !secretasNuevas.isEmpty { t.append(.medalla) }
        t.append(contentsOf: [.racha, .nivel])
        if vista.producto != nil { t.append(.producto) }
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
        .onAppear {
            // Primer arranque: la medalla que ya había no cuenta como nueva.
            if medallaVista < 0 { medallaVista = vista.medallas.max() ?? 0 }
            if secretasVistas < 0 { secretasVistas = vista.secretas.count }
        }
        .fullScreenCover(item: $visor) { abierto in
            // La página del reto se recalcula para enseñar lo recién apuntado.
            VisorHistorias(paginas: abierto.paginas.map { $0.id == "reto" ? paginaReto : $0 },
                           inicio: abierto.inicio,
                           alMostrar: mostrada)
                .sheet(isPresented: $hojaFacturacion) {
                    HojaFacturacion(modelo: modelo)
                        .presentationDetents([.medium, .large])
                        .presentationBackground(Tema.fondo)
                }
                .avisoLogro(texto: $modelo.aviso)
        }
    }

    private func abrir(_ t: Tipo) {
        var lista: [PaginaHistoria] = []
        var inicio = 0
        for tipo in tipos {
            if tipo == t { inicio = lista.count }
            lista += paginas(tipo)
        }
        visor = VisorAbierto(paginas: lista, inicio: inicio)
        marcarVista(t)
        if t == .medalla {
            if let m = medallaNueva { medallaVista = m }
            secretasVistas = vista.secretas.count
        }
    }

    /// Ver la página de la técnica (al abrirla o pasando de otra historia) la marca como vista.
    private func mostrada(_ id: String) {
        if id == "tecnica", (modelo.vista?.tecnicasNuevas ?? 0) > 0 {
            marcarVista(.tecnica)
            modelo.hacer("tecnicaVista")
        }
    }

    // MARK: Círculos

    @ViewBuilder private func historia(_ t: Tipo) -> some View {
        switch t {
        case .frase: historiaFrase
        case .tecnica: historiaTecnica
        case .reto: historiaReto
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

    private var historiaTecnica: some View {
        let n = vista.tecnicasNuevas
        return Historia(titulo: "Técnica",
                        etiqueta: n == 1 ? "Técnica nueva desbloqueada" : "Técnicas desbloqueadas: \(n)",
                        progreso: 1, color: Tema.acento, nueva: nueva(.tecnica),
                        contenido: {
                            Text("✦")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Tema.texto)
                        },
                        accion: { abrir(.tecnica) })
    }

    private var historiaReto: some View {
        let r = vista.reto
        let dias = r?.diasQuedan ?? 0
        let etiqueta = r.map { "Reto: \(euros($0.facturado)) de \(euros($0.meta)), quedan \($0.diasQuedan) días" } ?? "Reto"
        return Historia(titulo: "Reto", etiqueta: etiqueta,
                        progreso: r?.progreso ?? 0, color: Tema.Anillo.reto, nueva: nueva(.reto),
                        contenido: {
                            Text("\(dias)d")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Tema.texto)
                                .minimumScaleFactor(0.6)
                        },
                        accion: { abrir(.reto) })
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
                        contenido: { Caballo(humor: vista.humor, lado: 50, rango: vista.rango) },
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
        let etiqueta: String
        if let m = medallaNueva {
            etiqueta = "Medalla nueva: \(m) días seguidos"
        } else {
            etiqueta = "Medalla oculta: " + secretasNuevas.map(\.nombre).joined(separator: ", ")
        }
        return Historia(titulo: "Medalla", etiqueta: etiqueta,
                        progreso: 1, color: Tema.Anillo.xp, nueva: true,
                        contenido: { Text("🏅").font(.title2) },
                        accion: { abrir(.medalla) })
    }

    // MARK: Páginas del visor

    private func paginas(_ t: Tipo) -> [PaginaHistoria] {
        switch t {
        case .frase: return [paginaFrase] + (paginaConsejo.map { [$0] } ?? [])
        case .tecnica: return [paginaTecnica]
        case .reto: return [paginaReto]
        case .racha: return [paginaRacha]
        case .nivel:
            return [PaginaHistoria(id: "nivel", titulo: "Nivel",
                                   grande: "Nivel \(vista.nivel) · \(vista.rango)",
                                   pie: "\(vista.xp) / \(vista.xpSig) XP")]
        case .producto: return [paginaProducto]
        case .medalla: return paginasMedalla
        }
    }

    private var paginasMedalla: [PaginaHistoria] {
        var lista: [PaginaHistoria] = []
        if let m = medallaNueva {
            lista.append(PaginaHistoria(id: "medalla", titulo: "Medalla", grande: "🏅 \(m) días seguidos", pie: nil))
        }
        for s in secretasNuevas {
            lista.append(PaginaHistoria(id: "secreta-" + s.id, titulo: "Medalla oculta", grande: "🏅 " + s.nombre, pie: nil))
        }
        return lista
    }

    private var paginaConsejo: PaginaHistoria? {
        guard let c = vista.consejo else { return nil }
        return PaginaHistoria(id: "consejo", titulo: "Consejo de " + c.autor, grande: c.texto, pie: nil)
    }

    private var paginaTecnica: PaginaHistoria {
        let nuevas = tecnicasNuevas
        if nuevas.count == 1, let t = nuevas.first {
            return PaginaHistoria(id: "tecnica", titulo: "Técnica desbloqueada · Nivel \(t.nivel)",
                                  grande: t.titulo, pie: "A partir de hoy la verás en algunas misiones",
                                  cuerpo: t.texto)
        }
        return PaginaHistoria(id: "tecnica", titulo: "Técnicas desbloqueadas: \(nuevas.count)",
                              grande: "✦", pie: nil,
                              cuerpo: nuevas.map(\.titulo).joined(separator: "\n"))
    }

    private static let formatoFin: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "2026-12-31" → "31 dic".
    private static func diaCorto(_ fin: String) -> String {
        guard let fecha = formatoFin.date(from: fin) else { return fin }
        return fecha.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es_ES")))
    }

    private var paginaReto: PaginaHistoria {
        guard let r = vista.reto else {
            return PaginaHistoria(id: "reto", titulo: "Reto", grande: "", pie: nil)
        }
        let plazo: String
        if r.cumplido {
            plazo = "🏆 Reto cumplido"
        } else if r.vencido {
            plazo = "El plazo acabó el \(Self.diaCorto(r.fin)). Puedes empezar otro en Más"
        } else if r.diasQuedan == 0 {
            plazo = "Último día"
        } else if r.diasQuedan == 1 {
            plazo = "Queda 1 día hasta el \(Self.diaCorto(r.fin))"
        } else {
            plazo = "Quedan \(r.diasQuedan) días hasta el \(Self.diaCorto(r.fin))"
        }
        let boton = BotonPagina(titulo: "Apuntar facturación", etiqueta: "Apuntar facturación") {
            hojaFacturacion = true
        }
        return PaginaHistoria(id: "reto", titulo: "Reto · Facturado", grande: euros(r.facturado),
                              pie: r.videos == 1 ? "1 vídeo subido en el reto" : "\(r.videos) vídeos subidos en el reto",
                              progreso: r.progreso,
                              cuerpo: "de \(euros(r.meta))\n" + plazo,
                              boton: boton)
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
