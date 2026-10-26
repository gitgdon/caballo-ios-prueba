import SwiftUI

/// Pestaña Productos: todos los productos, los activos primero. Tocar uno en test o vendiendo da sus acciones.
struct Productos: View {
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var productoPara: Vista.ProductoFila?

    var body: some View {
        NavigationStack {
            lista
                .scrollContentBackground(.hidden)
                .background(Tema.fondo)
                .navigationTitle("Productos")
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
        .confirmationDialog(productoPara?.nombre ?? "", isPresented: Binding(
            get: { productoPara != nil },
            set: { if !$0 { productoPara = nil } }
        ), titleVisibility: .visible) {
            Button("🟢 Un vídeo ha funcionado") { ejecutar("ganador") }
            Button("🔥 10k en TikTok") { ejecutar("viral", "tiktok") }
            Button("🔥 10k en Instagram") { ejecutar("viral", "instagram") }
            Button("🔥 10k en YouTube Shorts") { ejecutar("viral", "youtube") }
            Button("💰 He vendido") { ejecutar("vendido") }
        }
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

    @ViewBuilder
    private func fila(_ p: Vista.ProductoFila, vendible: Bool) -> some View {
        if vendible {
            Button { productoPara = p } label: { FilaProducto(producto: p) }
                .accessibilityHint("Toca para apuntar un vídeo ganador, un 10k o una venta")
        } else {
            FilaProducto(producto: p)
        }
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

    private func ejecutar(_ accion: String, _ extra: String? = nil) {
        guard let p = productoPara else { return }
        productoPara = nil
        modelo.hacer(accion, [p.id] + (extra.map { [$0] } ?? []))
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
