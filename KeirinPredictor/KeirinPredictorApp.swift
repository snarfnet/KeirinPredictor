import SwiftUI
import GoogleMobileAds

@main
struct KeirinPredictorApp: App {
    @StateObject private var dataLoader = DataLoader.shared
    @StateObject private var tracker = PredictionTracker()

    init() {
        MobileAds.shared.start(completionHandler: nil)
        NotificationManager.shared.requestPermission()
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
