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
                    List {
                        // 鉄脚先生のAI予測
                        if !aiPicks.isEmpty {
                            Section {
                                AISenseiSection(picks: aiPicks, venueStats: dataLoader.venueStats, playerStats: dataLoader.playerStats)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }

                        ForEach(dayGroups, id: \.date) { group in
                            Section {
                                DaySectionView(group: group, homeVenue: homeVenue)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }

                        Section {
                            BannerAdView()
                                .frame(height: 50)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        dataLoader.fetchRemoteTodayEntries()
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
                            .font(.system(size: 17, weight: .black, design: .monospaced))
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
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
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

    /// 鉄脚先生のおすすめ: スコア差が大きい（予測しやすい）レースを最大3つピック
    private var aiPicks: [TodayRace] {
        let todayStr = todayString()
        let todayRaces = dataLoader.todayRaces.filter {
            let d = $0.dateString.isEmpty ? todayStr : $0.dateString
            return d == todayStr
        }

        // Score differential: top1 - top2 score gap = confidence
        let scored = todayRaces.compactMap { race -> (TodayRace, Double)? in
            let sorted = race.entries.sorted { $0.score > $1.score }
            guard sorted.count >= 3 else { return nil }
            let gap = sorted[0].score - sorted[2].score
            // Prefer races with clear favorites
            guard gap >= 5 else { return nil }
            return (race, gap)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.2.crossed")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.5))
            Text("レースデータなし")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Button("更新") {
                dataLoader.fetchRemoteTodayEntries()
            }
            .font(.system(size: 15, weight: .bold, design: .monospaced))
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
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(group.label == "今日" ? Color(hex: "#FFD700") : .white)

                if group.label != group.date {
                    Text(group.date.suffix(4).prefix(2) + "/" + group.date.suffix(2))
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                    Text("\(group.totalRaces)R")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
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
                                    .font(.system(size: 16, design: .monospaced))
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
                                        .font(.system(size: 17, weight: venue == homeVenue ? .bold : .regular, design: .monospaced))
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
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#FFD700"))
                } else {
                    Circle()
                        .fill(Color(hex: "#FFD700"))
                        .frame(width: 10, height: 10)
                }
                Text(venue)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isHome ? Color(hex: "#FFD700") : .white)
                if isHome {
                    Text("HOME")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#FFD700"))
                        .cornerRadius(4)
                }
                Spacer()
                Text("\(races.count)R")
                    .font(.system(size: 13, design: .monospaced))
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
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Text("R")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700").opacity(0.6))
            }
            .frame(width: 50)

            // Divider
            Rectangle()
                .fill(Color(hex: "#FFD700").opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Entries preview
            VStack(alignment: .leading, spacing: 6) {
                // Top 3 by score
                HStack(spacing: 8) {
                    ForEach(Array(topEntries.prefix(3).enumerated()), id: \.offset) { (i, entry) in
                        HStack(spacing: 4) {
                            Text("\(entry.umaban)")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(width: 22, height: 22)
                                .background(wakuColor(entry.waku))
                                .clipShape(Circle())

                            Text(entry.name)
                                .font(.system(size: 13, weight: i == 0 ? .bold : .regular))
                                .foregroundColor(i == 0 ? .white : .white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }

                // Score bar + entry count
                HStack(spacing: 8) {
                    if let top = topEntries.first {
                        Text("\(String(format: "%.0f", top.score))点")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
                    }
                    Text("\(race.entries.count)車立")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))

                    Spacer()
                }
            }
            .padding(.leading, 10)

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.4))
                .padding(.trailing, 8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }
}

// MARK: - 鉄脚先生のAI予測
struct AISenseiSection: View {
    let picks: [TodayRace]
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("鉄脚先生のAI予測")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                    Text("本日のおすすめレース")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(picks) { race in
                NavigationLink(value: race) {
                    AISenseiPickCard(race: race, venueStats: venueStats, playerStats: playerStats)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFD700").opacity(0.08), Color(hex: "#0A0E27")],
                startPoint: .top, endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
        )
    }
}

struct AISenseiPickCard: View {
    let race: TodayRace
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]

    private var sortedEntries: [TodayRaceEntry] {
        race.entries.sorted { $0.score > $1.score }
    }

    private var commentary: String {
        guard let top = sortedEntries.first else { return "" }
        let stat = playerStats[top.name]
        let bank = venueStats[race.venue]?.bank ?? 400

        var lines: [String] = []

        // Class rank
        let classRank = stat?.classRank ?? ""
        if classRank.hasPrefix("S") {
            lines.append("\(top.name)はS級の実力者")
        } else if classRank == "A1" {
            lines.append("\(top.name)はA1級で安定感あり")
        }

        // Style x Bank match
        let style = stat?.style ?? top.style
        if style == "逃" && bank <= 335 {
            lines.append("333mバンクは逃げ天国、先行有利の展開")
        } else if style == "追" && bank >= 500 {
            lines.append("500mバンクは追込み有利、後方から一気に")
        } else if style == "捲" && bank == 400 {
            lines.append("400mバンクで捲りが決まりやすい")
        } else if style == "差" && bank >= 500 {
            lines.append("500mの長い直線で差しが届く")
        }

        // Win rate
        let wr = stat?.winRate ?? top.win_rate / 100
        if wr > 0.3 {
            lines.append("勝率\(String(format: "%.0f", wr * 100))%の高勝率")
        }

        // Score gap
        if sortedEntries.count >= 2 {
            let gap = sortedEntries[0].score - sortedEntries[1].score
            if gap >= 10 {
                lines.append("2番手との実力差が大きく、堅い予想")
            } else if gap >= 5 {
                lines.append("頭一つ抜けた存在、軸に最適")
            }
        }

        // Recent form
        if let rr = stat?.recentRanks, rr.count >= 3 {
            let recent3 = Array(rr.prefix(3))
            let wins = recent3.filter { $0 == 1 }.count
            if wins >= 2 {
                lines.append("直近\(wins)連勝と絶好調")
            }
        }

        if lines.isEmpty {
            return "\(top.name)が総合力で上位、安定した成績に注目"
        }
        return lines.prefix(3).joined(separator: "。") + "。"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Race info
            HStack(spacing: 8) {
                Text("\(race.venue)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("\(race.raceNo)R")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                if let bank = venueStats[race.venue]?.bank {
                    Text("\(bank)m")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Text("\(race.entries.count)車立")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#FFD700").opacity(0.5))
            }

            // Top 3 prediction
            HStack(spacing: 10) {
                ForEach(Array(sortedEntries.prefix(3).enumerated()), id: \.offset) { (i, entry) in
                    HStack(spacing: 5) {
                        Text(i == 0 ? "◎" : i == 1 ? "○" : "▲")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(i == 0 ? Color(hex: "#FFD700") : .white.opacity(0.7))
                        Text("\(entry.umaban)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(wakuColor(entry.waku))
                            .clipShape(Circle())
                        Text(entry.name)
                            .font(.system(size: 14, weight: i == 0 ? .bold : .regular))
                            .foregroundColor(i == 0 ? .white : .white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            // Commentary
            Text(commentary)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#FFD700").opacity(0.15), lineWidth: 1)
        )
    }
}
