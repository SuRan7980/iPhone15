import SwiftUI

@main
struct QuizIslandApp: App {
    @StateObject private var solver = HeadlessWebSolver.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(solver)
        }
    }
}
