import SwiftUI

struct RaceDetailView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @EnvironmentObject var tracker: PredictionTracker
    let race: TodayRace

    @State private var predictions: [PredictionResult] = []
    @State private var bets: [BetRecommendation] = []
    @State private var raceAnalysis: RaceIntelligence?
    @State private var isAnimating = false
    @State private var showResults = false
    @State private var pulse = false

    @State private var selectedBetType = "3連単"

    var body: some View {
        ZStack {
            KeirinStageBackground()

            CompactAwareScroll {
                VStack(spacing: 16) {
                    raceHeader

                    if showResults {
                        resultsSection
                        betSection
                    } else if isAnimating {
                        animatingView
                    } else {
                        entryListSection
                        predictButton
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FixedTopAdView()
        }
        .navigationTitle("\(race.venue) \(race.raceNo)R")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(hex: "#050912"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var raceHeader: some View {
        RacingPanel(accent: KeirinUI.red) {
            VStack(alignment: .leading, spacing: 14) {
                AdaptiveStack(horizontalSpacing: 10, verticalSpacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RACE CONTROL")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.red)
                        Text("\(race.venue) \(race.raceNo)R")
                            .font(.system(size: 31, weight: .black, design: .serif))
                            .foregroundColor(Color(hex: "#111111"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        ScheduleBadge(label: race.scheduleLabel, time: race.startTimeText, tone: race.scheduleTone)
                    }
                    Text("\(race.raceNo)")
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 74, height: 58)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#111111"), KeirinUI.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                MetricPillRow {
                    MetricPill(title: "RIDERS", value: "\(race.entries.count)", color: KeirinUI.gold)
                    if let bankInfo = dataLoader.venueStats[race.venue] {
                        MetricPill(title: "BANK", value: "\(bankInfo.bank)m", color: KeirinUI.cyan)
                        MetricPill(title: "DATA", value: "\(bankInfo.races)R", color: KeirinUI.red)
                    }
                }
            }
        }
    }

    private var entryListSection: some View {
        RacingPanel(accent: KeirinUI.gold) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label("出走表", systemImage: "list.number")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                    Spacer()
                    Text("SCORE ORDER")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#111111").opacity(0.45))
                }

                ForEach(race.entries.sorted { $0.score > $1.score }) { entry in
                    EntryRowView(entry: entry)
                }
            }
        }
    }

    private var predictButton: some View {
        Button {
            runPrediction()
        } label: {
            RacingPrimaryButtonLabel(title: "このレースの指数を計算", icon: "waveform.path.ecg")
        }
        .buttonStyle(.plain)
    }

    private var animatingView: some View {
        GlassPanel(cornerRadius: 22, borderColor: KeirinUI.red.opacity(0.35)) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(KeirinUI.cyan.opacity(0.16), lineWidth: 13)
                        .frame(width: 112, height: 112)
                    Circle()
                        .trim(from: 0, to: 0.78)
                        .stroke(KeirinUI.red, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(pulse ? 360 : 0))
                    Text("RUN")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Text("展開とラインを解析中")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            AdaptiveStack(horizontalSpacing: 10, verticalSpacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("INDEX")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(KeirinUI.gold)
                    Text("指数結果")
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .foregroundColor(KeirinUI.paper)
                }
                Button {
                    showResults = false
                    predictions = []
                    bets = []
                    raceAnalysis = nil
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            if let raceAnalysis = raceAnalysis {
                RaceIntelligenceCard(analysis: raceAnalysis)
            }

            let lineFormations = PredictionEngine.analyzeLines(
                entries: race.entries.map { RaceEntry(name: $0.name, waku: $0.umaban) },
                playerStats: dataLoader.playerStats
            )
            if !lineFormations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ライン予測")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(KeirinUI.gold)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(lineFormations.enumerated()), id: \.offset) { (i, line) in
                                LineFormationCard(line: line, isStrongest: i == 0)
                            }
                        }
                    }
                }
            }

            ForEach(Array(predictions.enumerated()), id: \.element.id) { (i, result) in
                ResultCardView(result: result, index: i)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var betSection: some View {
        RacingPanel(accent: KeirinUI.red) {
            VStack(alignment: .leading, spacing: 12) {
                AdaptiveStack(horizontalSpacing: 10, verticalSpacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(KeirinUI.red)
                    Text("注目組み合わせ")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                    Text("\(filteredBets.count)")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(KeirinUI.gold)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["3連単", "2車単", "ワイド"], id: \.self) { type in
                            Button {
                                selectedBetType = type
                            } label: {
                                Text(type)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(selectedBetType == type ? .white : Color(hex: "#111111").opacity(0.66))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(selectedBetType == type ? Color(hex: "#111111") : Color(hex: "#F3F0E9"))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }

                VStack(spacing: 9) {
                    ForEach(filteredBets) { bet in
                        BetCardView(bet: bet)
                    }
                }
            }
        }
    }

    private var filteredBets: [BetRecommendation] {
        bets.filter { $0.type == selectedBetType }
    }

    private func runPrediction() {
        isAnimating = true

        let entries = race.entries.map { e in
            RaceEntry(name: e.name, waku: e.umaban)
        }
        var entryScores: [String: Double] = [:]
        var entryMetrics: [String: RaceEntryMetrics] = [:]
        for e in race.entries {
            entryScores[e.name] = e.score
            entryMetrics[e.name] = e.predictionMetrics
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            predictions = PredictionEngine.predict(
                entries: entries,
                venue: race.venue,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats,
                entryScores: entryScores,
                entryMetrics: entryMetrics,
                lineMatrix: dataLoader.lineMatrix
            )
            let analysis = PredictionEngine.analyzeRace(
                predictions: predictions,
                entries: entries,
                venue: race.venue,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats,
                entryMetrics: entryMetrics,
                lineMatrix: dataLoader.lineMatrix
            )
            raceAnalysis = analysis
            let raceOdds = dataLoader.todayOdds[race.race_id]?.trifecta ?? [:]
            bets = PredictionEngine.generateBets(predictions: predictions, odds: raceOdds)
            let top3Waku = predictions.prefix(3).map { $0.waku }
            tracker.savePrediction(
                raceId: race.race_id, venue: race.venue,
                raceNo: race.raceNo, date: race.dateString,
                predictedTop3: top3Waku,
                playGrade: analysis.playGrade,
                axisWinEstimate: analysis.axisWinEstimate
            )

            withAnimation(.spring(response: 0.54, dampingFraction: 0.76)) {
                isAnimating = false
                showResults = true
            }
        }
    }
}

struct RaceIntelligenceCard: View {
    let analysis: RaceIntelligence

    var body: some View {
        GlassPanel(cornerRadius: 20, borderColor: playColor.opacity(0.38)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("鉄脚先生の判定")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.black.opacity(0.72))
                        Text(analysis.actionReason)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.black.opacity(0.68))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 8)

                    Text(analysis.actionLabel)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(actionColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(12)
                .background(Color.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(actionColor.opacity(0.35), lineWidth: 1)
                )

                AdaptiveStack(horizontalSpacing: 10, verticalSpacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RACE READING")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.cyan)
                        Text(analysis.headline)
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    HStack(spacing: 8) {
                        scoreBlock(title: "勝負", value: analysis.playGrade, color: playColor)
                        scoreBlock(title: "荒れ", value: String(format: "%.0f", analysis.chaosScore), color: chaosColor)
                    }
                }

                MetricPillRow {
                    MetricPill(title: "展開", value: analysis.shapeLabel, color: chaosColor)
                    MetricPill(title: "信頼", value: analysis.confidenceLabel, color: KeirinUI.gold)
                    MetricPill(title: "ペース", value: analysis.paceLabel, color: KeirinUI.cyan)
                    MetricPill(title: "軸目安", value: "\(String(format: "%.0f", analysis.axisWinEstimate))%", color: playColor)
                }

                ProbabilityBar(value: analysis.chaosScore / 100, color: chaosColor)

                Text(analysis.playAdvice)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(playColor)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(analysis.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(KeirinUI.gold)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(note)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.64))
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    private func scoreBlock(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 31, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(minWidth: 45)
    }

    private var chaosColor: Color {
        if analysis.chaosScore >= 68 { return KeirinUI.red }
        if analysis.chaosScore >= 45 { return KeirinUI.gold }
        return KeirinUI.green
    }

    private var playColor: Color {
        switch analysis.playGrade {
        case "S": return KeirinUI.gold
        case "A": return KeirinUI.green
        case "B": return KeirinUI.cyan
        case "C": return Color(hex: "#CD7F32")
        default: return KeirinUI.red
        }
    }

    private var actionColor: Color {
        analysis.actionLabel == "買い" ? KeirinUI.green : KeirinUI.red
    }
}

