import Foundation

struct PredictionEngine {

    // Bank lengths by venue name
    static let bankLength: [String: Int] = [
        "函館": 400, "青森": 400, "いわき平": 400,
        "弥彦": 400, "前橋": 335, "取手": 400, "宇都宮": 500,
        "大宮": 500, "西武園": 400, "京王閣": 400, "立川": 400,
        "松戸": 333, "千葉": 500, "川崎": 400, "平塚": 400,
        "小田原": 333, "伊東": 333, "静岡": 400,
        "名古屋": 400, "岐阜": 400, "大垣": 400, "豊橋": 400,
        "富山": 333, "松阪": 400, "四日市": 400,
        "福井": 400, "奈良": 333, "向日町": 400, "和歌山": 400, "岸和田": 400,
        "玉野": 400, "広島": 400, "防府": 333,
        "高松": 400, "小松島": 400, "高知": 500, "松山": 400,
        "小倉": 400, "久留米": 400, "武雄": 400, "佐世保": 400,
        "別府": 400, "熊本": 500,
    ]

    static func predict(
        entries: [RaceEntry],
        venue: String,
        playerStats: [String: PlayerStats],
        venueStats: [String: VenueStats]
    ) -> [PredictionResult] {
        let bank = bankLength[venue] ?? 400
        let venueInfo = venueStats[venue]

        // Count district allies per player
        var districtCount: [String: Int] = [:]
        for entry in entries {
            if let stat = playerStats[entry.name] {
                let d = stat.district
                if !d.isEmpty {
                    districtCount[d, default: 0] += 1
                }
            }
        }

        var scored: [(entry: RaceEntry, score: Double, stat: PlayerStats?)] = []

        for entry in entries {
            let stat = playerStats[entry.name]
            var score = 50.0

            // 1. Base win rate
            let wr = stat?.winRate ?? 0
            let t3 = stat?.top3Rate ?? 0
            score += wr * 30
            score += t3 * 15

            // 2. Style x Bank
            let style = stat?.style ?? ""
            if !style.isEmpty {
                if style == "逃" && bank <= 335 { score += 5 }
                else if style == "逃" && bank >= 500 { score -= 3 }
                else if (style == "追" || style == "差") && bank >= 500 { score += 4 }
                else if style == "捲" && bank == 400 { score += 2 }

                // Venue kimarite match
                if let km = venueInfo?.km {
                    let styleKimariteMap: [String: String] = ["逃": "逃", "追": "差", "差": "差", "捲": "捲"]
                    if let mapped = styleKimariteMap[style], let ratio = km[mapped] {
                        score += ratio * 10
                    }
                }
            }

            // 3. Venue record (min 2 races)
            if let vr = stat?.venueStats[venue], vr.races >= 2 {
                score += vr.winRate * 20
            }

            // 4. Recent form (last 5)
            let recentRanks = Array((stat?.recentRanks ?? []).prefix(5))
            if !recentRanks.isEmpty {
                let avg = Double(recentRanks.reduce(0, +)) / Double(recentRanks.count)
                score += max(0, (6 - avg) * 2.5)
            }

            // 5. Kimarite pattern (dominant >= 3)
            let rk = stat?.recentKimarite ?? []
            if !rk.isEmpty {
                var counts: [String: Int] = [:]
                for k in rk { counts[k, default: 0] += 1 }
                if let top = counts.values.max(), top >= 3 {
                    score += 3
                }
            }

            // 6. Line allies (same district)
            let myDistrict = stat?.district ?? ""
            if !myDistrict.isEmpty {
                let allies = (districtCount[myDistrict] ?? 0) - 1  // subtract self
                if allies > 0 { score += Double(allies) * 4 }
            }

            scored.append((entry: entry, score: score, stat: stat))
        }

        // Sort by score descending
        let sorted = scored.sorted { $0.score > $1.score }

        // Softmax probabilities
        let scores = sorted.map { $0.score }
        let maxScore = scores.max() ?? 0
        let expScores = scores.map { exp($0 - maxScore) }
        let sumExp = expScores.reduce(0, +)
        let probs = expScores.map { $0 / sumExp }

        // Contrarian detection: low overall wr but high venue wr, or recent sharply improving
        let avgWr = scored.compactMap { $0.stat?.winRate }.reduce(0, +) / Double(max(1, scored.count))

        return sorted.enumerated().map { (i, item) in
            let stat = item.stat
            let myWr = stat?.winRate ?? 0
            let venueWr = stat?.venueStats[venue]?.winRate ?? 0
            let recentRanks = Array((stat?.recentRanks ?? []).prefix(5))
            let recentAvg: Double? = recentRanks.isEmpty ? nil :
                Double(recentRanks.reduce(0, +)) / Double(recentRanks.count)

            // Contrarian: low overall wr but high venue wr, OR recent form trending up sharply
            var isDarkHorse = false
            if myWr < avgWr * 0.7 && venueWr > myWr * 1.5 && stat?.venueStats[venue]?.races ?? 0 >= 3 {
                isDarkHorse = true
            }
            if let ra = recentAvg, ra <= 2.5 && myWr < avgWr * 0.8 {
                isDarkHorse = true
            }

            return PredictionResult(
                name: item.entry.name,
                waku: item.entry.waku,
                score: round(item.score * 10) / 10,
                winProb: round(probs[i] * 1000) / 10,
                predRank: i + 1,
                district: stat?.district ?? "",
                style: stat?.style ?? "",
                winRate: round((stat?.winRate ?? 0) * 1000) / 10,
                top3Rate: round((stat?.top3Rate ?? 0) * 1000) / 10,
                recentAvg: recentAvg.map { round($0 * 10) / 10 },
                rpg: stat?.rpg,
                classRank: stat?.classRank ?? "",
                isDarkHorse: isDarkHorse
            )
        }
    }
}
