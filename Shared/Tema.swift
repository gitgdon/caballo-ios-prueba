import SwiftUI
import UIKit

/// Colores por rol (valores de design/tokens.json, claro y oscuro). Ninguna vista usa hex sueltos.
enum Tema {
    private static func dinamico(_ claro: UInt32, _ oscuro: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? hex(oscuro) : hex(claro) })
    }

    private static func hex(_ valor: UInt32) -> UIColor {
        UIColor(red: CGFloat((valor >> 16) & 0xFF) / 255,
                green: CGFloat((valor >> 8) & 0xFF) / 255,
                blue: CGFloat(valor & 0xFF) / 255,
                alpha: 1)
    }

    static let fondo = dinamico(0xFBF8F3, 0x14110D)
    static let superficie = dinamico(0xFFFFFF, 0x211C16)
    static let superficie2 = dinamico(0xF4EEE5, 0x2B241C)
    static let borde = dinamico(0xECE5DA, 0x3A3229)
    static let bordeCampo = dinamico(0x8A7F70, 0x8C8173)
    static let texto = dinamico(0x1F1A14, 0xF6F1EA)
    static let textoSuave = dinamico(0x675D52, 0xB8AC9C)
    static let acento = dinamico(0x94600F, 0xE3A84A)
    static let sobreAcento = dinamico(0xFFFFFF, 0x1F1A14)
    static let exito = dinamico(0x24704A, 0x5CC48A)
    static let peligro = dinamico(0xB3261E, 0xFF7A6E)
    static let aviso = dinamico(0x8F5300, 0xF2B04F)

    enum Anillo {
        static let xp = dinamico(0xA86F15, 0xE3A84A)
        static let racha = dinamico(0xCF4F22, 0xE8673A)
        static let producto = dinamico(0x357F6C, 0x4FA38E)
        static let frase = dinamico(0x9C6514, 0xD59A3C)
        static let reto = dinamico(0xB07A10, 0xF2C14E)
    }

    /// Colores fijos (tokens oscuros) para la tarjeta de la pantalla de bloqueo, que siempre es oscura.
    enum Bloqueo {
        static let dorado = Color(hex(0xE3A84A))
        static let sobreDorado = Color(hex(0x1F1A14))
        static let texto = Color(hex(0xF6F1EA))
        static let tinte = Color(hex(0x14110D)).opacity(0.85)
    }

    static let degradadoMarca = LinearGradient(
        colors: [
            Color(hex(0xFFF4E2)),
            Color(hex(0xF6D9A6)),
            Color(hex(0xE3A84A)),
            Color(hex(0xB0742F)),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
}

enum Radio {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
}

enum Espacio {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
