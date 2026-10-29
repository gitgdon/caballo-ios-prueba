import SwiftUI

/// Las 15 técnicas, todas para leer; la del nivel actual lleva "Practicando ahora".
/// Debajo, "Mis técnicas": las propias y los ganchos del banco, que se pueden editar y borrar.
struct ListaTecnicas: View {
    @ObservedObject var modelo: Modelo
    @State private var edicion: Edicion?
    @State private var porBorrar: Borrado?
    /// Se guarda aparte para que el título no se vacíe mientras se cierra el diálogo.
    @State private var tituloBorrar = ""

    var body: some View {
        List {
            if let v = modelo.vista {
                seccionTecnicas(v)
                SeccionMisTecnicas(vista: v, editar: { edicion = $0 }, borrar: { b in
                    tituloBorrar = b.titulo
                    porBorrar = b
                })
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Tema.fondo)
        .navigationTitle("Técnicas")
        .sheet(item: $edicion) { e in
            HojaMiTecnica(edicion: e, productos: modelo.vista?.productos ?? []) { texto, producto in
                edicion = nil
                guardar(e, texto, producto)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Tema.fondo)
            .apariencia()
        }
        .confirmationDialog(tituloBorrar, isPresented: Binding(
            get: { porBorrar != nil },
            set: { if !$0 { porBorrar = nil } }
        ), titleVisibility: .visible, presenting: porBorrar) { b in
            Button("Borrar", role: .destructive) {
                porBorrar = nil
                borrar(b)
            }
            Button("Cancelar", role: .cancel) { porBorrar = nil }
        } message: { _ in
            Text("No se puede recuperar.")
        }
    }

    /// La técnica del nivel actual: la de nivel más alto ya alcanzado.
    private func actual(_ v: Vista) -> String? {
        v.tecnicas.filter { $0.nivel <= v.nivel }.max { $0.nivel < $1.nivel }?.id
    }

    private func seccionTecnicas(_ v: Vista) -> some View {
        let practicando = actual(v)
        return Section("Técnicas por nivel") {
            ForEach(v.tecnicas) { t in
                FilaTecnica(tecnica: t, practicando: t.id == practicando)
            }
        }
        .listRowBackground(Tema.superficie)
    }

    private func guardar(_ e: Edicion, _ texto: String, _ producto: String?) {
        switch e {
        case .nueva: modelo.hacer("miTecnica", [texto, producto ?? ""])
        case .tecnica(let t): modelo.hacer("editarMiTecnica", [t.id, texto])
        case .gancho(let indice, _): modelo.hacer("editarGancho", [String(indice), texto])
        }
    }

    private func borrar(_ b: Borrado) {
        switch b {
        case .tecnica(let t): modelo.hacer("borrarMiTecnica", [t.id])
        case .gancho(let indice, _): modelo.hacer("borrarGancho", [String(indice)])
        }
    }
}

/// Qué se escribe en la hoja: una técnica nueva, una propia o un gancho del banco (por su posición).
private enum Edicion: Identifiable {
    case nueva
    case tecnica(MiTecnica)
    case gancho(Int, Gancho)

    var id: String {
        switch self {
        case .nueva: return "nueva"
        case .tecnica(let t): return "t-" + t.id
        case .gancho(let i, _): return "g-\(i)"
        }
    }
}

/// Lo que se va a borrar, pendiente de confirmar.
private enum Borrado {
    case tecnica(MiTecnica)
    case gancho(Int, Gancho)

    var titulo: String {
        switch self {
        case .tecnica: return "¿Borrar esta técnica?"
        case .gancho: return "¿Borrar este gancho?"
        }
    }
}

private struct FilaTecnica: View {
    let tecnica: Tecnica
    let practicando: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            HStack(spacing: Espacio.s) {
                Text("Nivel \(tecnica.nivel)")
                    .font(.caption.bold())
                    .foregroundStyle(Tema.textoSuave)
                if practicando {
                    Text("Practicando ahora")
                        .font(.caption.bold())
                        .foregroundStyle(Tema.sobreAcento)
                        .padding(.horizontal, Espacio.s)
                        .padding(.vertical, 2)
                        .background(Tema.acento, in: Capsule())
                }
            }
            Text(tecnica.titulo)
                .font(.headline)
                .foregroundStyle(Tema.texto)
            Text(tecnica.texto)
                .font(.body)
                .foregroundStyle(Tema.texto)
        }
        .padding(.vertical, Espacio.xs)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// Técnicas propias (la más reciente arriba) y ganchos del banco con sus visitas.
private struct SeccionMisTecnicas: View {
    let vista: Vista
    let editar: (Edicion) -> Void
    let borrar: (Borrado) -> Void

