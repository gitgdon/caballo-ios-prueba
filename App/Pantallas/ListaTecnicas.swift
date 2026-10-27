import SwiftUI

/// Todas las técnicas: las desbloqueadas se pueden releer; las bloqueadas dicen el nivel que hace falta.
struct ListaTecnicas: View {
    let tecnicas: [Tecnica]

    var body: some View {
        List {
            ForEach(tecnicas) { t in
                if t.desbloqueada {
                    desbloqueada(t)
                } else {
                    bloqueada(t)
                }
            }
            .listRowBackground(Tema.superficie)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Tema.fondo)
        .navigationTitle("Técnicas")
    }

    private func desbloqueada(_ t: Tecnica) -> some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            Text("✦ Nivel \(t.nivel)")
                .font(.caption.bold())
                .foregroundStyle(Tema.textoSuave)
            Text(t.titulo)
                .font(.headline)
                .foregroundStyle(Tema.texto)
            Text(t.texto)
                .font(.body)
                .foregroundStyle(Tema.texto)
        }
        .padding(.vertical, Espacio.xs)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func bloqueada(_ t: Tecnica) -> some View {
        HStack(spacing: Espacio.m) {
            Text(t.titulo)
                .font(.body)
                .foregroundStyle(Tema.textoSuave)
            Spacer()
            Text("🔒 Nivel \(t.nivel)")
                .font(.footnote)
                .foregroundStyle(Tema.textoSuave)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(t.titulo), bloqueada hasta el nivel \(t.nivel)")
    }
}
