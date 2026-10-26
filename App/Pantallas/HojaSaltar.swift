import SwiftUI

/// Confirmación de "Saltar hoy": aviso del escudo, frase de disciplina y tres salidas.
struct HojaSaltar: View {
    @ObservedObject var modelo: Modelo
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.m) {
            Text("¿Seguro?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Tema.texto)
            if let v = modelo.vista {
                ScrollView {
                    VStack(alignment: .leading, spacing: Espacio.m) { textos(v) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                botones(v)
            }
        }
        .padding(Espacio.l)
        .padding(.top, Espacio.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Los mismos textos de siempre, según skipEffect.
    private func avisoEscudo(_ v: Vista) -> String? {
        switch v.efectoSaltar {
        case "escudo": return "Gastarás 1 escudo 🛡️ (te quedarán \(v.escudos - 1))"
        case "pierde": return "No tienes escudos 🛡️: tu racha se perderá"
        default: return nil
        }
    }

    @ViewBuilder private func textos(_ v: Vista) -> some View {
        if let aviso = avisoEscudo(v) {
            Text(aviso)
                .font(.headline)
                .foregroundStyle(Tema.aviso)
        }
        if let frase = v.fraseSaltar {
            Text(frase)
                .font(.body.italic())
                .foregroundStyle(Tema.textoSuave)
        }
    }

    private func botones(_ v: Vista) -> some View {
        VStack(spacing: Espacio.s) {
            Button("Vale, voy a hacer algo") { cerrar() }
                .buttonStyle(.principal)
                .accessibilityLabel("Vale, voy a hacer algo")
            if v.puedeMinimo {
                Button("😮‍💨 Mejor hago lo mínimo") {
                    modelo.hacer("minimo")
                    cerrar()
                }
                .buttonStyle(.secundario)
                .accessibilityLabel("Mejor hago lo mínimo")
            }
            Button("Saltar igualmente") {
                modelo.hacer("saltar")
                cerrar()
            }
            .buttonStyle(.peligro)
            .accessibilityLabel("Saltar igualmente")
        }
    }
}
