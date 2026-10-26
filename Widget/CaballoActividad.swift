import ActivityKit
import SwiftUI
import WidgetKit

private let doradoTarjeta = Color(red: 0.89, green: 0.659, blue: 0.29)
private let oscuroTarjeta = Color(red: 0.122, green: 0.102, blue: 0.078)

/// Caballo vectorial en plantilla (una sola tinta).
private struct CaballoMini: View {
    let lado: CGFloat

    var body: some View {
        Image("caballo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: lado, height: lado)
            .foregroundStyle(doradoTarjeta)
            .accessibilityHidden(true)
    }
}

private struct BotonHechoGrande: View {
    let misionId: String?

    var body: some View {
        if let id = misionId {
            Button(intent: HechoIntent(misionId: id)) {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(oscuroTarjeta)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(doradoTarjeta))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hecho")
        }
    }
}

private struct TarjetaBloqueo: View {
    let e: CaballoAtributos.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                CaballoMini(lado: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.nivel).font(.system(size: 14, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    if !e.frase.isEmpty {
                        Text(e.frase).font(.system(size: 13).italic()).lineLimit(3).minimumScaleFactor(0.85)
                    }
                }
            }
            Divider().overlay(.white.opacity(0.4))
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if !e.bloque.isEmpty {
                        Text("MISIÓN DE LA \(e.bloque.uppercased())").font(.system(size: 10, weight: .bold)).opacity(0.75)
                    }
                    Text(e.mision).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    if let p = e.producto {
                        Text(p).font(.system(size: 11)).opacity(0.75).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 4)
                BotonHechoGrande(misionId: e.misionId)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
    }
}

struct CaballoActividad: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaballoAtributos.self) { contexto in
            TarjetaBloqueo(e: contexto.state)
                .activityBackgroundTint(Color(red: 0.08, green: 0.067, blue: 0.05).opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { contexto in
            let e = contexto.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { CaballoMini(lado: 36) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(e.racha > 0 ? "🔥\(e.racha)" : "").font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(e.nivel).font(.caption.bold()).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(e.mision).font(.subheadline).lineLimit(2)
                        Spacer()
                        BotonHechoGrande(misionId: e.misionId)
                    }
                }
            } compactLeading: {
                // Experimento: contenido de ancho cero para que la isla crezca lo mínimo posible.
                Color.clear.frame(width: 0, height: 0)
            } compactTrailing: {
                Color.clear.frame(width: 0, height: 0)
            } minimal: {
                Color.clear.frame(width: 0, height: 0)
            }
            .contentMargins(.all, 0, for: .compactLeading)
            .contentMargins(.all, 0, for: .compactTrailing)
            .contentMargins(.all, 0, for: .minimal)
        }
    }
}
