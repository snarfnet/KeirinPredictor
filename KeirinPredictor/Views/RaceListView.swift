import SwiftUI

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @AppStorage("homeVenue") private var homeVenue: String = ""
    @State private var showVenuePicker = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F7F6F1").ignoresSafeArea()

                if dataLoader.todayRaces.isEmpty {
                    emptyState
                } else {
                    CompactAwareScroll {
                        VStack(alignment: .leading, spacing: 14) {
                            heroHeader

                            if !aiPicks.isEmpty {
                                FocusRaceStrip(
                                    picks: aiPicks,
                                    venueStats: dataLoader.venueStats,
                                    playerStats: dataLoader.playerStats
                                )
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                            }

                            ForEach(dayGroups, id: \.date) { group in
                                DaySectionView(group: group, homeVenue: homeVenue)
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
                        Text("競輪鉄脚ラボ")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#151515"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVenuePicker = true
                    } label: {
                        Image(systemName: homeVenue.isEmpty ? "mappin.circle" : "house.and.flag.fill")
                            .foregroundColor(homeVenue.isEmpty ? Color(hex: "#1E5BFF") : Color(hex: "#B68000"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationDestination(for: String.self) { raceId in
                if let race = dataLoader.todayRaces.first(where: { $0.race_id == raceId }) {
                    RaceDetailView(race: race)
                }
            }
            .sheet(isPresented: $showVenuePicker) {
                HomeVenuePickerView(homeVenue: $homeVenue, venues: availableVenues)
            }
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Image("HeroVisual")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 238, maxHeight: 260)
                .clipped()

            LinearGradient(
                colors: [.white.opacity(0.0), .white.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Text("BUILD \(appBuildNumber)")
                    Text(compactDateLabel)
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.72))
                .clipShape(Capsule())

                Text("競輪鉄脚ラボ")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#111111"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(dataLoader.todayDateString.isEmpty ? "本日のデータを確認中" : "データ日 \(dataLoader.todayDateString)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#5D5344"))
                    .lineLimit(1)

                MetricPillRow {
                    LightMetricPill(title: "開催場", value: "\(availableVenues.count)", tone: Color(hex: "#1E5BFF"))
                    LightMetricPill(title: "レース", value: "\(dataLoader.todayRaces.count)", tone: Color(hex: "#C79314"))
                    LightMetricPill(title: "勝負候補", value: "\(aiPicks.count)", tone: KeirinUI.red)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 238, maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)
    }

    private var availableVenues: [String] {
        Array(Set(dataLoader.todayRaces.map(\.venue))).sorted()
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
            Image("HeroVisual")
                .resizable()
                .scaledToFill()
                .frame(width: 260, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(0.92)

            Text("本日の出走表がありません")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#151515"))

            Text(dataLoader.todayDataWarning ?? "前日データは表示せず、今日以降のデータだけ表示します。")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#6E665A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                dataLoader.fetchRemoteTodayEntries()
            } label: {
                Label("更新", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#111111"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F7F6F1").ignoresSafeArea())
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

            let hv = homeVenue
            let venueGroups = Dictionary(grouping: races, by: { $0.venue })
                .map { VenueGroup(venue: $0.key, races: $0.value.sorted { $0.raceNo < $1.raceNo }) }
                .sorted { a, b in
                    if a.venue == hv { return true }
                    if b.venue == hv { return false }
                    return a.venue < b.venue
                }

            return DayGroup(
                date: date,
                label: label,
                dateLabel: formatFullDate(date),
                totalRaces: races.count,
                venues: venueGroups
            )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#151515"))
                    Text(group.dateLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#81786D"))
                }

                Spacer()

                Text("\(group.totalRaces)R")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#111111"))
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
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
}

struct LightMetricPill: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#766D61"))
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct HomeVenuePickerView: View {
    @Binding var homeVenue: String
    let venues: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F7F6F1").ignoresSafeArea()

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
                        .foregroundColor(Color(hex: "#1E5BFF"))
                }
            }
        }
    }

    private func pickerRow(title: String, icon: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(selected ? Color(hex: "#B68000") : Color(hex: "#1E5BFF"))
            Text(title)
                .font(.system(size: 16, weight: selected ? .black : .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#151515"))
            Spacer()
            if selected {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color(hex: "#B68000"))
            }
        }
        .padding(13)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? Color(hex: "#B68000").opacity(0.35) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct VenueSectionView: View {
    let venue: String
    let races: [TodayRace]
    var isHome: Bool = false
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isHome ? "house.and.flag.fill" : "building.columns.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(isHome ? Color(hex: "#B68000") : Color(hex: "#1E5BFF"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(venue)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#151515"))
                        Text(isExpanded ? "タップで閉じる" : "タップでレース表示")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#81786D"))
                    }

                    Spacer()

                    Text("\(races.count)R")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#151515"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#EFE7D7"))
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Color(hex: "#81786D"))
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(races) { race in
                        NavigationLink(value: race.race_id) {
                            RaceCardView(race: race)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isExpanded ? Color(hex: "#1E5BFF").opacity(0.28) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        .onAppear {
            if isHome {
                isExpanded = true
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
            VStack(spacing: -1) {
                Text("\(race.raceNo)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                Text("R")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 48, height: 54)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#111111"), Color(hex: "#333333")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    if let top = topEntries.first {
                        LaneBadge(number: top.umaban, size: 26)
                        Text(top.name)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#151515"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Color(hex: "#1E5BFF"))
                }

                HStack(spacing: 6) {
                    ForEach(Array(topEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 4) {
                            LaneBadge(number: entry.umaban, size: 21)
                            Text(index == 0 ? "軸" : "\(index + 1)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(index == 0 ? Color(hex: "#B68000") : Color(hex: "#81786D"))
                        }
                    }
                    Spacer()
                    Text(scoreGap >= 8 ? "勝負" : "混戦")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(scoreGap >= 8 ? .white : Color(hex: "#1E5BFF"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreGap >= 8 ? KeirinUI.red : Color(hex: "#E7EEFF"))
                        .clipShape(Capsule())
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(hex: "#FBFAF7"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct FocusRaceStrip: View {
    let picks: [TodayRace]
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の勝負候補")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#151515"))
                Spacer()
                Text("\(picks.count)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KeirinUI.red)
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(picks) { race in
                        NavigationLink(value: race.race_id) {
                            FocusRaceCard(race: race, venueStats: venueStats)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct FocusRaceCard: View {
    let race: TodayRace
    let venueStats: [String: VenueStats]

    private var sortedEntries: [TodayRaceEntry] {
        race.entries.sorted { $0.score > $1.score }
    }

    private var topScoreGap: Double {
        guard sortedEntries.count >= 3 else { return 0 }
        return sortedEntries[0].score - sortedEntries[2].score
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(race.venue)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#151515"))
                Text("\(race.raceNo)R")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#B68000"))
            }

            HStack(spacing: 7) {
                ForEach(Array(sortedEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                    VStack(spacing: 4) {
                        LaneBadge(number: entry.umaban, size: index == 0 ? 30 : 25)
                        Text(entry.name)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#151515"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: 48)
                }
            }

            Text("信頼 \(String(format: "%.0f", min(topScoreGap * 7, 99)))")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(hex: "#111111"))
                .clipShape(Capsule())
        }
        .frame(width: 176, alignment: .leading)
        .padding(11)
        .background(Color(hex: "#F7F6F1"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}
