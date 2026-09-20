import SwiftUI

@main
struct CatchApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var proStore = CatchProStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    CatchTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(appState)
            .environmentObject(proStore)
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
            .sheet(isPresented: $appState.showProPaywall) {
                ProPaywallView()
                    .environmentObject(appState)
                    .environmentObject(proStore)
                    .presentationDetents([.large])
            }
            .task {
                await proStore.prepare()
                appState.setProMembership(proStore.hasActiveEntitlement)
            }
            .task(id: scenePhase) {
                if scenePhase == .active {
                    appState.cancelPendingLiveBoardLeaveAlert()
                    while !Task.isCancelled {
                        await appState.refreshActiveLiveBoardIfNeeded()
                        let secondsToNextMinute = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
                        do { try await Task.sleep(for: .seconds(secondsToNextMinute)) }
                        catch { return }
                    }
                } else if scenePhase == .background {
                    await appState.schedulePendingLiveBoardLeaveAlertIfNeeded()
                }
            }
            .onChange(of: proStore.hasActiveEntitlement) { _, isActive in
                appState.setProMembership(isActive)
            }
        }
    }
}
