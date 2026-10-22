import Foundation
import Observation

@MainActor @Observable
final class AppViewModel {
    enum Route: Hashable { case packs, teams, settings, generator, game }
    var path: [Route] = []
    var selectedTab = 0
    var teams = [Team(name: "Лисички"), Team(name: "Медведи")]
    var settings = GameSettings()
    var selectedPacks: Set<String> = ["easy"]
    var customPacks: [WordPack] = []
    var game: GameSession?
    var history: [GameSession] = []
    var error: String?
    var topic = ""
    var difficulty = Difficulty.easy
    var wordCount = 30
    var generatedWords: [String] = []
    var generatedTopic = ""
    var generating = false
    var generationError: String?
    var serverAddress: String {
        didSet { preferences.serverAddress = serverAddress }
    }
    private let repository: any GameRepository
    private let generator: any WordGenerating
    private let preferences: any AppPreferences
    private var lastTick = Date()
    private var generationTask: Task<Void, Never>?
    var packs: [WordPack] { BuiltinPacks.all + customPacks }
    var validTeams: Bool {
        let names = teams.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return names.count >= 2 && names.allSatisfy { !$0.isEmpty && $0.count <= 24 } && Set(names).count == names.count
    }
    init(repository: any GameRepository, generator: any WordGenerating, preferences: any AppPreferences) {
        self.repository = repository; self.generator = generator; self.preferences = preferences
        serverAddress = preferences.serverAddress
        do {
            customPacks = try repository.loadPacks()
            game = try repository.loadActive()
            if game?.phase == .playing || game?.phase == .common { game?.paused = true }
            history = try repository.loadHistory()
        } catch { self.error = "Не удалось прочитать сохранения: \(error.localizedDescription)" }
    }
    func persist() {
        do {
            if let game, game.phase == .winner {
                try repository.saveFinished(game)
                try repository.saveActive(nil)
                history = try repository.loadHistory()
            } else { try repository.saveActive(game) }
        } catch { self.error = "Не удалось сохранить игру: \(error.localizedDescription)" }
    }
    func beginGame() {
        guard validTeams else { error = "Нужны разные названия команд от 1 до 24 символов."; return }
        let chosen = packs.filter { selectedPacks.contains($0.id) }
        let deck = BuiltinPacks.deck(from: chosen)
        guard !deck.isEmpty else { error = "Выберите хотя бы один набор."; return }
        teams = teams.map { Team(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)) }
        game = GameSession(teams: teams, settings: settings, words: deck, packNames: chosen.map(\.title))
        path = [.game]; persist()
    }
    func mutate(_ body: (inout GameSession) -> Void) {
        tick()
        guard var session = game else { return }; body(&session); game = session; persist(); lastTick = Date()
    }
    func startTurn() { mutate { $0.startTurn() } }
    func answer(_ correct: Bool) { mutate { $0.answer(correct: correct) } }
    func undo() { mutate { $0.undo() } }
    func pause() { tick(); mutate { $0.paused = true } }
    func resume() { mutate { $0.paused = false } }
    func tick() {
        let now = Date(); let elapsed = now.timeIntervalSince(lastTick); lastTick = now
        guard var session = game, !session.paused,
              session.phase == .playing || session.phase == .common else { return }
        if session.phase == .common && session.settings.commonSeconds == 0 { return }
        session.remaining = max(0, session.remaining - elapsed)
        if session.remaining == 0 { session.timeExpired(); game = session; persist() }
        else { game = session }
    }
    func goHome() { path = []; selectedTab = 0; persist() }
    func newGame() { game = nil; path = [.packs]; persist() }
    func continueGame() { path = [.game]; lastTick = Date() }
    func deleteHistory(_ id: UUID) {
        do {
            try repository.deleteGame(id)
            if game?.id == id && game?.phase == .winner { game = nil }
            history = try repository.loadHistory()
        }
        catch { self.error = error.localizedDescription }
    }
    func updateHistory(_ edited: GameSession) {
        do {
            try repository.saveFinished(edited)
            history = try repository.loadHistory()
            if game?.id == edited.id { game = edited }
        } catch { self.error = "Не удалось сохранить счёт: \(error.localizedDescription)" }
    }
    func generate() {
        let name = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(name.count) else { generationError = "Введите тему от 2 до 80 символов."; return }
        guard let url = URL(string: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.host != nil, url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host ?? "")) else {
            generationError = "Укажите HTTPS-адрес сервера. Для симулятора можно http://localhost:8787."; return
        }
        generationTask?.cancel()
        generating = true; generationError = nil; generatedWords = []
        let level = difficulty, count = wordCount
        generationTask = Task {
            defer { generating = false }
            do {
                let words = try await generator.generate(topic: name, difficulty: level, count: count, server: url)
                try Task.checkCancellation()
                generatedTopic = name; generatedWords = words
            } catch is CancellationError { }
            catch { if !Task.isCancelled { generationError = error.localizedDescription } }
        }
    }
    func cancelGeneration() { generationTask?.cancel() }
    func saveGeneratedPack() {
        guard generatedWords.count >= 5 else { return }
        let pack = WordPack(id: UUID().uuidString, title: generatedTopic, subtitle: "Своя тема · \(generatedWords.count) слов", symbol: "wand.and.stars", words: generatedWords, custom: true)
        do {
            try repository.savePacks(customPacks + [pack])
            customPacks.append(pack); selectedPacks.insert(pack.id)
            generatedWords = []; topic = ""; path.removeLast()
        } catch { self.error = "Не удалось сохранить набор: \(error.localizedDescription)" }
    }
    func deletePack(_ id: String) {
        let updated = customPacks.filter { $0.id != id }
        do { try repository.savePacks(updated); customPacks = updated; selectedPacks.remove(id) }
        catch { self.error = error.localizedDescription }
    }
}
