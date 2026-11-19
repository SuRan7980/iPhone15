import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var solver: HeadlessWebSolver
    @State private var selectedTab: Int = 0
    @State private var enableWebSearch: Bool = SharedIslandStore.shared.enableWebSearch
    @State private var historyList: [QuizHistoryItem] = SharedIslandStore.shared.loadHistory()
    @State private var testQuestion: String = "若函数 f(x) = x^2 - 4x + 3，求其最小值及对应的 x 值。"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 网页端 AI 登录与引擎切换
            NavigationStack {
                VStack(spacing: 0) {
                    // 顶部引擎与联网控制栏
                    VStack(spacing: 10) {
                        HStack {
                            Text("当前主力引擎")
                                .font(.subheadline.bold())
                            Spacer()
                            Picker("选择 AI 引擎", selection: Binding(
                                get: { solver.currentProvider },
                                set: { solver.loadProvider($0) }
                            )) {
                                ForEach(AIProvider.allCases) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Toggle("自动激活网页端「联网搜索」", isOn: $enableWebSearch)
                                .font(.subheadline)
                                .onChange(of: enableWebSearch) { _, newVal in
                                    SharedIslandStore.shared.enableWebSearch = newVal
                                }
                        }
                        
                        HStack {
                            Circle()
                                .fill(solver.isPageReady ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(solver.lastStatusLog)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("测试灵动岛搜题") {
                                solver.solveQuestionSilently(questionText: testQuestion) { text, isDone in
                                    LiveActivityManager.shared.updateStreamingResponse(
                                        rawText: text,
                                        isDone: isDone,
                                        originalQuestion: testQuestion
                                    )
                                }
                                LiveActivityManager.shared.startOrUpdateSearch(question: testQuestion)
                            }
                            .font(.caption.bold())
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    
                    // 内嵌持久化 WebView（首次登录一次后 Cookie 永久保存）
                    PersistentWebViewRepresentable(webView: solver.webView)
                }
                .navigationTitle("灵动搜题 · 账号中心")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            solver.webView.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .tabItem {
                Label("AI 网页登录", systemImage: "globe")
            }
            .tag(0)
            
            // Tab 2: 错题与搜题历史记录
            NavigationStack {
                List {
                    if historyList.isEmpty {
                        ContentUnavailableView(
                            "暂无搜题记录",
                            systemImage: "tray",
                            description: Text("在任意刷题 App 中唤醒 Siri 或快捷指令搜题后，解析会自动保存在这里。")
                        )
                    } else {
                        ForEach(historyList) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.provider)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                    Text(item.summary)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(item.date, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("题目：\(item.question)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                Text(item.fullAnswer)
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                    .padding(.top, 2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle("历史搜题本")
                .onAppear {
                    historyList = SharedIslandStore.shared.loadHistory()
                }
            }
            .tabItem {
                Label("搜题记录", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)
            
            // Tab 3: 零跳端快捷指令配置指南
            NavigationStack {
                List {
                    Section("为什么之前快捷指令会跳转 App？") {
                        Text("iOS 自带的「询问 ChatGPT / DeepSeek」动作默认开启了前台跳转。本应用通过 AppIntents 底层声明了 openAppWhenRun = false，实现真正的 100% 后台静默传参，绝不离开当前做题画面。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Section("iPhone 快捷指令 3 步配置（仅需配置一次）") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. 打开系统自带「快捷指令」App，点击右上角 + 新建，命名为「搜题」。")
                            Text("2. 添加第 1 个动作：【拍摄屏幕快照】。")
                            Text("3. 添加第 2 个动作：【从图像中提取文本】（输入选屏幕快照）。")
                            Text("4. 添加第 3 个动作：搜索「灵动搜题」，选择【后台静默搜题】，将“题目文本”填入上一步提取的文本，并点开小箭头关闭「运行时显示」。")
                        }
                        .font(.footnote)
                    }
                    
                    Section("最佳触发技巧（无需喊 Siri 也行）") {
                        Text("除了喊「嘿 Siri，搜题」，强烈建议在 iPhone【设置 → 辅助功能 → 触控 → 轻点背面】中，将「轻点两下」绑定为「搜题」快捷指令！刷题时敲两下手机背面，灵动岛直接静默出答案。")
                            .font(.footnote)
                    }
                }
                .navigationTitle("零跳端配置指南")
            }
            .tabItem {
                Label("配置教程", systemImage: "book.closed")
            }
            .tag(2)
        }
    }
}

struct PersistentWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
