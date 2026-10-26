import SwiftUI

@main
struct JikuangApp: App {
    @StateObject private var metrics = SystemMetrics()
    @StateObject private var charge = ChargeEstimator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(metrics)
                .environmentObject(charge)
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
    }
}
