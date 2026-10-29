import Foundation

/// Texto para buscar: sin acentos ni mayúsculas ("Ácción" → "accion").
func normalizar(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}
