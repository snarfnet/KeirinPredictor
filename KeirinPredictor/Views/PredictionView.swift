import SwiftUI

struct PredictionView: View {
    @EnvironmentObject var dataLoader: DataLoader

    @State private var selectedVenue = ""
    @State private var playerNames: [String] = Array(repeating: "", count: 7)
    @State private var wakuNumbers: [Int] = Array(1...7)
    @State private var results: [PredictionResult] = []
    @State private var isAnimating = false
    @State private var showResults = false
    @State private var cardOffsets: [CGFloat] = Array(repeating: 0, count: 9)
    @State private var showBannerAd = true
    @State private var pulse = false

    private var venues: [String] {
        Array(dataLoader.venueStats.keys).sorted()
    }

    private var playerCount: Int {
        playerNames.filter { !$0.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinStageBackground()

                CompactAwareScroll {
                    VStack(spacing: 18) {
                        commandHeader
                        venueSection
                        playerInputSection
                        predictButton

                        if isAnimating {
                            analyzingPanel
                        }

                        if showResults {
                            resultsSection
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showBannerAd {
                    FixedTopAdView()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DATA LAB")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#151515"))
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KeirinUI.lightBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var commandHeader: some View {
        GlassPanel(cornerRadius: 24, borderColor: KeirinUI.cyan.opacity(0.28)) {
            AdaptiveStack(horizontalSpacing: 14, verticalSpacing: 12) {
                ZStack {
                    Circle()
                        .stroke(KeirinUI.cyan.opacity(pulse ? 0.42 : 0.14), lineWidth: 8)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(KeirinUI.red)
                        .frame(width: 18, height: 18)
                        .shadow(color: KeirinUI.red.opacity(0.8), radius: pulse ? 18 : 6)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("RACE ANALYZER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(KeirinUI.cyan)
                    Text("出走表から勝ち筋を読む")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(dataLoader.playerStats.count) 選手データ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.46))
                }

            }
        }
    }

    private var venueSection: some View {
        GlassPanel(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Label("競輪場", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(KeirinUI.gold)

                Menu {
                    ForEach(venues, id: \.self) { v in
                        Button(v) { selectedVenue = v }
                    }
                } label: {
                    HStack {
                        Text(selectedVenue.isEmpty ? "競輪場を選択" : selectedVenue)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(selectedVenue.isEmpty ? .white.opacity(0.42) : .white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(KeirinUI.cyan)
                    }
                    .padding(13)
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(selectedVenue.isEmpty ? Color.white.opacity(0.10) : KeirinUI.cyan.opacity(0.45), lineWidth: 1)
                    )
                }

                if let info = dataLoader.venueStats[selectedVenue] {
                    HStack(spacing: 8) {
                        MetricPill(title: "BANK", value: "\(info.bank)m", color: KeirinUI.cyan)
                        MetricPill(title: "DATA", value: "\(info.races)R", color: KeirinUI.gold)
                    }
                }
            }
        }
    }

    private var playerInputSection: some View {
        GlassPanel(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("出走選手", systemImage: "rectangle.grid.3x2.fill")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(KeirinUI.gold)
                    Spacer()
                    Text("\(playerCount)/\(playerNames.count)")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(playerCount >= 3 ? KeirinUI.green : KeirinUI.red)
                    Stepper("", value: Binding(
                        get: { playerNames.count },
                        set: { newCount in
                            let n = min(9, max(3, newCount))
                            let current = playerNames.count
                            if n > current {
                                playerNames.append(contentsOf: Array(repeating: "", count: n - current))
                            } else {
                                playerNames = Array(playerNames.prefix(n))
                            }
                            wakuNumbers = Array(1...n)
                        }
                    ), in: 3...9)
                    .labelsHidden()
                    .tint(KeirinUI.gold)
                }

                VStack(spacing: 9) {
                    ForEach(0..<playerNames.count, id: \.self) { i in
                        HStack(spacing: 10) {
                            LaneBadge(number: i + 1, size: 32)
                            PlayerAutocompleteField(
                                text: $playerNames[i],
                                players: Array(dataLoader.playerStats.keys),
                                placeholder: "\(i + 1)番 選手名"
                            )
                        }
                    }
                }
            }
        }
    }

    private var predictButton: some View {
        Button {
            runPrediction()
        } label: {
            RacingPrimaryButtonLabel(
                title: isAnimating ? "解析中..." : "指数を計算",
                icon: "bolt.fill",
                isLoading: isAnimating
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedVenue.isEmpty || playerCount < 3 || isAnimating)
        .opacity(selectedVenue.isEmpty || playerCount < 3 ? 0.45 : 1)
    }

    private var analyzingPanel: some View {
        GlassPanel(cornerRadius: 20, borderColor: KeirinUI.red.opacity(0.36)) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(KeirinUI.red.opacity(0.18), lineWidth: 12)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(KeirinUI.gold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(pulse ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
                    Text("RUN")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text("ラインと脚質を照合中")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            resultHero

            let districts = Dictionary(grouping: results.filter { !$0.district.isEmpty }, by: { $0.district })
            if districts.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(districts.keys.sorted(), id: \.self) { dist in
                            LinePartyView(district: dist, members: districts[dist] ?? [])
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { (i, result) in
                ResultCardView(result: result, index: i)
                    .offset(y: cardOffsets[safe: i] ?? 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var resultHero: some View {
        let top = results.first

        return GlassPanel(cornerRadius: 24, borderColor: KeirinUI.gold.opacity(0.42)) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INDEX RESULT")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.gold)
                        Text(top?.name ?? "RESULT")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer()
                    if let top = top {
                        VStack(spacing: 3) {
                            LaneBadge(number: top.waku, size: 44)
                            Text("本命")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(KeirinUI.gold)
                        }
                    }
                }

                if let top = top {
                    MetricPillRow {
                        MetricPill(title: "WIN", value: "\(String(format: "%.1f", top.winProb))%", color: KeirinUI.gold)
                        MetricPill(title: "SCORE", value: "\(String(format: "%.0f", top.score))", color: KeirinUI.red)
                        MetricPill(title: "FORM", value: "\(String(format: "%.0f", top.formScore))", color: KeirinUI.cyan)
                    }
                    ProbabilityBar(value: top.winProb / 100, color: KeirinUI.gold)
                }
            }
        }
    }

    private func runPrediction() {
        let entries = playerNames.enumerated().compactMap { (i, name) -> RaceEntry? in
            guard !name.isEmpty else { return nil }
            return RaceEntry(name: name, waku: i + 1)
        }
        guard entries.count >= 3 else { return }

        isAnimating = true
        showResults = false

        for i in 0..<9 {
            cardOffsets[i] = CGFloat.random(in: -20...20)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            results = PredictionEngine.predict(
                entries: entries,
                venue: selectedVenue,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats,
                lineMatrix: dataLoader.lineMatrix
            )

            withAnimation(.spring(response: 0.62, dampingFraction: 0.72)) {
                for i in 0..<9 { cardOffsets[i] = 0 }
                showResults = true
                isAnimating = false
            }
        }
    }
}

struct LinePartyView: View {
    let district: String
    let members: [PredictionResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(district)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(KeirinUI.cyan)
            HStack(spacing: 6) {
                ForEach(members.sorted(by: { $0.predRank < $1.predRank })) { m in
                    VStack(spacing: 4) {
                        LaneBadge(number: m.waku, size: 28)
                        Text(String(m.name.prefix(2)))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.68))
                    }
                }
            }
        }
        .padding(11)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KeirinUI.cyan.opacity(0.16), lineWidth: 1)
        )
    }
}

