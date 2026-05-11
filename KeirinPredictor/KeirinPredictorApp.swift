import SwiftUI
import GoogleMobileAds

@main
struct KeirinPredictorApp: App {
    @StateObject private var dataLoader = DataLoader.shared
    @StateObject private var tracker = PredictionTracker()

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            if dataLoader.isLoaded {
                ContentView()
                    .environmentObject(dataLoader)
                    .environmentObject(tracker)
            } else {
                LoadingView()
                    .environmentObject(dataLoader)
            }
        }
    }
}
