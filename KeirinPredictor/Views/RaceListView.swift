import SwiftUI

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @AppStorage("homeVenue") private var homeVenue: String = ""
    @State private var showVenuePicker = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinStageBackground()

                if dataLoader.todayRaces.isEmpty {
                    emptyState
                } else {
                    CompactAwareScroll {
                        VStack(alignment: .leading, spacing: 18) {
                            heroHeader

                            if !aiPicks.isEmpty {
                                AISenseiSection(
                                    picks: aiPicks,
                                    venueStats: dataLoader.venueStats,
                                    playerStats: dataLoader.playerStats
                                )
                                .scaleEffect(appeared ? 1 : 0.96)
                                .opacity(appeared ? 1 : 0)
                            }

                            ForEach(Array(dayGroups.enumerated()), id: \.element.date) { index, group in
                                DaySectionView(group: group, homeVenue: homeVenue)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 18)
                                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(Double(index) * 0.05), value: appeared)
                            }

                            BannerAdView()
                                .frame(height: 50)
                                .padding(.top, 4)

                        }
                    }
                    .refreshable {
                        dataLoader.fetchRemoteTodayEntries()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .foregroundColor(KeirinUI.red)
                        Text("KEIRIN PREDICTOR")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVenuePicker = true
                    } label: {
                        Image(systemName: homeVenue.isEmpty ? "mappin.circle" : "house.and.flag.fill")
                            .foregroundColor(homeVenue.isEmpty ? KeirinUI.cyan : KeirinUI.gold)
                    }
                }
            }
            .navigationDestination(for: String.self) { raceId in
                if let race = dataLoader.todayRaces.first(where: { $0.race_id == raceId }) {
                    RaceDetailView(race: race)
                }
            }
            .sheet(isPresented: $showVenuePicker) {
                HomeVenuePickerView(homeVenue: $homeVenue, venues: availableVenues)
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
        }
    }

    private var heroHeader: some View {
        GlassPanel(cornerRadius: 22, borderColor: KeirinUI.cyan.opacity(0.28)) {
            VStack(alignment: .leading, spacing: 14) {
                AdaptiveStack(horizontalSpacing: 10, verticalSpacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TODAY'S RACES")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.cyan)
                        Text("本日のレース一覧")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text(dataLoader.todayDateString.isEmpty ? "データ日を確認中" : "データ日 \(dataLoader.todayDateString)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(KeirinUI.gold.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(dataLoader.todayRaces.count)")
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.gold)
                        Text("RACES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                MetricPillRow {
                    MetricPill(title: "DATE", value: compactDateLabel, color: KeirinUI.green)
                    MetricPill(title: "VENUE", value: "\(availableVenues.count)", color: KeirinUI.cyan)
                    MetricPill(title: "HOME", value: homeVenue.isEmpty ? "未設定" : homeVenue, color: KeirinUI.gold)
                    MetricPill(title: "注目指数", value: "\(aiPicks.count)", color: KeirinUI.red)
                    MetricPill(title: "BUILD", value: appBuildNumber, color: KeirinUI.cyan)
                }
            }
        }
    }

    private var availableVenues: [String] {
        Array(dataLoader.venueStats.keys).sorted()
    }

    private var compactDateLabel: String {
        let raw = dataLoader.todayRaces.first?.dateString ?? todayString()
        return formatShortDate(raw)
    }

    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private var aiPicks: [TodayRace] {
        let todayStr = todayString()
        let todayRaces = dataLoader.todayRaces.filter {
            let d = $0.dateString.isEmpty ? todayStr : $0.dateString
            return d == todayStr
        }

        let scored = todayRaces.compactMap { race -> (TodayRace, Double)? in
            let sorted = race.entries.sorted { $0.score > $1.score }
            guard sorted.count >= 3 else { return nil }
            let gap = sorted[0].score - sorted[2].score
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
            Image("EmptyState")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .opacity(0.72)
            Text("レースデータがありません")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
            Button("更新") {
                dataLoader.fetchRemoteTodayEntries()
            }
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(KeirinUI.actionGradient)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var dayGroups: [DayGroup] {
        let todayStr = todayString()
        let tomorrowStr = tomorrowString()

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
            let dateLabel = formatFullDate(date)

            let hv = homeVenue
            let venueGroups = Dictionary(grouping: races, by: { $0.venue })
                .map { VenueGroup(venue: $0.key, races: $0.value.sorted { $0.raceNo < $1.raceNo }) }
                .sorted { a, b in
                    if a.venue == hv { return true }
                    if b.venue == hv { return false }
                    return a.venue < b.venue
                }

            return DayGroup(date: date, label: label, dateLabel: dateLabel, totalRaces: races.count, venues: venueGroups)
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

    private func formatFullDate(_ yyyymmdd: String) -> String {
        guard yyyymmdd.count == 8,
              let y = Int(yyyymmdd.prefix(4)),
              let m = Int(yyyymmdd.dropFirst(4).prefix(2)),
              let d = Int(yyyymmdd.suffix(2)) else { return yyyymmdd }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        components.year = y
        components.month = m
        components.day = d

        guard let date = components.date else {
            return "\(y)年\(m)月\(d)日"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日（E）"
        return formatter.string(from: date)
    }
}

struct DayGroup {
    let date: String
    let label: String
    let dateLabel: String
    let totalRaces: Int
    let venues: [VenueGroup]
}

struct VenueGroup {
    let venue: String
    let races: [TodayRace]
}

struct DaySectionView: View {
    let group: DayGroup
    var homeVenue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label)
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundColor(group.label == "今日" ? KeirinUI.gold : .white)
                    Text(group.dateLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text("\(group.totalRaces)R")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(group.label == "今日" ? KeirinUI.gold : KeirinUI.cyan)
                    .clipShape(Capsule())

                Spacer()
            }

            ForEach(group.venues, id: \.venue) { venueGroup in
                VenueSectionView(
                    venue: venueGroup.venue,
                    races: venueGroup.races,
                    isHome: venueGroup.venue == homeVenue
                )
            }
        }
    }
}

