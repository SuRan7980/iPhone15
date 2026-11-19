import Foundation
import AppIntents
import ActivityKit

/// 灵动岛展开态交互按钮意图：支持在灵动岛上直接点击“上一页 / 下一页 / 关闭”，全程不跳端
struct IslandPaginationIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "灵动岛解析翻页"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "操作动作")
    var action: String // "prev", "next", "close"
    
    init() {
        self.action = "next"
    }
    
    init(action: String) {
        self.action = action
    }
    
    func perform() async throws -> some IntentResult {
        if action == "close" {
            for activity in Activity<QuizIslandAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return .result()
        }
        
        let suiteName = "group.com.ran.quizisland"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        guard let data = defaults.data(forKey: "latest_island_state"),
              var state = try? JSONDecoder().decode(QuizIslandAttributes.ContentState.self, from: data) else {
            return .result()
        }
        
        let totalPages = max(state.pages.count, 1)
        if action == "next" {
            state.currentPageIndex = (state.currentPageIndex + 1) % totalPages
        } else if action == "prev" {
            state.currentPageIndex = (state.currentPageIndex - 1 + totalPages) % totalPages
        }
        
        if let updatedData = try? JSONEncoder().encode(state) {
            defaults.set(updatedData, forKey: "latest_island_state")
        }
        
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(600))
        for activity in Activity<QuizIslandAttributes>.activities {
            await activity.update(content)
        }
        
        return .result()
    }
}
