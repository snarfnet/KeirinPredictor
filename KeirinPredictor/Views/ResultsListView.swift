import SwiftUI

struct ResultsListView: View {
    @EnvironmentObject var dataLoader: DataLoader

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinStageBackground()

                CompactAwareScroll {
                    VStack(alignment: .leading, spacing: 16) {
                        resultsHeader
                        resultsContent

                        BannerAdView()
                            .frame(height: 50)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RESULTS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(KeirinUI.gold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dataLoader.fetchRemoteTodayResults()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(KeirinUI.gold)
                    }
                }
            }
            .onAppear {
                if dataLoader.todayResults.isEmpty && !dataLoader.isResultsLoading {
                    dataLoader.fetchRemoteTodayResults()
                }
            }
        }
    }

    private var resultsHeader: some View {
        GlassPanel(cornerRadius: 22, borderColor: KeirinUI.gold.opacity(0.32)) {
            VStack(alignment: .leading, spacing: 13) {
                AdaptiveStack(horizontalSpacing: 12, verticalSpacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RACE RESULTS")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.cyan)
                        Text("レース結果")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("データ日 \(resultDateText)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(KeirinUI.gold.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(dataLoader.todayResults.count)")
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.gold)
                        Text("CONFIRMED")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                MetricPillRow {
                    MetricPill(title: "DATE", value: shortDateText, color: KeirinUI.green)
                    MetricPill(title: "RESULT", value: "\(dataLoader.todayResults.count)R", color: KeirinUI.gold)
                    MetricPill(title: "STATUS", value: statusLabel, color: statusColor)
                    MetricPill(title: "BUILD", value: appBuildNumber, color: KeirinUI.cyan)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if dataLoader.isResultsLoading && dataLoader.todayResults.isEmpty {
            ResultsStatusCard(
                icon: "arrow.triangle.2.circlepath",
                title: "結果データを確認中",
                message: "\(resultDateText) の確定結果を取得しています。",
                color: KeirinUI.cyan
            )
        } else if let error = dataLoader.resultsLoadError {
            ResultsStatusCard(
                icon: "exclamationmark.triangle.fill",
                title: "結果を取得できませんでした",
                message: error,
                color: KeirinUI.red
            )
        } else if dataLoader.todayResults.isEmpty {
            ResultsStatusCard(
                icon: "clock.badge.questionmark",
                title: "結果はまだ未確定です",
                message: "\(resultDateText) の結果ファイルは取得済みです。確定結果が入り次第ここに表示します。",
                color: KeirinUI.gold
            )
        } else {
            ForEach(groupedByVenue, id: \.venue) { group in
                VenueResultSection(venue: group.venue, results: group.results)
            }
        }
    }

    private var resultDateText: String {
        if !dataLoader.todayResultsDateString.isEmpty { return dataLoader.todayResultsDateString }
        if !dataLoader.todayDateString.isEmpty { return dataLoader.todayDateString }
        return "確認中"
    }

    private var shortDateText: String {
        let text = resultDateText
        if text == "確認中" { return text }
        let currentYear = Calendar(identifier: .gregorian)
            .component(.year, from: Date())
        return text
            .replacingOccurrences(of: "\(currentYear)年", with: "")
            .replacingOccurrences(of: "月", with: "/")
            .replacingOccurrences(of: "日", with: "")
    }

    private var statusLabel: String {
        if dataLoader.isResultsLoading { return "取得中" }
        if dataLoader.resultsLoadError != nil { return "要確認" }
        if dataLoader.todayResults.isEmpty { return "未確定" }
        return "確定"
    }

    private var statusColor: Color {
        if dataLoader.isResultsLoading { return KeirinUI.cyan }
        if dataLoader.resultsLoadError != nil { return KeirinUI.red }
        if dataLoader.todayResults.isEmpty { return KeirinUI.gold }
        return KeirinUI.green
    }

    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private var groupedByVenue: [VenueResultGroup] {
        let dict = Dictionary(grouping: dataLoader.todayResults, by: { $0.venue })
        return dict.map { VenueResultGroup(venue: $0.key, results: $0.value.sorted { $0.race_no < $1.race_no }) }
            .sorted { $0.venue < $1.venue }
    }
}

struct ResultsStatusCard: View {
    let icon: String
    let title: String
    let message: String
    let color: Color

    var body: some View {
        GlassPanel(cornerRadius: 20, borderColor: color.opacity(0.28)) {
            AdaptiveStack(horizontalSpacing: 12, verticalSpacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.13))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(message)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(3)
                }
            }
        }
    }
}

struct VenueResultGroup {
    let venue: String
    let results: [TodayRaceResult]
}

struct VenueResultSection: View {
    let venue: String
    let results: [TodayRaceResult]

    var body: some View {
        GlassPanel(cornerRadius: 18, borderColor: KeirinUI.gold.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(KeirinUI.gold)
                    Text(venue)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(results.count)R")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.56))
                }

                ForEach(results) { result in
                    RaceResultRow(result: result)
                }
            }
        }
    }
}

struct RaceResultRow: View {
    let result: TodayRaceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(result.race_no)R")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(KeirinUI.gold)
                Spacer()
            }

            ForEach(Array(result.finishers.prefix(3).enumerated()), id: \.offset) { (i, finisher) in
                HStack(spacing: 8) {
                    Text("\(i + 1)着")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(i == 0 ? KeirinUI.gold : .white.opacity(0.6))
                        .frame(width: 34)

                    Text("\(finisher.umaban)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(wakuColor(finisher.waku))
                        .clipShape(Circle())

                    Text(finisher.name)
                        .font(.system(size: 15, weight: i == 0 ? .bold : .regular, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    if !finisher.kimarite.isEmpty {
                        Text(finisher.kimarite)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(styleColor(finisher.kimarite))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }

            if !result.paybacks.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 6) {
                    ForEach(Array(result.paybacks.enumerated()), id: \.offset) { _, pb in
                        VStack(spacing: 2) {
                            Text(pb.type)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                            Text(pb.combination)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(pb.payout)円")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(pb.payout >= 10000 ? KeirinUI.red : KeirinUI.gold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
