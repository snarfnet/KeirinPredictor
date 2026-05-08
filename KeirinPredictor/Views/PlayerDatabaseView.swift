import SwiftUI

struct PlayerDatabaseView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @State private var searchText = ""
    @State private var filterDistrict = ""
    @State private var filterStyle = ""
    @State private var selectedPlayer: String? = nil

    private let districts = ["", "北日本", "関東", "南関東", "中部", "近畿", "中国", "四国", "九州"]
    private let styles = ["", "逃", "捲", "差", "追", "両"]

    private var filteredPlayers: [(String, PlayerStats)] {
        dataLoader.playerStats
            .filter { (name, stat) in
                let matchSearch = searchText.isEmpty || name.contains(searchText)
                let matchDistrict = filterDistrict.isEmpty || stat.district == filterDistrict
                let matchStyle = filterStyle.isEmpty || stat.style == filterStyle
                return matchSearch && matchDistrict && matchStyle
            }
            .sorted { $0.1.winRate > $1.1.winRate }
            .prefix(100)
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "#FFD700").opacity(0.6))
                        TextField("選手名を検索...", text: $searchText)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "地区", options: districts, selected: $filterDistrict)
                            FilterChip(title: "脚質", options: styles, selected: $filterStyle)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    // Count
                    HStack {
                        Text("\(filteredPlayers.count)選手表示")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    // Player list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredPlayers, id: \.0) { (name, stat) in
                                PlayerCardView(name: name, stat: stat)
                                    .onTapGesture { selectedPlayer = name }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PLAYER DATABASE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
            .sheet(item: Binding(
                get: { selectedPlayer.map { PlayerWrapper(name: $0) } },
                set: { selectedPlayer = $0?.name }
            )) { wrapper in
                PlayerDetailView(name: wrapper.name, stat: dataLoader.playerStats[wrapper.name])
            }
        }
    }
}

struct PlayerWrapper: Identifiable {
    var id: String { name }
    let name: String
}

// MARK: - Player Card (RPG style)
struct PlayerCardView: View {
    let name: String
    let stat: PlayerStats

    var body: some View {
        HStack(spacing: 12) {
            // Waku-style rank indicator
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(classColor)
                    .frame(width: 36, height: 36)
                Text(stat.classRank.isEmpty ? "?" : stat.classRank)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .minimumScaleFactor(0.6)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(stat.style)
                        .font(.system(size: 11))
                        .foregroundColor(styleColor(stat.style))
                }
                Text("\(stat.district) \(stat.prefecture)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            // Mini RPG stats
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    MiniStatBar(value: stat.rpg.atk, color: Color(hex: "#FF4444"), label: "A")
                    MiniStatBar(value: stat.rpg.def, color: Color(hex: "#4488FF"), label: "D")
                }
                HStack(spacing: 4) {
                    MiniStatBar(value: stat.rpg.spd, color: Color(hex: "#44CC88"), label: "S")
                    MiniStatBar(value: stat.rpg.lck, color: Color(hex: "#CC44CC"), label: "L")
                }
                Text("\(String(format: "%.1f", stat.winRate * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(classColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var classColor: Color {
        switch stat.classRank {
        case "S1", "S2": return Color(hex: "#FFD700")
        case "A1": return Color(hex: "#C0C0C0")
        case "A2": return Color(hex: "#CD7F32")
        default: return Color.gray.opacity(0.5)
        }
    }
}

struct MiniStatBar: View {
    let value: Int
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(value) / 100, height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 30, height: 10)
        }
    }
}

struct FilterChip: View {
    let title: String
    let options: [String]
    @Binding var selected: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(opt.isEmpty ? "すべて" : opt) { selected = opt }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selected.isEmpty ? title : selected)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(selected.isEmpty ? .white.opacity(0.6) : .black)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(selected.isEmpty ? .white.opacity(0.6) : .black)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected.isEmpty ? Color.white.opacity(0.08) : Color(hex: "#FFD700"))
            .cornerRadius(20)
        }
    }
}

// MARK: - Player Detail Sheet
struct PlayerDetailView: View {
    let name: String
    let stat: PlayerStats?

    var body: some View {
        ZStack {
            Color(hex: "#0A0E27").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                        if let s = stat {
                            HStack(spacing: 8) {
                                ClassBadge(classRank: s.classRank)
                                Text(s.district)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(s.style)
                                    .font(.system(size: 13))
                                    .foregroundColor(styleColor(s.style))
                            }
                        }
                    }
                    .padding(.top, 24)

                    if let s = stat {
                        // RPG Stats Card
                        VStack(spacing: 12) {
                            Text("RPG STATS")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(Color(hex: "#FFD700"))

                            HStack(spacing: 20) {
                                RPGStatItem(label: "ATK", value: s.rpg.atk, color: Color(hex: "#FF4444"))
                                RPGStatItem(label: "DEF", value: s.rpg.def, color: Color(hex: "#4488FF"))
                                RPGStatItem(label: "SPD", value: s.rpg.spd, color: Color(hex: "#44CC88"))
                                RPGStatItem(label: "LCK", value: s.rpg.lck, color: Color(hex: "#CC44CC"))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#FFD700").opacity(0.2), lineWidth: 1)
                        )

                        // Race stats
                        HStack(spacing: 12) {
                            StatBox(label: "出走", value: "\(s.races)")
                            StatBox(label: "勝利", value: "\(s.wins)")
                            StatBox(label: "勝率", value: "\(String(format: "%.1f", s.winRate * 100))%")
                            StatBox(label: "3連対", value: "\(String(format: "%.1f", s.top3Rate * 100))%")
                        }

                        // Recent ranks
                        if !s.recentRanks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("直近着順")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#FFD700"))
                                HStack(spacing: 6) {
                                    ForEach(Array(s.recentRanks.prefix(10).enumerated()), id: \.offset) { _, rank in
                                        ZStack {
                                            Circle()
                                                .fill(rankColor(rank))
                                                .frame(width: 28, height: 28)
                                            Text("\(rank)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }

                        // Venue stats top 5
                        if !s.venueStats.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("競輪場別成績 TOP5")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#FFD700"))
                                ForEach(s.venueStats.sorted { $0.value.winRate > $1.value.winRate }.prefix(5), id: \.key) { (venue, vr) in
                                    HStack {
                                        Text(venue)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(vr.wins)/\(vr.races)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("\(String(format: "%.1f", vr.winRate * 100))%")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(hex: "#FFD700"))
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RPGStatItem: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 3)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

func rankColor(_ rank: Int) -> Color {
    switch rank {
    case 1: return Color(hex: "#FFD700")
    case 2: return Color(hex: "#C0C0C0")
    case 3: return Color(hex: "#CD7F32")
    default: return Color.white.opacity(0.15)
    }
}
