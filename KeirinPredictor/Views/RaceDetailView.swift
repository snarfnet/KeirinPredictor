import SwiftUI

struct RaceDetailView: View {
    @EnvironmentObject var dataLoader: DataLoader
    let race: TodayRace

    @State private var predictions: [PredictionResult] = []
    @State private var bets: [BetRecommendation] = []
    @State private var isAnimating = false
    @State private var showResults = false

    @State private var selectedBetType = "3連単"

    var body: some View {
        ZStack {
            Color(hex: "#0A0E27").ignoresSafeArea()

            ScrollView {
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

                    BannerAdView()
                        .frame(height: 50)
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("\(race.venue) \(race.raceNo)R")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var raceHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(race.venue) \(race.raceNo)R")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                    Text("\(race.entries.count)車立")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                if let bankInfo = dataLoader.venueStats[race.venue] {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(bankInfo.bank)m")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("バンク")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    private var entryListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("出走表")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))

            ForEach(race.entries) { entry in
                EntryRowView(entry: entry)
            }
        }
    }

    private var predictButton: some View {
        Button {
            runPrediction()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                Text("予測開始")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .foregroundColor(.black)
            .cornerRadius(12)
            .shadow(color: Color(hex: "#FFD700").opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }

    private var animatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "#FFD700"))
            Text("予測中...")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))
        }
        .padding(40)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("予測結果")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
                Button("リセット") {
                    showResults = false
                    predictions = []
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            }

            // Line formations
            let districts = Dictionary(grouping: predictions.filter { !$0.district.isEmpty }, by: { $0.district })
            if districts.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(districts.keys.sorted(), id: \.self) { dist in
                            LinePartyView(district: dist, members: districts[dist] ?? [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            ForEach(Array(predictions.enumerated()), id: \.element.id) { (i, result) in
                ResultCardView(result: result, index: i)
            }
        }
    }

    private var betSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "yensign.circle.fill")
                    .foregroundColor(Color(hex: "#FFD700"))
                Text("推奨買い目")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
                Text("\(filteredBets.count)点")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Bet type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["3連単", "2車単", "ワイド"], id: \.self) { type in
                        Button {
                            selectedBetType = type
                        } label: {
                            Text(type)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(selectedBetType == type ? .black : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedBetType == type ? Color(hex: "#FFD700") : Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            ForEach(filteredBets) { bet in
                BetCardView(bet: bet)
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
        for e in race.entries {
            entryScores[e.name] = e.score
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            predictions = PredictionEngine.predict(
                entries: entries,
                venue: race.venue,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats,
                entryScores: entryScores
            )
            let raceOdds = dataLoader.todayOdds[race.race_id]?.trifecta ?? [:]
            bets = PredictionEngine.generateBets(predictions: predictions, odds: raceOdds)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = false
                showResults = true
            }
        }
    }
}

// MARK: - Bet Card
struct BetCardView: View {
    let bet: BetRecommendation

    var body: some View {
        HStack(spacing: 10) {
            // Confidence badge
            Text(bet.confidence)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
                .background(confidenceColor)
                .cornerRadius(6)

            // Combination
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    ForEach(Array(bet.combination.enumerated()), id: \.offset) { (i, waku) in
                        if i > 0 {
                            Image(systemName: bet.type == "ワイド" ? "minus" : "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Text("\(waku)")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 28, height: 28)
                            .background(wakuColor(waku))
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(Array(bet.names.enumerated()), id: \.offset) { (i, name) in
                        if i > 0 {
                            Text("-")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        Text(String(name.prefix(3)))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Probability
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", bet.probability))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(bet.confidence == "S" ? Color(hex: "#FFD700") : .white)
                if let ev = bet.expectedValue {
                    Text("EV \(String(format: "%.1f", ev))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(ev > 1.0 ? .green : .red)
                }
            }
        }
        .padding(12)
        .background(bet.confidence == "S" ? Color(hex: "#FFD700").opacity(0.08) : Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(bet.confidence == "S" ? Color(hex: "#FFD700").opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var confidenceColor: Color {
        switch bet.confidence {
        case "S": return Color(hex: "#FFD700")
        case "A": return Color(hex: "#C0C0C0")
        case "B": return Color(hex: "#CD7F32")
        default: return Color.gray
        }
    }
}

struct EntryRowView: View {
    let entry: TodayRaceEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.umaban)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 30, height: 30)
                .background(wakuColor(entry.waku))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(entry.style)
                        .font(.system(size: 13))
                        .foregroundColor(styleColor(entry.style))
                }
                if !entry.comment.isEmpty {
                    Text(entry.comment)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", entry.score))点")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Text("勝率\(String(format: "%.0f", entry.winRate))%")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}
