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

    // Class rank base power
    private static let classWeight: [String: Double] = [
        "SS": 30, "S1": 25, "S2": 18, "A1": 10, "A2": 4, "A3": 1
    ]

    static func predict(
        entries: [RaceEntry],
        venue: String,
        playerStats: [String: PlayerStats],
        venueStats: [String: VenueStats],
        entryScores: [String: Double] = [:] // name -> competition score from entry table
    ) -> [PredictionResult] {
        let bank = bankLength[venue] ?? 400
        let venueInfo = venueStats[venue]
        let entryCount = entries.count

        // Build district map for line analysis
        var districtMembers: [String: [(entry: RaceEntry, stat: PlayerStats?)]] = [:]
        for entry in entries {
            let stat = playerStats[entry.name]
            let d = stat?.district ?? ""
            if !d.isEmpty {
                districtMembers[d, default: []].append((entry, stat))
            }
        }

        var scored: [(entry: RaceEntry, score: Double, stat: PlayerStats?)] = []

        for entry in entries {
            let stat = playerStats[entry.name]
            var score = 50.0

            // ========== 1. Class rank (strongest factor) ==========
            let classRank = stat?.classRank ?? ""
            score += classWeight[classRank] ?? 0

            // ========== 2. Win rate + top rates ==========
            let wr = stat?.winRate ?? 0
            let t2 = stat?.top2Rate ?? 0
            let t3 = stat?.top3Rate ?? 0
            // Weighted combination: winning matters most
            score += wr * 25
            score += t2 * 8
            score += t3 * 5

            // ========== 3. Style x Bank (refined) ==========
            let style = stat?.style ?? ""
            if !style.isEmpty {
                score += styleBankBonus(style: style, bank: bank)

                // Venue kimarite distribution match
                if let km = venueInfo?.km {
                    let styleKimariteMap: [String: String] = [
                        "逃": "逃", "追": "差", "差": "差", "捲": "捲", "両": "捲"
                    ]
                    if let mapped = styleKimariteMap[style], let ratio = km[mapped] {
                        score += ratio * 12
                    }
                }
            }

            // ========== 4. Venue record (min 2 races, weighted by sample) ==========
            if let vr = stat?.venueStats[venue], vr.races >= 2 {
                let confidence = min(1.0, Double(vr.races) / 10.0)
                score += vr.winRate * 25 * confidence
            }

            // ========== 5. Recent form (trend analysis) ==========
            let recentRanks = Array((stat?.recentRanks ?? []).prefix(8))
            if recentRanks.count >= 3 {
                let avg = Double(recentRanks.reduce(0, +)) / Double(recentRanks.count)
                score += max(0, (5 - avg) * 3)

                // Trend: compare first half vs second half
                let half = recentRanks.count / 2
                let recentHalf = Array(recentRanks.prefix(half))
                let olderHalf = Array(recentRanks.suffix(half))
                let recentAvg = Double(recentHalf.reduce(0, +)) / Double(recentHalf.count)
                let olderAvg = Double(olderHalf.reduce(0, +)) / Double(olderHalf.count)
                let trend = olderAvg - recentAvg // positive = improving
                score += trend * 2.5

                // Win streak bonus
                let consecutiveWins = recentRanks.prefix(while: { $0 == 1 }).count
                if consecutiveWins >= 2 {
                    score += Double(consecutiveWins) * 3
                }
            }

            // ========== 6. Kimarite pattern ==========
            let rk = stat?.recentKimarite ?? []
            if rk.count >= 3 {
                var counts: [String: Int] = [:]
                for k in rk { counts[k, default: 0] += 1 }
                if let (topK, topCount) = counts.max(by: { $0.value < $1.value }) {
                    let dominance = Double(topCount) / Double(rk.count)
                    if dominance >= 0.5 {
                        score += 4
                        // Extra if dominant style matches bank
                        if topK == "逃" && bank <= 335 { score += 3 }
                        if topK == "捲" && bank == 400 { score += 2 }
                        if topK == "差" && bank >= 500 { score += 2 }
                    }
                }
            }

            // ========== 7. Line strength (district allies) ==========
            let myDistrict = stat?.district ?? ""
            if !myDistrict.isEmpty {
                let allies = (districtMembers[myDistrict]?.count ?? 0) - 1
                if allies > 0 {
                    // More allies = stronger line
                    score += Double(allies) * 4

                    // Line quality: average class of allies
                    let allyScores = districtMembers[myDistrict]?
                        .filter { $0.entry.name != entry.name }
                        .compactMap { $0.stat }
                        .map { classWeight[$0.classRank] ?? 0 } ?? []
                    if !allyScores.isEmpty {
                        let avgAllyClass = allyScores.reduce(0, +) / Double(allyScores.count)
                        score += avgAllyClass * 0.3
                    }

                    // Leading line bonus: if this player is the strongest in the line
                    let myClassScore = classWeight[classRank] ?? 0
                    let maxAllyClass = allyScores.max() ?? 0
                    if myClassScore > maxAllyClass {
                        score += 3 //番手有利
                    }
                }
            }

            // ========== 8. Fewer entries = more predictable ==========
            if entryCount <= 5 && wr > 0.2 {
                score += 3 // Strong riders dominate in small fields
            }

            // ========== 9. Competition score from entry table ==========
            if let compScore = entryScores[entry.name], compScore > 0 {
                // Normalize: avg score ~70-80, top ~115+
                // Give bonus relative to field average
                let avgScore = entryScores.values.reduce(0, +) / Double(max(1, entryScores.count))
                let scoreDiff = compScore - avgScore
                score += scoreDiff * 0.5 // +0.5 per point above average
            }

            // ========== 10. Experience bonus ==========
            let totalRaces = stat?.races ?? 0
            if totalRaces >= 500 {
                score += 2
            } else if totalRaces >= 200 {
                score += 1
            }

            scored.append((entry: entry, score: score, stat: stat))
        }

        // Sort by score descending
        let sorted = scored.sorted { $0.score > $1.score }

        // Softmax probabilities (temperature-adjusted)
        let scores = sorted.map { $0.score }
        let maxScore = scores.max() ?? 0
        let temperature = 8.0 // Lower = more decisive, higher = more spread
        let expScores = scores.map { exp(($0 - maxScore) / temperature) }
        let sumExp = expScores.reduce(0, +)
        let probs = expScores.map { $0 / sumExp }

        // Average win rate for contrarian detection
        let avgWr = scored.compactMap { $0.stat?.winRate }.reduce(0, +) / Double(max(1, scored.count))

        return sorted.enumerated().map { (i, item) in
            let stat = item.stat
            let myWr = stat?.winRate ?? 0
            let venueWr = stat?.venueStats[venue]?.winRate ?? 0
            let recentRanks = Array((stat?.recentRanks ?? []).prefix(5))
            let recentAvg: Double? = recentRanks.isEmpty ? nil :
                Double(recentRanks.reduce(0, +)) / Double(recentRanks.count)

            // Contrarian detection
            var isDarkHorse = false
            // Low overall but high venue performance
            if myWr < avgWr * 0.7 && venueWr > myWr * 1.5 && stat?.venueStats[venue]?.races ?? 0 >= 3 {
                isDarkHorse = true
            }
            // Recent form sharply improving
            if let ra = recentAvg, ra <= 2.0 && myWr < avgWr * 0.8 {
                isDarkHorse = true
            }
            // Low class but recent wins
            let recentWins = recentRanks.filter { $0 == 1 }.count
            if (stat?.classRank == "A2" || stat?.classRank == "A1") && recentWins >= 3 {
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

    // MARK: - Bet Recommendations
    static func generateBets(predictions: [PredictionResult], odds: [String: Double] = [:]) -> [BetRecommendation] {
        guard predictions.count >= 3 else { return [] }

        var bets: [BetRecommendation] = []
        let top = predictions.sorted { $0.score > $1.score }
        let darkHorses = top.filter { $0.isDarkHorse }

        // Helper: calculate EV from odds
        func trifectaEV(_ combo: [PredictionResult], prob: Double) -> Double? {
            let key = combo.map { "\($0.waku)" }.joined(separator: "-")
            guard let o = odds[key] else { return nil }
            return round(o * prob * 100) / 100
        }

        // === 3連単 (Trifecta exact order) ===
        // Pattern 1: Top 3 box (6 bets) - confidence S/A
        let top3 = Array(top.prefix(3))
        let top3Perms = permutations(top3)
        for perm in top3Perms {
            let prob = estimateTrifectaProb(perm, allPredictions: top)
            let ev = trifectaEV(perm, prob: prob)
            let conf: String
            if let ev = ev, ev > 1.5 { conf = "S" }
            else if prob > 0.08 { conf = "S" }
            else if prob > 0.04 { conf = "A" }
            else { conf = "B" }
            bets.append(BetRecommendation(
                type: "3連単",
                combination: perm.map { $0.waku },
                names: perm.map { $0.name },
                probability: round(prob * 1000) / 10,
                confidence: conf,
                expectedValue: ev
            ))
        }

        // Pattern 2: Top 2 + dark horse (if exists)
        if let dh = darkHorses.first, !top3.contains(where: { $0.waku == dh.waku }) {
            let top2 = Array(top.prefix(2))
            // Dark horse in 2nd or 3rd
            for pos in [1, 2] {
                var combo = top2
                combo.insert(dh, at: pos)
                let c3 = Array(combo.prefix(3))
                let prob = estimateTrifectaProb(c3, allPredictions: top)
                let ev = trifectaEV(c3, prob: prob)
                let conf = ev != nil && ev! > 1.5 ? "A" : "B"
                bets.append(BetRecommendation(
                    type: "3連単",
                    combination: c3.map { $0.waku },
                    names: c3.map { $0.name },
                    probability: round(prob * 1000) / 10,
                    confidence: conf,
                    expectedValue: ev
                ))
            }
        }

        // Pattern 3: Top1 fixed, Top 2-4 for 2nd/3rd
        if top.count >= 4 {
            let axis = top[0]
            let candidates = Array(top[1...3])
            for i in 0..<candidates.count {
                for j in 0..<candidates.count where j != i {
                    let combo = [axis, candidates[i], candidates[j]]
                    // Skip if already in top3 box
                    let key = combo.map { $0.waku }
                    let alreadyExists = bets.contains { $0.type == "3連単" && $0.combination == key }
                    if !alreadyExists {
                        let prob = estimateTrifectaProb(combo, allPredictions: top)
                        let ev = trifectaEV(combo, prob: prob)
                        let conf: String
                        if let ev = ev, ev > 1.5 { conf = "A" }
                        else if prob > 0.04 { conf = "A" }
                        else { conf = "B" }
                        bets.append(BetRecommendation(
                            type: "3連単",
                            combination: key,
                            names: combo.map { $0.name },
                            probability: round(prob * 1000) / 10,
                            confidence: conf,
                            expectedValue: ev
                        ))
                    }
                }
            }
        }

        // === 2車単 (Exacta) ===
        let top4 = Array(top.prefix(min(4, top.count)))
        for i in 0..<min(3, top4.count) {
            for j in 0..<top4.count where j != i {
                let prob = top4[i].winProb / 100 * top4[j].winProb / 100 * 3
                let conf = prob > 0.15 ? "S" : (prob > 0.08 ? "A" : "B")
                bets.append(BetRecommendation(
                    type: "2車単",
                    combination: [top4[i].waku, top4[j].waku],
                    names: [top4[i].name, top4[j].name],
                    probability: round(min(prob, 0.99) * 1000) / 10,
                    confidence: conf,
                    expectedValue: nil
                ))
            }
        }

        // === ワイド (Wide - any 2 in top 3) ===
        for i in 0..<min(4, top.count) {
            for j in (i+1)..<min(4, top.count) {
                let prob = (top[i].winProb + top[j].winProb) / 100 * 0.6
                bets.append(BetRecommendation(
                    type: "ワイド",
                    combination: [top[i].waku, top[j].waku],
                    names: [top[i].name, top[j].name],
                    probability: round(min(prob, 0.99) * 1000) / 10,
                    confidence: prob > 0.3 ? "S" : (prob > 0.15 ? "A" : "B"),
                    expectedValue: nil
                ))
            }
        }

        // Sort: confidence S first, then by probability
        let confOrder: [String: Int] = ["S": 0, "A": 1, "B": 2, "C": 3]
        return bets.sorted {
            let c1 = confOrder[$0.confidence] ?? 3
            let c2 = confOrder[$1.confidence] ?? 3
            if c1 != c2 { return c1 < c2 }
            return $0.probability > $1.probability
        }
    }

    private static func estimateTrifectaProb(_ trio: [PredictionResult], allPredictions: [PredictionResult]) -> Double {
        guard trio.count >= 3 else { return 0 }
        let p1 = trio[0].winProb / 100
        let remaining1 = 1 - p1
        let p2 = remaining1 > 0 ? (trio[1].winProb / 100) / remaining1 : 0
        let remaining2 = remaining1 - trio[1].winProb / 100
        let p3 = remaining2 > 0 ? (trio[2].winProb / 100) / max(0.01, remaining2) : 0
        return p1 * min(p2, 1) * min(p3, 1)
    }

    private static func permutations(_ arr: [PredictionResult]) -> [[PredictionResult]] {
        guard arr.count == 3 else { return [arr] }
        let a = arr[0], b = arr[1], c = arr[2]
        return [
            [a, b, c], [a, c, b],
            [b, a, c], [b, c, a],
            [c, a, b], [c, b, a]
        ]
    }

    // MARK: - Style x Bank bonus (refined)
    private static func styleBankBonus(style: String, bank: Int) -> Double {
        // 333m: 先行圧倒的有利、捲りも有効
        // 400m: バランス型、捲り・差しが多い
        // 500m: 差し・追込み有利、逃げ不利
        switch style {
        case "逃":
            if bank <= 335 { return 8 }      // 333mバンクは逃げ天国
            if bank == 400 { return 2 }
            if bank >= 500 { return -4 }      // 500mは逃げ切り困難
        case "捲":
            if bank <= 335 { return 4 }
            if bank == 400 { return 5 }       // 400mは捲り最適
            if bank >= 500 { return 2 }
        case "差":
            if bank <= 335 { return -2 }      // 333mは差し届きにくい
            if bank == 400 { return 3 }
            if bank >= 500 { return 7 }       // 500mは差し天国
        case "追":
            if bank <= 335 { return -3 }
            if bank == 400 { return 2 }
            if bank >= 500 { return 8 }       // 500mは追込み最強
        case "両":
            return 3                          // 自在型はどこでも安定
        default:
            break
        }
        return 0
    }
}
