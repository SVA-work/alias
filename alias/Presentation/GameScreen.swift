import SwiftUI
import UIKit

struct GameScreen: View {
    @Bindable var model: AppViewModel
    @State private var drag: CGFloat = 0
    @State private var resolvingSwipe = false
    @State private var showExit = false
    @State private var showReview = false
    @State private var showRules = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if let game = model.game {
                if game.paused && (game.phase == .playing || game.phase == .common) { pauseScreen }
                else {
                    switch game.phase {
                    case .ready: ready(game)
                    case .playing: wordScreen(game)
                    case .common: commonScreen(game)
                    case .award: awardScreen(game)
                    case .review: resultScreen(game)
                    case .scoreboard: scoreboard(game)
                    case .winner: winner(game)
                    }
                }
            } else { Text("Начните новую игру") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Завершить игру с текущим счётом?", isPresented: $showExit, titleVisibility: .visible) {
            Button("Завершить игру", role: .destructive) { model.mutate { $0.finish() } }
            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showReview) {
            if let game = model.game { ReviewScreen(game: game) { model.updateHistory($0) } }
        }
        .sheet(isPresented: $showRules) { NavigationStack { RulesScreen().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showRules = false } } } } }
    }
    private func ready(_ game: GameSession) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Text("Передайте телефон").foregroundStyle(Palette.muted)
            Image(systemName: "person.2.fill").font(.system(size: 54)).foregroundStyle(Palette.accent).padding(28).background(Palette.pink, in: Circle())
            Text(game.currentTeam.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("Ход \(game.turn / game.teams.count + 1) · \(game.settings.turnSeconds) секунд").foregroundStyle(Palette.muted)
            Text("Объясняющий видит слово.\nОстальные в команде угадывают.").multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Spacer()
            Button("Мы готовы", action: model.startTurn).buttonStyle(GameButtonStyle())
            Button("На главную", action: model.goHome).frame(minHeight: 44)
        }.padding(24)
    }
    private func wordScreen(_ game: GameSession) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    Button(action: model.undo) { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }.disabled(game.roundResults.isEmpty).accessibilityLabel("Отменить последнее слово")
                    Spacer(); Text(game.currentTeam.name).font(.headline).lineLimit(1); Spacer(); Color.clear.frame(width: 44, height: 44)
                }.padding(.horizontal, 8)
                Color.clear.frame(height: 12)
                Button { answer(true) } label: {
                    Text("↑  Угадано").font(.title3.bold()).foregroundStyle(Palette.green).frame(maxWidth: .infinity).frame(height: 76).background(Palette.sage.opacity(drag < -30 ? 1 : 0.8), in: HalfOval(upper: true))
                }.padding(.horizontal, 16).accessibilityHint("Также можно смахнуть слово вверх")
                Spacer(minLength: 15)
                Text(game.currentWord ?? "Все слова сыграны")
                    .font(.system(size: 42, weight: .bold, design: .rounded)).minimumScaleFactor(0.55).multilineTextAlignment(.center).lineLimit(4)
                    .frame(maxWidth: .infinity, minHeight: 140).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette.soft, lineWidth: 1))
                    .padding(.horizontal, 24).offset(y: drag)
                    .opacity(max(0, 1 - Double(abs(drag) / 180)))
                    .allowsHitTesting(!resolvingSwipe).accessibilityIdentifier("wordCard").zIndex(1)
                    .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .named("wordPlayArea")).onChanged { drag = max(-180, min(180, $0.translation.height)) }.onEnded { value in
                        if value.translation.height < -70 { answer(true) }
                        else if value.translation.height > 70 { answer(false) }
                        else { withAnimation(reduceMotion ? nil : .spring(response: 0.25)) { drag = 0 } }
                    })
                    .accessibilityAction(named: "Угадано") { answer(true) }
                    .accessibilityAction(named: "Пропуск") { answer(false) }
                Spacer(minLength: 15)
                Button { answer(false) } label: {
                    Text("Пропуск  ↓").font(.title3.bold()).foregroundStyle(Palette.accent).frame(maxWidth: .infinity).frame(height: 76).background(Palette.pink, in: HalfOval(upper: false))
                }.padding(.horizontal, 16).accessibilityHint("Также можно смахнуть слово вниз")
                Color.clear.frame(height: 12)
                HStack {
                    Text(time(game.remaining)).font(.title2.bold()).monospacedDigit().padding(.horizontal, 16).frame(height: 48).background(Palette.pink, in: RoundedRectangle(cornerRadius: 17)).accessibilityLabel("Осталось \(Int(ceil(game.remaining))) секунд")
                    Spacer(); Text("\(game.roundResults.filter { $0.creditedTeam != nil }.count) угадано").font(.footnote).foregroundStyle(Palette.muted); Spacer()
                    Button(action: model.pause) { Image(systemName: "pause.fill").frame(width: 48, height: 48).background(Palette.soft, in: RoundedRectangle(cornerRadius: 16)) }.accessibilityLabel("Пауза")
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }.frame(height: geo.size.height).coordinateSpace(name: "wordPlayArea")
        }
    }
    private func commonScreen(_ game: GameSession) -> some View {
        VStack(spacing: 20) {
            Text("Общее слово").font(.title2.bold()).padding(.top, 24)
            Text("Угадывают все команды").foregroundStyle(Palette.muted)
            Spacer()
            Text(game.currentWord ?? "").font(.system(size: 42, weight: .bold, design: .rounded)).multilineTextAlignment(.center).minimumScaleFactor(0.5).padding(28).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 26))
            Spacer()
            Button("Завершить слово") { model.mutate { $0.phase = .award } }.buttonStyle(GameButtonStyle())
            HStack {
                Text(game.settings.commonSeconds == 0 ? "∞" : time(game.remaining)).font(.title2.bold()).monospacedDigit().frame(minWidth: 80, minHeight: 48).background(Palette.pink, in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                Button(action: model.pause) { Image(systemName: "pause.fill").frame(width: 48, height: 48).background(Palette.soft, in: RoundedRectangle(cornerRadius: 16)) }.accessibilityLabel("Пауза")
            }
        }.padding(24)
    }
    private func awardScreen(_ game: GameSession) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                GameHeading(title: "Кто угадал?")
                Text(game.currentWord ?? "").font(.title.bold()).multilineTextAlignment(.center).padding(.vertical, 30)
                ForEach(game.teams) { team in
                    Button { model.mutate { $0.award(to: team.id) } } label: {
                        HStack { Text(team.name).font(.title3.bold()); Spacer(); Text("+1").font(.title3.bold()).foregroundStyle(Palette.accent) }.padding(24).background(Palette.pink, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain)
                }
                Button("Никто не угадал") { model.mutate { $0.award(to: nil) } }.buttonStyle(GameButtonStyle(secondary: true)).padding(.top, 20)
            }.padding(24)
        }
    }
    private func resultScreen(_ game: GameSession) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                GameHeading(title: "Итоги хода", subtitle: game.currentTeam.name)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(game.roundResults.filter { $0.creditedTeam == game.currentTeam.id }.count)").font(.system(size: 58, weight: .bold, design: .rounded)).foregroundStyle(Palette.accent)
                    Text("угадано командой").font(.subheadline).foregroundStyle(Palette.muted); Spacer()
                }
                if game.roundResults.isEmpty { Text("В этом ходе нет сыгранных слов.").foregroundStyle(Palette.muted).padding(.vertical, 30) }
                ForEach(game.roundResults) { result in
                    ResultRow(result: result, teams: game.teams, penalty: game.settings.skipPenalty,
                              toggle: { model.mutate { $0.toggle(result.id) } },
                              credit: { id in model.mutate { $0.credit(result.id, to: id) } })
                }
                Text("Нажмите на слово, чтобы исправить результат.").font(.footnote).foregroundStyle(Palette.muted)
            }.padding(24)
        }.safeAreaInset(edge: .bottom) {
            Button("Сохранить результат") { model.mutate { $0.confirmTurn() } }.buttonStyle(GameButtonStyle()).padding(24).background(Palette.background)
        }
    }
    private func scoreboard(_ game: GameSession) -> some View {
        VStack(spacing: 24) {
            GameHeading(title: "Счёт игры", subtitle: "До \(game.settings.targetScore) очков")
            standings(game)
            Spacer()
            Text("Теперь \(game.teams[(game.turn + 1) % game.teams.count].name)").font(.title2.bold()).multilineTextAlignment(.center)
            Button("Следующий ход") { model.mutate { $0.nextTurn() } }.buttonStyle(GameButtonStyle())
            Button("На главную", action: model.goHome).frame(minHeight: 44)
        }.padding(24)
    }
    private func winner(_ game: GameSession) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Игра окончена").foregroundStyle(Palette.muted).padding(.top, 20)
                ZStack {
                    Circle().fill(Palette.pink).frame(width: 180, height: 180)
                    ForEach(0..<18, id: \.self) { i in
                        Capsule().fill(i.isMultiple(of: 3) ? Palette.pink : Palette.accent).frame(width: 6, height: 13).rotationEffect(.degrees(Double(i * 29))).offset(x: cos(Double(i) * .pi / 9) * 135, y: sin(Double(i) * .pi / 9) * 100)
                    }
                    Image(systemName: "crown.fill").font(.system(size: 86)).foregroundStyle(Palette.accent)
                }.frame(height: 210).accessibilityHidden(true)
                Text(game.leaders.map(\.name).joined(separator: " и ")).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(game.leaders.count > 1 ? "Ничья!" : "Победители!").font(.title2.bold()).foregroundStyle(Palette.accent)
                standings(game).padding(.vertical, 15)
                Button("Проверить слова") { showReview = true }.frame(minHeight: 44)
                Button("Ещё партию", action: model.newGame).buttonStyle(GameButtonStyle())
                Button("На главную", action: model.goHome).frame(minHeight: 44)
            }.padding(24)
        }
    }
    private var pauseScreen: some View {
        VStack(spacing: 18) {
            Spacer(); Text("Передышка").font(.largeTitle.bold()); Text("Таймер остановлен").foregroundStyle(Palette.muted); Spacer()
            Button("Продолжить", action: model.resume).buttonStyle(GameButtonStyle())
            Button("Правила") { showRules = true }.buttonStyle(GameButtonStyle(secondary: true))
            Button("Сохранить и выйти", action: model.goHome).frame(minHeight: 44)
            Button("Завершить игру", role: .destructive) { showExit = true }.frame(minHeight: 44)
        }.padding(24)
    }
    private func standings(_ game: GameSession) -> some View {
        VStack(spacing: 18) { ForEach(game.standings) { team in HStack { Text(team.name).font(.title3.bold()); Spacer(); Text("\(game.score(for: team.id))").font(.title2.bold()).monospacedDigit() } } }
    }
    private func time(_ value: Double) -> String { let seconds = Int(ceil(value)); return String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    private func answer(_ correct: Bool) {
        guard !resolvingSwipe, model.game?.phase == .playing, model.game?.paused == false else { return }
        let word = model.game?.currentWord
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard !reduceMotion else { model.answer(correct); drag = 0; return }
        resolvingSwipe = true
        withAnimation(.easeOut(duration: 0.16)) { drag = correct ? -220 : 220 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            if model.game?.phase == .playing && model.game?.currentWord == word { model.answer(correct) }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { drag = 0; resolvingSwipe = false }
        }
    }
}

