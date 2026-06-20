import SwiftUI
import UIKit

struct RaceListView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @EnvironmentObject var tracker: PredictionTracker
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
                                    playerStats: dataLoader.playerStats,
                                    tracker: tracker
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
                        dataLoader.fetchRemotePlayerStats()
                        dataLoader.fetchRemoteTodayEntries()
                        dataLoader.fetchRemoteTodayResults()
                        dataLoader.fetchRemoteTodayOdds()
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
                            .foregroundColor(KeirinUI.gold)
                        Text("競輪鉄脚ラボ")
                            .font(.system(size: 17, weight: .black, design: .serif))
                            .foregroundColor(KeirinUI.gold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVenuePicker = true
                    } label: {
                        Image(systemName: homeVenue.isEmpty ? "mappin.circle" : "house.and.flag.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(homeVenue.isEmpty ? Color(hex: "#111827") : KeirinUI.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(KeirinUI.gold.opacity(0.55), lineWidth: 1)
                            )
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(hex: "#050912"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        ZStack(alignment: .bottomLeading) {
            Image("HakaseHeroV3")
                .resizable()
                .scaledToFill()
                .frame(minHeight: 334)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.04),
                            Color(hex: "#06101C").opacity(0.36),
                            Color.black.opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.80), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Text("BUILD \(appBuildNumber)")
                    Text(compactDateLabel)
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(KeirinUI.gold)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.56))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(KeirinUI.gold.opacity(0.45), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text("鉄脚博士")
                        .font(.system(size: 46, weight: .black, design: .serif))
                        .foregroundColor(KeirinUI.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text("今日の一着、博士に聞け。")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.92))
                }

                Text("展開と脚の流れ...この並び、見逃すな。")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(KeirinUI.paper)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.46))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(KeirinUI.gold.opacity(0.55), lineWidth: 1)
                    )
                    .frame(maxWidth: 250, alignment: .leading)

                DataStatusRow(
                    title: dataLoader.dataStatusTitle,
                    detail: dataLoader.dataStatusDetail,
                    updated: dataLoader.dataLastUpdatedText
                )

                MetricPillRow {
                    LightMetricPill(title: "開催場", value: "\(availableVenues.count)", tone: KeirinUI.gold)
                    LightMetricPill(title: "レース", value: "\(dataLoader.todayRaces.count)", tone: KeirinUI.red)
                    LightMetricPill(title: "一押し", value: "\(aiPicks.count)", tone: KeirinUI.green)
                }
            }
            .padding(14)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#07101A"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.48), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.34), radius: 20, x: 0, y: 10)
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

        let analyzed = visibleRaces.compactMap { race -> (race: TodayRace, analysis: RaceIntelligence, insight: PredictionConditionInsight, quality: Double, isBuy: Bool)? in
            guard race.entries.count >= 3 else { return nil }
            let analysis = PredictionEngine.analyzeTodayRace(
                race,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats,
                lineMatrix: dataLoader.lineMatrix
            )
            let insight = tracker.conditionInsight(
                venue: race.venue,
                raceNo: race.raceNo,
                playGrade: analysis.playGrade,
                axisWinEstimate: analysis.axisWinEstimate
            )
            return (
                race: race,
                analysis: analysis,
                insight: insight,
                quality: dailyPickQuality(analysis, insight: insight),
                isBuy: analysis.actionLabel == "買い"
            )
        }
        .sorted { lhs, rhs in
            if lhs.isBuy != rhs.isBuy { return lhs.isBuy }
            if lhs.quality == rhs.quality { return lhs.race.raceNo < rhs.race.raceNo }
            return lhs.quality > rhs.quality
        }

        let targetCount = min(10, analyzed.count)
        let buyCandidates = analyzed.filter { $0.isBuy }
        let backupCandidates = analyzed.filter { !$0.isBuy }
        let selected = buyCandidates.count >= targetCount
            ? buyCandidates
            : buyCandidates + Array(backupCandidates.prefix(targetCount - buyCandidates.count))

        return selected.map { item in
            let analysis = item.analysis
            let adjustedEstimate = min(max(analysis.axisWinEstimate + item.insight.estimateAdjustment, 0), 60)
            let label = item.isBuy ? "買い" : (adjustedEstimate >= 30 ? "注目" : "押さえ")
            let reason = item.isBuy ? analysis.actionReason : "勝負条件まであと少し。指数上位から候補に追加"
            var reasons: [String] = [
                reason,
                "本命1着の目安 \(String(format: "%.0f", adjustedEstimate))%",
                "軸候補 \(analysis.axisName)"
            ]
            reasons.append(contentsOf: item.insight.notes)
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

    private func dailyPickQuality(_ analysis: RaceIntelligence, insight: PredictionConditionInsight) -> Double {
        let gradeBonus: Double
        switch analysis.playGrade {
        case "S": gradeBonus = 24
        case "A": gradeBonus = 16
        case "B": gradeBonus = 8
        default: gradeBonus = 0
        }
        let buyBonus = analysis.actionLabel == "買い" ? 40.0 : 0.0
        let chaosPenalty = max(0, analysis.chaosScore - 55) * 1.4
        return analysis.axisWinEstimate * 2.0 + gradeBonus + buyBonus - chaosPenalty + insight.qualityAdjustment
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("HakaseHeroV3")
                .resizable()
                .scaledToFill()
                .frame(width: 260, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(0.92)

            Text("本日の出走表がありません")
                .font(.system(size: 21, weight: .black, design: .serif))
                .foregroundColor(KeirinUI.gold)

            Text(dataLoader.todayDataWarning ?? "前日データは表示せず、今日以降のデータだけ表示します。")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.70))
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
                    .background(KeirinUI.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeirinStageBackground())
    }

    private var dayGroups: [DayGroup] {
        let todayStr = todayString()
        let tomorrowStr = tomorrowString()

        var grouped: [String: [TodayRace]] = [:]
        for race in dataLoader.todayRaces {
            let d = race.dateString.isEmpty ? todayStr : race.dateString
            grouped[d, default: []].append(race)
        }

        let groups = grouped.map { (date, races) in
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
        }

        return groups.sorted { lhs, rhs in
            if shouldPrioritizeTomorrow {
                if lhs.date == tomorrowStr, rhs.date != tomorrowStr { return true }
                if rhs.date == tomorrowStr, lhs.date != tomorrowStr { return false }
            }
            return lhs.date < rhs.date
        }
    }

    private var shouldPrioritizeTomorrow: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar.component(.hour, from: Date()) >= 21
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

    private var liveTrifectaCount: Int {
        liveMatches.filter { $0.predicted == $0.actual }.count
    }

    private var liveExactaCount: Int {
        liveMatches.filter {
            Array($0.predicted.prefix(2)) == Array($0.actual.prefix(2))
        }.count
    }

    private var liveWideCount: Int {
        liveMatches.filter {
            Set($0.predicted.prefix(2)).isSubset(of: Set($0.actual.prefix(3)))
        }.count
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

    private var trifectaRate: Double {
        if liveCount > 0 {
            return Double(liveTrifectaCount) / Double(liveCount) * 100
        }
        return tracker.trifectaHitRate
    }

    private var exactaRate: Double {
        if liveCount > 0 {
            return Double(liveExactaCount) / Double(liveCount) * 100
        }
        return tracker.exactaHitRate
    }

    private var wideRate: Double {
        if liveCount > 0 {
            return Double(liveWideCount) / Double(liveCount) * 100
        }
        return tracker.wideHitRate
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
                        .font(.system(size: 15, weight: .black, design: .serif))
                        .foregroundColor(KeirinUI.gold)
                    Text("ただ今の的中率")
                        .font(.system(size: 23, weight: .black, design: .serif))
                        .foregroundColor(KeirinUI.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(statusText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
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
                HitRateMiniPill(title: "1着", value: "\(hitCount)/\(totalCount)", tone: rateColor)
                HitRateMiniPill(title: "3連単", value: String(format: "%.1f%%", trifectaRate), tone: KeirinUI.red)
                HitRateMiniPill(title: "2車単", value: String(format: "%.1f%%", exactaRate), tone: Color(hex: "#1E5BFF"))
                HitRateMiniPill(title: "ワイド", value: String(format: "%.1f%%", wideRate), tone: KeirinUI.green)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#101923"), Color(hex: "#07101A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.54), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(colors: [KeirinUI.gold, KeirinUI.red], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
        }
        .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
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
                .foregroundColor(Color(hex: "#6B5830"))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(KeirinUI.paper)
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

    var scheduleLabel: String {
        if races.contains(where: { $0.scheduleLabel == "ミッドナイト" }) { return "ミッドナイト" }
        if races.contains(where: { $0.scheduleLabel == "ナイター" }) { return "ナイター" }
        if races.contains(where: { $0.scheduleLabel == "デイ" }) { return "デイ" }
        return ""
    }

    var scheduleTone: String {
        switch scheduleLabel {
        case "ミッドナイト": return "midnight"
        case "ナイター": return "night"
        case "デイ": return "day"
        default: return ""
        }
    }
}

struct RaceScheduleGroup: Identifiable {
    let id: String
    let label: String
    let tone: String
    let venues: [VenueGroup]

    var totalRaces: Int {
        venues.reduce(0) { $0 + $1.races.count }
    }
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
    @State private var isExpanded = true

    private var scheduleGroups: [RaceScheduleGroup] {
        let order = [
            ("ミッドナイト", "midnight"),
            ("ナイター", "night"),
            ("デイ", "day"),
            ("", "")
        ]

        return order.compactMap { label, tone in
            let venues = group.venues.filter { $0.scheduleLabel == label }
            guard !venues.isEmpty else { return nil }
            return RaceScheduleGroup(
                id: label.isEmpty ? "other" : label,
                label: label.isEmpty ? "時間未定" : label,
                tone: tone,
                venues: venues
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label)
                        .font(.system(size: 25, weight: .black, design: .serif))
                        .foregroundColor(KeirinUI.gold)
                    Text(group.dateLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.64))
                }

                Spacer()

                    Text("\(group.totalRaces)R")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#111111"))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(KeirinUI.gold)
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(KeirinUI.gold)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                ForEach(scheduleGroups) { scheduleGroup in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ScheduleBadge(label: scheduleGroup.label, time: "", tone: scheduleGroup.tone)
                            Text("\(scheduleGroup.venues.count)場 \(scheduleGroup.totalRaces)R")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.70))
                            Spacer()
                        }

                        VStack(spacing: 8) {
                            ForEach(scheduleGroup.venues, id: \.venue) { venueGroup in
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if group.label == "明日" {
                isExpanded = false
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
                .foregroundColor(Color(hex: "#6B5830"))
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(KeirinUI.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tone)
                .frame(height: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
    }
}

struct ScheduleBadge: View {
    let label: String
    let time: String
    let tone: String

    private var color: Color {
        switch tone {
        case "midnight": return Color(hex: "#111111")
        case "night": return KeirinUI.red
        case "day": return Color(hex: "#B68000")
        default: return Color(hex: "#111111")
        }
    }

    private var icon: String {
        switch tone {
        case "midnight": return "moon.stars.fill"
        case "night": return "sparkles"
        case "day": return "sun.max.fill"
        default: return "clock.fill"
        }
    }

    var body: some View {
        if !label.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .black))
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                if !time.isEmpty {
                    Text(time)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .opacity(0.82)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
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
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(tone)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(KeirinUI.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(updated.isEmpty ? detail : "\(detail) ・ \(updated)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 6)

            Rectangle()
                .fill(tone)
                .frame(width: 4, height: 34)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 10, x: 0, y: 6)
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
                        .foregroundColor(KeirinUI.gold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(hex: "#050912"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func pickerRow(title: String, icon: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(selected ? KeirinUI.red : KeirinUI.gold)
            Text(title)
                .font(.system(size: 16, weight: selected ? .black : .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#151515"))
            Spacer()
            if selected {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(KeirinUI.red)
            }
        }
        .padding(13)
        .background(KeirinUI.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? KeirinUI.red.opacity(0.45) : KeirinUI.gold.opacity(0.22), lineWidth: 1)
        )
    }
}

struct VenueSectionView: View {
    let venue: String
    let races: [TodayRace]
    var isHome: Bool = false
    @State private var isExpanded = false

    private var scheduleLabel: String {
        if races.contains(where: { $0.scheduleLabel == "ミッドナイト" }) { return "ミッドナイト" }
        if races.contains(where: { $0.scheduleLabel == "ナイター" }) { return "ナイター" }
        if races.contains(where: { $0.scheduleLabel == "デイ" }) { return "デイ" }
        return ""
    }

    private var scheduleTone: String {
        switch scheduleLabel {
        case "ミッドナイト": return "midnight"
        case "ナイター": return "night"
        case "デイ": return "day"
        default: return ""
        }
    }

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
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(isHome ? KeirinUI.red : Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(venue)
                            .font(.system(size: 22, weight: .black, design: .serif))
                            .foregroundColor(KeirinUI.paper)
                        HStack(spacing: 6) {
                            Text(isExpanded ? "タップで閉じる" : "タップでレース表示")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.58))
                            ScheduleBadge(label: scheduleLabel, time: "", tone: scheduleTone)
                        }
                    }

                    Spacer()

                    Text("\(races.count)R")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(KeirinUI.gold)
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
        .background(
            LinearGradient(
                colors: [Color(hex: "#101923"), Color(hex: "#07101A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isHome ? KeirinUI.red : KeirinUI.gold)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isExpanded ? KeirinUI.gold.opacity(0.55) : KeirinUI.gold.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 7)
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
                    .font(.system(size: 27, weight: .black, design: .monospaced))
                Text("R")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 52, height: 58)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#111111"), KeirinUI.red.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    if let top = topEntries.first {
                        LaneBadge(number: top.umaban, size: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(top.name)
                                .font(.system(size: 18, weight: .black, design: .serif))
                                .foregroundColor(KeirinUI.paper)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            ScheduleBadge(label: race.scheduleLabel, time: race.startTimeText, tone: race.scheduleTone)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(KeirinUI.gold)
                }

                HStack(spacing: 6) {
                    ForEach(Array(topEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 4) {
                            LaneBadge(number: entry.umaban, size: 21)
                            Text(index == 0 ? "軸" : "\(index + 1)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(index == 0 ? KeirinUI.gold : .white.opacity(0.64))
                        }
                    }
                    Spacer()
                    Text(playAction)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(playAction == "注目" ? KeirinUI.red : Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.black.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

struct FocusRaceStrip: View {
    let picks: [FocusRacePick]
    let venueStats: [String: VenueStats]
    let playerStats: [String: PlayerStats]
    @ObservedObject var tracker: PredictionTracker
    @State private var didCopyNote = false

    private var visiblePicks: [FocusRacePick] {
        picks
    }

    private var hiddenCount: Int {
        max(0, picks.count - visiblePicks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の一押し！")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundColor(KeirinUI.gold)
                Spacer()
                Text("\(picks.count)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#111111"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KeirinUI.gold)
                    .clipShape(Capsule())
            }

            Button {
                UIPasteboard.general.string = buildNoteDraft()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    didCopyNote = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        didCopyNote = false
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: didCopyNote ? "checkmark.seal.fill" : "doc.on.doc.fill")
                        .font(.system(size: 15, weight: .black))
                    Text(didCopyNote ? "note用文面をコピーしました" : "note用にコピー")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Spacer()
                    Text("前日実績・的中率入り")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .opacity(0.78)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [KeirinUI.red, Color(hex: "#7C1111")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(KeirinUI.gold.opacity(0.38), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                ForEach(visiblePicks) { pick in
                    NavigationLink(value: pick.race.race_id) {
                        FocusRaceCard(pick: pick, venueStats: venueStats)
                    }
                    .buttonStyle(.plain)
                }
            }

            if hiddenCount > 0 {
                Button {
                } label: {
                    HStack {
                        Text("残り\(hiddenCount)件を見る")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundColor(KeirinUI.paper)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.36))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(KeirinUI.gold.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color(hex: "#0E1721"), Color(hex: "#050912")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [KeirinUI.red, KeirinUI.gold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 16, x: 0, y: 8)
    }

    private func buildNoteDraft() -> String {
        let today = noteDateLabel(Date())
        let completed = tracker.records.filter { !$0.actualTop3.isEmpty }
        let previous = previousDayRecords(from: completed)
        let previousHits = previous.filter { isAnyHit($0) }
        let title = "鉄脚博士の競輪予想｜\(today) 本日の一押し\(picks.count)レース"

        var lines: [String] = [
            title,
            "",
            "本日の鉄脚博士予想です。",
            "指数、展開、軸候補、過去の記録を見て、勝負候補を\(picks.count)レースに絞りました。",
            "有料部分は200円想定です。",
            "",
            "※的中を保証するものではありません。",
            "※車券購入は20歳以上です。無理のない範囲で楽しんでください。",
            "",
            "【現在の的中率】",
            "対象: アプリに記録済みで結果まで同期できた\(completed.count)レース",
            "1着的中: \(tracker.winCount)/\(tracker.totalPredictions)（\(percent(tracker.hitRate))）",
            "3連単: \(tracker.trifectaHitCount)/\(tracker.totalPredictions)（\(percent(tracker.trifectaHitRate))）",
            "2車単: \(tracker.exactaHitCount)/\(tracker.totalPredictions)（\(percent(tracker.exactaHitRate))）",
            "ワイド: \(tracker.wideHitCount)/\(tracker.totalPredictions)（\(percent(tracker.wideHitRate))）",
            ""
        ]

        lines.append("【前日的中実績】")
        if previous.isEmpty {
            lines.append("前日分の記録はまだありません。結果同期後にここへ反映します。")
        } else if previousHits.isEmpty {
            let date = previous.first?.date ?? ""
            lines.append("\(formatRecordDate(date))は的中記録なし。外れも隠さず記録しています。")
        } else {
            let date = previousHits.first?.date ?? ""
            lines.append("\(formatRecordDate(date))の的中: \(previousHits.count)/\(previous.count)")
            for record in previousHits.prefix(8) {
                lines.append("・\(record.venue) \(record.raceNo)R \(hitLabel(record)) / 予 \(combo(record.predictedTop3)) → 結 \(combo(record.actualTop3))")
            }
            if previousHits.count > 8 {
                lines.append("・ほか\(previousHits.count - 8)件")
            }
        }

        lines.append(contentsOf: [
            "",
            "【無料公開】",
            "上位2レースだけ先に出します。残りの一押し、買い目候補、理由は有料部分です。",
            ""
        ])

        for (index, pick) in picks.prefix(2).enumerated() {
            lines.append(notePickBlock(index: index + 1, pick: pick, isPaid: false))
        }

        lines.append(contentsOf: [
            "",
            "----- ここから先は有料部分です -----",
            "noteでは、この下から有料エリアにしてください。価格は200円想定です。",
            "",
            "【本日の一押し一覧】"
        ])

        for (index, pick) in picks.enumerated() {
            lines.append(notePickBlock(index: index + 1, pick: pick, isPaid: true))
        }

        lines.append(contentsOf: [
            "",
            "【最後に】",
            "的中率はアプリの記録ベースでそのまま載せています。良い日も悪い日も数字を残して、予想精度を少しずつ上げていきます。"
        ])

        return lines.joined(separator: "\n")
    }

    private func notePickBlock(index: Int, pick: FocusRacePick, isPaid: Bool) -> String {
        let top = pick.race.entries.sorted { $0.score > $1.score }.prefix(3).map(\.umaban)
        let prediction = combo(Array(top))
        let exactaCandidate = top.count >= 2 ? "\(top[0])-\(top[1])" : "-"
        let wideCandidate = exactaCandidate
        let reasons = pick.reasons.prefix(isPaid ? 4 : 2).map { "  - \($0)" }.joined(separator: "\n")
        let reasonsText = reasons.isEmpty ? "  - 出走表と指数を確認してから最終判断" : reasons
        let start = pick.race.startTimeText.isEmpty ? "" : " \(pick.race.startTimeText)発走"
        return """

\(index). \(pick.race.venue) \(pick.race.raceNo)R\(start)
判定: \(pick.actionLabel) \(pick.grade)
予想: \(prediction)
3連単候補: \(prediction)
2車単候補: \(exactaCandidate)
ワイド候補: \(wideCandidate)
理由:
\(reasonsText)
"""
    }

    private func previousDayRecords(from records: [PredictionRecord]) -> [PredictionRecord] {
        let today = yyyymmdd(Date())
        let yesterday = yyyymmdd(Date().addingTimeInterval(-86400))
        let exact = records.filter { $0.date == yesterday }
        if !exact.isEmpty { return exact.sorted { $0.raceNo < $1.raceNo } }

        guard let latestPastDate = records
            .map(\.date)
            .filter({ !$0.isEmpty && $0 < today })
            .max()
        else {
            return []
        }
        return records.filter { $0.date == latestPastDate }.sorted { $0.raceNo < $1.raceNo }
    }

    private func isAnyHit(_ record: PredictionRecord) -> Bool {
        record.isTrifectaHit || record.isExactaHit || record.isWideHit || record.isHit || record.isTop3Hit
    }

    private func hitLabel(_ record: PredictionRecord) -> String {
        if record.isTrifectaHit { return "3連単的中" }
        if record.isExactaHit { return "2車単的中" }
        if record.isWideHit { return "ワイド的中" }
        if record.isHit { return "1着的中" }
        if record.isTop3Hit { return "3連対" }
        return "的中"
    }

    private func combo(_ values: [Int]) -> String {
        values.prefix(3).map { String($0) }.joined(separator: "-")
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func yyyymmdd(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func noteDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func formatRecordDate(_ value: String) -> String {
        guard value.count == 8,
              let y = Int(value.prefix(4)),
              let m = Int(value.dropFirst(4).prefix(2)),
              let d = Int(value.suffix(2)) else {
            return value.isEmpty ? "前日" : value
        }
        return "\(y)年\(m)月\(d)日"
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
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("R")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 62, height: 68)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#111111"), KeirinUI.red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 7) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(race.venue)
                            .font(.system(size: 21, weight: .black, design: .serif))
                            .foregroundColor(Color(hex: "#151515"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        ScheduleBadge(label: race.scheduleLabel, time: race.startTimeText, tone: race.scheduleTone)
                        if let topEntry {
                            Text("軸 \(topEntry.umaban)番 \(topEntry.name)")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "#5D5344"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }

                    Spacer(minLength: 6)

                    VStack(spacing: 2) {
                        Text(pick.actionLabel)
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(pick.grade)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(width: 62, height: 46)
                    .background(pick.actionLabel == "買い" ? KeirinUI.red : Color(hex: "#111111"))
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
                            Text("◎")
                                .font(.system(size: 11, weight: .black, design: .serif))
                                .foregroundColor(KeirinUI.red)
                                .padding(.top, 1)
                            Text(reason)
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundColor(Color(hex: "#5D5344"))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 6) {
                    ForEach(Array(sortedEntries.prefix(3).enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 5) {
                            LaneBadge(number: entry.umaban, size: 28)
                            Text(index == 0 ? "軸" : "\(index + 1)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(index == 0 ? Color(hex: "#B68000") : Color(hex: "#81786D"))
                                .frame(minWidth: 18, minHeight: 24)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [KeirinUI.paper, Color(hex: "#E7D5AA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(pick.actionLabel == "買い" ? KeirinUI.red : KeirinUI.gold)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.56), lineWidth: 1)
        )
    }
}
