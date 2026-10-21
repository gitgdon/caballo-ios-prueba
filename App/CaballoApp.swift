import SwiftUI
import WidgetKit

@main
struct CaballoApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var valor = Contador.valor
    @Environment(\.scenePhase) private var fase

    var body: some View {
        VStack(spacing: 20) {
            Text("🐴").font(.system(size: 80))
            Text("Contador: \(valor)").font(.largeTitle.bold())
            Text("Pulsa ✅ +1 en el widget y vuelve aquí: este número tiene que ser el mismo que el del widget.")
                .multilineTextAlignment(.center)
                .padding()
            Button("Sumar desde la app") {
                Contador.valor += 1
                valor = Contador.valor
                WidgetCenter.shared.reloadAllTimelines()
            }
            .buttonStyle(.borderedProminent)
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .active { valor = Contador.valor }
        }
    }
}
