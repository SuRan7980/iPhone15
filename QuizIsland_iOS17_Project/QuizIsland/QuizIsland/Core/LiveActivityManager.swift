import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<QuizIslandAttributes>?
    private var lastUpdateTimestamp: Date = .distantPast
    
    private init() {}
    
    func startOrUpdateSearch(question: String) {
        let providerName = SharedIslandStore.shared.selectedProvider.shortName
        let initialState = QuizIslandAttributes.ContentState(
            providerName: providerName,
            statusText: "联网检索中...",
            summaryAnswer: "思考中",
            pages: ["正在向 \(providerName) 发起联网搜题请求，请保持当前做题界面..."],
            currentPageIndex: 0,
            isDone: false,
            isError: false
        )
        SharedIslandStore.shared.saveLatestState(initialState)
        
        // 先结束旧的灵动岛会话，确保每次搜题都是全新干净的状态
        Task {
            for activity in Activity<QuizIslandAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("[LiveActivity] System Live Activities are disabled.")
                return
            }
            
            let attributes = QuizIslandAttributes(questionPreview: String(question.prefix(40)))
            do {
                let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(300))
                let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
                self.currentActivity = activity
            } catch {
                print("[LiveActivity] Failed to request activity: \(error)")
            }
        }
    }
    
    func updateStreamingResponse(rawText: String, isDone: Bool, originalQuestion: String) {
        // 节流保护：非完成态下每 0.8 秒最多刷新一次灵动岛，防止触发 iOS 系统频率限制
        let now = Date()
        if !isDone && now.timeIntervalSince(lastUpdateTimestamp) < 0.8 {
            return
        }
        lastUpdateTimestamp = now
        
        let providerName = SharedIslandStore.shared.selectedProvider.shortName
        let summary = AnswerPaginator.extractSummary(rawText)
        let pages = AnswerPaginator.paginate(rawText)
        let isError = rawText.contains("未检测到输入框") || rawText.contains("请求超时")
        
        let newState = QuizIslandAttributes.ContentState(
            providerName: providerName,
            statusText: isDone ? (isError ? "需要处理" : "联网解答完成") : "正在生成解析...",
            summaryAnswer: summary,
            pages: pages,
            currentPageIndex: 0,
            isDone: isDone,
            isError: isError
        )
        
        SharedIslandStore.shared.saveLatestState(newState)
        
        if isDone {
            let record = QuizHistoryItem(
                id: UUID(),
                date: Date(),
                provider: providerName,
                question: originalQuestion,
                summary: summary,
                fullAnswer: AnswerPaginator.cleanMathSymbols(rawText)
            )
            SharedIslandStore.shared.appendHistory(record)
        }
        
        Task {
            let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(600))
            if let activity = currentActivity {
                await activity.update(content)
            } else if let firstActive = Activity<QuizIslandAttributes>.activities.first {
                await firstActive.update(content)
            }
        }
    }
}
