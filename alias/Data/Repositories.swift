import Foundation
import SwiftData

@MainActor
protocol GameRepository {
    func loadPacks() throws -> [WordPack]
    func savePacks(_ packs: [WordPack]) throws
    func loadActive() throws -> GameSession?
    func saveActive(_ game: GameSession?) throws
    func loadHistory() throws -> [GameSession]
    func saveFinished(_ game: GameSession) throws
    func deleteGame(_ id: UUID) throws
}

@Model
final class StoredDocument {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date
    init(key: String, payload: Data) {
        self.key = key; self.payload = payload; updatedAt = Date()
    }
}

@MainActor
final class SwiftDataGameRepository: GameRepository {
    private let context: ModelContext
    init(container: ModelContainer) { context = ModelContext(container); context.autosaveEnabled = false }
    private func documents() throws -> [StoredDocument] { try context.fetch(FetchDescriptor<StoredDocument>()) }
    private func read<T: Decodable>(_ key: String, as: T.Type) throws -> T? {
        guard let data = try documents().first(where: { $0.key == key })?.payload else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private func write<T: Encodable>(_ key: String, _ value: T) throws {
        let data = try JSONEncoder().encode(value)
        if let doc = try documents().first(where: { $0.key == key }) { doc.payload = data; doc.updatedAt = Date() }
        else { context.insert(StoredDocument(key: key, payload: data)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
    private func remove(_ key: String) throws {
        for doc in try documents() where doc.key == key { context.delete(doc) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
    func loadPacks() throws -> [WordPack] { try read("packs", as: [WordPack].self) ?? [] }
    func savePacks(_ packs: [WordPack]) throws { try write("packs", packs) }
    func loadActive() throws -> GameSession? { try read("active", as: GameSession.self) }
    func saveActive(_ game: GameSession?) throws {
        if let game { try write("active", game) } else { try remove("active") }
    }
    func loadHistory() throws -> [GameSession] {
        try documents().filter { $0.key.hasPrefix("game:") }.map { try JSONDecoder().decode(GameSession.self, from: $0.payload) }.sorted { $0.createdAt > $1.createdAt }
    }
    func saveFinished(_ game: GameSession) throws { try write("game:" + game.id.uuidString, game) }
    func deleteGame(_ id: UUID) throws { try remove("game:" + id.uuidString) }
}

protocol WordGenerating: Sendable {
    func generate(topic: String, difficulty: Difficulty, count: Int, server: URL) async throws -> [String]
}

struct GenerationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct RemoteWordGenerator: WordGenerating {
    private struct Request: Encodable { let topic: String; let difficulty: String; let count: Int }
    private struct Reply: Decodable { let words: [String]?; let error: String? }
    func generate(topic: String, difficulty: Difficulty, count: Int, server: URL) async throws -> [String] {
        var request = URLRequest(url: server.appendingPathComponent("generate"))
        request.httpMethod = "POST"
        request.timeoutInterval = 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(topic: topic, difficulty: difficulty.rawValue, count: count))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GenerationError(message: "Сервер не ответил. Попробуйте ещё раз.") }
        let reply = try? JSONDecoder().decode(Reply.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            throw GenerationError(message: reply?.error ?? "Не удалось создать набор. Код ответа: \(http.statusCode).")
        }
        let words = WordValidation.clean(reply?.words ?? [])
        guard words.count >= 5 else { throw GenerationError(message: "ИИ вернул слишком мало подходящих слов. Попробуйте другую тему.") }
        return words
    }
}

enum WordValidation {
    static func clean(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.compactMap { raw in
            let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...60).contains(word.count), !word.contains("\n"), word.rangeOfCharacter(from: .letters) != nil,
                  seen.insert(word.lowercased().replacingOccurrences(of: "ё", with: "е")).inserted else { return nil }
            return word
        }
    }
}
