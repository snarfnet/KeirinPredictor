import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @EnvironmentObject var tracker: PredictionTracker

    var body: some View {
        TabView {
            RaceListView()
                .tabItem {
                    Label("予測", systemImage: "bolt.horizontal.fill")
                }

            ResultsListView()
                .tabItem {
                    Label("結果", systemImage: "trophy.fill")
                }

            TrackingView()
                .tabItem {
                    Label("成績", systemImage: "chart.bar.fill")
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
        .accentColor(KeirinUI.gold)
        .preferredColorScheme(.dark)
        .onAppear {
            tracker.syncResults(dataLoader.todayResults)
        }
        .onReceive(dataLoader.$todayResults) { results in
            tracker.syncResults(results)
        }
    }
}