struct ResultCardView: View {
    let result: PredictionResult
    let index: Int

    @State private var glowOpacity: Double = 0.25

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(rankGradient)
                    .frame(width: 58, height: 70)
                    .shadow(color: rankShadow, radius: index == 0 ? 18 : 6, x: 0, y: 8)
                VStack(spacing: -2) {
                    Text("\(result.predRank)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                    Text(rankLabel)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                }
                .foregroundColor(index == 0 ? .black : .white)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    LaneBadge(number: result.waku, size: 28)
                    Text(result.name)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !result.classRank.isEmpty {
                        ClassBadge(classRank: result.classRank)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if !result.district.isEmpty {
                            Text(result.district)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        if !result.style.isEmpty {
                            Text(result.style)
                                .foregroundColor(styleColor(result.style))
                        }
                        if result.isDarkHorse {
                            Text("穴")
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(KeirinUI.cyan)
                                .clipShape(Capsule())
                        }
                        if !result.lineRole.isEmpty {
                            Text(result.lineRole)
                                .foregroundColor(KeirinUI.gold)
                        }
                        if result.riskLabel != "標準" {
                            Text(result.riskLabel)
                                .foregroundColor(result.riskLabel == "穴注意" ? KeirinUI.cyan : KeirinUI.gold)
                        }
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                }

                if !result.signals.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(result.signals) { signal in
                                PredictionSignalChip(signal: signal)
                            }
                        }
                    }
                }

