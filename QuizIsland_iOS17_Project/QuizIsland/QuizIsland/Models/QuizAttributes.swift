import Foundation
import ActivityKit

struct QuizIslandAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var providerName: String      // 当前使用的 AI 引擎，如 "DeepSeek"
        var statusText: String        // 状态标签，如 "联网检索中..."、"解答完成"
        var summaryAnswer: String     // 紧凑态右端简明结果，如 "选 B" 或 "x = 2"
        var pages: [String]           // 展开态分页内容数组（解决灵动岛不可滚动的痛点）
        var currentPageIndex: Int     // 当前所在页码（0-based）
        var isDone: Bool              // 是否回答结束
        var isError: Bool             // 是否报错（如需要重新登录）
    }
    
    var questionPreview: String
}
