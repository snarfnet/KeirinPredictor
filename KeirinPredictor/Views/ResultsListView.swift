import SwiftUI

struct ResultsListView: View {
    @EnvironmentObject var dataLoader: DataLoader

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0E27").ignoresSafeArea()

                if dataLoader.todayResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#FFD700").opacity(0.5))
                        Text("結果データを取得中...")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Button("更新") {
                            dataLoader.fetchRemoteTodayResults()
                        }
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            resultsHeader

                            ForEach(groupedByVenue, id: \.venue) { group in
                                VenueResultSection(venue: group.venue, results: group.results)
                            }

                            BannerAdView()
                                .frame(height: 50)
                                .padding(.horizontal)

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RESULTS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dataLoader.fetchRemoteTodayResults()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(hex: "#FFD700"))
                    }
                }
            }
        }
    }

    private var resultsHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundColor(Color(hex: "#FFD700"))
            Text(dataLoader.todayDateString)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("\(dataLoader.todayResults.count)レース確定")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color(hex: "#FFD700").opacity(0.7))
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private var groupedByVenue: [VenueResultGroup] {
        let dict = Dictionary(grouping: dataLoader.todayResults, by: { $0.venue })
        return dict.map { VenueResultGroup(venue: $0.key, results: $0.value.sorted { $0.race_no < $1.race_no }) }
            .sorted { $0.venue < $1.venue }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color(hex: "#FFD700"))
                Text(venue)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("\(results.count)R")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            ForEach(results) { result in
                RaceResultRow(result: result)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

struct RaceResultRow: View {
    let result: TodayRaceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(result.race_no)R")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))
                Spacer()
            }

            // Top 3 finishers
            ForEach(Array(result.finishers.prefix(3).enumerated()), id: \.offset) { (i, finisher) in
                HStack(spacing: 8) {
                    Text("\(i + 1)着")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(i == 0 ? Color(hex: "#FFD700") : .white.opacity(0.6))
                        .frame(width: 34)

                    Text("\(finisher.umaban)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(wakuColor(finisher.waku))
                        .clipShape(Circle())

                    Text(finisher.name)
                        .font(.system(size: 15, weight: i == 0 ? .bold : .regular))
                        .foregroundColor(.white)

                    if !finisher.kimarite.isEmpty {
                        Text(finisher.kimarite)
                            .font(.system(size: 12))
                            .foregroundColor(styleColor(finisher.kimarite))
                    }

                    Spacer()
                }
            }

            // Paybacks
            if !result.paybacks.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 12) {
                    ForEach(result.paybacks.prefix(3), id: \.type) { pb in
                        VStack(spacing: 2) {
                            Text(pb.type)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(pb.payout)円")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(pb.payout >= 10000 ? .red : Color(hex: "#FFD700"))
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
    }
}
