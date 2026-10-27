import SwiftUI
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
        // Lo mejor posible: iOS puede cerrar la extensión antes de que termine.
        Task { await Avisos.reprogramar(Juego()) }
    }
}

struct BotonHecho: View {
    let mision: Vista.Mision?
    var lado: CGFloat = 36

    var body: some View {
        if let m = mision, m.tipo != "decision" {
            Button(intent: HechoIntent(misionId: m.id)) {
                Image(systemName: "checkmark")
                    .font(.system(size: lado * 0.45, weight: .bold))
                    .foregroundStyle(Tema.sobreAcento)
                    .frame(width: lado, height: lado)
                    .background(Circle().fill(Tema.acento))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hecho")
        }
    }
}

private func textoSinMision(_ v: Vista) -> String {
    v.hayProductos ? "Día cerrado. Descansa, jinete." : "Toca para empezar tu primer producto"
}

private func lineaRacha(_ v: Vista) -> String {
    "Nv \(v.nivel)" + (v.racha > 0 ? " · 🔥\(v.racha)" : "")
}

private func etiquetaRacha(_ v: Vista) -> String {
    "Nivel \(v.nivel)" + (v.racha > 0 ? ", racha \(v.racha) días" : "")
}

private struct BarraXP: View {
    let v: Vista

    var body: some View {
        let fraccion = min(max(Double(v.xp) / Double(max(v.xpSig, 1)), 0), 1)
        ZStack(alignment: .leading) {
            Capsule().fill(Tema.borde)
            Capsule().fill(Tema.Anillo.xp).frame(width: 70 * fraccion)
        }
        .frame(width: 70, height: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Experiencia")
        .accessibilityValue("\(v.xp) de \(v.xpSig)")
    }
}

struct Mediano: View {
    let v: Vista

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let texto = v.porque.map({ "💭 " + $0 }) ?? v.frase?.texto {
                Text(texto).font(.callout.italic().weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8)
                    .foregroundStyle(Tema.texto)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Caballo(humor: v.humor, lado: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lineaRacha(v)).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityLabel(etiquetaRacha(v))
                        .foregroundStyle(Tema.texto)
                    BarraXP(v: v)
                }
                Text(v.mision?.texto ?? textoSinMision(v)).font(.caption.weight(.semibold)).lineLimit(2)
                    .foregroundStyle(Tema.texto)
                Spacer(minLength: 4)
                BotonHecho(mision: v.mision)
            }
        }
    }
}

struct Pequeno: View {
    let v: Vista

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Caballo(humor: v.humor, lado: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lineaRacha(v)).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityLabel(etiquetaRacha(v))
                        .foregroundStyle(Tema.texto)
                    BarraXP(v: v)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 4) {
                Text(v.mision?.texto ?? textoSinMision(v)).font(.caption.weight(.semibold)).lineLimit(3)
                    .foregroundStyle(Tema.texto)
                Spacer(minLength: 0)
                BotonHecho(mision: v.mision)
            }
        }
    }
}

struct Rectangular: View {
    let v: Vista

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image("caballo").renderingMode(.template).resizable().scaledToFit().frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(lineaRacha(v)).font(.headline).lineLimit(1).accessibilityLabel(etiquetaRacha(v))
                }
                Text(v.mision?.texto ?? textoSinMision(v)).font(.caption).lineLimit(2)
            }
            Spacer(minLength: 0)
            if let m = v.mision, m.tipo != "decision" {
                Button(intent: HechoIntent(misionId: m.id)) {
                    Image(systemName: "checkmark.circle").font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hecho")
            }
        }
    }
}

struct Circular: View {
    let v: Vista

    private static let medallas = [7, 30, 100, 365]

    var body: some View {
        let tope = Self.medallas.first { $0 > v.racha } ?? max(v.racha, 1)
        Gauge(value: Double(min(v.racha, tope)), in: 0...Double(tope)) {
            Text("Racha")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text("🔥").font(.system(size: 12))
                Text("\(v.racha)").font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Racha: \(v.racha) días")
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
            case .accessoryInline:
                Text(["Nv \(v.nivel)", v.racha > 0 ? "🔥\(v.racha)" : nil, v.escudos > 0 ? "🛡️\(v.escudos)" : nil].compactMap { $0 }.joined(separator: " · "))
            case .systemSmall: Pequeno(v: v)
            default: Mediano(v: v)
            }
        } else if [.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(familia) {
            Text("Abre Caballo Blanco")
        } else {
            HStack(spacing: 8) {
                Caballo(humor: "normal", lado: 36)
                Text("Abre Caballo Blanco").font(.caption).foregroundStyle(Tema.textoSuave)
            }
        }
    }

    @ViewBuilder private var fondo: some View {
        switch familia {
        case .accessoryCircular: AccessoryWidgetBackground()
        case .accessoryRectangular, .accessoryInline: Color.clear
        default:
            ZStack(alignment: .topTrailing) {
                Tema.superficie
                Circle().fill(Tema.degradadoMarca).frame(width: 120, height: 120)
                    .blur(radius: 30).opacity(0.35).offset(x: 40, y: -40)
            }
        }
    }
}

@main
struct CaballoWidgets: WidgetBundle {
    var body: some Widget {
        CaballoWidget()
        CaballoReto()
        CaballoActividad()
    }
}

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

private func metaCorta(_ meta: Int) -> String {
    meta % 1000 == 0 ? "\(meta / 1000)k" : euros(meta)
}

/// Pareja del rectangular de Hoy en la pantalla de bloqueo: cuánto llevas del reto.
struct RetoRectangular: View {
    let r: Reto

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Reto Q4 · \(r.diasQuedan) \(r.diasQuedan == 1 ? "día" : "días")").font(.headline).lineLimit(1)
            ProgressView(value: min(max(r.progreso, 0), 1)).progressViewStyle(.linear)
            Text("\(euros(r.facturado)) de \(metaCorta(r.meta)) · \(r.videos) \(r.videos == 1 ? "vídeo" : "vídeos")")
                .font(.caption).lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reto: \(miles(r.facturado)) euros de \(miles(r.meta)), quedan \(r.diasQuedan) \(r.diasQuedan == 1 ? "día" : "días"), \(r.videos) \(r.videos == 1 ? "vídeo" : "vídeos")")
    }
}

struct VistaReto: View {
    let entrada: Entrada

    var body: some View {
        Group {
            if let r = entrada.vista?.reto {
                RetoRectangular(r: r)
            } else {
                Text("Abre Caballo Blanco")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct CaballoReto: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaballoReto", provider: Proveedor()) { entrada in
            VistaReto(entrada: entrada)
        }
        .configurationDisplayName("Reto")
        .description("Lo que llevas facturado del reto, los días que quedan y tus vídeos")
        .supportedFamilies([.accessoryRectangular])
    }
}
