import SwiftUI
import UIKit
import WidgetKit

struct Entrada: TimelineEntry {
    let date: Date
    let vista: Vista?
}

struct Proveedor: TimelineProvider {
    func placeholder(in context: Context) -> Entrada { Entrada(date: .now, vista: nil) }

    func getSnapshot(in context: Context, completion: @escaping (Entrada) -> Void) {
        completion(Entrada(date: .now, vista: Juego().preparar()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entrada>) -> Void) {
        let ahora = Date.now
        let mediaHora = ahora.addingTimeInterval(30 * 60)
        let manana = Calendar.current.startOfDay(for: ahora.addingTimeInterval(24 * 3600)).addingTimeInterval(60)
        let entrada = Entrada(date: ahora, vista: Juego().preparar())
        completion(Timeline(entries: [entrada], policy: .after(min(mediaHora, manana))))
    }
}

struct BotonHecho: View {
    let mision: Vista.Mision?

    var body: some View {
        if let m = mision, m.tipo != "decision" {
            Button(intent: HechoIntent(misionId: m.id)) {
                Image(systemName: "checkmark.circle.fill").font(.title2)
            }
            .buttonStyle(.plain)
        }
    }
}

private let fondoInicio = LinearGradient(
    colors: [Color(red: 0.23, green: 0.16, blue: 0.11), Color(red: 0.85, green: 0.55, blue: 0.25)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

private func textoSinMision(_ v: Vista) -> String {
    v.hayProductos ? "Día cerrado. Descansa, jinete." : "Toca para empezar tu primer producto"
}

struct Mediano: View {
    let v: Vista

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let texto = v.porque.map({ "💭 " + $0 }) ?? v.frase?.texto {
                Text(texto).font(.system(size: 13).italic()).lineLimit(2).minimumScaleFactor(0.8)
            }
            HStack(spacing: 8) {
                Caballo(humor: v.humor, lado: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(v.lineaNivel).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                    ProgressView(value: Double(v.xp), total: Double(max(v.xpSig, 1))).tint(.white)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    if let m = v.mision {
                        Text("MISIÓN DE LA \(m.bloque.uppercased())").font(.system(size: 9, weight: .bold)).opacity(0.75)
                        Text(m.texto).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                    } else {
                        Text(textoSinMision(v)).font(.system(size: 12, weight: .semibold))
                    }
                    if let linea = v.lineaProducto {
                        Text(linea).font(.system(size: 10)).opacity(0.75).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 4)
                BotonHecho(mision: v.mision)
            }
        }
        .foregroundStyle(.white)
    }
}

struct Pequeno: View {
    let v: Vista

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Caballo(humor: v.humor, lado: 30)
                Text("Nv \(v.nivel)" + (v.racha > 0 ? " · 🔥\(v.racha)" : "")).font(.system(size: 13, weight: .bold))
            }
            Spacer(minLength: 0)
            Text(v.mision?.texto ?? textoSinMision(v)).font(.system(size: 12, weight: .semibold)).lineLimit(3)
            HStack { Spacer(); BotonHecho(mision: v.mision) }
        }
        .foregroundStyle(.white)
    }
}

struct Rectangular: View {
    let v: Vista

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("🐴 Nv \(v.nivel)" + (v.racha > 0 ? " · 🔥\(v.racha)" : "")).font(.headline).lineLimit(1)
                Text(v.mision?.texto ?? textoSinMision(v)).font(.caption).lineLimit(2)
            }
            Spacer(minLength: 0)
            BotonHecho(mision: v.mision)
        }
    }
}

struct Circular: View {
    let v: Vista

    var body: some View {
        VStack(spacing: 0) {
            Text(v.racha > 0 ? "🔥" : "🐴").font(.system(size: 14))
            Text("\(v.racha > 0 ? v.racha : v.nivel)").font(.system(size: 18, weight: .bold))
        }
    }
}

struct VistaWidget: View {
    let entrada: Entrada
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        contenido.containerBackground(for: .widget) { fondo }
    }

    @ViewBuilder private var contenido: some View {
        if let v = entrada.vista {
            switch familia {
            case .accessoryCircular: Circular(v: v)
            case .accessoryRectangular: Rectangular(v: v)
            case .accessoryInline: Text("🐴 Nv \(v.nivel) · " + (v.mision?.texto ?? "Día cerrado"))
            case .systemSmall: Pequeno(v: v)
            default: Mediano(v: v)
            }
        } else {
            Text("🐴 Abre Caballo Blanco").font(.caption)
        }
    }

    @ViewBuilder private var fondo: some View {
        switch familia {
        case .accessoryCircular: AccessoryWidgetBackground()
        case .accessoryRectangular, .accessoryInline: Color.clear
        default: fondoInicio
        }
    }
}

@main
struct CaballoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaballoBlanco", provider: Proveedor()) { entrada in
            VistaWidget(entrada: entrada)
        }
        .configurationDisplayName("Caballo Blanco")
        .description("Tu caballo, tu misión de hoy y tu racha")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
