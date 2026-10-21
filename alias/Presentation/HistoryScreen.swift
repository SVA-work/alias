import SwiftUI

struct HistoryScreen: View {
    @Bindable var model: AppViewModel
    @State private var selected: GameSession?
    @State private var deleting: GameSession?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if model.history.isEmpty {
                    ContentUnavailableView("Пока нет игр", systemImage: "clock", description: Text("Завершённые партии появятся здесь. Можно открыть любую и исправить счёт.")).padding(.top, 80)
                }
                ForEach(model.history) { game in
                    HStack {
                        Button { selected = game } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(game.leaders.count > 1 ? "Ничья" : game.leaders.first?.name ?? "Игра").font(.title3.bold()).foregroundStyle(Palette.ink)
                                Text(game.teams.map { "\($0.name) — \(game.score(for: $0.id))" }.joined(separator: " · ")).font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
                                Text(game.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Palette.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        Button { deleting = game } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Удалить игру")
                    }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
            }.padding(24)
        }.background(Palette.background).navigationTitle("История")
            .sheet(item: $selected) { game in ReviewScreen(game: game) { model.updateHistory($0) } }
            .confirmationDialog("Удалить эту игру?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { if let deleting { model.deleteHistory(deleting.id) }; deleting = nil }
                Button("Отмена", role: .cancel) { deleting = nil }
            }
    }
}

struct ReviewScreen: View {
    @State var game: GameSession
    let onSave: (GameSession) -> Void
    @State private var filter: UUID?
    @State private var search = ""
    @State private var changed = false
    @State private var discard = false
    @Environment(\.dismiss) private var dismiss
    private var visible: [WordResult] {
        game.results.filter { (filter == nil || $0.explainingTeam == filter || $0.creditedTeam == filter) && (search.isEmpty || $0.word.localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(game.standings) { team in HStack { Text(team.name).font(.headline); Spacer(); Text("\(game.score(for: team.id))").font(.title2.bold()) } }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            filterButton("Все", id: nil)
                            ForEach(game.teams) { team in filterButton(team.name, id: team.id) }
                        }
                    }.padding(.vertical, 10)
                    if visible.isEmpty { Text("Нет слов").foregroundStyle(Palette.muted).padding(30) }
                    ForEach(visible) { result in
                        ResultRow(result: result, teams: game.teams, penalty: game.settings.skipPenalty,
                                  toggle: { game.toggle(result.id); changed = true },
                                  credit: { game.credit(result.id, to: $0); changed = true })
                    }
                }.padding(24)
            }.background(Palette.background).navigationTitle("Проверка слов").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "Найти слово")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { if changed { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(game); dismiss() }.bold().disabled(!changed) }
                }
                .confirmationDialog("Не сохранять изменения?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Не сохранять", role: .destructive) { dismiss() }
                    Button("Продолжить проверку", role: .cancel) { }
                }
        }.interactiveDismissDisabled(changed).tint(Palette.accent).foregroundStyle(Palette.ink)
    }
    private func filterButton(_ title: String, id: UUID?) -> some View {
        Button(title) { filter = id }.font(.subheadline.bold()).padding(.horizontal, 16).frame(height: 44).background(filter == id ? Palette.accent : Palette.soft, in: Capsule()).foregroundStyle(filter == id ? .white : Palette.ink)
    }
}

struct RulesScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                rule("01", "Соберите команды", "Выберите наборы и названия 2–6 команд. Укажите время хода и целевой счёт.")
                rule("02", "Объясняйте слова", "Объясняющий держит телефон. Нельзя использовать однокоренные слова или перевод. Свайп вверх — угадано, вниз — пропуск. Можно нажимать на цветные области.")
                rule("03", "Общее слово", "После сигнала текущее слово могут угадывать все команды. Завершите слово и выберите команду, которой засчитать очко, либо «Никто не угадал».")
                rule("04", "Проверьте результат", "В итогах хода нажмите на слово, чтобы убрать или добавить очко. Общее слово можно передать другой команде.")
                rule("05", "Определите победителя", "После равного числа ходов побеждает единственный лидер, набравший целевой счёт. При ничьей игра продолжается. Если слова закончились, выигрывает лидер; возможна ничья.")
                rule("06", "Своя тема", "Введите тему в генераторе, проверьте слова и сохраните набор. Для генерации нужен интернет и настроенный сервер; сохранённые наборы доступны офлайн.")
            }.padding(24)
        }.background(Palette.background).navigationTitle("Как играть")
    }
    private func rule(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(number).font(.caption.bold()).foregroundStyle(Palette.accent)
            Text(title).font(.title2.bold())
            Text(detail).foregroundStyle(Palette.muted).lineSpacing(5)
        }
    }
}
