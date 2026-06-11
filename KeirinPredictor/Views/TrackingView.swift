import SwiftUI

struct TrackingView: View {
    @EnvironmentObject var tracker: PredictionTracker

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinStageBackground()

                CompactAwareScroll {
                    VStack(spacing: 16) {
                        performanceHeader
                        statsCards
                        calibrationCard
                        recentHistory
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("成績")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(KeirinUI.gold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KeirinUI.lightBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var performanceHeader: some View {
        RacingPanel(accent: KeirinUI.red) {
            AdaptiveStack(horizontalSpacing: 14, verticalSpacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#111111"), KeirinUI.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PERFORMANCE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(KeirinUI.red)
                    Text("予測成績")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                    Text(tracker.totalPredictions == 0 ? "まだ予測はありません" : "\(tracker.totalPredictions)レースを解析済み")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#5D5344"))
                }
            }
        }
    }

    private var statsCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 118), spacing: 10)],
            spacing: 10
        ) {
            statCardsContent
        }
    }

    @ViewBuilder
    private var statCardsContent: some View {
            StatCard(
                label: "勝負1着",
                value: String(format: "%.1f%%", tracker.actionHitRate),
                sub: "\(tracker.actionWinCount)/\(tracker.actionPredictionCount)",
                color: tracker.actionHitRate >= 30 ? .green : KeirinUI.gold
            )
            StatCard(
                label: "1着的中率",
                value: String(format: "%.1f%%", tracker.hitRate),
                sub: "\(tracker.winCount)/\(tracker.totalPredictions)",
                color: tracker.hitRate >= 20 ? .green : Color(hex: "#FFD700")
            )
            StatCard(
                label: "3連単",
                value: String(format: "%.1f%%", tracker.trifectaHitRate),
                sub: "\(tracker.trifectaHitCount)/\(tracker.totalPredictions)",
                color: tracker.trifectaHitRate >= 10 ? .green : Color(hex: "#FFD700")
            )
            StatCard(
                label: "2車単",
                value: String(format: "%.1f%%", tracker.exactaHitRate),
                sub: "\(tracker.exactaHitCount)/\(tracker.totalPredictions)",
                color: tracker.exactaHitRate >= 20 ? .green : Color(hex: "#FFD700")
            )
            StatCard(
                label: "ワイド",
                value: String(format: "%.1f%%", tracker.wideHitRate),
                sub: "\(tracker.wideHitCount)/\(tracker.totalPredictions)",
                color: tracker.wideHitRate >= 30 ? .green : Color(hex: "#FFD700")
            )
            StatCard(
                label: "記録数",
                value: "\(tracker.totalPredictions)",
                sub: "解析済み",
                color: KeirinUI.cyan
            )
    }

    private var calibrationCard: some View {
        RacingPanel(accent: calibrationColor) {
            VStack(alignment: .leading, spacing: 12) {
                AdaptiveStack(horizontalSpacing: 12, verticalSpacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("30% WALL")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(calibrationColor)
                        Text(tracker.actionTuningAdvice)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#111111"))
                            .lineLimit(2)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%+.1f", tracker.actionTargetGap))
                            .font(.system(size: 27, weight: .black, design: .monospaced))
                            .foregroundColor(calibrationColor)
                        Text("30%との差")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#111111").opacity(0.44))
                    }
                }

                ProbabilityBar(value: min(max(tracker.actionHitRate / 30, 0), 1), color: calibrationColor)

                MetricPillRow {
                    RacingMetricBox(title: "勝負数", value: "\(tracker.actionPredictionCount)", color: Color(hex: "#B68000"))
                    RacingMetricBox(title: "状態", value: tracker.actionSampleLabel, color: KeirinUI.red)
                    RacingMetricBox(title: "目標", value: "30%", color: KeirinUI.green)
                }
            }
        }
    }

    private var calibrationColor: Color {
        if tracker.actionHitRate >= 30 { return KeirinUI.green }
        if tracker.actionPredictionCount < 10 { return KeirinUI.cyan }
        return KeirinUI.red
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("直近の予測")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(KeirinUI.gold)

            if tracker.recentRecords.isEmpty {
                VStack(spacing: 12) {
                    Image("EmptyState")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .opacity(0.5)
                    Text("レースを予測すると記録されます")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#5D5344"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(tracker.recentRecords) { record in
                    RecordRow(record: record)
                }
            }
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let sub: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#111111").opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#111111").opacity(0.42))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(color)
                .frame(height: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }
}

struct RecordRow: View {
    let record: PredictionRecord

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                resultMark

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(record.venue)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#111111"))
                        Text("\(record.raceNo)R")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#B68000"))
                    }
                    Text("予: \(record.predictedTop3.map { "\($0)" }.joined(separator: "-"))")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#4F473B"))
                    if !record.actualTop3.isEmpty {
                        Text("結: \(record.actualTop3.prefix(3).map { "\($0)" }.joined(separator: "-"))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(resultTextColor)
                    }
                    if let grade = record.playGrade {
                        Text("勝負 \(grade) / 軸目安 \(String(format: "%.0f", record.axisWinEstimate ?? 0))%")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(grade == "S" || grade == "A" ? KeirinUI.green : Color(hex: "#5D5344"))
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(resultLabel)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(resultTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    if let payout = record.payout, payout > 0 {
                        Text("+\(payout)円")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.green)
                    }
                }
            }
            .padding(12)

            if isSuccessful {
                Text("的中!")
                    .font(.system(size: 22, weight: .black, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(KeirinUI.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(KeirinUI.gold, lineWidth: 2)
                    )
                    .rotationEffect(.degrees(-9))
                    .offset(x: -8, y: -10)
                    .shadow(color: KeirinUI.red.opacity(0.42), radius: 8, x: 0, y: 4)
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSuccessful ? KeirinUI.red.opacity(0.42) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var resultMark: some View {
        ZStack {
            Circle()
                .fill(resultColor)
                .frame(width: 46, height: 46)
            Image(systemName: resultIcon)
                .font(.system(size: 19, weight: .black))
                .foregroundColor(resultIconColor)
        }
    }

    private var resultLabel: String {
        if record.actualTop3.isEmpty { return "結果待ち" }
        if record.isTrifectaHit { return "3連単的中" }
        if record.isExactaHit { return "2車単的中" }
        if record.isWideHit { return "ワイド的中" }
        if record.isHit { return "1着的中" }
        if record.isTop3Hit { return "3連対" }
        return "不的中"
    }

    private var isSuccessful: Bool {
        record.isTrifectaHit || record.isExactaHit || record.isWideHit || record.isHit || record.isTop3Hit
    }

    private var resultColor: Color {
        if record.actualTop3.isEmpty { return Color(hex: "#8A8F98") }
        return isSuccessful ? Color(hex: "#FFD400") : Color(hex: "#2E333B")
    }

    private var resultIcon: String {
        if record.actualTop3.isEmpty { return "clock" }
        return isSuccessful ? "checkmark" : "xmark"
    }

    private var resultIconColor: Color {
        if record.actualTop3.isEmpty { return .white }
        return isSuccessful ? .black : .white
    }

    private var resultTextColor: Color {
        if record.actualTop3.isEmpty { return Color(hex: "#5D5344") }
        return isSuccessful ? KeirinUI.red : Color(hex: "#5D5344")
    }
}
