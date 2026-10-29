import Foundation

/// Texto para buscar: sin acentos ni mayúsculas ("Ácción" → "accion").
func normalizar(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
}

/// Hasta `maximo` escalares Unicode, como corta el juego (Array.from), sin partir ningún carácter.
func recortar(_ texto: String, _ maximo: Int) -> String {
    var salida = ""
    var n = 0
    for c in texto {
        n += c.unicodeScalars.count
        if n > maximo { break }
        salida.append(c)
    }
    return salida
}
