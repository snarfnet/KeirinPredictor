import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataLoader: DataLoader

    var body: some View {
        TabView {
            PredictionView()
                .tabItem {
                    Label("予測", systemImage: "bolt.fill")
                }

            PlayerDatabaseView()
                .tabItem {
                    Label("選手", systemImage: "person.3.fill")
                }

            VenueInfoView()
                .tabItem {
                    Label("競輪場", systemImage: "mappin.circle.fill")
                }
        }
        .accentColor(Color(hex: "#FFD700"))
        .preferredColorScheme(.dark)
    }
}
