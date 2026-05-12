import SwiftUI

struct TrackingView: View {
    @EnvironmentObject var tracker: PredictionTracker

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinStageBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        performanceHeader
                        statsCards
                        recentHistory
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TRACKING")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
    }

    private var performanceHeader: some View {
        GlassPanel(cornerRadius: 20, borderColor: KeirinUI.cyan.opacity(0.24)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(KeirinUI.cyan.opacity(0.25), lineWidth: 8)
                        .frame(width: 58, height: 58)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(KeirinUI.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PERFORMANCE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(KeirinUI.cyan)
                    Text("予測成績")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(tracker.totalPredictions == 0 ? "まだ予測はありません" : "\(tracker.totalPredictions)レースを解析済み")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                }
                Spacer()
            }
        }
    }

    private var legacyPerformanceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: "#FFD700").opacity(0.5), lineWidth: 2))

            VStack(alignment: .leading, spacing: 4) {
                Text("鉄脚博士の成績")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Text(tracker.totalPredictions == 0 ? "予測を始めよう" : "予測\(tracker.totalPredictions)レース分析済み")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(14)
        .background(
            ZStack {
                Image("HeaderBg")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.2)
                Color.white.opacity(0.03)
            }
        )
        .clipped()
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
        )
    }

    private var statsCards: some View {
        HStack(spacing: 10) {
            StatCard(
                label: "1着的中率",
                value: String(format: "%.1f%%", tracker.hitRate),
                sub: "\(tracker.winCount)/\(tracker.totalPredictions)",
                color: tracker.hitRate >= 20 ? .green : Color(hex: "#FFD700")
            )
            StatCard(
                label: "3連対的中",
                value: String(format: "%.1f%%", tracker.top3HitRate),
                sub: "\(tracker.top3HitCount)/\(tracker.totalPredictions)",
                color: tracker.top3HitRate >= 30 ? .green : Color(hex: "#FFD700")
            )
            StatCard(
                label: "記録数",
                value: "\(tracker.totalPredictions)",
                sub: "解析済み",
                color: KeirinUI.cyan
            )
        }
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("直近の予測")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))

            if tracker.recentRecords.isEmpty {
                VStack(spacing: 12) {
                    Image("EmptyState")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .opacity(0.5)
                    Text("レースを予測すると記録されます")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
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
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text(sub)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct RecordRow: View {
    let record: PredictionRecord

    var body: some View {
        HStack(spacing: 10) {
            // Result indicator
            ZStack {
                Circle()
                    .fill(resultColor)
                    .frame(width: 32, height: 32)
                if record.actualTop3.isEmpty {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                } else if record.isHit {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                } else if record.isTop3Hit {
                    Text("3")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.venue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(record.raceNo)R")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                Text("予: \(record.predictedTop3.map { "\($0)" }.joined(separator: "-"))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            if let payout = record.payout, payout > 0 {
                Text("+\(payout)円")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            } else if !record.actualTop3.isEmpty {
                Text("不的中")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private var resultColor: Color {
        if record.actualTop3.isEmpty { return Color.white.opacity(0.15) }
        if record.isHit { return Color(hex: "#FFD700") }
        if record.isTop3Hit { return Color(hex: "#CD7F32") }
        return Color.white.opacity(0.1)
    }
}
