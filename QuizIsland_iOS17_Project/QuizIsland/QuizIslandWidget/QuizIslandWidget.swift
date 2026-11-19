import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct QuizIslandWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuizIslandLiveActivity()
    }
}

struct QuizIslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuizIslandAttributes.self) { context in
            // 锁屏 / 通知中心横向卡片视图
            ExpandedCardView(state: context.state)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态（长按灵动岛下拉卡片）
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isDone ? "checkmark.seal.fill" : "sparkles")
                            .foregroundColor(context.state.isError ? .orange : .cyan)
                            .font(.subheadline)
                        Text(context.state.providerName)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.statusText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 6) {
                        // 高亮主结论栏
                        HStack {
                            Text("结论")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.25))
                                .foregroundColor(.cyan)
                                .cornerRadius(4)
                            
                            Text(context.state.summaryAnswer)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                        
                        // 分页解析正文（清晰易读，无需滚动条）
                        let safeIndex = min(max(context.state.currentPageIndex, 0), max(context.state.pages.count - 1, 0))
                        let pageContent = context.state.pages.isEmpty ? "" : context.state.pages[safeIndex]
                        
                        Text(pageContent)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // 交互翻页与关闭栏（iOS 17 原生支持，点击不跳转 App）
                    HStack(spacing: 12) {
                        if context.state.pages.count > 1 {
                            Button(intent: IslandPaginationIntent(action: "prev")) {
                                Label("上一页", systemImage: "chevron.left")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(context.state.currentPageIndex + 1) / \(context.state.pages.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.white.opacity(0.7))
                            
                            Button(intent: IslandPaginationIntent(action: "next")) {
                                Label("下一页", systemImage: "chevron.right")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("长按可随时查看解析")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button(intent: IslandPaginationIntent(action: "close")) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // 紧凑态左侧
                HStack(spacing: 4) {
                    Image(systemName: context.state.isDone ? "checkmark.circle.fill" : "sparkle.magnifyingglass")
                        .foregroundColor(context.state.isDone ? .green : .cyan)
                        .font(.caption)
                }
            } compactTrailing: {
                // 紧凑态右侧：直接显示核心答案
                Text(context.state.summaryAnswer)
                    .font(.caption2.bold())
                    .foregroundColor(context.state.isDone ? .cyan : .white)
                    .lineLimit(1)
                    .frame(maxWidth: 72)
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundColor(.cyan)
            }
        }
    }
}

struct ExpandedCardView: View {
    let state: QuizIslandAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(state.providerName) · \(state.statusText)")
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                Spacer()
                Text(state.summaryAnswer)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            let safeIndex = min(max(state.currentPageIndex, 0), max(state.pages.count - 1, 0))
            if !state.pages.isEmpty {
                Text(state.pages[safeIndex])
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}
