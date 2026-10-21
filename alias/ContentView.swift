import SwiftUI
import Combine

struct ContentView: View {
    @Bindable var model: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    var body: some View {
        TabView(selection: $model.selectedTab) {
            NavigationStack(path: $model.path) {
                HomeScreen(model: model)
                    .navigationDestination(for: AppViewModel.Route.self) { route in
                        switch route {
                        case .packs: PacksScreen(model: model).navigationTitle("Наборы").navigationBarTitleDisplayMode(.inline).toolbarBackground(Palette.background, for: .navigationBar)
                        case .teams: TeamsScreen(model: model)
                        case .settings: SettingsScreen(model: model)
                        case .generator: GeneratorScreen(model: model)
                        case .game: GameScreen(model: model).navigationBarBackButtonHidden().toolbar(.hidden, for: .tabBar)
                        }
                    }
            }.tabItem { Label("Играть", systemImage: "play.circle") }.tag(0)
            NavigationStack { HistoryScreen(model: model) }
                .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }.tag(1)
            NavigationStack { RulesScreen() }
                .tabItem { Label("Правила", systemImage: "book.closed") }.tag(2)
        }
        .tint(Palette.accent).foregroundStyle(Palette.ink).preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .onReceive(timer) { _ in model.tick() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.pause() }
        }
        .alert("Не получилось", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Понятно") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct HomeScreen: View {
    @Bindable var model: AppViewModel
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 18) {
                    Text("Шляпа").font(.system(size: 48, weight: .heavy, design: .rounded)).padding(.top, 24)
                    Text("Объясняй. Угадывай.").foregroundStyle(Palette.muted)
                    HatArtwork().padding(.vertical, 12)
                    Spacer(minLength: 8)
                    if model.game != nil && model.game?.phase != .winner {
                        Button("Продолжить игру", action: model.continueGame).buttonStyle(GameButtonStyle())
                        Button("Новая игра") { model.path.append(.packs) }.buttonStyle(GameButtonStyle(secondary: true))
                    } else {
                        Button("Начать игру") { model.path.append(.packs) }.buttonStyle(GameButtonStyle())
                    }
                    Text("2–6 команд · один телефон").font(.footnote).foregroundStyle(Palette.muted)
                }.padding(24).frame(minHeight: geo.size.height)
            }.background(Palette.background)
        }.navigationTitle("").toolbar(.hidden, for: .navigationBar)
    }
}

struct TeamsScreen: View {
    @Bindable var model: AppViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GameHeading(title: "Кто играет?", subtitle: "От 2 до 6 команд")
                ForEach($model.teams) { $team in
                    HStack(spacing: 14) {
                        Image(systemName: "person.2.fill").foregroundStyle(Palette.accent).frame(width: 30)
                        TextField("Название команды", text: $team.name).font(.headline).submitLabel(.done)
                            .onChange(of: team.name) { _, value in if value.count > 24 { team.name = String(value.prefix(24)) } }
                        if model.teams.count > 2 {
                            Button { model.teams.removeAll { $0.id == team.id } } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }.accessibilityLabel("Удалить команду \(team.name)")
                        }
                    }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
                if model.teams.count < 6 {
                    Button { model.teams.append(Team(name: "Команда \(model.teams.count + 1)")) } label: { Label("Добавить команду", systemImage: "plus") }.buttonStyle(GameButtonStyle(secondary: true))
                }
                if !model.validTeams { Text("Названия не должны быть пустыми или повторяться.").font(.footnote).foregroundStyle(Palette.accent) }
            }.padding(24)
        }.background(Palette.background).navigationTitle("Команды").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Дальше") { model.path.append(.settings) }.buttonStyle(GameButtonStyle()).disabled(!model.validTeams).opacity(model.validTeams ? 1 : 0.4).padding(24).background(Palette.background)
            }
    }
}

