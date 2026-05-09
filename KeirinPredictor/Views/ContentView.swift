import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataLoader: DataLoader

    var body: some View {
        TabView {
            RaceListView()
                .tabItem {
                    Label("予測", systemImage: "flag.checkered")
                }

            ResultsListView()
                .tabItem {
                    Label("結果", systemImage: "trophy.fill")
                }

            PlayerDatabaseView()
                .tabItem {
                    Label("選手", systemImage: "person.3.fill")
                }

            VenueInfoView()
                .tabItem {
                    Label("競輪場", systemImage: "mappin.circle.fill")
                }

            PredictionView()
                .tabItem {
                    Label("RPG", systemImage: "bolt.fill")
                }
        }
        .accentColor(Color(hex: "#FFD700"))
        .preferredColorScheme(.dark)
    }
}
