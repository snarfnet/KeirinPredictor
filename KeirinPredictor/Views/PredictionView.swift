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

    private var venues: [String] {
        Array(dataLoader.venueStats.keys).sorted()
    }

    private var playerCount: Int {
        playerNames.filter { !$0.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerBanner

                        venueSection

                        playerInputSection

                        predictButton

                        if showResults {
                            resultsSection
                        }

                        if showBannerAd {
                            BannerAdView()
                                .frame(height: 50)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("KEIRIN PREDICTOR")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
    }

    // MARK: - Header
    private var headerBanner: some View {
        HStack(spacing: 8) {
            Image("HakaseAvatar")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            Text("鉄脚博士のAI予測")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("\(dataLoader.playerStats.count)選手")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Venue selector
    private var venueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("競輪場", systemImage: "mappin.circle")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))

            Menu {
                ForEach(venues, id: \.self) { v in
                    Button(v) { selectedVenue = v }
                }
            } label: {
                HStack {
                    Text(selectedVenue.isEmpty ? "競輪場を選択..." : selectedVenue)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(selectedVenue.isEmpty ? .white.opacity(0.4) : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                .padding(12)
                .background(Color.white.opacity(0.07))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
                )
            }

            if let info = dataLoader.venueStats[selectedVenue] {
                HStack(spacing: 12) {
                    Label("\(info.bank)m", systemImage: "arrow.triangle.2.circlepath")
                    Text("|\(info.races)レース")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Player input
    private var playerInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("出走選手 (最大9名)", systemImage: "person.3")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
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
                .tint(Color(hex: "#FFD700"))
            }

            ForEach(0..<playerNames.count, id: \.self) { i in
                HStack(spacing: 8) {
                    Text("\(i+1)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .frame(width: 24)

                    PlayerAutocompleteField(
                        text: $playerNames[i],
                        players: Array(dataLoader.playerStats.keys),
                        placeholder: "\(i+1)番 選手名"
                    )
                }
            }
        }
    }

    // MARK: - Predict button
    private var predictButton: some View {
        Button {
            runPrediction()
        } label: {
            HStack(spacing: 10) {
                if isAnimating {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(isAnimating ? "分析中..." : "予測開始 / PREDICT")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.black)
            .cornerRadius(12)
            .shadow(color: Color(hex: "#FFD700").opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(selectedVenue.isEmpty || playerCount < 3 || isAnimating)
        .opacity(selectedVenue.isEmpty || playerCount < 3 ? 0.5 : 1)
    }

    // MARK: - Results
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PREDICTION RESULT")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
                Text(selectedVenue)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Line party formations
            let districts = Dictionary(grouping: results.filter { !$0.district.isEmpty }, by: { $0.district })
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

            ForEach(Array(results.enumerated()), id: \.element.id) { (i, result) in
                ResultCardView(result: result, index: i)
                    .offset(y: cardOffsets[safe: i] ?? 0)
            }
        }
    }

    // MARK: - Prediction logic
    private func runPrediction() {
        let entries = playerNames.enumerated().compactMap { (i, name) -> RaceEntry? in
            guard !name.isEmpty else { return nil }
            return RaceEntry(name: name, waku: i + 1)
        }
        guard entries.count >= 3 else { return }

        isAnimating = true
        showResults = false

        // Animate cards shuffling
        for i in 0..<9 {
            cardOffsets[i] = CGFloat.random(in: -20...20)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            results = PredictionEngine.predict(
                entries: entries,
                venue: selectedVenue,
                playerStats: dataLoader.playerStats,
                venueStats: dataLoader.venueStats
            )

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                for i in 0..<9 { cardOffsets[i] = 0 }
                showResults = true
                isAnimating = false
            }
        }
    }
}

// MARK: - Line Party View
struct LinePartyView: View {
    let district: String
    let members: [PredictionResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(district)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700"))
            HStack(spacing: 5) {
                ForEach(members.sorted(by: { $0.predRank < $1.predRank })) { m in
                    VStack(spacing: 2) {
                        Text("\(m.waku)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 26, height: 26)
                            .background(wakuColor(m.waku))
                            .clipShape(Circle())
                        Text(String(m.name.prefix(2)))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }
}

// MARK: - Result Card
struct ResultCardView: View {
    let result: PredictionResult
    let index: Int

    @State private var glowOpacity: Double = 0.5

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankGradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: rankShadow, radius: index == 0 ? 8 : 0)

                Text("\(result.predRank)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(index == 0 ? .black : .white)
            }

            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(result.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    if !result.classRank.isEmpty {
                        ClassBadge(classRank: result.classRank)
                    }
                    if result.isDarkHorse {
                        Text("DARK HORSE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    if !result.district.isEmpty {
                        Text(result.district)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if !result.style.isEmpty {
                        Text(result.style)
                            .font(.system(size: 13))
                            .foregroundColor(styleColor(result.style))
                    }
                    if let avg = result.recentAvg {
                        Text("直近\(String(format: "%.1f", avg))着")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if result.formScore > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text(String(format: "%.0f", result.formScore))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(result.formScore >= 7 ? .orange : .white.opacity(0.4))
                    }
                }
            }

            Spacer()

            // Win prob
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", result.winProb))%")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(index == 0 ? Color(hex: "#FFD700") : .white)
                Text("勝率\(String(format: "%.1f", result.winRate))%")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: index == 0 ? 1.5 : 0.5)
        )
        .overlay {
            if result.isDarkHorse {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(glowOpacity), lineWidth: 2)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowOpacity)
            }
        }
        .onAppear {
            if result.isDarkHorse { glowOpacity = 1.0 }
        }
    }

    private var rankGradient: LinearGradient {
        switch index {
        case 0: return LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 1: return LinearGradient(colors: [Color(hex: "#C0C0C0"), Color(hex: "#A0A0A0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: return LinearGradient(colors: [Color(hex: "#CD7F32"), Color(hex: "#A0522D")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var rankShadow: Color {
        index == 0 ? Color(hex: "#FFD700").opacity(0.6) : .clear
    }

    private var cardBackground: some ShapeStyle {
        if index == 0 {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "#FFD700").opacity(0.12), Color(hex: "#0A0E27")],
                startPoint: .leading,
                endPoint: .trailing
            ))
        }
        return AnyShapeStyle(Color.white.opacity(0.05))
    }

    private var cardBorder: Color {
        switch index {
        case 0: return Color(hex: "#FFD700").opacity(0.6)
        case 1: return Color(hex: "#C0C0C0").opacity(0.4)
        case 2: return Color(hex: "#CD7F32").opacity(0.4)
        default: return Color.white.opacity(0.1)
        }
    }
}

