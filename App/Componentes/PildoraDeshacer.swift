import SwiftUI
import UIKit

/// Lo que enseña la píldora y la copia que deshace; `id` cambia con cada acción para que los 6 s vuelvan a empezar.
struct AvisoDeshacer: Equatable {
    let id = UUID()
    let para: Deshacer
    var texto: String { Juego.etiqueta(para) }
}

/// Píldora de abajo: "<qué se hizo> · Deshacer".
struct PildoraDeshacer: View {
    let texto: String
    let deshacer: () -> Void

    var body: some View {
        HStack(spacing: Espacio.s) {
            Text(texto + " ·")
                .font(.subheadline)
                .foregroundStyle(Tema.texto)
                .lineLimit(2)
                .accessibilityHidden(true)
            Button(action: deshacer) {
                Text("Deshacer")
                    .font(.subheadline.bold())
                    .foregroundStyle(Tema.acento)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Deshacer: \(texto)")
        }
        .padding(.leading, Espacio.l)
        .padding(.trailing, Espacio.m)
        .background(Tema.superficie, in: Capsule())
        .overlay(Capsule().stroke(Tema.borde, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, Espacio.l)
    }
}

@MainActor
private struct ModificadorPildora: ViewModifier {
    @ObservedObject var modelo: Modelo
    let margen: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let aviso = modelo.pildora {
                    PildoraDeshacer(texto: aviso.texto) { modelo.deshacerUltimo() }
                        .padding(.bottom, margen)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAction(.escape) { modelo.pildora = nil }
                        .task(id: aviso.id) {
                            AccessibilityNotification.Announcement("\(aviso.texto). Deshacer disponible").post()
                            // Con VoiceOver no caduca sola: se cierra con el gesto de escape o deshaciendo.
                            if UIAccessibility.isVoiceOverRunning { return }
                            try? await Task.sleep(nanoseconds: 6_000_000_000)
                            if !Task.isCancelled, modelo.pildora?.id == aviso.id { modelo.pildora = nil }
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: modelo.pildora)
    }
}

extension View {
    /// Píldora de deshacer abajo durante 6 s. `sobreBarra`: en `Raiz`, para quedar encima de la barra de pestañas.
    func pildoraDeshacer(_ modelo: Modelo, sobreBarra: Bool = false) -> some View {
        // La barra de pestañas mide 49 pt (50 en iPad) por encima de la zona segura de abajo.
        modifier(ModificadorPildora(modelo: modelo, margen: sobreBarra ? 50 + Espacio.s : Espacio.l))
    }
}

#Preview("Píldora clara") {
    PildoraDeshacer(texto: "Producto borrado") {}.padding().background(Tema.fondo)
}

#Preview("Píldora oscura") {
    PildoraDeshacer(texto: "Misión hecha desde el widget") {}.padding().background(Tema.fondo).preferredColorScheme(.dark)
}