                ProbabilityBar(value: result.winProb / 100, color: index == 0 ? KeirinUI.gold : KeirinUI.cyan)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", result.winProb))%")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(index == 0 ? KeirinUI.gold : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text("WIN")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.38))
            }
        }
        .padding(11)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder.opacity(glowOpacity), lineWidth: index == 0 ? 2 : 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                glowOpacity = index == 0 || result.isDarkHorse ? 1.0 : 0.35
            }
        }
    }

    private var rankLabel: String {
        index == 0 ? "AXIS" : index == 1 ? "2ND" : index == 2 ? "3RD" : "RANK"
    }

    private var rankGradient: LinearGradient {
        switch index {
        case 0: return LinearGradient(colors: [KeirinUI.gold, Color(hex: "#FF7A18")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 1: return LinearGradient(colors: [KeirinUI.cyan, Color(hex: "#216BFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: return LinearGradient(colors: [KeirinUI.red, Color(hex: "#7A1CFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var rankShadow: Color {
        switch index {
        case 0: return KeirinUI.gold.opacity(0.45)
        case 1: return KeirinUI.cyan.opacity(0.28)
        case 2: return KeirinUI.red.opacity(0.26)
        default: return .black.opacity(0.22)
        }
    }

    private var cardBackground: some ShapeStyle {
        if index == 0 {
            return AnyShapeStyle(LinearGradient(
                colors: [KeirinUI.gold.opacity(0.16), KeirinUI.panel.opacity(0.94)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        }
        return AnyShapeStyle(KeirinUI.panel.opacity(0.86))
    }

    private var cardBorder: Color {
        if result.isDarkHorse { return KeirinUI.cyan }
        switch index {
        case 0: return KeirinUI.gold
        case 1: return KeirinUI.cyan
        case 2: return KeirinUI.red
        default: return Color.white.opacity(0.18)
        }
    }
}

struct PredictionSignalChip: View {
    let signal: PredictionSignal

    var body: some View {
        HStack(spacing: 4) {
            Text(signal.title)
                .foregroundColor(.white.opacity(0.48))
            Text(signal.value)
                .foregroundColor(signalColor)
        }
        .font(.system(size: 10, weight: .black, design: .rounded))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(signalColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(signalColor.opacity(0.22), lineWidth: 1)
        )
    }

    private var signalColor: Color {
        switch signal.tone {
        case "gold": return KeirinUI.gold
        case "green": return KeirinUI.green
        case "red": return KeirinUI.red
        default: return KeirinUI.cyan
        }
    }
}

struct ClassBadge: View {
    let classRank: String

    var body: some View {
        Text(classRank)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var badgeColor: Color {
        switch classRank {
        case "S1", "S2": return KeirinUI.gold
        case "A1": return KeirinUI.cyan
        case "A2": return Color(hex: "#CD7F32")
        default: return Color.gray
        }
    }
}

struct PlayerAutocompleteField: View {
    @Binding var text: String
    let players: [String]
    let placeholder: String

    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFocused ? KeirinUI.cyan.opacity(0.62) : Color.white.opacity(0.10), lineWidth: 1)
                )
                .focused($isFocused)
                .onChange(of: text) { _, newVal in
                    if newVal.count >= 1 {
                        suggestions = players.filter { $0.contains(newVal) }.prefix(5).map { $0 }
                        showSuggestions = !suggestions.isEmpty
                    } else {
                        showSuggestions = false
                    }
                }

            if showSuggestions && isFocused {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { s in
                        Button {
                            text = s
                            showSuggestions = false
                            isFocused = false
                        } label: {
                            Text(s)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                        }
                        if s != suggestions.last {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(KeirinUI.panelBright)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.55), radius: 10)
                .zIndex(100)
            }
        }
    }
}

func wakuColor(_ waku: Int) -> Color {
    let colors: [Color] = [
        Color(hex: "#FFFFFF"),
        Color(hex: "#111111"),
        Color(hex: "#E62020"),
        Color(hex: "#1D56FF"),
        Color(hex: "#FFE100"),
        Color(hex: "#00A651"),
        Color(hex: "#FF7A18"),
        Color(hex: "#FF4FA3"),
    ]
    return colors[safe: max(0, min(waku - 1, colors.count - 1))] ?? .gray
}

func styleColor(_ style: String) -> Color {
    switch style {
    case "逃": return KeirinUI.red
    case "捲": return Color(hex: "#FF8C00")
    case "差": return KeirinUI.cyan
    case "追": return KeirinUI.green
    default: return .white
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
