import Foundation

@main struct DomainTests {
    static func main() {
        let a = Team(name: "A"), b = Team(name: "B")
        var settings = GameSettings(); settings.targetScore = 1
        var g = GameSession(teams: [a, b], settings: settings, words: ["Чайник", "Венчик", "Плита", "Нож", "Сыр", "Суп"], packNames: [])
        g.startTurn(); g.answer(correct: true)
        assert(g.score(for: a.id) == 1 && g.cursor == 1)
        g.undo(); assert(g.score(for: a.id) == 0 && g.cursor == 0)
        g.answer(correct: false); assert(g.score(for: a.id) == 0)
        g.settings.skipPenalty = true; assert(g.score(for: a.id) == -1)
        g.toggle(g.results[0].id); assert(g.score(for: a.id) == 1)
        g.timeExpired(); assert(g.phase == .common && g.currentWord == "Венчик")
        g.timeExpired(); assert(g.phase == .award)
        g.award(to: b.id); assert(g.score(for: b.id) == 1 && g.results.last!.common)
        g.confirmTurn(); assert(g.phase == .scoreboard) // Equal turns required.
        g.nextTurn(); assert(g.currentTeam.id == b.id)
        g.startTurn(); g.answer(correct: false); g.settings.commonWord = false
        g.timeExpired(); g.confirmTurn(); assert(g.phase == .winner && g.leaders.first!.id == a.id)
        g.credit(g.results[0].id, to: nil); assert(g.score(for: a.id) == -1)
        g.credit(g.results.last!.id, to: b.id); assert(g.leaders.first!.id == b.id)
        let restored = try! JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(g))
        assert(restored.id == g.id && restored.results.count == 3 && restored.score(for: b.id) == 2)
        var tie = GameSession(teams: [a,b], settings: settings, words: ["Один", "Два", "Три"], packNames: [])
        tie.settings.commonWord = false
        for _ in 0..<2 { tie.startTurn(); tie.answer(correct: true); tie.timeExpired(); tie.confirmTurn(); if tie.phase == .scoreboard { tie.nextTurn() } }
        assert(tie.phase == .ready && tie.leaders.count == 2)
        var last = GameSession(teams: [a,b], settings: settings, words: ["Финал"], packNames: [])
        last.startTurn(); last.answer(correct: false); assert(last.phase == .review)
        last.confirmTurn(); assert(last.phase == .winner && last.leaders.count == 2)
        let deck = BuiltinPacks.deck(from: BuiltinPacks.all)
        assert(deck.count >= 240 && deck.count == Set(deck).count)
        print("PASS: scoring, skip penalty, undo, common award, fair turns, tie, exhaustion, Codable, unique deck")
    }
}
