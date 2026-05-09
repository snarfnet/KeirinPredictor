import SwiftUI

struct RaceDetailView: View {
    @EnvironmentObject var dataLoader: DataLoader
    let race: TodayRace

    @State private var predictions: [PredictionResult] = []
    @State private var isAnimating = false
    @State private var showResults = false
    @State private var showBattle = false

    var body: some View {
        ZStack {
            Color(hex: "#0A0E27").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    raceHeader

                    if showResults {
                        resultsSection
                        battleButton
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
        .sheet(isPresented: $showBattle) {
            BattleView(race: race, predictions: predictions)
                .environmentObject(dataLoader)
        }
    }

    private var raceHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(race.venue) \(race.raceNo)R")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                    Text("\(race.entries.count)車立")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                if let bankInfo = dataLoader.venueStats[race.venue] {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(bankInfo.bank)m")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("バンク")
                            .font(.system(size: 10))
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
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
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
                    .font(.system(size: 16, weight: .black, design: .monospaced))
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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))
        }
        .padding(40)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("予測結果")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
                Button("リセット") {
                    showResults = false
                    predictions = []
                }
                .font(.system(size: 12, design: .monospaced))
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

    private var battleButton: some View {
        Button {
            showBattle = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                Text("RPGバトルで見る")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple.opacity(0.5), lineWidth: 1)
            )
        }
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = false
                showResults = true
            }
        }
    }
}

// MARK: - RPG Battle View (auto-populated from race data)
struct BattleView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @Environment(\.dismiss) var dismiss
    let race: TodayRace
    let predictions: [PredictionResult]

    @State private var currentMatchIndex = 0
    @State private var battleLog: [String] = []
    @State private var isBattling = false
    @State private var battleFinished = false
    @State private var timer: Timer?

    private var sortedPredictions: [PredictionResult] {
        predictions.sorted { $0.score > $1.score }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("\(race.venue) \(race.raceNo)R BATTLE")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700"))

                        if !battleFinished {
                            battleArena
                        }

                        if !battleLog.isEmpty {
                            battleLogSection
                        }

                        if battleFinished {
                            finalRankingSection
                        }

                        if !isBattling && !battleFinished {
                            Button {
                                startBattle()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "flame.fill")
                                    Text("バトル開始")
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.red, Color.orange],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
    }

    private var battleArena: some View {
        VStack(spacing: 12) {
            if sortedPredictions.count >= 2 && currentMatchIndex < sortedPredictions.count - 1 {
                let p1 = sortedPredictions[currentMatchIndex]
                let p2 = sortedPredictions[min(currentMatchIndex + 1, sortedPredictions.count - 1)]

                HStack(spacing: 20) {
                    fighterCard(p1, side: "LEFT")
                    Text("VS")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    fighterCard(p2, side: "RIGHT")
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    private func fighterCard(_ p: PredictionResult, side: String) -> some View {
        VStack(spacing: 6) {
            Text("\(p.waku)")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
                .background(wakuColor(p.waku))
                .clipShape(Circle())

            Text(p.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            if let rpg = p.rpg {
                VStack(spacing: 2) {
                    statBar("ATK", value: rpg.atk, color: .red)
                    statBar("DEF", value: rpg.def, color: .blue)
                    statBar("SPD", value: rpg.spd, color: .green)
                    statBar("LCK", value: rpg.lck, color: .yellow)
                }
            }

            Text("\(String(format: "%.1f", p.winProb))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))
        }
        .frame(maxWidth: .infinity)
    }

    private func statBar(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(min(value, 100)) / 100)
                }
            }
            .frame(height: 6)
            Text("\(value)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20, alignment: .trailing)
        }
    }

    private var battleLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BATTLE LOG")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))

            ForEach(Array(battleLog.suffix(8).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }

    private var finalRankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINAL RANKING")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))

            ForEach(Array(sortedPredictions.enumerated()), id: \.element.id) { (i, result) in
                ResultCardView(result: result, index: i)
            }
        }
    }

    private func startBattle() {
        isBattling = true
        currentMatchIndex = 0
        battleLog = []

        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { t in
            guard currentMatchIndex < sortedPredictions.count - 1 else {
                t.invalidate()
                battleLog.append(">> バトル終了！")
                withAnimation {
                    isBattling = false
                    battleFinished = true
                }
                return
            }

            let p1 = sortedPredictions[currentMatchIndex]
            let p2 = sortedPredictions[currentMatchIndex + 1]

            let attacks = ["の猛攻！", "がスパート！", "の捲り！", "の差し！", "の逃げ切り！"]
            let attack = attacks.randomElement() ?? "の攻撃！"

            withAnimation {
                battleLog.append("\(p1.name)\(attack) → \(p2.name)に勝利")
                currentMatchIndex += 1
            }
        }
    }
}

struct EntryRowView: View {
    let entry: TodayRaceEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.umaban)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 26, height: 26)
                .background(wakuColor(entry.waku))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(entry.style)
                        .font(.system(size: 11))
                        .foregroundColor(styleColor(entry.style))
                }
                if !entry.comment.isEmpty {
                    Text(entry.comment)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", entry.score))点")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Text("勝率\(String(format: "%.0f", entry.winRate))%")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}
