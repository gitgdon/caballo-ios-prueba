import SwiftUI
import WidgetKit

struct Entrada: TimelineEntry {
    let date: Date
    let valor: Int
}

struct Proveedor: TimelineProvider {
    func placeholder(in context: Context) -> Entrada { Entrada(date: .now, valor: 0) }

    func getSnapshot(in context: Context, completion: @escaping (Entrada) -> Void) {
        completion(Entrada(date: .now, valor: Contador.valor))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entrada>) -> Void) {
        completion(Timeline(entries: [Entrada(date: .now, valor: Contador.valor)], policy: .never))
    }
}

struct VistaWidget: View {
    let entrada: Entrada

    var body: some View {
        VStack(spacing: 10) {
            Text("🐴 \(entrada.valor)")
                .font(.system(size: 34, weight: .bold))
            Button(intent: SumarIntent()) {
                Text("✅ +1").font(.headline)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.23, green: 0.16, blue: 0.11), Color(red: 0.85, green: 0.55, blue: 0.25)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

@main
struct CaballoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaballoPrueba", provider: Proveedor()) { entrada in
            VistaWidget(entrada: entrada)
        }
        .configurationDisplayName("Caballo prueba")
        .description("Botón +1 sin abrir la app")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
