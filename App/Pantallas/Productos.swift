import SwiftUI

/// Pestaña Productos: todos los productos, los activos primero. Tocar uno en test o vendiendo da sus acciones.
struct Productos: View {
    @ObservedObject var modelo: Modelo
    @Binding var hojaNuevo: Bool
    @State private var productoPara: Vista.ProductoFila?
    @State private var plataformaPara: String?

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
                seccion("En marcha", v.productos.filter { $0.estado != "descartado" }, v)
                seccion("Descartados", v.productos.filter { $0.estado == "descartado" }, v)
            }
        }
        .listStyle(.insetGrouped)
        .confirmationDialog(productoPara?.nombre ?? "", isPresented: Binding(
            get: { productoPara != nil },
            set: { if !$0 { productoPara = nil } }
        ), titleVisibility: .visible) {
            Button("🟢 Un vídeo ha funcionado") { ejecutar("ganador") }
            Button("🔥 Un vídeo ha pasado de 10k") { ejecutar("viral") }
            Button("💰 He vendido") { ejecutar("vendido") }
        }
        .confirmationDialog("¿En qué plataforma?", isPresented: Binding(
            get: { plataformaPara != nil },
            set: { if !$0 { plataformaPara = nil } }
        ), titleVisibility: .visible) {
            Button("TikTok") { viral("tiktok") }
            Button("Instagram") { viral("instagram") }
            Button("YouTube Shorts") { viral("youtube") }
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

    private func ejecutar(_ accion: String) {
        guard let p = productoPara else { return }
        productoPara = nil
        if accion == "viral" { plataformaPara = p.id } else { modelo.hacer(accion, [p.id]) }
    }

    private func viral(_ plataforma: String) {
        if let id = plataformaPara { modelo.hacer("viral", [id, plataforma]) }
        plataformaPara = nil
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
