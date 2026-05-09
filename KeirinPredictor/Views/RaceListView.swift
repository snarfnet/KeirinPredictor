import SwiftUI

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @State private var selectedRace: RaceEntry? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                if dataLoader.todayRaces.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "flag.2.crossed")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#FFD700").opacity(0.5))
                        Text("レースデータを読み込み中...")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            todayHeader

                            ForEach(groupedByVenue, id: \.venue) { group in
                                VenueSection(venue: group.venue, races: group.races)
                            }

                            BannerAdView()
                                .frame(height: 50)
                                .padding(.horizontal)

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TODAY'S RACES")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
    }

    private var todayHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundColor(Color(hex: "#FFD700"))
            Text(dataLoader.todayDateString)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("\(dataLoader.todayRaces.count)レース")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private var groupedByVenue: [VenueGroup] {
        let dict = Dictionary(grouping: dataLoader.todayRaces, by: { $0.venue })
        return dict.map { VenueGroup(venue: $0.key, races: $0.value.sorted { $0.raceNo < $1.raceNo }) }
            .sorted { $0.venue < $1.venue }
    }
}

struct VenueGroup {
    let venue: String
    let races: [TodayRace]
}

struct VenueSection: View {
    let venue: String
    let races: [TodayRace]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color(hex: "#FFD700"))
                Text(venue)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("\(races.count)R")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            ForEach(races) { race in
                NavigationLink(destination: RaceDetailView(race: race)) {
                    RaceRowView(race: race)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

struct RaceRowView: View {
    let race: TodayRace

    var body: some View {
        HStack(spacing: 12) {
            Text("\(race.raceNo)R")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    ForEach(race.entries.prefix(5)) { entry in
                        Text(String(entry.name.prefix(2)))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    if race.entries.count > 5 {
                        Text("+\(race.entries.count - 5)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                Text("\(race.entries.count)車立")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
