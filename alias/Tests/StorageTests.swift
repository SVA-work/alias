import Foundation
import SwiftData

@main struct StorageTests {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: "/tmp/alias-storage-test-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(url: url)
        let a = Team(name: "Лисички"), b = Team(name: "Медведи")
        var session = GameSession(teams: [a,b], settings: GameSettings(), words: ["Чайник", "Плита"], packNames: ["Кухня"])
        session.startTurn(); session.answer(correct: true)
        do {
            let store = try ModelContainer(for: StoredDocument.self, configurations: configuration)
            let repo = SwiftDataGameRepository(container: store)
            try repo.saveActive(session)
            try repo.savePacks([WordPack(id: "test", title: "Кухня", subtitle: "", symbol: "sparkles", words: ["Чайник"], custom: true)])
            session.finish(); try repo.saveFinished(session)
        }
        let store = try ModelContainer(for: StoredDocument.self, configurations: configuration)
        let repo = SwiftDataGameRepository(container: store)
        let active = try repo.loadActive(); assert(active?.cursor == 1)
        let packs = try repo.loadPacks(); assert(packs.first?.title == "Кухня")
        var history = try repo.loadHistory(); assert(history.count == 1)
        history[0].toggle(history[0].results[0].id); try repo.saveFinished(history[0])
        let corrected = try repo.loadHistory(); assert(corrected.count == 1 && corrected[0].score(for: a.id) == 0)
        try repo.deleteGame(session.id); let deleted = try repo.loadHistory(); assert(deleted.isEmpty)
        try repo.saveActive(nil); let cleared = try repo.loadActive(); assert(cleared == nil)
        print("PASS: disk reload, active game, custom packs, history upsert, corrections, deletion")
    }
}
