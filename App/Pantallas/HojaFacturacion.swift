import SwiftUI

/// Hoja inferior para apuntar el total facturado del reto (siempre el total, nunca venta a venta)
/// y, aparte, un gasto suelto para el calendario de dinero.
struct HojaFacturacion: View {
    @ObservedObject var modelo: Modelo
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @FocusState private var enfocado: Bool
    @State private var gastoAbierto = false
    @State private var textoGasto = ""
    @State private var concepto = ""
    @FocusState private var enfocadoGasto: Bool

    private static let maximoConcepto = 40

    /// Último total de la tienda apuntado (no el del reto, que empieza de cero en un reto nuevo).
    private var antes: Int { modelo.vista?.ultimoTotal ?? 0 }
    /// Hasta el entero más grande que guarda el juego (Number.MAX_SAFE_INTEGER).
    private var valor: Double? { importe(texto).flatMap { $0 <= 9_007_199_254_740_991 ? $0 : nil } }
    /// Gasto mayor que 0 (el juego lo guarda a céntimos).
    private var valorGasto: Double? { importe(textoGasto).flatMap { $0 >= 0.01 && $0 <= 9_007_199_254_740_991 ? $0 : nil } }

    private var lineaAntes: String {
        var linea = "Antes: " + euros(antes)
        if let v = valor {
            let diferencia = Int(v.rounded()) - antes
            if diferencia > 0 { linea += " · +" + euros(diferencia) }
            if diferencia < 0 { linea += " · " + euros(diferencia) }
        }
        return linea
    }

    var body: some View {
        ScrollView {
            contenido
        }
        .onAppear { enfocado = true }
    }

    private var contenido: some View {
        VStack(alignment: .leading, spacing: Espacio.m) {
            Text("Apuntar facturación")
                .font(.title2.bold())
                .foregroundStyle(Tema.texto)
                .accessibilityAddTraits(.isHeader)
            Text("Escribe el total que te marca la tienda, de todos los productos. Si te equivocas, vuelve a escribirlo.")
                .font(.subheadline)
                .foregroundStyle(Tema.textoSuave)
            campo
            Text(lineaAntes)
                .font(.footnote)
                .foregroundStyle(Tema.textoSuave)
            Button("Guardar", action: guardar)
                .buttonStyle(.principal)
                .disabled(valor == nil)
                .accessibilityLabel("Guardar facturación")
            if gastoAbierto {
                formularioGasto
            } else {
                Button("Añadir gasto") { gastoAbierto = true }
                .buttonStyle(.secundario)
                .accessibilityLabel("Añadir gasto")
            }
            Spacer(minLength: 0)
        }
        .padding(Espacio.l)
    }

    private var formularioGasto: some View {
        VStack(alignment: .leading, spacing: Espacio.m) {
            Text("Añadir gasto")
                .font(.headline)
                .foregroundStyle(Tema.texto)
                .accessibilityAddTraits(.isHeader)
            Text("Lo que te cobran por la tienda, como la suscripción. Sale en rojo en el calendario; no resta del reto.")
                .font(.subheadline)
                .foregroundStyle(Tema.textoSuave)
            campoGasto
            TextField("Concepto (p. ej. Shopify)", text: $concepto)
                .foregroundStyle(Tema.texto)
                .padding(.horizontal, Espacio.l)
                .frame(minHeight: 44)
                .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.md))
                .overlay(RoundedRectangle(cornerRadius: Radio.md).stroke(Tema.bordeCampo, lineWidth: 1))
                .onChange(of: concepto) { _, nuevo in
                    if nuevo.unicodeScalars.count > Self.maximoConcepto { concepto = Self.recortar(nuevo) }
                }
                .accessibilityLabel("Concepto del gasto")
            Button("Guardar gasto", action: guardarGasto)
                .buttonStyle(.principal)
                .disabled(valorGasto == nil)
                .accessibilityLabel("Guardar gasto")
        }
        .task { enfocadoGasto = true }
    }

    private var campoGasto: some View {
        HStack(spacing: Espacio.s) {
            TextField("0", text: $textoGasto)
                .keyboardType(.decimalPad)
                .focused($enfocadoGasto)
                .font(.title3.bold())
                .foregroundStyle(Tema.texto)
                .accessibilityLabel("Importe del gasto en euros")
            Text("€")
                .font(.title3.bold())
                .foregroundStyle(Tema.textoSuave)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Espacio.l)
        .frame(minHeight: 52)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.md))
        .overlay(RoundedRectangle(cornerRadius: Radio.md).stroke(Tema.bordeCampo, lineWidth: 1))
    }

    private var campo: some View {
        HStack(spacing: Espacio.s) {
            TextField("0", text: $texto)
                .keyboardType(.decimalPad)
                .focused($enfocado)
                .font(.title.bold())
                .foregroundStyle(Tema.texto)
                .accessibilityLabel("Total facturado en euros")
            Text("€")
                .font(.title.bold())
                .foregroundStyle(Tema.textoSuave)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Espacio.l)
        .frame(minHeight: 56)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Radio.md))
        .overlay(RoundedRectangle(cornerRadius: Radio.md).stroke(Tema.bordeCampo, lineWidth: 1))
    }

    private func guardar() {
        guard let v = valor else { return }
        modelo.hacer("facturacion", [String(v)])
        cerrar()
    }

    /// Hasta 40 escalares Unicode, como corta el juego, sin partir ningún carácter.
    private static func recortar(_ texto: String) -> String {
        var salida = ""
        var n = 0
        for c in texto {
            n += c.unicodeScalars.count
            if n > maximoConcepto { break }
            salida.append(c)
        }
        return salida
    }

    private func guardarGasto() {
        guard let v = valorGasto else { return }
        modelo.hacer("gasto", [String(v), concepto])
        cerrar()
    }
}
