import SwiftUI

/// Fila de una misión pendiente, con círculo de check.
struct FilaMision: View {
    let mision: Vista.Mision
    let hecho: () -> Void
    @State private var marcada = false

    var body: some View {
        HStack(spacing: Espacio.m) {
            VStack(alignment: .leading, spacing: Espacio.xs) {
                Text(mision.bloque.uppercased())
                    .font(.caption)
                    .foregroundStyle(Tema.textoSuave)
                Text(mision.texto)
                    .font(.body)
                    .foregroundStyle(Tema.texto)
                    .strikethrough(marcada)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                guard !marcada else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { marcada = true }
                hecho()
            } label: {
                ZStack {
                    Circle().stroke(Tema.bordeCampo, lineWidth: 2)
                    if marcada {
                        Circle().fill(Tema.exito)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Tema.sobreAcento)
                    }
                }
                .frame(width: 28, height: 28)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Marcar como hecha")
        }
        .opacity(marcada ? 0.5 : 1)
    }
}
