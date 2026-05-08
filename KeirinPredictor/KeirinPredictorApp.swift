import SwiftUI
import GoogleMobileAds

@main
struct KeirinPredictorApp: App {
    @StateObject private var dataLoader = DataLoader.shared

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            if dataLoader.isLoaded {
                ContentView()
                    .environmentObject(dataLoader)
            } else {
                LoadingView()
                    .environmentObject(dataLoader)
            }
        }
    }
}
