import SwiftUI

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @EnvironmentObject var tracker: PredictionTracker
    @AppStorage("homeVenue") private var homeVenue: String = ""
    @State private var showVenuePicker = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinUI.lightBackground.ignoresSafeArea()

                if dataLoader.todayRaces.isEmpty {
                    emptyState
                } else {
                    CompactAwareScroll {
                        VStack(alignment: .leading, spacing: 14) {
                            LiveHitRateCard(
                                tracker: tracker,
                                races: hitRateSourceRaces,
                                results: dataLoader.todayResults
                            )
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
                        }
                    }
                    .refreshable {
                        dataLoader.fetchRemoteTodayEntries()
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                FixedTopAdView()
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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KeirinUI.lightBackground, for: .navigationBar)
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
                tracker.syncResults(dataLoader.todayResults)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("HeroVisual")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#FBFAF7"))

            VStack(alignment: .leading, spacing: 9) {
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
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#111111"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(dataLoader.todayDateString.isEmpty ? "本日のデータを確認中" : "データ日 \(dataLoader.todayDateString)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#5D5344"))
                    .lineLimit(1)

                DataStatusRow(
                    title: dataLoader.dataStatusTitle,
                    detail: dataLoader.dataStatusDetail,
                    updated: dataLoader.dataLastUpdatedText
                )

                MetricPillRow {
                    LightMetricPill(title: "開催場", value: "\(availableVenues.count)", tone: Color(hex: "#1E5BFF"))
                    LightMetricPill(title: "レース", value: "\(dataLoader.todayRaces.count)", tone: Color(hex: "#C79314"))
                    LightMetricPill(title: "一押し", value: "\(aiPicks.count)", tone: KeirinUI.red)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
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

    private var hitRateSourceRaces: [TodayRace] {
        var seen = Set<String>()
        return (dataLoader.todayRaces + dataLoader.resultRaces).filter { race in
            if seen.contains(race.race_id) { return false }
            seen.insert(race.race_id)
            return true
        }
    }

    private var compactDateLabel: String {
        if let first = dayGroups.first {
            return first.label == "今日" ? formatShortDate(first.date) : "\(first.label) \(formatShortDate(first.date))"
        }
        return formatShortDate(todayString())
    }

    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private var aiPicks: [FocusRacePick] {
        let todayStr = todayString()
        let visibleRaces = dataLoader.todayRaces.filter {
            let d = $0.dateString.isEmpty ? todayStr : $0.dateString
            return d == todayStr
        }

        let analyzed = visibleRaces.compactMap { race -> (race: TodayRace, analysis: RaceIntelligence, quality: Double, isBuy: Bool)? in
            guard race.entries.count >= 3 else { return nil }
            let analysis = PredictionEngine.analyzeTodayRace(
                race,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats,
                lineMatrix: dataLoader.lineMatrix
            )
            return (
                race: race,
                analysis: analysis,
                quality: dailyPickQuality(analysis),
                isBuy: analysis.actionLabel == "買う"
            )
        }
        .sorted { lhs, rhs in
            if lhs.isBuy != rhs.isBuy { return lhs.isBuy }
            if lhs.quality == rhs.quality { return lhs.race.raceNo < rhs.race.raceNo }
            return lhs.quality > rhs.quality
        }

        let targetCount = min(5, analyzed.count)
        let buyCandidates = analyzed.filter { $0.isBuy }
        let backupCandidates = analyzed.filter { !$0.isBuy }
        let selected = buyCandidates.count >= targetCount
            ? buyCandidates
            : buyCandidates + Array(backupCandidates.prefix(targetCount - buyCandidates.count))

        return selected.map { item in
            let analysis = item.analysis
            let label = item.isBuy ? "勝負" : (analysis.axisWinEstimate >= 30 ? "注目" : "押さえ")
            let reason = item.isBuy ? analysis.actionReason : "勝負条件まであと少し。指数上位から候補に追加"
            var reasons: [String] = [
                reason,
                "本命1着の目安 \(String(format: "%.0f", analysis.axisWinEstimate))%",
                "軸候補 \(analysis.axisName)"
            ]
            reasons.append(contentsOf: analysis.notes.prefix(3))

            return FocusRacePick(
                race: item.race,
                score: item.quality,
                actionLabel: label,
                actionReason: reason,
                grade: item.isBuy ? analysis.playGrade : "候",
                reasons: reasons
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.race.raceNo < rhs.race.raceNo }
            return lhs.score > rhs.score
        }
    }

    private func dailyPickQuality(_ analysis: RaceIntelligence) -> Double {
        let gradeBonus: Double
        switch analysis.playGrade {
        case "S": gradeBonus = 24
        case "A": gradeBonus = 16
        case "B": gradeBonus = 8
        default: gradeBonus = 0
        }
        let buyBonus = analysis.actionLabel == "買う" ? 40.0 : 0.0
        let chaosPenalty = max(0, analysis.chaosScore - 55) * 1.4
        return analysis.axisWinEstimate * 2.0 + gradeBonus + buyBonus - chaosPenalty
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
        .background(KeirinUI.lightBackground.ignoresSafeArea())
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

struct LiveHitRateCard: View {
    @ObservedObject var tracker: PredictionTracker
    let races: [TodayRace]
    let results: [TodayRaceResult]

    private struct LiveMatch {
        let predicted: [Int]
        let actual: [Int]
    }

    private var liveMatches: [LiveMatch] {
        results.compactMap { result in
            guard let race = races.first(where: { $0.race_id == result.race_id }) else { return nil }
            let predicted = race.entries
                .sorted { $0.score > $1.score }
                .prefix(3)
                .map { $0.umaban }
            let actual = result.finishers
                .sorted { $0.rank < $1.rank }
                .prefix(3)
                .map { $0.umaban }
            guard predicted.count >= 3, actual.count >= 3 else { return nil }
            return LiveMatch(predicted: Array(predicted), actual: Array(actual))
        }
    }

    private var liveWinCount: Int {
        liveMatches.filter { $0.predicted.first == $0.actual.first }.count
    }

    private var liveTop3Count: Int {
        liveMatches.filter { Set($0.predicted) == Set($0.actual) }.count
    }

    private var liveCount: Int {
        liveMatches.count
    }

    private var usesActionRate: Bool {
        liveCount == 0 && tracker.actionPredictionCount > 0
    }

    private var rate: Double {
        if liveCount > 0 {
            return Double(liveWinCount) / Double(liveCount) * 100
        }
        return usesActionRate ? tracker.actionHitRate : tracker.hitRate
    }

    private var hitCount: Int {
        if liveCount > 0 { return liveWinCount }
        return usesActionRate ? tracker.actionWinCount : tracker.winCount
    }

    private var totalCount: Int {
        if liveCount > 0 { return liveCount }
        return usesActionRate ? tracker.actionPredictionCount : tracker.totalPredictions
    }

    private var top3Rate: Double {
        if liveCount > 0 {
            return Double(liveTop3Count) / Double(liveCount) * 100
        }
        return tracker.top3HitRate
    }

    private var rateText: String {
        totalCount > 0 ? String(format: "%.1f%%", rate) : "--.-%"
    }

    private var statusText: String {
        if totalCount == 0 {
            return "結果が出た予測から集計します"
        }
        if liveCount > 0 {
            return "今日の結果と自動予測を照合"
        }
        return usesActionRate ? "勝負S/Aの1着的中" : "全予測の1着的中"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("鉄脚先生")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#B68000"))
                    Text("ただ今の的中率")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(statusText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#6E665A"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                Text(rateText)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundColor(rateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }

            HStack(spacing: 8) {
                HitRateMiniPill(title: "的中", value: "\(hitCount)/\(totalCount)", tone: rateColor)
                HitRateMiniPill(title: "3連対", value: String(format: "%.1f%%", top3Rate), tone: Color(hex: "#1E5BFF"))
                HitRateMiniPill(title: "30%壁", value: String(format: "%+.1f", rate - 30), tone: rate >= 30 ? KeirinUI.green : KeirinUI.red)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [.white, Color(hex: "#FFF8E7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "#E2C46F").opacity(0.46), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 7)
    }

    private var rateColor: Color {
        if totalCount == 0 { return Color(hex: "#81786D") }
        if rate >= 30 { return KeirinUI.green }
        if rate >= 20 { return Color(hex: "#C79314") }
        return KeirinUI.red
    }
}

struct HitRateMiniPill: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#766D61"))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color(hex: "#F7F6F1"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

struct FocusRacePick: Identifiable {
    var id: String { race.race_id }
    let race: TodayRace
    let score: Double
    let actionLabel: String
    let actionReason: String
    let grade: String
    let reasons: [String]
}

struct DaySectionView: View {
    let group: DayGroup
    var homeVenue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label)
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#151515"))
                    Text(group.dateLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#766D61"))
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
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

struct DataStatusRow: View {
    let title: String
    let detail: String
    let updated: String

    private var tone: Color {
        if title.contains("失敗") || title.contains("エラー") { return KeirinUI.red }
        if title.contains("前回") { return Color(hex: "#C79314") }
        if title.contains("取得済み") { return KeirinUI.green }
        return Color(hex: "#1E5BFF")
    }

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(tone)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#151515"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(updated.isEmpty ? detail : "\(detail) ・ \(updated)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#6E665A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 6)

            Image(systemName: iconName)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(tone)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "#F7F6F1"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.opacity(0.22), lineWidth: 1)
        )
    }

    private var iconName: String {
        if title.contains("失敗") || title.contains("エラー") { return "exclamationmark.triangle.fill" }
        if title.contains("前回") { return "clock.arrow.circlepath" }
        return "checkmark.seal.fill"
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
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#151515"))
                        Text(isExpanded ? "タップで閉じる" : "タップでレース表示")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
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

    private var top3Gap: Double {
        guard topEntries.count >= 3 else { return 0 }
        return topEntries[0].score - topEntries[2].score
    }

    private var playAction: String {
        guard topEntries.count >= 3 else { return "待ち" }
        let top = topEntries[0]
        let ratePass = top.top3Rate <= 0 || top.top3Rate >= 35
        return top3Gap >= 8 && scoreGap >= 5 && top.score >= 90 && ratePass ? "注目" : "確認"
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
                            .font(.system(size: 18, weight: .black, design: .rounded))
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
                    Text(playAction)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(playAction == "注目" ? .white : Color(hex: "#1E5BFF"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(playAction == "注目" ? KeirinUI.red : Color(hex: "#E7EEFF"))
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
    let picks: [FocusRacePick]
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の一押し！")
                    .font(.system(size: 21, weight: .black, design: .rounded))
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

            VStack(spacing: 8) {
                ForEach(picks) { pick in
                    NavigationLink(value: pick.race.race_id) {
                        FocusRaceCard(pick: pick, venueStats: venueStats)
                    }
                    .buttonStyle(.plain)
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
    let pick: FocusRacePick
    let venueStats: [String: VenueStats]

    private var race: TodayRace { pick.race }

    private var sortedEntries: [TodayRaceEntry] {
        race.entries.sorted { $0.score > $1.score }
    }

    private var topEntry: TodayRaceEntry? {
        sortedEntries.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: -1) {
                Text("\(race.raceNo)")
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                Text("R")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 46, height: 52)
            .background(KeirinUI.red)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 7) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(race.venue)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#151515"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let topEntry {
                            Text("軸 \(topEntry.umaban)番 \(topEntry.name)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#5D5344"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }

                    Spacer(minLength: 6)

                    VStack(spacing: 2) {
                        Text(pick.actionLabel)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(pick.grade)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(width: 58, height: 44)
                    .background(KeirinUI.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .accessibilityLabel("\(pick.actionLabel) \(pick.grade)")

                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(pick.reasons.prefix(4), id: \.self) { reason in
                        HStack(alignment: .top, spacing: 5) {
                            Circle()
                                .fill(Color(hex: "#B68000"))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            Text(reason)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#5D5344"))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 6) {
                    ForEach(Array(sortedEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 4) {
                            LaneBadge(number: entry.umaban, size: 20)
                            Text(index == 0 ? "軸" : "\(index + 1)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(index == 0 ? Color(hex: "#B68000") : Color(hex: "#81786D"))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Color(hex: "#1E5BFF"))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(hex: "#F7F6F1"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}
