import SwiftUI

@main
struct CatchApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
            .sheet(isPresented: $appState.showProPaywall) {
                ProPaywallView()
                    .environmentObject(appState)
                    .presentationDetents([.large])
            }
            .task {
                let hasEntitlement = await CatchProStore.hasActiveProEntitlement()
                appState.setProMembership(hasEntitlement)
            }
        }
    }
}