// MARK: - Class Badge
struct ClassBadge: View {
    let classRank: String

    var body: some View {
        Text(classRank)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(badgeColor)
            .cornerRadius(4)
    }

    private var badgeColor: Color {
        switch classRank {
        case "S1", "S2": return Color(hex: "#FFD700")
        case "A1": return Color(hex: "#C0C0C0")
        case "A2": return Color(hex: "#CD7F32")
        default: return Color.gray
        }
    }
}

// MARK: - Player Autocomplete Field
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
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.07))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FFD700").opacity(isFocused ? 0.5 : 0.15), lineWidth: 1)
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
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        if s != suggestions.last {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color(hex: "#1A1E3A"))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.5), radius: 8)
                .zIndex(100)
            }
        }
    }
}

// MARK: - Helpers
func wakuColor(_ waku: Int) -> Color {
    let colors: [Color] = [
        Color(hex: "#FFFFFF"),
        Color(hex: "#000000"),
        Color(hex: "#FF0000"),
        Color(hex: "#0000FF"),
        Color(hex: "#FFFF00"),
        Color(hex: "#00AA00"),
        Color(hex: "#FF6600"),
        Color(hex: "#FF69B4"),
    ]
    return colors[safe: waku] ?? .gray
}

func styleColor(_ style: String) -> Color {
    switch style {
    case "逃": return Color(hex: "#FF4444")
    case "捲": return Color(hex: "#FF8C00")
    case "差": return Color(hex: "#4488FF")
    case "追": return Color(hex: "#44CC88")
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
