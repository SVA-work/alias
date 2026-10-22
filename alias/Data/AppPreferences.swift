import Foundation

@MainActor
protocol AppPreferences: AnyObject {
    var serverAddress: String { get set }
}

@MainActor
final class UserDefaultsAppPreferences: AppPreferences {
    private let defaults: UserDefaults
    private let serverAddressKey = "generationServer"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var serverAddress: String {
        get { defaults.string(forKey: serverAddressKey) ?? "http://localhost:8787" }
        set { defaults.set(newValue, forKey: serverAddressKey) }
    }
}
