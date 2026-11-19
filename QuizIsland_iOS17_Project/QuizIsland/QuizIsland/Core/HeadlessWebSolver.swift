import Foundation
import WebKit
import UIKit

@MainActor
final class HeadlessWebSolver: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let shared = HeadlessWebSolver()
    
    // 持久化复用一个隐藏在后台的 WKWebView 实例，共享 Cookie 存储
    private(set) var webView: WKWebView!
    @Published var currentProvider: AIProvider = SharedIslandStore.shared.selectedProvider
    @Published var isPageReady: Bool = false
    @Published var lastStatusLog: String = "就绪"
    
    private var onStreamUpdate: ((String, Bool) -> Void)?
    private var latestAccumulatedText: String = ""
    private var completionDebounceTimer: Timer?
    private var timeoutTimer: Timer?
    private var pendingPrompt: String?
    
    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "quizStreamHandler")
        contentController.add(self, name: "quizStatusHandler")
        config.userContentController = contentController
        
        // 使用移动端 Safari UA，适配国内各家网页版 AI
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        self.webView.navigationDelegate = self
        
        loadProvider(currentProvider)
    }
    
    func loadProvider(_ provider: AIProvider) {
        currentProvider = provider
        SharedIslandStore.shared.selectedProvider = provider
        isPageReady = false
        lastStatusLog = "正在加载 \(provider.shortName)..."
        webView.load(URLRequest(url: provider.loginURL))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isPageReady = true
        lastStatusLog = "\(currentProvider.shortName) 页面已加载"
        if let prompt = pendingPrompt {
            pendingPrompt = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.injectAndSend(prompt: prompt)
            }
        }
    }
    
    /// 后台静默提问入口（由 AppIntent 调用，绝不切前台）
    func solveQuestionSilently(questionText: String, onUpdate: @escaping (String, Bool) -> Void) {
        self.onStreamUpdate = onUpdate
        self.latestAccumulatedText = ""
        self.timeoutTimer?.invalidate()
        self.completionDebounceTimer?.invalidate()
        
        let enableSearch = SharedIslandStore.shared.enableWebSearch
        let formattedPrompt = """
        请作为专业学科辅导老师解答以下题目。
        要求：
        1. 第一行必须严格按照格式输出：【结论】简短答案（例如：【结论】选 B 或 【结论】x = 2）。
        2. 换行后给出清晰、精炼的分步解析（控制在300字以内，避免冗长废话）。
        
        题目内容：
        \(questionText)
        """
        
        // 超时兜底（45秒）
        self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let fallback = self.latestAccumulatedText.isEmpty
                    ? "【结论】请求超时\n请打开「灵动搜题」App 检查 \(self.currentProvider.shortName) 是否需要重新登录或过人机验证。"
                    : self.latestAccumulatedText
                self.finishCurrentTask(finalText: fallback)
            }
        }
        
        if isPageReady && webView.url != nil {
            injectAndSend(prompt: formattedPrompt, enableSearch: enableSearch)
        } else {
            pendingPrompt = formattedPrompt
            loadProvider(currentProvider)
        }
    }
    
    private func injectAndSend(prompt: String, enableSearch: Bool = SharedIslandStore.shared.enableWebSearch) {
        guard let jsonData = try? JSONEncoder().encode(prompt),
              let escapedPrompt = String(data: jsonData, encoding: .utf8) else { return }
        
        // 通用多站点 React/Vue 原型链注入脚本 + 联网搜索自动勾选 + 流式回复监听
        let jsCode = """
        (function() {
            const promptText = \(escapedPrompt);
            const wantWebSearch = \(enableSearch ? "true" : "false");
            
            function postStatus(msg) {
                if (window.webkit && window.webkit.messageHandlers.quizStatusHandler) {
                    window.webkit.messageHandlers.quizStatusHandler.postMessage(msg);
                }
            }
            
            // 1. 尝试开启“联网搜索”开关（兼容 DeepSeek / Kimi / 通义 / 豆包）
            if (wantWebSearch) {
                const candidates = Array.from(document.querySelectorAll('button, div[role="button"], span'));
                for (const el of candidates) {
                    const txt = (el.innerText || el.textContent || '').trim();
                    if (txt === '联网搜索' || txt === '深度思考' && false || txt.includes('联网')) {
                        const cls = (el.className || '').toString();
                        const aria = el.getAttribute('aria-checked') || el.getAttribute('aria-pressed') || '';
                        const isSelected = cls.includes('active') || cls.includes('selected') || cls.includes('checked') || aria === 'true';
                        if (!isSelected && el.offsetParent !== null) {
                            el.click();
                            postStatus('已自动激活联网搜索');
                        }
                        break;
                    }
                }
            }
            
            // 2. 定位输入框（兼容 textarea 和 contenteditable div）
            const textarea = document.querySelector('textarea');
            const editable = document.querySelector('[contenteditable="true"]');
            
            if (textarea) {
                textarea.focus();
                // 绕过 React 受控组件拦截，直接调用原生原型链 setter
                const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
                nativeSetter.call(textarea, promptText);
                textarea.dispatchEvent(new Event('input', { bubbles: true }));
                textarea.dispatchEvent(new Event('change', { bubbles: true }));
            } else if (editable) {
                editable.focus();
                editable.innerText = promptText;
                editable.dispatchEvent(new InputEvent('input', { bubbles: true, data: promptText }));
            } else {
                postStatus('ERROR_NO_INPUT');
                return;
            }
            
            // 3. 记录发送前的页面文本快照，随后点击发送
            const baselineLength = document.body.innerText.length;
            
            setTimeout(() => {
                // 查找发送按钮或模拟 Enter 键
                const sendBtns = Array.from(document.querySelectorAll('button, div[role="button"]')).filter(b => {
                    if (b.disabled || b.offsetParent === null) return false;
                    const aria = (b.getAttribute('aria-label') || '').toLowerCase();
                    const txt = (b.innerText || '').trim();
                    return aria.includes('send') || aria.includes('发送') || txt === '发送';
                });
                
                if (sendBtns.length > 0) {
                    sendBtns[sendBtns.length - 1].click();
                } else if (textarea) {
                    // 回退方案：寻找输入框旁边的最后一个可点击图标按钮，或触发 Enter
                    const container = textarea.closest('form') || textarea.parentElement?.parentElement;
                    const iconBtns = container ? Array.from(container.querySelectorAll('button, div[role="button"]')).filter(b => b.offsetParent !== null) : [];
                    if (iconBtns.length > 0) {
                        iconBtns[iconBtns.length - 1].click();
                    }
                    textarea.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
                }
                
                postStatus('已发送提问，等待流式响应');
                startObservingResponse(baselineLength);
            }, 350);
            
            // 4. 监听最新一条 AI 回复气泡的 DOM 变化
            function startObservingResponse(baseLen) {
                if (window.__quizObserver) {
                    window.__quizObserver.disconnect();
                }
                
                let lastSent = '';
                const extractLatestReply = () => {
                    // 优先抓取通用 markdown 回复块（DeepSeek / Kimi / Qwen / Doubao 均使用 markdown 容器）
                    const mdBlocks = document.querySelectorAll('.ds-markdown, [class*="markdown"], [class*="message-content"], [class*="prose"]');
                    if (mdBlocks.length > 0) {
                        const lastBlock = mdBlocks[mdBlocks.length - 1];
                        return (lastBlock.innerText || '').trim();
                    }
                    return '';
                };
                
                window.__quizObserver = new MutationObserver(() => {
                    const reply = extractLatestReply();
                    if (reply && reply !== lastSent && !reply.includes('请作为专业学科辅导老师解答以下题目')) {
                        lastSent = reply;
                        window.webkit.messageHandlers.quizStreamHandler.postMessage({
                            text: reply,
                            isComplete: false
                        });
                    }
                });
                
                window.__quizObserver.observe(document.body, {
                    childList: true,
                    subtree: true,
                    characterData: true
                });
            }
        })();
        """
        
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "quizStatusHandler", let status = message.body as? String {
            self.lastStatusLog = status
            if status == "ERROR_NO_INPUT" {
                let errMsg = "【结论】未检测到输入框\n请先打开「灵动搜题」App 登录 \(currentProvider.shortName) 账号后再使用 Siri 搜题。"
                finishCurrentTask(finalText: errMsg)
            }
        } else if message.name == "quizStreamHandler", let dict = message.body as? [String: Any], let text = dict["text"] as? String {
            self.latestAccumulatedText = text
            self.onStreamUpdate?(text, false)
            
            // 流式防抖：如果连续 2.2 秒没有新字吐出，判定 AI 已回答完毕
            self.completionDebounceTimer?.invalidate()
            self.completionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.finishCurrentTask(finalText: self.latestAccumulatedText)
                }
            }
        }
    }
    
    private func finishCurrentTask(finalText: String) {
        timeoutTimer?.invalidate()
        completionDebounceTimer?.invalidate()
        onStreamUpdate?(finalText, true)
        onStreamUpdate = nil
        
        // 触发轻柔震动反馈，提示用户灵动岛已出结果
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
