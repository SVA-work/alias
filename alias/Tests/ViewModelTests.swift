import Foundation
import SwiftData

struct FakeGenerator: WordGenerating {
    func generate(topic: String, difficulty: Difficulty, count: Int, server: URL) async throws -> [String] { ["Венчик", "Плита", "Сотейник", "Дуршлаг", "Скалка"] }
}
@main struct ViewModelTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(for: StoredDocument.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repo = SwiftDataGameRepository(container: container)
        let model = AppViewModel(repository: repo, generator: FakeGenerator())
        model.path = [.packs, .generator]; model.topic = "Кухня"; model.generate()
        while model.generating { try await Task.sleep(for: .milliseconds(5)) }
        assert(model.generatedWords.count == 5 && model.generatedTopic == "Кухня")
        model.saveGeneratedPack()
        assert(model.customPacks.count == 1 && model.selectedPacks.contains(model.customPacks[0].id))
        model.selectedPacks = [model.customPacks[0].id]; model.beginGame()
        assert(model.game?.words.count == 5 && model.path == [.game])
        model.startTurn(); model.answer(true); model.game?.remaining = 0.001
        try await Task.sleep(for: .milliseconds(20)); model.tick()
        assert(model.game?.phase == .common)
        model.pause(); let remaining = model.game!.remaining
        try await Task.sleep(for: .milliseconds(20)); model.tick(); assert(model.game!.remaining == remaining)
        let restored = AppViewModel(repository: repo, generator: FakeGenerator())
        assert(restored.game?.paused == true && restored.game?.cursor == 1 && restored.customPacks.count == 1)
        restored.resume(); restored.mutate { $0.phase = .award; $0.award(to: $0.teams[1].id) }
        assert(restored.game!.score(for: restored.game!.teams[1].id) == 1)
        restored.mutate { $0.finish() }; assert(restored.history.count == 1)
        var edited = restored.history[0]; edited.toggle(edited.results[0].id); restored.updateHistory(edited)
        assert(restored.history[0].score(for: edited.teams[0].id) == 0)
        restored.deleteHistory(edited.id); restored.goHome()
        let afterDelete = try repo.loadHistory(); assert(restored.history.isEmpty && restored.game == nil && afterDelete.isEmpty)
        print("PASS: generation preview/save, selected pack, game setup, timer transition, pause, restore, history correction")
    }
}
