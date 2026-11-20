import Foundation

enum AnswerPaginator {
    /// 将常见 LaTeX 符号转换为灵动岛原生可读的 Unicode 数学字符
    static func cleanMathSymbols(_ raw: String) -> String {
        var text = raw
        let replacements: [(String, String)] = [
            ("\\times", "×"),
            ("\\div", "÷"),
            ("\\pm", "±"),
            ("\\neq", "≠"),
            ("\\leq", "≤"),
            ("\\geq", "≥"),
            ("\\approx", "≈"),
            ("\\infty", "∞"),
            ("\\sqrt", "√"),
            ("\\pi", "π"),
            ("\\alpha", "α"),
            ("\\beta", "β"),
            ("\\theta", "θ"),
            ("\\Delta", "Δ"),
            ("\\rightarrow", "→"),
            ("\\Rightarrow", "⇒"),
            ("\\because", "∵"),
            ("\\therefore", "∴"),
            ("**", ""),
            ("### ", ""),
            ("## ", ""),
            ("$$", ""),
            ("$", "")
        ]
        for (pattern, target) in replacements {
            text = text.replacingOccurrences(of: pattern, with: target)
        }
        // 上标数字简化
        text = text.replacingOccurrences(of: "^2", with: "²")
        text = text.replacingOccurrences(of: "^3", with: "³")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 从回答中提取极简结论（用于灵动岛紧凑态右侧胶囊展示）
    static func extractSummary(_ text: String) -> String {
        let cleaned = cleanMathSymbols(text)
        let lines = cleaned.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // 优先查找包含【结论】或“答案”的行
        for line in lines {
            if line.contains("【结论】") || line.contains("结论：") || line.contains("答案：") || line.contains("答案选") {
                let compact = line
                    .replacingOccurrences(of: "【结论】", with: "")
                    .replacingOccurrences(of: "结论：", with: "")
                    .replacingOccurrences(of: "答案：", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !compact.isEmpty {
                    return String(compact.prefix(12))
                }
            }
        }
        
        if let first = lines.first {
            return String(first.prefix(10))
        }
        return "解析中..."
    }
    
    /// 将长解析切分为适合灵动岛展开态展示的若干页（每页约 170 字，杜绝截断且无需滚动）
    static func paginate(_ rawText: String, pageSize: Int = 175) -> [String] {
        let cleaned = cleanMathSymbols(rawText)
        guard !cleaned.isEmpty else { return ["正在等待模型输出..."] }
        
        var pages: [String] = []
        var currentPage = ""
        let paragraphs = cleaned.components(separatedBy: .newlines)
        
        for para in paragraphs {
            let trimmed = para.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if currentPage.count + trimmed.count + 1 <= pageSize {
                currentPage += (currentPage.isEmpty ? "" : "\n") + trimmed
            } else {
                if !currentPage.isEmpty {
                    pages.append(currentPage)
                    currentPage = ""
                }
                // 如果单段超过 pageSize，按字符切分
                var remaining = trimmed
                while remaining.count > pageSize {
                    let idx = remaining.index(remaining.startIndex, offsetBy: pageSize)
                    pages.append(String(remaining[..<idx]))
                    remaining = String(remaining[idx...])
                }
                currentPage = remaining
            }
        }
        
        if !currentPage.isEmpty {
            pages.append(currentPage)
        }
        
        return pages.isEmpty ? ["暂无内容"] : pages
    }
}
