import Foundation

/// Lee una cantidad escrita a mano: "1.240", "1240", "1240,50", "1.240,50", "12.5".
/// Regla: se quitan espacios y "€". Si hay coma, la coma es decimal (1 o 2 cifras) y los puntos
/// son de miles. Sin coma, un punto seguido de grupos de exactamente 3 cifras es de miles ("1.240");
/// cualquier otro punto es decimal ("1240.5"). Devuelve nil si no se entiende.
func importe(_ texto: String) -> Double? {
    let t = texto.filter { !$0.isWhitespace && $0 != "€" }
    let entero = "^[0-9]+$"
    let miles = "^[0-9]{1,3}(\\.[0-9]{3})+$"
    func casa(_ s: String, _ patron: String) -> Bool {
        s.range(of: patron, options: .regularExpression) != nil
    }

    let normal: String
    if t.contains(",") {
        let partes = t.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard partes.count == 2, casa(partes[1], "^[0-9]{1,2}$"),
              casa(partes[0], entero) || casa(partes[0], miles) else { return nil }
        normal = partes[0].replacingOccurrences(of: ".", with: "") + "." + partes[1]
    } else if casa(t, miles) {
        normal = t.replacingOccurrences(of: ".", with: "")
    } else if casa(t, "^[0-9]+(\\.[0-9]+)?$") {
        normal = t
    } else {
        return nil
    }
    guard let valor = Double(normal), valor.isFinite else { return nil }
    return valor
}

/// 1240 → "1.240" (punto de miles siempre, también con 4 cifras).
func miles(_ n: Int) -> String {
    let cifras = String(n.magnitude)
    var salida = ""
    for (i, c) in cifras.enumerated() {
        if i > 0 && (cifras.count - i) % 3 == 0 { salida.append(".") }
        salida.append(c)
    }
    return (n < 0 ? "−" : "") + salida
}

/// 1240 → "1.240 €".
func euros(_ n: Int) -> String { miles(n) + " €" }
