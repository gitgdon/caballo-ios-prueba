import SwiftUI

/// Hoja inferior para apuntar el total facturado del reto (siempre el total, nunca venta a venta).
struct HojaFacturacion: View {
    @ObservedObject var modelo: Modelo
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @FocusState private var enfocado: Bool

    private var antes: Int { modelo.vista?.reto?.facturado ?? 0 }
    /// Hasta el entero más grande que guarda el juego (Number.MAX_SAFE_INTEGER).
    private var valor: Double? { importe(texto).flatMap { $0 <= 9_007_199_254_740_991 ? $0 : nil } }

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
            Spacer(minLength: 0)
        }
        .padding(Espacio.l)
        .onAppear { enfocado = true }
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
}
