import Foundation
import AppIntents

struct SubmitQuestionIntent: AppIntent {
    static var title: LocalizedStringResource = "后台静默搜题"
    static var description = IntentDescription("接收屏幕识别的题目文本，在不离开当前做题 App 的情况下通过灵动岛展示 AI 联网解析。")
    
    // 核心红线：强制禁止将主 App 拉起到前台，100% 停留在用户当前做题画面！
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "题目文本", description: "从当前屏幕截图中提取的题目文字")
    var questionText: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let cleanedQuestion = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuestion.isEmpty else {
            return .result()
        }
        
        // 1. 开启按需静音保活（防止 iOS 在后台冻结 WKWebView 网络请求）
        BackgroundKeepAliveManager.shared.startTemporaryKeepAlive(duration: 75)
        
        // 2. 立即点亮灵动岛，显示“联网检索中...”
        LiveActivityManager.shared.startOrUpdateSearch(question: cleanedQuestion)
        
        // 3. 后台无头浏览器静默向 DeepSeek 提问并实时推送流式结果至灵动岛
        HeadlessWebSolver.shared.solveQuestionSilently(questionText: cleanedQuestion) { partialOrFinalText, isDone in
            LiveActivityManager.shared.updateStreamingResponse(
                rawText: partialOrFinalText,
                isDone: isDone,
                originalQuestion: cleanedQuestion
            )
            
            if isDone {
                BackgroundKeepAliveManager.shared.stopKeepAlive()
            }
        }
        
        return .result()
    }
}

struct QuizShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SubmitQuestionIntent(),
            phrases: [
                "用\(.applicationName)搜题",
                "\(.applicationName)解答这题"
            ],
            shortTitle: "静默搜题",
            systemImageName: "sparkle.magnifyingglass"
        )
    }
}
