import Foundation
import ActivityKit

final class SharedIslandStore {
    static let shared = SharedIslandStore()
    private let suiteName = "group.com.ran.quizisland"
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    var selectedProvider: AIProvider {
        get {
            let raw = defaults.string(forKey: "selected_provider") ?? AIProvider.deepseek.rawValue
            return AIProvider(rawValue: raw) ?? .deepseek
        }
        set {
            defaults.set(newValue.rawValue, forKey: "selected_provider")
        }
    }
    
    var enableWebSearch: Bool {
        get {
            if defaults.object(forKey: "enable_web_search") == nil { return true }
            return defaults.bool(forKey: "enable_web_search")
        }
        set {
            defaults.set(newValue, forKey: "enable_web_search")
        }
    }
    
    // Save latest state so Widget Interactive Buttons (Next/Prev Page) can update without opening App
    func saveLatestState(_ state: QuizIslandAttributes.ContentState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: "latest_island_state")
        }
    }
    
    func loadLatestState() -> QuizIslandAttributes.ContentState? {
        guard let data = defaults.data(forKey: "latest_island_state"),
              let state = try? JSONDecoder().decode(QuizIslandAttributes.ContentState.self, from: data) else {
            return nil
        }
        return state
    }
    
    // Save History
    func appendHistory(_ item: QuizHistoryItem) {
        var list = loadHistory()
        list.insert(item, at: 0)
        if list.count > 100 { list = Array(list.prefix(100)) }
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: "quiz_history")
        }
    }
    
    func loadHistory() -> [QuizHistoryItem] {
        guard let data = defaults.data(forKey: "quiz_history"),
              let list = try? JSONDecoder().decode([QuizHistoryItem].self, from: data) else {
            return []
        }
        return list
    }
}
