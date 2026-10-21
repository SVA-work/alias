import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Лёгкое", medium = "Среднее", hard = "Сложное"
    var id: String { rawValue }
}

struct WordPack: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var symbol: String
    var words: [String]
    var custom = false
}

struct Team: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}

struct GameSettings: Codable {
    var turnSeconds = 60
    var targetScore = 30
    var commonWord = true
    /// Zero means unlimited.
    var commonSeconds = 20
    var skipPenalty = false
}

enum GamePhase: String, Codable { case ready, playing, common, award, review, scoreboard, winner }

struct WordResult: Identifiable, Codable {
    var id = UUID()
    var word: String
    var round: Int
    var explainingTeam: UUID
    var creditedTeam: UUID?
    var common: Bool
}

struct GameSession: Identifiable, Codable {
    var id = UUID()
    var createdAt = Date()
    var teams: [Team]
    var settings: GameSettings
    var words: [String]
    var packNames: [String]
    var cursor = 0
    var turn = 0
    var phase = GamePhase.ready
    var results: [WordResult] = []
    var remaining: Double = 0
    var paused = false
    var finishedAt: Date?

    var currentTeam: Team { teams[turn % teams.count] }
    var currentWord: String? { words.indices.contains(cursor) ? words[cursor] : nil }
    var roundResults: [WordResult] { results.filter { $0.round == turn } }
    var exhausted: Bool { cursor >= words.count }
    func score(for team: UUID) -> Int {
        results.reduce(0) { total, result in
            if result.creditedTeam == team { return total + 1 }
            if settings.skipPenalty && !result.common && result.creditedTeam == nil && result.explainingTeam == team { return total - 1 }
            return total
        }
    }
    var standings: [Team] { teams.sorted { score(for: $0.id) > score(for: $1.id) } }
    var leaders: [Team] {
        guard let best = standings.first else { return [] }
        return teams.filter { score(for: $0.id) == score(for: best.id) }
    }
    mutating func startTurn() {
        guard phase == .ready, !exhausted else { return }
        remaining = Double(settings.turnSeconds)
        paused = false
        phase = .playing
    }
    mutating func answer(correct: Bool) {
        guard phase == .playing, !paused, let word = currentWord else { return }
        results.append(WordResult(word: word, round: turn, explainingTeam: currentTeam.id,
                                  creditedTeam: correct ? currentTeam.id : nil, common: false))
        cursor += 1
        if exhausted { phase = .review }
    }
    mutating func undo() {
        guard phase == .playing, let last = results.last, last.round == turn, !last.common else { return }
        results.removeLast()
        cursor -= 1
    }
    mutating func timeExpired() {
        guard phase == .playing || phase == .common else { return }
        if phase == .common { phase = .award; return }
        if settings.commonWord && !exhausted {
            phase = .common
            remaining = Double(settings.commonSeconds)
        } else { phase = .review }
    }
    mutating func award(to team: UUID?) {
        guard phase == .award, let word = currentWord else { return }
        results.append(WordResult(word: word, round: turn, explainingTeam: currentTeam.id,
                                  creditedTeam: team, common: true))
        cursor += 1
        phase = .review
    }
    mutating func toggle(_ id: UUID) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        results[index].creditedTeam = results[index].creditedTeam == nil ? results[index].explainingTeam : nil
    }
    mutating func credit(_ id: UUID, to team: UUID?) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        results[index].creditedTeam = team
    }
    mutating func confirmTurn() {
        guard phase == .review else { return }
        // Give every team the same number of turns before checking the target.
        let equalTurns = (turn + 1).isMultiple(of: teams.count)
        if exhausted || (equalTurns && leaders.count == 1 && (standings.first.map { score(for: $0.id) } ?? 0) >= settings.targetScore) {
            finish()
        } else { phase = .scoreboard }
    }
    mutating func nextTurn() {
        guard phase == .scoreboard else { return }
        turn += 1
        phase = .ready
    }
    mutating func finish() { phase = .winner; paused = false; finishedAt = Date() }
}
