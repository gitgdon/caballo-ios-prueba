import SwiftUI

/// Banco de ganchos guardados, el más reciente arriba.
struct ListaGanchos: View {
    let ganchos: [Gancho]
    let productos: [Vista.ProductoFila]

    private func nombre(_ id: String) -> String {
        productos.first { $0.id == id }?.nombre ?? id
    }

    var body: some View {
        List {
            if ganchos.isEmpty {
                Text("Aún no has guardado ganchos")
                    .foregroundStyle(Tema.textoSuave)
                    .frame(minHeight: 44)
                    .listRowBackground(Tema.superficie)
            } else {
                ForEach(Array(ganchos.enumerated()).reversed(), id: \.offset) { par in
                    fila(par.element)
                }
                .listRowBackground(Tema.superficie)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Tema.fondo)
        .navigationTitle("Mis ganchos")
    }

    private func fila(_ g: Gancho) -> some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            Text(g.texto)
                .font(.body)
                .foregroundStyle(Tema.texto)
            Text("\(nombre(g.producto)) · \(miles(g.visitas)) visitas")
                .font(.footnote)
                .foregroundStyle(Tema.textoSuave)
        }
        .padding(.vertical, Espacio.xs)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
