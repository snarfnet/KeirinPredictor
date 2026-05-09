import SwiftUI

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @State private var showAllRaces = false

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
                            filterToggle

                            ForEach(groupedByVenue, id: \.venue) { group in
                                VenueSection(venue: group.venue, races: group.races)
                            }

                            if upcomingRaces.isEmpty && !showAllRaces {
                                VStack(spacing: 12) {
                                    Text("本日のレースは全て終了しました")
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Button("全レースを表示") {
                                        showAllRaces = true
                                    }
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#FFD700"))
                                }
                                .padding(20)
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
            .navigationDestination(for: TodayRace.self) { race in
                RaceDetailView(race: race)
            }
        }
    }

    // Estimate which races are upcoming based on race number and current hour
    private var upcomingRaces: [TodayRace] {
        let hour = Calendar.current.component(.hour, from: Date())
        // Rough mapping: 12 races per venue, starting ~10:30, ending ~16:30
        // Each race ~30 min apart. Race 1 = 10:30, Race 7 = 13:30, Race 12 = 16:00
        let estimatedCurrentRace: Int
        if hour < 11 { estimatedCurrentRace = 0 }
        else if hour < 12 { estimatedCurrentRace = 3 }
        else if hour < 13 { estimatedCurrentRace = 5 }
        else if hour < 14 { estimatedCurrentRace = 7 }
        else if hour < 15 { estimatedCurrentRace = 9 }
        else if hour < 16 { estimatedCurrentRace = 10 }
        else if hour < 17 { estimatedCurrentRace = 11 }
        else { estimatedCurrentRace = 99 }

        return dataLoader.todayRaces.filter { $0.raceNo > estimatedCurrentRace }
    }

    private var displayRaces: [TodayRace] {
        showAllRaces ? dataLoader.todayRaces : upcomingRaces
    }

    private var todayHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundColor(Color(hex: "#FFD700"))
            Text(dataLoader.todayDateString)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("\(displayRaces.count)/\(dataLoader.todayRaces.count)レース")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private var filterToggle: some View {
        HStack {
            Button {
                showAllRaces.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showAllRaces ? "clock" : "clock.badge.checkmark")
                    Text(showAllRaces ? "全レース表示中" : "これからのレース")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundColor(showAllRaces ? .white.opacity(0.5) : Color(hex: "#FFD700"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(showAllRaces ? 0.05 : 0.1))
                .cornerRadius(8)
            }
            Spacer()
        }
    }

    private var groupedByVenue: [VenueGroup] {
        let races = displayRaces
        let dict = Dictionary(grouping: races, by: { $0.venue })
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
                NavigationLink(value: race) {
                    RaceRowView(race: race)
                }
                .buttonStyle(.plain)
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
