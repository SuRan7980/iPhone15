import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case deepseek = "deepseek"
    case kimi = "kimi"
    case qwen = "qwen"
    case doubao = "doubao"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek 网页版 (主力推荐)"
        case .kimi:     return "Kimi 智能助手 (国内直连)"
        case .qwen:     return "通义千问网页版 (国内直连)"
        case .doubao:   return "豆包网页版 (国内直连)"
        }
    }
    
    var shortName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .kimi:     return "Kimi"
        case .qwen:     return "通义千问"
        case .doubao:   return "豆包"
        }
    }
    
    var loginURL: URL {
        switch self {
        case .deepseek: return URL(string: "https://chat.deepseek.com/")!
        case .kimi:     return URL(string: "https://kimi.moonshot.cn/")!
        case .qwen:     return URL(string: "https://tongyi.aliyun.com/qianwen/")!
        case .doubao:   return URL(string: "https://www.doubao.com/chat/")!
        }
    }
    
    var badgeText: String {
        switch self {
        case .deepseek: return "主力 · 强推理+联网"
        case .kimi:     return "备用 · 长文本+联网"
        case .qwen:     return "备用 · 阿里直连"
        case .doubao:   return "备用 · 字节直连"
        }
    }
}

struct QuizHistoryItem: Identifiable, Codable {
    let id: UUID
    let date: Date
    let provider: String
    let question: String
    let summary: String
    let fullAnswer: String
}
