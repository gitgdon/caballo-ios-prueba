import SwiftUI

/// Calendario de dinero, como uno de trading: cada día en verde si el neto es positivo,
/// en rojo si es negativo y gris si no hubo movimientos. Se abre en el mes actual.
struct Calendario: View {
    @ObservedObject var modelo: Modelo
    /// Día 1 del mes que se ve.
    @State private var mes = Calendario.primeroDeMes(.now)
    @State private var elegido: DiaElegido?

    private static let calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2
        return c
    }()

    private static let formatoClave: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let formatoTitulo: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL 'de' yyyy"
        return f
    }()

    private static func primeroDeMes(_ fecha: Date) -> Date {
        calendario.date(from: calendario.dateComponents([.year, .month], from: fecha)) ?? fecha
    }

    private var clave: String { Self.formatoClave.string(from: mes) }
    private var esMesActual: Bool { mes >= Self.primeroDeMes(.now) }

    private var titulo: String {
        let t = Self.formatoTitulo.string(from: mes)
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    /// Huecos antes del día 1, con la semana de lunes a domingo.
    private var huecos: Int { (Self.calendario.component(.weekday, from: mes) + 5) % 7 }

    /// Nunca más allá del mes actual.
    private func mover(_ meses: Int) {
        guard meses < 0 || !esMesActual,
              let nuevo = Self.calendario.date(byAdding: .month, value: meses, to: mes) else { return }
        mes = nuevo
    }

    var body: some View {
        let datos = modelo.calendario(mes: clave)
        ScrollView {
            VStack(spacing: Espacio.l) {
                selectorMes
                if let datos {
                    ResumenMes(datos: datos)
                    CuadriculaMes(datos: datos, huecos: huecos) { elegido = DiaElegido(id: $0) }
                }
            }
            .padding(Espacio.l)
        }
        .background(Tema.fondo)
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.inline)
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { g in
            guard abs(g.translation.width) > abs(g.translation.height) * 2 else { return }
            mover(g.translation.width < 0 ? 1 : -1)
        })
        .sheet(item: $elegido) { e in
            HojaDia(modelo: modelo, clave: e.id)
                .presentationDetents([.medium, .large])
                .presentationBackground(Tema.fondo)
        }
    }

    private var selectorMes: some View {
        HStack {
            Button { mover(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mes anterior")
            Spacer()
            Text(titulo)
                .font(.headline)
                .foregroundStyle(Tema.texto)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { mover(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .disabled(esMesActual)
            .opacity(esMesActual ? 0.3 : 1)
            .accessibilityLabel("Mes siguiente")
        }
        .foregroundStyle(Tema.acento)
    }
}

private struct DiaElegido: Identifiable {
    /// "YYYY-MM-DD".
    let id: String
}

/// Total del mes y días verdes y rojos.
private struct ResumenMes: View {
    let datos: CalendarioMes

    private var colorTotal: Color { datos.total > 0 ? Tema.exito : datos.total < 0 ? Tema.peligro : Tema.texto }

    private var lineaDias: String {
        "\(datos.verdes) \(datos.verdes == 1 ? "día verde" : "días verdes") · "
            + "\(datos.rojos) \(datos.rojos == 1 ? "día rojo" : "días rojos")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.xs) {
            Text("Total del mes")
                .font(.subheadline)
                .foregroundStyle(Tema.textoSuave)
            Text(conSigno(datos.total))
                .font(.title.bold())
                .foregroundStyle(colorTotal)
            Text(lineaDias)
                .font(.subheadline)
                .foregroundStyle(Tema.textoSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Espacio.l)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.lg))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total del mes: \(enVoz(datos.total)). \(lineaDias)")
    }
}

/// 7 columnas de lunes a domingo.
private struct CuadriculaMes: View {
    let datos: CalendarioMes
    let huecos: Int
    let tocar: (String) -> Void

    private static let semana = ["L", "M", "X", "J", "V", "S", "D"]
    private let columnas = Array(repeating: GridItem(.flexible(), spacing: Espacio.xs), count: 7)

    var body: some View {
        LazyVGrid(columns: columnas, spacing: Espacio.xs) {
            ForEach(Self.semana, id: \.self) { letra in
                Text(letra)
                    .font(.caption.bold())
                    .foregroundStyle(Tema.textoSuave)
                    .accessibilityHidden(true)
            }
            ForEach((0..<huecos).map { "hueco\($0)" }, id: \.self) { _ in
                Color.clear
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            ForEach(datos.dias) { dia in
                CasillaDia(dia: dia) { tocar(dia.dia) }
            }
        }
    }
}

private struct CasillaDia: View {
    let dia: CalendarioMes.Dia
    let accion: () -> Void
    @Environment(\.dynamicTypeSize) private var tamano

    private var numero: String { String(Int(dia.dia.suffix(2)) ?? 0) }
    private var fondo: Color { dia.neto > 0 ? Tema.exito : dia.neto < 0 ? Tema.peligro : Tema.superficie2 }
    private var tinta: Color { dia.neto > 0 ? Tema.sobreExito : dia.neto < 0 ? Tema.sobrePeligro : Tema.textoSuave }

    /// "27 de octubre: más 260 euros".
    private var etiqueta: String {
        let fecha = nombreDia(dia.dia)
        return dia.movimientos.isEmpty ? fecha + ": sin movimientos" : fecha + ": " + enVoz(dia.neto)
    }

    var body: some View {
        Button(action: accion) {
            VStack(spacing: 2) {
                Text(numero)
                    .font(.caption2)
                // Con letra de accesibilidad el importe no cabe: lo dicen el color y VoiceOver.
                if dia.neto != 0 && !tamano.isAccessibilitySize {
                    Text(compacto(dia.neto))
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(tinta)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(fondo, in: RoundedRectangle(cornerRadius: Radio.sm))
            .contentShape(RoundedRectangle(cornerRadius: Radio.sm))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
        .accessibilityHint("Ver movimientos")
    }
}

/// Lo que entró y salió un día; los gastos se pueden borrar.
private struct HojaDia: View {
    @ObservedObject var modelo: Modelo
    let clave: String
    @Environment(\.dismiss) private var cerrar
    /// Gasto pendiente de confirmar: solo el diálogo lo borra, así un doble toque no borra dos.
    @State private var porBorrar: CalendarioMes.Movimiento?

    private var dia: CalendarioMes.Dia? {
        modelo.calendario(mes: String(clave.prefix(7)))?.dias.first { $0.dia == clave }
    }

    var body: some View {
        NavigationStack {
            List {
                if let d = dia, !d.movimientos.isEmpty {
                    ForEach(d.movimientos) { m in
                        FilaMovimiento(movimiento: m) { porBorrar = m }
                    }
                } else {
                    Text("Este día no hay movimientos")
                        .foregroundStyle(Tema.textoSuave)
                        .frame(minHeight: 44)
                        .listRowBackground(Tema.superficie)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Tema.fondo)
            .navigationTitle(nombreDia(clave))
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("¿Borrar este gasto?",
                                isPresented: Binding(get: { porBorrar != nil }, set: { if !$0 { porBorrar = nil } }),
                                titleVisibility: .visible,
                                presenting: porBorrar) { m in
                Button("Borrar gasto", role: .destructive) {
                    porBorrar = nil
                    modelo.hacer("borrarMovimiento", [String(m.indice)])
                }
                Button("Cancelar", role: .cancel) { porBorrar = nil }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { cerrar() }
                        .foregroundStyle(Tema.acento)
                        .accessibilityLabel("Cerrar")
                }
            }
        }
    }
}

private struct FilaMovimiento: View {
    let movimiento: CalendarioMes.Movimiento
    let borrar: () -> Void

    private var esGasto: Bool { movimiento.tipo == "gasto" }
    private var importe: Double { esGasto ? -movimiento.importe : movimiento.importe }

    var body: some View {
        HStack(spacing: Espacio.s) {
            Text(movimiento.concepto)
                .foregroundStyle(Tema.texto)
            Spacer()
            Text(conSigno(importe))
                .font(.body.bold())
                .foregroundStyle(importe < 0 ? Tema.peligro : Tema.exito)
            if esGasto {
                Button(action: borrar) {
                    Image(systemName: "trash").frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Tema.peligro)
                .accessibilityLabel("Borrar gasto \(movimiento.concepto)")
            }
        }
        .frame(minHeight: 44)
        .listRowBackground(Tema.superficie)
    }
}

// MARK: - Textos

private let mesesEspanol: [String] = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_ES")
    return f.monthSymbols ?? []
}()

/// "2026-10-27" → "27 de octubre".
private func nombreDia(_ clave: String) -> String {
    let partes = clave.split(separator: "-").compactMap { Int($0) }
    guard partes.count == 3, partes[1] >= 1, partes[1] <= mesesEspanol.count else { return clave }
    return "\(partes[2]) de \(mesesEspanol[partes[1] - 1])"
}

/// 1200.01 → "1.200,01"; 260 → "260" (sin signo).
private func cantidad(_ x: Double) -> String {
    let centimos = Int((min(abs(x), 9e15) * 100).rounded())
    let resto = centimos % 100
    return miles(centimos / 100) + (resto == 0 ? "" : String(format: ",%02ld", resto))
}

/// "+260 €", "−29,99 €", "0 €".
private func conSigno(_ x: Double) -> String {
    (x > 0 ? "+" : x < 0 ? "−" : "") + cantidad(x) + " €"
}

/// Para VoiceOver: "más 260 euros", "menos 29,99 euros".
private func enVoz(_ x: Double) -> String {
    (x > 0 ? "más " : x < 0 ? "menos " : "") + cantidad(x) + " euros"
}

/// Para las casillas: "+260", "−30", "+1,2k", "+12k".
private func compacto(_ x: Double) -> String {
    let signo = x > 0 ? "+" : "−"
    let a = min(abs(x), 9e15)
    guard a.rounded() >= 1000 else { return signo + (a < 1 ? cantidad(a) : String(Int(a.rounded()))) }
    let decimas = Int((a / 100).rounded())
    if decimas >= 1000 || decimas % 10 == 0 { return signo + miles(Int((a / 1000).rounded())) + "k" }
    return signo + "\(decimas / 10),\(decimas % 10)k"
}
