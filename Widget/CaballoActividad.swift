import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// Caballo pequeño para la tarjeta (imágenes reducidas: las grandes pueden no pintarse aquí).
private struct CaballoMini: View {
    let humor: String
    let lado: CGFloat

    var body: some View {
        if let imagen = UIImage(named: "caballo-\(humor)-p") {
            Image(uiImage: imagen).resizable().scaledToFit().frame(width: lado, height: lado)
        } else {
            Text("🐴").font(.system(size: lado * 0.8))
        }
    }
}

private struct BotonHechoGrande: View {
    let misionId: String?

    var body: some View {
        if let id = misionId {
            Button(intent: HechoIntent(misionId: id)) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 38))
            }
            .buttonStyle(.plain)
            .tint(.green)
        }
    }
}

private struct TarjetaBloqueo: View {
    let e: CaballoAtributos.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                CaballoMini(humor: e.humor, lado: 46)
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
                .activityBackgroundTint(Color(red: 0.30, green: 0.20, blue: 0.13))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { contexto in
            let e = contexto.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { CaballoMini(humor: e.humor, lado: 36) }
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
                Text("🐴")
            } compactTrailing: {
                Text(e.racha > 0 ? "🔥\(e.racha)" : "✅")
            } minimal: {
                Text("🐴")
            }
        }
    }
}
