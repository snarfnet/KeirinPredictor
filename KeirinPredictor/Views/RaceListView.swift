import SwiftUI

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @AppStorage("homeVenue") private var homeVenue: String = ""
    @State private var showVenuePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                if dataLoader.todayRaces.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(dayGroups, id: \.date) { group in
                                DaySectionView(group: group, homeVenue: homeVenue)
                            }

                            BannerAdView()
                                .frame(height: 50)
                                .padding(.horizontal)

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("KEIRIN PREDICTOR")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVenuePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: homeVenue.isEmpty ? "house" : "house.fill")
                            if !homeVenue.isEmpty {
                                Text(homeVenue)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                        }
                        .foregroundColor(Color(hex: "#FFD700"))
                    }
                }
            }
            .navigationDestination(for: TodayRace.self) { race in
                RaceDetailView(race: race)
            }
            .sheet(isPresented: $showVenuePicker) {
                HomeVenuePickerView(homeVenue: $homeVenue, venues: availableVenues)
            }
        }
    }

    private var availableVenues: [String] {
        Array(dataLoader.venueStats.keys).sorted()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.2.crossed")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.5))
            Text("レースデータなし")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Button("更新") {
                dataLoader.fetchRemoteTodayEntries()
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: "#FFD700"))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var dayGroups: [DayGroup] {
        let todayStr = todayString()
        let tomorrowStr = tomorrowString()

        // Group by date
        var grouped: [String: [TodayRace]] = [:]
        for race in dataLoader.todayRaces {
            let d = race.dateString.isEmpty ? todayStr : race.dateString
            grouped[d, default: []].append(race)
        }

        return grouped.map { (date, races) in
            let label: String
            if date == todayStr { label = "今日" }
            else if date == tomorrowStr { label = "明日" }
            else { label = formatShortDate(date) }

            let hv = homeVenue
            let venueGroups = Dictionary(grouping: races, by: { $0.venue })
                .map { VenueGroup(venue: $0.key, races: $0.value.sorted { $0.raceNo < $1.raceNo }) }
                .sorted { a, b in
                    if a.venue == hv { return true }
                    if b.venue == hv { return false }
                    return a.venue < b.venue
                }

            return DayGroup(date: date, label: label, totalRaces: races.count, venues: venueGroups)
        }.sorted { $0.date < $1.date }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f.string(from: Date())
    }

    private func tomorrowString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f.string(from: Date().addingTimeInterval(86400))
    }

    private func formatShortDate(_ yyyymmdd: String) -> String {
        guard yyyymmdd.count == 8,
              let m = Int(yyyymmdd.dropFirst(4).prefix(2)),
              let d = Int(yyyymmdd.suffix(2)) else { return yyyymmdd }
        return "\(m)/\(d)"
    }
}

// MARK: - Data Structures
struct DayGroup {
    let date: String
    let label: String
    let totalRaces: Int
    let venues: [VenueGroup]
}

struct VenueGroup {
    let venue: String
    let races: [TodayRace]
}

// MARK: - Day Section
struct DaySectionView: View {
    let group: DayGroup
    var homeVenue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack(spacing: 10) {
                Text(group.label)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(group.label == "今日" ? Color(hex: "#FFD700") : .white)

                if group.label != group.date {
                    Text(group.date.suffix(4).prefix(2) + "/" + group.date.suffix(2))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                    Text("\(group.totalRaces)R")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
            }

            ForEach(group.venues, id: \.venue) { venueGroup in
                VenueSectionView(venue: venueGroup.venue, races: venueGroup.races, isHome: venueGroup.venue == homeVenue)
            }
        }
    }
}

// MARK: - Home Venue Picker
struct HomeVenuePickerView: View {
    @Binding var homeVenue: String
    let venues: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 4) {
                        // Clear option
                        Button {
                            homeVenue = ""
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("ホーム設定なし")
                                    .font(.system(size: 14, design: .monospaced))
                                Spacer()
                                if homeVenue.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "#FFD700"))
                                }
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }

                        ForEach(venues, id: \.self) { venue in
                            Button {
                                homeVenue = venue
                                dismiss()
                            } label: {
                                HStack {
                                    Text(venue)
                                        .font(.system(size: 15, weight: venue == homeVenue ? .bold : .regular, design: .monospaced))
                                        .foregroundColor(venue == homeVenue ? Color(hex: "#FFD700") : .white)
                                    Spacer()
                                    if venue == homeVenue {
                                        Image(systemName: "house.fill")
                                            .foregroundColor(Color(hex: "#FFD700"))
                                    }
                                }
                                .padding(12)
                                .background(venue == homeVenue ? Color(hex: "#FFD700").opacity(0.1) : Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("ホーム競輪場")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
    }
}

// MARK: - Venue Section
struct VenueSectionView: View {
    let venue: String
    let races: [TodayRace]
    var isHome: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Venue header
            HStack(spacing: 8) {
                if isHome {
                    Image(systemName: "house.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#FFD700"))
                } else {
                    Circle()
                        .fill(Color(hex: "#FFD700"))
                        .frame(width: 8, height: 8)
                }
                Text(venue)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isHome ? Color(hex: "#FFD700") : .white)
                if isHome {
                    Text("HOME")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#FFD700"))
                        .cornerRadius(4)
                }
                Spacer()
                Text("\(races.count)R")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(races) { race in
                NavigationLink(value: race) {
                    RaceCardView(race: race)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

// MARK: - Race Card
struct RaceCardView: View {
    let race: TodayRace

    private var topEntries: [TodayRaceEntry] {
        race.entries.sorted { $0.score > $1.score }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Race number
            VStack {
                Text("\(race.raceNo)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Text("R")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700").opacity(0.6))
            }
            .frame(width: 44)

            // Divider
            Rectangle()
                .fill(Color(hex: "#FFD700").opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Entries preview
            VStack(alignment: .leading, spacing: 4) {
                // Top 3 by score
                HStack(spacing: 8) {
                    ForEach(Array(topEntries.prefix(3).enumerated()), id: \.offset) { (i, entry) in
                        HStack(spacing: 4) {
                            Text("\(entry.umaban)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(width: 18, height: 18)
                                .background(wakuColor(entry.waku))
                                .clipShape(Circle())

                            Text(entry.name)
                                .font(.system(size: 11, weight: i == 0 ? .bold : .regular))
                                .foregroundColor(i == 0 ? .white : .white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }

                // Score bar + entry count
                HStack(spacing: 8) {
                    if let top = topEntries.first {
                        Text("\(String(format: "%.0f", top.score))点")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
                    }
                    Text("\(race.entries.count)車立")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))

                    Spacer()
                }
            }
            .padding(.leading, 10)

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.4))
                .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }
}