struct BetCardView: View {
    let bet: BetRecommendation

    var body: some View {
        HStack(spacing: 11) {
            Text(bet.confidence)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 38, height: 38)
                .background(confidenceColor)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(Array(bet.combination.enumerated()), id: \.offset) { (i, waku) in
                        if i > 0 {
                            Image(systemName: bet.type == "ワイド" ? "minus" : "arrow.right")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color(hex: "#111111").opacity(0.35))
                        }
                        LaneBadge(number: waku, size: 30)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(Array(bet.names.enumerated()), id: \.offset) { (i, name) in
                        if i > 0 {
                            Text("-")
                                .foregroundColor(Color(hex: "#111111").opacity(0.25))
                        }
                        Text(String(name.prefix(3)))
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#111111").opacity(0.60))

                if !bet.rationale.isEmpty {
                    Text(bet.rationale)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(KeirinUI.red.opacity(0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", bet.probability))%")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(bet.confidence == "S" ? Color(hex: "#B68000") : Color(hex: "#111111"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let ev = bet.expectedValue {
                        Text("指数 \(String(format: "%.1f", ev))")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(ev > 1.0 ? KeirinUI.green : KeirinUI.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                Text("\(bet.stakeUnits)u")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#111111").opacity(0.42))
            }
        }
        .padding(10)
        .background(bet.confidence == "S" ? KeirinUI.gold.opacity(0.13) : Color(hex: "#F7F6F1"))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(bet.confidence == "S" ? KeirinUI.gold.opacity(0.45) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var confidenceColor: Color {
        switch bet.confidence {
        case "S": return KeirinUI.gold
        case "A": return KeirinUI.cyan
        case "B": return Color(hex: "#CD7F32")
        default: return Color.gray
        }
    }
}

struct LineFormationCard: View {
    let line: PredictionEngine.LineFormation
    let isStrongest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text(line.district)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(isStrongest ? Color(hex: "#B68000") : Color(hex: "#111111"))
                if isStrongest {
                    Text("本線")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(KeirinUI.gold)
                        .clipShape(Capsule())
                }
            }
            ForEach(Array(line.members.enumerated()), id: \.offset) { (_, member) in
                HStack(spacing: 6) {
                    LaneBadge(number: member.waku, size: 25)
                    Text(String(member.name.prefix(3)))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                    Text(member.role)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(member.role == "先行" ? KeirinUI.red : Color(hex: "#111111").opacity(0.50))
                }
            }
        }
        .padding(11)
        .background(isStrongest ? KeirinUI.gold.opacity(0.13) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isStrongest ? KeirinUI.gold.opacity(0.36) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct EntryRowView: View {
    let entry: TodayRaceEntry

    var body: some View {
        HStack(spacing: 11) {
            LaneBadge(number: entry.umaban, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(entry.name)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !entry.style.isEmpty {
                        Text(entry.style)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(styleColor(entry.style))
                    }
                }
                if !entry.comment.isEmpty {
                    Text(entry.comment)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#111111").opacity(0.50))
                        .lineLimit(1)
                }
                ProbabilityBar(value: min(entry.score / 120, 1), color: KeirinUI.cyan)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", entry.score))")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(KeirinUI.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text("WIN \(String(format: "%.0f", entry.winRate))%")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#111111").opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text("3着 \(String(format: "%.0f", entry.top3Rate))%")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#111111").opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(12)
        .background(Color(hex: "#F7F6F1"))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}
