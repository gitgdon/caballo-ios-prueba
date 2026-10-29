import SwiftUI

/// Pestaña Productos: todos los productos, los activos primero. Tocar uno abre su menú: renombrar, borrar
/// y, en test o vendiendo, sus acciones.
struct Productos: View {
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var visitasPara: Vista.Ref?
    @State private var renombrando: Vista.ProductoFila?
    @State private var nombreNuevo = ""
    @State private var porBorrar: Vista.ProductoFila?

    var body: some View {
        NavigationStack {
            lista
                .scrollContentBackground(.hidden)
                .background(Tema.fondo)
                .navigationTitle("Productos")
        }
        .sheet(item: $visitasPara) { p in
            HojaVisitas(producto: p, modelo: modelo)
                .presentationDetents([.medium, .large])
                .presentationBackground(Tema.fondo)
                .avisoLogro(texto: $modelo.aviso)
                .pildoraDeshacer(modelo)
                .apariencia()
        }
    }

    private var lista: some View {
        List {
            if let v = modelo.vista {
                if v.puedeNuevo {
                    Section {
                        Button("➕ Nuevo producto") { hojaNuevo = true }
                            .foregroundStyle(Tema.acento)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Nuevo producto")
                    }
                    .listRowBackground(Tema.superficie)
                }
                seccion("En marcha", enMarcha(v.productos), v)
                seccion("Descartados", v.productos.filter { $0.estado == "descartado" }, v)
            }
        }
        .listStyle(.insetGrouped)
        // Las acciones van en un Menu: al elegir una, el menú ya se ha cerrado y el alert o la confirmación salen bien.
        .alert("Renombrar producto", isPresented: Binding(
            get: { renombrando != nil },
            set: { if !$0 { renombrando = nil } }
        ), presenting: renombrando) { p in
            TextField("Nombre", text: $nombreNuevo)
                .accessibilityLabel("Nombre del producto")
            Button("Guardar") { guardarNombre(p) }
            Button("Cancelar", role: .cancel) { renombrando = nil }
        }
        .confirmationDialog("¿Borrar «\(porBorrar?.nombre ?? "")»?", isPresented: Binding(
            get: { porBorrar != nil },
            set: { if !$0 { porBorrar = nil } }
        ), titleVisibility: .visible, presenting: porBorrar) { p in
            Button("Borrar producto", role: .destructive) {
                porBorrar = nil
                modelo.hacer("borrarProducto", [p.id])
            }
            Button("Cancelar", role: .cancel) { porBorrar = nil }
        } message: { p in
            Text(Self.mensajeBorrar(p))
        }
    }

    /// "Se borrará «Lámpara» con sus 3 vídeos y 1 ganador. No se puede recuperar."
    private static func mensajeBorrar(_ p: Vista.ProductoFila) -> String {
        let videos = "\(p.videos) \(p.videos == 1 ? "vídeo" : "vídeos")"
        let ganadores = "\(p.ganadores) \(p.ganadores == 1 ? "ganador" : "ganadores")"
        return "Se borrará «\(p.nombre)» con sus \(videos) y \(ganadores). No se puede recuperar."
    }

    private func guardarNombre(_ p: Vista.ProductoFila) {
        renombrando = nil
        let nombre = nombreNuevo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombre.isEmpty, nombre != p.nombre else { return }
        modelo.hacer("renombrarProducto", [p.id, nombre])
    }

    @ViewBuilder
    private func seccion(_ titulo: String, _ productos: [Vista.ProductoFila], _ v: Vista) -> some View {
        if !productos.isEmpty {
            Section(titulo) {
                ForEach(productos) { p in
                    fila(p, vendible: v.vendibles.contains { $0.id == p.id })
                }
            }
            .listRowBackground(Tema.superficie)
        }
    }

    private func fila(_ p: Vista.ProductoFila, vendible: Bool) -> some View {
        Menu {
            if vendible { accionesJuego(p) }
            Button("✏️ Renombrar") {
                nombreNuevo = p.nombre
                renombrando = p
            }
            .accessibilityLabel("Renombrar")
            Button("🗑️ Borrar", role: .destructive) { porBorrar = p }
                .accessibilityLabel("Borrar")
        } label: {
            FilaProducto(producto: p)
        }
        .accessibilityHint(vendible
            ? "Toca para apuntar un vídeo ganador, un 10k, una venta o visitas, renombrarlo o borrarlo"
            : "Toca para renombrarlo o borrarlo")
    }

    @ViewBuilder
    private func accionesJuego(_ p: Vista.ProductoFila) -> some View {
        Button("🟢 Un vídeo ha funcionado") { modelo.hacer("ganador", [p.id]) }
            .accessibilityLabel("Un vídeo ha funcionado")
        Button("🔥 10k en TikTok") { modelo.hacer("viral", [p.id, "tiktok"]) }
            .accessibilityLabel("10k en TikTok")
        Button("🔥 10k en Instagram") { modelo.hacer("viral", [p.id, "instagram"]) }
            .accessibilityLabel("10k en Instagram")
        Button("🔥 10k en YouTube Shorts") { modelo.hacer("viral", [p.id, "youtube"]) }
            .accessibilityLabel("10k en YouTube Shorts")
        Button("💰 He vendido") { modelo.hacer("vendido", [p.id]) }
            .accessibilityLabel("He vendido")
        Button("📈 Apuntar visitas") { visitasPara = Vista.Ref(id: p.id, nombre: p.nombre) }
            .accessibilityLabel("Apuntar visitas")
    }

    /// Los activos (test, vendiendo) primero, luego decisión y preparación; sin descartados.
    private func enMarcha(_ productos: [Vista.ProductoFila]) -> [Vista.ProductoFila] {
        func orden(_ estado: String) -> Int {
            switch estado {
            case "test", "vendiendo": return 0
            case "decision": return 1
            default: return 2
            }
        }
        return productos.enumerated()
            .filter { $0.element.estado != "descartado" }
            .sorted { a, b in
                let oa = orden(a.element.estado), ob = orden(b.element.estado)
                return oa != ob ? oa < ob : a.offset < b.offset
            }
            .map { $0.element }
    }
}

/// Una fila: anillo de días, nombre, estado, ganadores/vídeos y lugar.
private struct FilaProducto: View {
    let producto: Vista.ProductoFila

    private var estado: String {
        switch producto.estado {
        case "preparacion": return "Preparación"
        case "test": return "Test"
        case "decision": return "Decisión"
        case "vendiendo": return "Vendiendo"
        case "descartado": return "Descartado"
        default: return producto.estado
        }
    }

    private var lugar: String { producto.lugar == "calle" ? "En la calle" : "En casa" }

    private var etiqueta: String {
        var partes = [producto.nombre, estado]
        if producto.dia > 0 { partes.append("día \(producto.dia) de 14") }
        partes.append("\(producto.ganadores) ganadores de \(producto.videos) vídeos")
        partes.append(lugar)
        return partes.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: Espacio.m) {
            anillo
            VStack(alignment: .leading, spacing: Espacio.xs) {
                Text(producto.nombre)
                    .font(.headline)
                    .foregroundStyle(Tema.texto)
                Text("\(estado) · 🟢 \(producto.ganadores)/\(producto.videos) · \(lugar)")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSuave)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiqueta)
    }

    private var anillo: some View {
        ZStack {
            Circle().stroke(Tema.borde, lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(1, Double(producto.dia) / 14))
                .stroke(Tema.Anillo.producto, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(producto.dia)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Tema.texto)
        }
        .frame(width: 36, height: 36)
    }
}