    /// Nombre del producto, o nil si no tiene o ya se borró.
    private func nombre(_ id: String?) -> String? {
        guard let id else { return nil }
        return vista.productos.first { $0.id == id }?.nombre
    }

    var body: some View {
        Section {
            Button("Añadir mi técnica") { editar(.nueva) }
                .foregroundStyle(Tema.acento)
                .frame(minHeight: 44)
            if vista.misTecnicas.isEmpty && vista.ganchos.isEmpty {
                Text("Aún no has guardado técnicas ni ganchos")
                    .foregroundStyle(Tema.textoSuave)
                    .frame(minHeight: 44)
            }
            ForEach(vista.misTecnicas.reversed()) { t in
                FilaMia(texto: t.texto, detalle: nombre(t.producto), tipo: "Técnica",
                        editar: { editar(.tecnica(t)) }, borrar: { borrar(.tecnica(t)) })
            }
            ForEach(Array(vista.ganchos.enumerated()).reversed(), id: \.offset) { par in
                let g = par.element
                let visitas = "\(miles(g.visitas)) visitas"
                FilaMia(texto: g.texto, detalle: nombre(g.producto).map { "\($0) · \(visitas)" } ?? visitas, tipo: "Gancho",
                        editar: { editar(.gancho(par.offset, g)) }, borrar: { borrar(.gancho(par.offset, g)) })
            }
        } header: {
            Text("Mis técnicas")
        } footer: {
            Text("Tus notas y los ganchos que guardas al apuntar visitas.")
        }
        .listRowBackground(Tema.superficie)
    }
}

/// Una técnica propia o un gancho: tocar edita; la papelera pide confirmación.
private struct FilaMia: View {
    let texto: String
    let detalle: String?
    /// "Técnica" o "Gancho".
    let tipo: String
    let editar: () -> Void
    let borrar: () -> Void

    var body: some View {
        HStack(spacing: Espacio.s) {
            Button(action: editar) {
                VStack(alignment: .leading, spacing: Espacio.xs) {
                    Text(texto)
                        .font(.body)
                        .foregroundStyle(Tema.texto)
                    Text([tipo, detalle].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSuave)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Toca para editar")
            Button(action: borrar) {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Tema.peligro)
            .accessibilityLabel("Borrar \(tipo.lowercased()): \(texto)")
        }
        .padding(.vertical, Espacio.xs)
    }
}

/// Escribir o editar una técnica propia (hasta 140) o un gancho (hasta 80, como lo corta el juego).
private struct HojaMiTecnica: View {
    let edicion: Edicion
    let productos: [Vista.ProductoFila]
    let guardar: (String, String?) -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var producto = ""
    @FocusState private var enfocado: Bool

    private var maximo: Int {
        if case .gancho = edicion { return 80 }
        return 140
    }

    private var titulo: String {
        switch edicion {
        case .nueva: return "Mi técnica"
        case .tecnica: return "Editar técnica"
        case .gancho: return "Editar gancho"
        }
    }

    private var esNueva: Bool {
        if case .nueva = edicion { return true }
        return false
    }

    private var limpio: String { texto.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Qué te ha funcionado", text: $texto, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($enfocado)
                        .foregroundStyle(Tema.texto)
                        .frame(minHeight: 44)
                        .onChange(of: texto) { _, nuevo in
                            if nuevo.unicodeScalars.count > maximo { texto = recortar(nuevo, maximo) }
                        }
                        .accessibilityLabel("Texto")
                } footer: {
                    Text("\(texto.unicodeScalars.count)/\(maximo)")
                }
                .listRowBackground(Tema.superficie)
                if esNueva && !productos.isEmpty {
                    Section {
                        Picker("Producto", selection: $producto) {
                            Text("Ninguno").tag("")
                            ForEach(productos) { p in Text(p.nombre).tag(p.id) }
                        }
                        .tint(Tema.acento)
                        .foregroundStyle(Tema.texto)
                        .frame(minHeight: 44)
                    }
                    .listRowBackground(Tema.superficie)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo)
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
        }
        .onAppear(perform: empezar)
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancelar") { cerrar() }
                .foregroundStyle(Tema.acento)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Guardar") { guardar(limpio, producto.isEmpty ? nil : producto) }
                .foregroundStyle(Tema.acento)
                .disabled(limpio.isEmpty)
        }
    }

    private func empezar() {
        switch edicion {
        case .nueva: texto = ""
        case .tecnica(let t): texto = t.texto
        case .gancho(_, let g): texto = g.texto
        }
        enfocado = true
    }
}