struct ResultRow: View {
    let result: WordResult
    let teams: [Team]
    let penalty: Bool
    let toggle: () -> Void
    let credit: (UUID?) -> Void
    private var label: String {
        if let id = result.creditedTeam { return result.common ? "+1 · " + (teams.first { $0.id == id }?.name ?? "Команда") : "Угадано" }
        return penalty && !result.common ? "Пропуск · −1" : "Пропуск"
    }
    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.word).font(.headline).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Text(label).font(.caption).foregroundStyle(result.creditedTeam == nil ? Palette.muted : Palette.green)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint("Изменить результат слова")
            if result.common {
                Menu {
                    ForEach(teams) { team in Button(team.name) { credit(team.id) } }
                    Button("Никто не угадал") { credit(nil) }
                } label: { Image(systemName: "person.2").frame(width: 44, height: 44).background(Palette.pink, in: RoundedRectangle(cornerRadius: 13)) }.accessibilityLabel("Кому засчитать общее слово")
            } else {
                Button(action: toggle) { Image(systemName: result.creditedTeam != nil ? "checkmark" : "plus").frame(width: 44, height: 44).background(result.creditedTeam != nil ? Palette.sage : Palette.soft, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(result.creditedTeam != nil ? Palette.green : Palette.muted) }.accessibilityLabel(result.creditedTeam != nil ? "Убрать очко за \(result.word)" : "Засчитать \(result.word)")
            }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
