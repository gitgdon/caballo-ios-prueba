import SwiftUI
import UIKit

/// El caballo según su estado (radiante, normal, barro); si faltan las imágenes, el emoji.
struct Caballo: View {
    let humor: String
    let lado: CGFloat

    var body: some View {
        if let imagen = UIImage(named: "caballo-\(humor)") {
            Image(uiImage: imagen).resizable().scaledToFit().frame(width: lado, height: lado)
        } else {
            Text("🐴").font(.system(size: lado * 0.8))
        }
    }
}
