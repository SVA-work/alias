import SwiftUI
import SwiftData

@main
struct aliasApp: App {
    @State private var model: AppViewModel?
    @State private var startupError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let model { ContentView(model: model) }
                else {
                    VStack(spacing: 20) {
                        Text("Шляпа").font(.largeTitle.bold())
                        if let startupError {
                            Text("Не удалось открыть хранилище").font(.headline)
                            Text(startupError).font(.footnote)
                            Button("Попробовать снова", action: bootstrap).buttonStyle(.borderedProminent)
                        } else { ProgressView() }
                    }.padding().task { bootstrap() }
                }
            }
        }
    }
    private func bootstrap() {
        do {
            let configuration: ModelConfiguration
            #if DEBUG
            configuration = ModelConfiguration(isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("-ui-testing"))
            #else
            configuration = ModelConfiguration()
            #endif
            let container = try ModelContainer(for: StoredDocument.self, configurations: configuration)
            model = AppViewModel(repository: SwiftDataGameRepository(container: container), generator: RemoteWordGenerator())
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}