struct SettingsScreen: View {
    @Bindable var model: AppViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GameHeading(title: "Ваша игра")
                GameCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("Время хода").font(.headline); Spacer(); Text("\(model.settings.turnSeconds) сек").font(.title2.bold()).foregroundStyle(Palette.accent).monospacedDigit() }
                        Slider(value: Binding(get: { Double(model.settings.turnSeconds) }, set: { model.settings.turnSeconds = Int($0) }), in: 30...120, step: 10).accessibilityLabel("Время хода")
                        HStack { Text("30 сек"); Spacer(); Text("2 мин") }.font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                GameCard {
                    HStack {
                        Text("Очков для победы").font(.headline); Spacer()
                        Button { model.settings.targetScore = max(10, model.settings.targetScore - 10) } label: { Image(systemName: "minus").frame(width: 44, height: 44).background(Palette.soft, in: Circle()) }.disabled(model.settings.targetScore == 10).accessibilityLabel("Меньше очков")
                        Text("\(model.settings.targetScore)").font(.title2.bold()).monospacedDigit().frame(minWidth: 30)
                        Button { model.settings.targetScore = min(100, model.settings.targetScore + 10) } label: { Image(systemName: "plus").frame(width: 44, height: 44).background(Palette.soft, in: Circle()) }.disabled(model.settings.targetScore == 100).accessibilityLabel("Больше очков")
                    }
                }
                GameCard {
                    VStack(alignment: .leading, spacing: 18) {
                        customToggle("Общее слово", value: $model.settings.commonWord)
                        if model.settings.commonWord {
                            Text("После сигнала угадывают все команды").font(.footnote).foregroundStyle(Palette.muted)
                            HStack(spacing: 8) {
                                ForEach([10, 20, 30, 0], id: \.self) { seconds in
                                    Button { model.settings.commonSeconds = seconds } label: {
                                        Text(seconds == 0 ? "∞" : "\(seconds) с").font(.headline).frame(maxWidth: .infinity).frame(height: 48)
                                            .background(model.settings.commonSeconds == seconds ? Palette.accent : Palette.soft, in: RoundedRectangle(cornerRadius: 15))
                                            .foregroundStyle(model.settings.commonSeconds == seconds ? .white : Palette.ink)
                                    }.accessibilityLabel(seconds == 0 ? "Без ограничения времени" : "\(seconds) секунд")
                                }
                            }
                        }
                    }
                }
                GameCard { customToggle("−1 за пропуск", value: $model.settings.skipPenalty) }
                Text("Каждая команда получит одинаковое число ходов. При равном счёте игра продолжается. Если слова закончатся, победит лидер.").font(.footnote).foregroundStyle(Palette.muted)
            }.padding(24)
        }.background(Palette.background).navigationTitle("Настройки").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { Button("К игре", action: model.beginGame).buttonStyle(GameButtonStyle()).padding(24).background(Palette.background) }
    }
    private func customToggle(_ title: String, value: Binding<Bool>) -> some View {
        Button { value.wrappedValue.toggle() } label: {
            HStack { Text(title).font(.headline); Spacer(); Image(systemName: value.wrappedValue ? "checkmark.square.fill" : "square").font(.title).foregroundStyle(Palette.accent) }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(value.wrappedValue ? "Включено" : "Выключено")
    }
}

struct GeneratorScreen: View {
    @Bindable var model: AppViewModel
    @State private var showServer = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GameHeading(title: "Своя тема", subtitle: "ИИ придумает слова для вашей компании")
                if model.generatedWords.isEmpty {
                    GameCard { TextField("Например, кухня", text: $model.topic).font(.title3).disabled(model.generating).accessibilityLabel("Тема набора") }
                    Text("Сложность").font(.headline)
                    HStack { ForEach(Difficulty.allCases) { level in
                        Button(level.rawValue) { model.difficulty = level }.padding(.vertical, 14).frame(maxWidth: .infinity).font(.subheadline.bold()).background(model.difficulty == level ? Palette.accent : Palette.soft, in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(model.difficulty == level ? .white : Palette.ink)
                    }}.disabled(model.generating)
                    HStack { Text("Слов в наборе").font(.headline); Spacer(); ForEach([30, 50], id: \.self) { count in Button("\(count)") { model.wordCount = count }.padding(15).background(model.wordCount == count ? Palette.pink : .white, in: RoundedRectangle(cornerRadius: 14)) } }.disabled(model.generating)
                    if model.generating {
                        HStack { ProgressView(); Text("Придумываем слова…").foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity).padding()
                        Button("Отменить", action: model.cancelGeneration).buttonStyle(GameButtonStyle(secondary: true))
                    } else { Button("Создать набор", action: model.generate).buttonStyle(GameButtonStyle()).disabled(model.topic.trimmingCharacters(in: .whitespacesAndNewlines).count < 2) }
                    if let message = model.generationError { Text(message).font(.callout).foregroundStyle(Palette.accent).accessibilityIdentifier("generationError") }
                    Text("Тема отправится на сервер для генерации. После сохранения набор доступен без интернета.").font(.footnote).foregroundStyle(Palette.muted)
                    DisclosureGroup("Подключение к серверу", isExpanded: $showServer) {
                        TextField("https://ваш-сервер", text: $model.serverAddress).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().padding().background(.white, in: RoundedRectangle(cornerRadius: 14))
                        Text("В симуляторе: http://localhost:8787. На iPhone нужен HTTPS-адрес сервера.").font(.caption).foregroundStyle(Palette.muted)
                    }.font(.subheadline)
                } else {
                    Text(model.generatedTopic).font(.title2.bold())
                    Text("\(model.generatedWords.count) слов · уберите неподходящие").font(.subheadline).foregroundStyle(Palette.muted)
                    ForEach(model.generatedWords, id: \.self) { word in
                        HStack { Text(word); Spacer(); Button { model.generatedWords.removeAll { $0 == word } } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Убрать \(word)") }.padding(.leading, 18).padding(.trailing, 4).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    }
                    if model.generatedWords.count < 5 { Text("Оставьте минимум 5 слов.").foregroundStyle(Palette.accent) }
                    Button("Сгенерировать заново") { model.generatedWords = [] }.buttonStyle(GameButtonStyle(secondary: true))
                }
            }.padding(24)
        }.background(Palette.background).navigationTitle("Генератор").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !model.generatedWords.isEmpty { Button("Сохранить набор", action: model.saveGeneratedPack).buttonStyle(GameButtonStyle()).disabled(model.generatedWords.count < 5).padding(24).background(Palette.background) }
            }.onDisappear { model.cancelGeneration() }
    }
}