struct HomeVenuePickerView: View {
    @Binding var homeVenue: String
    let venues: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinStageBackground()

                ScrollView {
                    VStack(spacing: 8) {
                        Button {
                            homeVenue = ""
                            dismiss()
                        } label: {
                            pickerRow(title: "ホームを解除", icon: "xmark.circle", selected: homeVenue.isEmpty)
                        }

                        ForEach(venues, id: \.self) { venue in
                            Button {
                                homeVenue = venue
                                dismiss()
                            } label: {
                                pickerRow(title: venue, icon: "mappin.circle.fill", selected: venue == homeVenue)
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
                        .foregroundColor(KeirinUI.cyan)
                }
            }
        }
    }

    private func pickerRow(title: String, icon: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(selected ? KeirinUI.gold : KeirinUI.cyan)
            Text(title)
                .font(.system(size: 16, weight: selected ? .black : .semibold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            if selected {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(KeirinUI.gold)
            }
        }
        .padding(13)
        .background(selected ? KeirinUI.gold.opacity(0.16) : Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct VenueSectionView: View {
    let venue: String
    let races: [TodayRace]
    var isHome: Bool = false

    var body: some View {
        GlassPanel(cornerRadius: 18, borderColor: isHome ? KeirinUI.gold.opacity(0.42) : Color.white.opacity(0.10)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: isHome ? "house.and.flag.fill" : "scope")
                        .foregroundColor(isHome ? KeirinUI.gold : KeirinUI.cyan)
                    Text(venue)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isHome {
                        Text("HOME")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(KeirinUI.gold)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text("\(races.count)R")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.58))
                }

                VStack(spacing: 10) {
                    ForEach(races) { race in
                        NavigationLink(value: race.race_id) {
                            RaceCardView(race: race)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct RaceCardView: View {
    let race: TodayRace

    private var topEntries: [TodayRaceEntry] {
        race.entries.sorted { $0.score > $1.score }
    }

    private var scoreGap: Double {
        guard topEntries.count >= 2 else { return 0 }
        return topEntries[0].score - topEntries[1].score
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(KeirinUI.actionGradient)
                    .frame(width: 56, height: 64)
                    .shadow(color: KeirinUI.red.opacity(0.30), radius: 12, x: 0, y: 7)
                VStack(spacing: -2) {
                    Text("\(race.raceNo)")
                        .font(.system(size: 27, weight: .black, design: .monospaced))
                    Text("RACE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 7) {
                    if let top = topEntries.first {
                        LaneBadge(number: top.umaban, size: 29)
                        VStack(alignment: .leading, spacing: 1) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(race.venue)
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(KeirinUI.cyan)
                                    .lineLimit(1)
                                Text(top.name)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Text("本命指数 \(String(format: "%.0f", top.score))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(KeirinUI.gold)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(KeirinUI.cyan.opacity(0.72))
                }

                HStack(spacing: 6) {
                    ForEach(Array(topEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 4) {
                            LaneBadge(number: entry.umaban, size: 22)
                            Text(index == 0 ? "軸" : "\(index + 1)")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(index == 0 ? KeirinUI.gold : .white.opacity(0.5))
                        }
                    }
                    Spacer()
                    Text(scoreGap >= 8 ? "注目" : "混戦")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(scoreGap >= 8 ? .black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreGap >= 8 ? KeirinUI.gold : KeirinUI.cyan.opacity(0.24))
                        .clipShape(Capsule())
                }

                ProbabilityBar(value: min(max(scoreGap / 20, 0.08), 1), color: scoreGap >= 8 ? KeirinUI.red : KeirinUI.cyan)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct AISenseiSection: View {
    let picks: [TodayRace]
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]

    var body: some View {
        GlassPanel(cornerRadius: 24, borderColor: KeirinUI.red.opacity(0.34)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image("HakaseAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(KeirinUI.gold.opacity(0.68), lineWidth: 2)
                        )
                        .shadow(color: KeirinUI.gold.opacity(0.26), radius: 14, x: 0, y: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("鉄脚博士の注目指数")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("今日の狙い目")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    Spacer()
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(KeirinUI.gold)
                        .shadow(color: KeirinUI.gold.opacity(0.5), radius: 12)
                }

                ForEach(picks) { race in
                    NavigationLink(value: race.race_id) {
                        AISenseiPickCard(race: race, venueStats: venueStats, playerStats: playerStats)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct AISenseiPickCard: View {
    let race: TodayRace
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]

    private var sortedEntries: [TodayRaceEntry] {
        race.entries.sorted { $0.score > $1.score }
    }

    private var topScoreGap: Double {
        guard sortedEntries.count >= 3 else { return 0 }
        return sortedEntries[0].score - sortedEntries[2].score
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text(race.venue)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(race.raceNo)R")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(KeirinUI.gold)
                if let bank = venueStats[race.venue]?.bank {
                    Text("\(bank)m")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(KeirinUI.cyan)
                }
                Spacer()
                Text("信頼 \(String(format: "%.0f", min(topScoreGap * 7, 99)))")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(KeirinUI.gold)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                ForEach(Array(sortedEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                    VStack(spacing: 5) {
                        LaneBadge(number: entry.umaban, size: index == 0 ? 34 : 28)
                        Text(entry.name)
                            .font(.system(size: 11, weight: index == 0 ? .black : .semibold, design: .rounded))
                            .foregroundColor(index == 0 ? .white : .white.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            ProbabilityBar(value: min(topScoreGap / 18, 1), color: KeirinUI.red)
        }
        .padding(13)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KeirinUI.red.opacity(0.22), lineWidth: 1)
        )
    }
}
