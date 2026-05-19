import SwiftUI

struct VenueInfoView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @State private var selectedVenue: String? = nil

    private var sortedVenues: [(String, VenueStats)] {
        dataLoader.venueStats.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KeirinUI.lightBackground.ignoresSafeArea()

                if let venue = selectedVenue, let stats = dataLoader.venueStats[venue] {
                    VenueDetailView(name: venue, stats: stats, onBack: { selectedVenue = nil })
                } else {
                    venueList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("競輪場")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#111111"))
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KeirinUI.lightBackground, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private var venueList: some View {
        CompactAwareScroll {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(sortedVenues, id: \.0) { (name, stats) in
                    VenueCardTile(name: name, stats: stats)
                        .onTapGesture { selectedVenue = name }
                }
            }
        }
    }
}

struct VenueCardTile: View {
    let name: String
    let stats: VenueStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "#111111"))
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                Text("\(stats.bank)m")
                    .font(.system(size: 12, design: .monospaced))
            }
            .foregroundColor(bankColor(stats.bank))

            // Mini kimarite bar
            KimariteMiniBars(km: stats.km)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(bankColor(stats.bank))
                .frame(height: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

struct KimariteMiniBars: View {
    let km: [String: Double]

    private let order = ["逃", "捲", "差", "マーク"]
    private let colors: [String: Color] = [
        "逃": Color(hex: "#FF4444"),
        "捲": Color(hex: "#FF8C00"),
        "差": Color(hex: "#4488FF"),
        "マーク": Color(hex: "#44CC88"),
    ]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(km.sorted(by: { $0.value > $1.value }).prefix(3), id: \.key) { (key, val) in
                HStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(colors[key] ?? .white)
                        .frame(width: 24, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(colors[key] ?? .white)
                                .frame(width: geo.size.width * CGFloat(val))
                        }
                    }
                    .frame(height: 5)
                    Text("\(Int(val * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#5D5344"))
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }
}

func bankColor(_ bank: Int) -> Color {
    switch bank {
    case ...335: return Color(hex: "#FF4444")
    case 500...: return Color(hex: "#4488FF")
    default: return Color(hex: "#FFD700")
    }
}

// MARK: - Venue Detail
struct VenueDetailView: View {
    let name: String
    let stats: VenueStats
    let onBack: () -> Void

    var body: some View {
        CompactAwareScroll {
            VStack(spacing: 20) {
                // Back button + header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("戻る")
                        }
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#111111"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Spacer()
                }

                // Venue name + bank
                RacingPanel(accent: bankColor(stats.bank)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.system(size: 28, weight: .black))
                            .foregroundColor(Color(hex: "#111111"))
                    AdaptiveStack(horizontalSpacing: 16, verticalSpacing: 6) {
                        Label("\(stats.bank)m バンク", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(bankColor(stats.bank))
                        Label("\(stats.races)レース", systemImage: "flag.checkered")
                                .foregroundColor(Color(hex: "#5D5344"))
                    }
                    .font(.system(size: 13, design: .monospaced))

                    // Bank type label
                    Text(bankTypeLabel(stats.bank))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                            .background(Color(hex: "#111111"))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                }

                // Kimarite distribution chart
                RacingPanel(accent: KeirinUI.gold) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("決まり手分布")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "#B68000"))

                    ForEach(stats.km.sorted(by: { $0.value > $1.value }), id: \.key) { (key, val) in
                        KimariteBar(name: key, ratio: val)
                    }
                }
                }

                // Strategy hints
                RacingPanel(accent: KeirinUI.red) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("バンク攻略ヒント")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(KeirinUI.red)

                    ForEach(bankHints(bank: stats.bank, km: stats.km), id: \.self) { hint in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                    .foregroundColor(KeirinUI.red)
                                .padding(.top, 2)
                            Text(hint)
                                .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#111111").opacity(0.80))
                        }
                    }
                }
                }

            }
        }
    }

    private func bankTypeLabel(_ bank: Int) -> String {
        switch bank {
        case ...335: return "短走路（逃げ有利）"
        case 500...: return "長走路（差し有利）"
        default: return "標準走路"
        }
    }

    private func bankHints(bank: Int, km: [String: Double]) -> [String] {
        var hints: [String] = []
        if bank <= 335 {
            hints.append("短いバンクは先行選手（逃げ）が有利。スピード型を上位に。")
        } else if bank >= 500 {
            hints.append("長いバンクは追込・差し選手が台頭しやすい。終盤の伸びに注目。")
        } else {
            hints.append("標準バンク。脚質の優劣は少なく、ライン戦術と直近調子が鍵。")
        }
        if let nige = km["逃"], nige >= 0.5 {
            hints.append("逃げ率\(Int(nige * 100))%と高め。先行選手の番手選手も要チェック。")
        }
        if let maki = km["捲"], maki >= 0.3 {
            hints.append("捲り率\(Int(maki * 100))%。捲り脚質の選手が穴を開けやすい。")
        }
        return hints
    }
}

struct KimariteBar: View {
    let name: String
    let ratio: Double

    private let colors: [String: Color] = [
        "逃": Color(hex: "#FF4444"),
        "捲": Color(hex: "#FF8C00"),
        "差": Color(hex: "#4488FF"),
        "マーク": Color(hex: "#44CC88"),
    ]

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(colors[name] ?? Color(hex: "#111111"))
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(colors[name] ?? Color.white)
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(height: 10)

            Text("\(Int(ratio * 100))%")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#111111"))
                .frame(width: 36, alignment: .trailing)
        }
    }
}
