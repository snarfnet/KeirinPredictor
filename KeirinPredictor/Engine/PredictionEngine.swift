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

    private static let classWeight: [String: Double] = [
        "SS": 32, "S1": 27, "S2": 19, "A1": 11, "A2": 5, "A3": 2, "L1": 8
    ]

    static func predict(
        entries: [RaceEntry],
        venue: String,
        playerStats: [String: PlayerStats],
        venueStats: [String: VenueStats],
        entryScores: [String: Double] = [:],
        entryMetrics: [String: RaceEntryMetrics] = [:],
        lineMatrix: [String: LineEntry] = [:]
    ) -> [PredictionResult] {
        let bank = bankLength[venue] ?? venueStats[venue]?.bank ?? 400
        let venueInfo = venueStats[venue]
        let entryCount = entries.count

        var liveScores = entryScores
        for (name, metric) in entryMetrics {
            liveScores[name] = metric.score
        }
        let avgLiveScore = average(liveScores.values)
        let avgMetricWinRate = average(entryMetrics.values.map { $0.winRate })
        let gearValues = entryMetrics.values.compactMap { Double($0.gear) }
        let avgGear = gearValues.isEmpty ? nil : average(gearValues)

        var districtMembers: [String: [(entry: RaceEntry, stat: PlayerStats?)]] = [:]
        for entry in entries {
            let stat = playerStats[entry.name]
            let district = stat?.district ?? ""
            if !district.isEmpty {
                districtMembers[district, default: []].append((entry, stat))
            }
        }

        let lines = analyzeLines(entries: entries, playerStats: playerStats)
        let lineRoles = Dictionary(uniqueKeysWithValues: lines.flatMap { line in
            line.members.map { member in (member.name, member.role) }
        })
        let scenarioBonuses = simulateScenarios(lines: lines, bank: bank, entries: entries, playerStats: playerStats)

        var scored: [(entry: RaceEntry, score: Double, stat: PlayerStats?, signals: [PredictionSignal], lineRole: String)] = []

        for entry in entries {
            let stat = playerStats[entry.name]
            let metric = entryMetrics[entry.name]
            let classRank = stat?.classRank ?? ""
            let listedStyle = metric?.style.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let style = listedStyle.isEmpty ? (stat?.style ?? "") : listedStyle

            var score = 50.0
            var signals: [PredictionSignal] = []

            score += classWeight[classRank] ?? 0
            if ["SS", "S1", "S2", "L1"].contains(classRank) {
                signals.append(PredictionSignal(title: "格", value: classRank, tone: "gold"))
            }

            let wr = stat?.winRate ?? 0
            let t2 = stat?.top2Rate ?? 0
            let t3 = stat?.top3Rate ?? 0
            score += wr * 26
            score += t2 * 9
            score += t3 * 6

            if !style.isEmpty {
                let bankBonus = styleBankBonus(style: style, bank: bank)
                score += bankBonus
                if bankBonus >= 4 {
                    signals.append(PredictionSignal(title: "バンク", value: "\(style)向き", tone: "cyan"))
                }

                if let km = venueInfo?.km {
                    let styleKimariteMap: [String: String] = [
                        "逃": "逃", "追": "差", "差": "差", "捲": "捲", "両": "捲"
                    ]
                    if let mapped = styleKimariteMap[style], let ratio = km[mapped] {
                        score += ratio * 12
                    }
                }
            }

            let bankCat = bank <= 335 ? "s" : (bank <= 400 ? "m" : "l")
            if let bankRecord = stat?.bankStats[bankCat], bankRecord.races >= 3 {
                let confidence = min(1.0, Double(bankRecord.races) / 15.0)
                score += bankRecord.winRate * 21 * confidence
                score += bankRecord.top3Rate * 9 * confidence
                if bankRecord.top3Rate >= 0.45 {
                    signals.append(PredictionSignal(title: "距離", value: "3着内強い", tone: "green"))
                }
            }

            if let venueRecord = stat?.venueStats[venue], venueRecord.races >= 2 {
                let confidence = min(1.0, Double(venueRecord.races) / 10.0)
                score += venueRecord.winRate * 25 * confidence
                if venueRecord.winRate >= max(0.18, wr * 1.2) {
                    signals.append(PredictionSignal(title: "場", value: "相性あり", tone: "gold"))
                }
            }

            let formScore = stat?.formScore ?? 0
            if formScore > 0 {
                score += formScore * 1.6
                if formScore >= 7 {
                    signals.append(PredictionSignal(title: "調子", value: "上向き", tone: "green"))
                }
            }

            let recentRanks = Array((stat?.recentRanks ?? []).prefix(8))
            if recentRanks.count >= 3 {
                let avgRank = Double(recentRanks.reduce(0, +)) / Double(recentRanks.count)
                score += max(0, (5 - avgRank) * 3)

                let half = max(1, recentRanks.count / 2)
                let recentHalf = Array(recentRanks.prefix(half))
                let olderHalf = Array(recentRanks.suffix(half))
                let recentAvg = average(recentHalf.map(Double.init))
                let olderAvg = average(olderHalf.map(Double.init))
                let trend = olderAvg - recentAvg
                score += trend * 2.5

                let consecutiveWins = recentRanks.prefix(while: { $0 == 1 }).count
                if consecutiveWins >= 2 {
                    score += Double(consecutiveWins) * 3
                    signals.append(PredictionSignal(title: "近況", value: "\(consecutiveWins)連勝", tone: "gold"))
                } else if trend >= 0.8 {
                    signals.append(PredictionSignal(title: "近況", value: "着順改善", tone: "green"))
                }
            }

            let dominantKimarite = stat?.dominantKimarite ?? ""
            if !dominantKimarite.isEmpty {
                score += 3
                if dominantKimarite == "逃" && bank <= 335 { score += 4 }
                if dominantKimarite == "捲" && bank == 400 { score += 3 }
                if dominantKimarite == "差" && bank >= 500 { score += 3 }
                if dominantKimarite == "追" && bank >= 500 { score += 4 }
            }

            let recentKimarite = stat?.recentKimarite ?? []
            if recentKimarite.count >= 3 {
                var counts: [String: Int] = [:]
                for kimarite in recentKimarite { counts[kimarite, default: 0] += 1 }
                if let (topKimarite, topCount) = counts.max(by: { $0.value < $1.value }) {
                    let dominance = Double(topCount) / Double(recentKimarite.count)
                    if dominance >= 0.5 {
                        score += 2
                        if topKimarite == "逃" && bank <= 335 { score += 2 }
                        if topKimarite == "捲" && bank == 400 { score += 1.5 }
                        if topKimarite == "差" && bank >= 500 { score += 1.5 }
                    }
                }
            }

            let myDistrict = stat?.district ?? ""
            if !myDistrict.isEmpty {
                let allies = (districtMembers[myDistrict]?.count ?? 0) - 1
                if allies > 0 {
                    score += Double(allies) * 4

                    let allyScores = districtMembers[myDistrict]?
                        .filter { $0.entry.name != entry.name }
                        .compactMap { $0.stat }
                        .map { classWeight[$0.classRank] ?? 0 } ?? []
                    if !allyScores.isEmpty {
                        let avgAllyClass = average(allyScores)
                        score += avgAllyClass * 0.3
                    }

                    let myClassScore = classWeight[classRank] ?? 0
                    let maxAllyClass = allyScores.max() ?? 0
                    if myClassScore > maxAllyClass {
                        score += 3
                    }

                    if let rate = lineMatrixRate(myDistrict, myDistrict, lineMatrix: lineMatrix) {
                        score += clamp((rate - 0.36) * 18, lower: -1.5, upper: 4.5)
                        if rate >= 0.45 {
                            signals.append(PredictionSignal(title: "ライン", value: "連係強め", tone: "cyan"))
                        }
                    } else {
                        signals.append(PredictionSignal(title: "ライン", value: "\(allies + 1)車", tone: "cyan"))
                    }
                }
            }

            if let role = lineRoles[entry.name], !role.isEmpty {
                if role == "番手" && bank >= 400 { score += 2.2 }
                if role == "先行" && bank <= 335 { score += 2.5 }
            }

            score += scenarioBonuses[entry.name] ?? 0

            if entryCount <= 5 && wr > 0.2 {
                score += 3
            }

            if let liveScore = liveScores[entry.name], liveScore > 0, avgLiveScore > 0 {
                let scoreDiff = liveScore - avgLiveScore
                score += scoreDiff * 0.55
                if scoreDiff >= 4 {
                    signals.append(PredictionSignal(title: "当日", value: "得点上位", tone: "gold"))
                }
            }

            if let metric = metric {
                score += (metric.winRate / 100) * 8
                score += (metric.top2Rate / 100) * 4
                score += (metric.top3Rate / 100) * 3
                if metric.winRate >= avgMetricWinRate + 8 {
                    signals.append(PredictionSignal(title: "出走表", value: "勝率上位", tone: "green"))
                }
                if metric.top3Rate >= 60 {
                    signals.append(PredictionSignal(title: "安定", value: "3着内高い", tone: "green"))
                }

                let comment = commentProfile(comment: metric.comment, style: style, bank: bank)
                score += comment.bonus
                if let label = comment.label {
                    signals.append(PredictionSignal(title: "コメント", value: label, tone: "cyan"))
                }

                if let gear = Double(metric.gear), let avgGear = avgGear {
                    let gearDelta = clamp((gear - avgGear) * 1.25, lower: -1.5, upper: 2.0)
                    score += gearDelta
                    if gearDelta >= 0.8 {
                        signals.append(PredictionSignal(title: "ギア", value: "重め", tone: "gold"))
                    }
                }
            }

            let totalRaces = stat?.races ?? 0
            if totalRaces >= 500 {
                score += 2
            } else if totalRaces >= 200 {
                score += 1
            }

            scored.append((
                entry: entry,
                score: score,
                stat: stat,
                signals: Array(signals.prefix(4)),
                lineRole: lineRoles[entry.name] ?? ""
            ))
        }

        let sorted = scored.sorted { $0.score > $1.score }
        let scores = sorted.map { $0.score }
        let maxScore = scores.max() ?? 0
        let scoreStdDev = standardDeviation(scores)
        let temperature = clamp(10.2 - scoreStdDev / 4.5, lower: 6.4, upper: 10.5)
        let expScores = scores.map { exp(($0 - maxScore) / temperature) }
        let sumExp = expScores.reduce(0, +)
        let probabilities = expScores.map { $0 / max(0.0001, sumExp) }

        let avgWinRate = average(scored.compactMap { $0.stat?.winRate })
        let leaderScore = sorted.first?.score ?? 0

        return sorted.enumerated().map { index, item in
            let stat = item.stat
            let myWinRate = stat?.winRate ?? 0
            let venueWinRate = stat?.venueStats[venue]?.winRate ?? 0
            let recentRanks = Array((stat?.recentRanks ?? []).prefix(5))
            let recentAvg: Double? = recentRanks.isEmpty ? nil : average(recentRanks.map(Double.init))

            var isDarkHorse = false
            if myWinRate < avgWinRate * 0.7,
               venueWinRate > myWinRate * 1.5,
               stat?.venueStats[venue]?.races ?? 0 >= 3 {
                isDarkHorse = true
            }
            if let recentAvg = recentAvg, recentAvg <= 2.0, myWinRate < avgWinRate * 0.8 {
                isDarkHorse = true
            }
            let recentWins = recentRanks.filter { $0 == 1 }.count
            if (stat?.classRank == "A2" || stat?.classRank == "A1") && recentWins >= 3 {
                isDarkHorse = true
            }

            let metric = entryMetrics[item.entry.name]
            var upsetScore = (stat?.top3Rate ?? 0) * 45
            upsetScore += (metric?.top3Rate ?? 0) * 0.35
            if item.score >= leaderScore - 8, index >= 3 { upsetScore += 18 }
            if isDarkHorse { upsetScore += 25 }
            if let recentAvg = recentAvg, recentAvg <= 2.2 { upsetScore += 12 }
            upsetScore = clamp(upsetScore, lower: 0, upper: 99)

            let riskLabel: String
            if index == 0 && (probabilities[index] * 100) >= 30 && item.score >= leaderScore - 0.1 {
                riskLabel = "軸候補"
            } else if isDarkHorse || upsetScore >= 55 {
                riskLabel = "穴注意"
            } else if item.score >= leaderScore - 6 {
                riskLabel = "相手有力"
            } else {
                riskLabel = "押さえ"
            }

            var signals = item.signals
            if isDarkHorse {
                signals.insert(PredictionSignal(title: "妙味", value: "穴", tone: "cyan"), at: 0)
            }
            let resultStyle = (metric?.style ?? "").isEmpty ? (stat?.style ?? "") : (metric?.style ?? "")

            return PredictionResult(
                name: item.entry.name,
                waku: item.entry.waku,
                score: round(item.score * 10) / 10,
                winProb: round(probabilities[index] * 1000) / 10,
                predRank: index + 1,
                district: stat?.district ?? "",
                style: resultStyle,
                winRate: round((stat?.winRate ?? 0) * 1000) / 10,
                top3Rate: round((stat?.top3Rate ?? 0) * 1000) / 10,
                recentAvg: recentAvg.map { round($0 * 10) / 10 },
                formScore: round((stat?.formScore ?? 0) * 10) / 10,
                classRank: stat?.classRank ?? "",
                isDarkHorse: isDarkHorse,
                signals: Array(signals.prefix(4)),
                riskLabel: riskLabel,
                lineRole: item.lineRole,
                upsetScore: round(upsetScore * 10) / 10
            )
        }
    }

    // MARK: - Race Intelligence
    static func analyzeTodayRace(
        _ race: TodayRace,
        playerStats: [String: PlayerStats],
        venueStats: [String: VenueStats],
        lineMatrix: [String: LineEntry] = [:]
    ) -> RaceIntelligence {
        let entries = race.entries.map { entry in
            RaceEntry(name: entry.name, waku: entry.umaban)
        }
        var entryScores: [String: Double] = [:]
        var entryMetrics: [String: RaceEntryMetrics] = [:]
        for entry in race.entries {
            entryScores[entry.name] = entry.score
            entryMetrics[entry.name] = entry.predictionMetrics
        }

        let predictions = predict(
            entries: entries,
            venue: race.venue,
            playerStats: playerStats,
            venueStats: venueStats,
            entryScores: entryScores,
            entryMetrics: entryMetrics,
            lineMatrix: lineMatrix
        )

        return analyzeRace(
            predictions: predictions,
            entries: entries,
            venue: race.venue,
            playerStats: playerStats,
            venueStats: venueStats,
            entryMetrics: entryMetrics,
            lineMatrix: lineMatrix
        )
    }

    static func analyzeRace(
        predictions: [PredictionResult],
        entries: [RaceEntry],
        venue: String,
        playerStats: [String: PlayerStats],
        venueStats: [String: VenueStats],
        entryMetrics: [String: RaceEntryMetrics] = [:],
        lineMatrix: [String: LineEntry] = [:]
    ) -> RaceIntelligence {
        let sorted = predictions.sorted { $0.score > $1.score }
        guard let axis = sorted.first else {
            return RaceIntelligence(
                headline: "出走表を待っています",
                shapeLabel: "未解析",
                confidenceLabel: "低",
                paceLabel: "不明",
                chaosScore: 0,
                axisWinEstimate: 0,
                playGrade: "見",
                playAdvice: "データ待ち",
                actionLabel: "見送り",
                actionReason: "出走データ待ち",
                axisName: "",
                dangerName: nil,
                lineBias: "ライン不明",
                notes: []
            )
        }

        let second = sorted.dropFirst().first
        let third = sorted.dropFirst(2).first
        let topGap = axis.score - (second?.score ?? axis.score)
        let top3Gap = axis.score - (third?.score ?? axis.score)
        let bank = bankLength[venue] ?? venueStats[venue]?.bank ?? 400
        let lines = analyzeLines(entries: entries, playerStats: playerStats)
        let escapes = sorted.filter { result in
            let metricStyle = entryMetrics[result.name]?.style ?? ""
            return result.style == "逃" || metricStyle == "逃"
        }.count
        let darkHorseCount = sorted.filter { $0.isDarkHorse }.count
        let closePack = sorted.filter { axis.score - $0.score <= 8 }.count

        var chaos = 46.0
        chaos -= topGap * 3.2
        chaos -= axis.winProb * 0.18
        chaos += Double(max(0, closePack - 2)) * 7
        chaos += Double(darkHorseCount) * 9
        chaos += Double(max(0, lines.count - 2)) * 8
        if escapes >= 3 { chaos += 10 }
        if bank >= 500 { chaos += 5 }
        if top3Gap <= 10 { chaos += 8 }
        chaos = clamp(chaos, lower: 8, upper: 92)

        let shapeLabel: String
        let confidenceLabel: String
        if topGap >= 12 && axis.winProb >= 30 {
            shapeLabel = "本命寄り"
            confidenceLabel = "高"
        } else if chaos >= 68 {
            shapeLabel = "波乱注意"
            confidenceLabel = "低"
        } else if closePack >= 4 {
            shapeLabel = "混戦"
            confidenceLabel = "中"
        } else {
            shapeLabel = "相手探し"
            confidenceLabel = "中"
        }

        let paceLabel: String
        if escapes >= 3 {
            paceLabel = "速め"
        } else if escapes == 0 {
            paceLabel = "遅め"
        } else {
            paceLabel = "標準"
        }

        let axisWinEstimate = estimateAxisHitRate(
            axis: axis,
            topGap: topGap,
            chaosScore: chaos,
            closePack: closePack,
            darkHorseCount: darkHorseCount,
            lines: lines
        )
        let playPlan = racePlayPlan(
            axisWinEstimate: axisWinEstimate,
            topGap: topGap,
            chaosScore: chaos,
            closePack: closePack,
            darkHorseCount: darkHorseCount
        )

        let lineBias: String
        if let strongest = lines.first {
            let secondStrength = lines.dropFirst().first?.strength ?? 0
            let rate = lineMatrixRate(strongest.district, strongest.district, lineMatrix: lineMatrix)
            if strongest.strength - secondStrength >= 18 {
                lineBias = "\(strongest.district)本線が強い"
            } else if let rate = rate, rate >= 0.48 {
                lineBias = "\(strongest.district)の連係実績あり"
            } else if lines.count >= 3 {
                lineBias = "別線も割れる"
            } else {
                lineBias = "\(strongest.district)中心"
            }
        } else {
            lineBias = "単騎多め"
        }

        let danger = sorted.dropFirst().first { $0.isDarkHorse || $0.upsetScore >= 50 } ?? second
        var headline = "\(axis.name)を軸に見るレース"
        if let danger = danger, danger.name != axis.name {
            headline += "。相手は\(danger.name)"
        }

        var notes: [String] = []
        notes.append("軸と2番手の指数差 \(String(format: "%.1f", topGap))")
        notes.append("本命1着の目安 \(String(format: "%.0f", axisWinEstimate))%")
        notes.append("\(bank)mバンク、ペースは\(paceLabel)")
        if closePack >= 4 { notes.append("上位\(closePack)人が接近") }
        if darkHorseCount > 0 { notes.append("穴サイン \(darkHorseCount)人") }
        notes.append(lineBias)

        return RaceIntelligence(
            headline: headline,
            shapeLabel: shapeLabel,
            confidenceLabel: confidenceLabel,
            paceLabel: paceLabel,
            chaosScore: round(chaos * 10) / 10,
            axisWinEstimate: round(axisWinEstimate * 10) / 10,
            playGrade: playPlan.grade,
            playAdvice: playPlan.advice,
            actionLabel: playPlan.actionLabel,
            actionReason: playPlan.actionReason,
            axisName: axis.name,
            dangerName: danger?.name,
            lineBias: lineBias,
            notes: Array(notes.prefix(5))
        )
    }

    // MARK: - Bet Recommendations
    static func generateBets(predictions: [PredictionResult], odds: [String: Double] = [:]) -> [BetRecommendation] {
        guard predictions.count >= 3 else { return [] }

        var bets: [BetRecommendation] = []
        let top = predictions.sorted { $0.score > $1.score }
        let darkHorses = top.filter { $0.isDarkHorse || $0.upsetScore >= 55 }

        func trifectaEV(_ combo: [PredictionResult], prob: Double) -> Double? {
            let key = combo.map { "\($0.waku)" }.joined(separator: "-")
            guard let oddsValue = odds[key] else { return nil }
            return round(oddsValue * prob * 100) / 100
        }

        func appendBet(
            type: String,
            combo: [PredictionResult],
            probability: Double,
            confidence: String,
            expectedValue: Double?,
            rationale: String
        ) {
            let probabilityPercent = round(min(probability, 0.99) * 1000) / 10
            bets.append(BetRecommendation(
                type: type,
                combination: combo.map { $0.waku },
                names: combo.map { $0.name },
                probability: probabilityPercent,
                confidence: confidence,
                expectedValue: expectedValue,
                stakeUnits: stakeUnits(confidence: confidence, expectedValue: expectedValue, probability: probabilityPercent),
                rationale: rationale
            ))
        }

        let top3 = Array(top.prefix(3))
        for perm in permutations(top3) {
            let prob = estimateTrifectaProb(perm, allPredictions: top)
            let ev = trifectaEV(perm, prob: prob)
            let conf = confidence(probability: prob, expectedValue: ev, base: prob > 0.08 ? "S" : (prob > 0.04 ? "A" : "B"))
            appendBet(
                type: "3連単",
                combo: perm,
                probability: prob,
                confidence: conf,
                expectedValue: ev,
                rationale: "上位3車の基本線"
            )
        }

        if let darkHorse = darkHorses.first, !top3.contains(where: { $0.waku == darkHorse.waku }) {
            let top2 = Array(top.prefix(2))
            for position in [1, 2] {
                var combo = top2
                combo.insert(darkHorse, at: position)
                let trio = Array(combo.prefix(3))
                let prob = estimateTrifectaProb(trio, allPredictions: top)
                let ev = trifectaEV(trio, prob: prob)
                appendBet(
                    type: "3連単",
                    combo: trio,
                    probability: prob,
                    confidence: confidence(probability: prob, expectedValue: ev, base: "B"),
                    expectedValue: ev,
                    rationale: "穴サイン込み"
                )
            }
        }

        if top.count >= 4 {
            let axis = top[0]
            let candidates = Array(top[1...3])
            for i in 0..<candidates.count {
                for j in 0..<candidates.count where j != i {
                    let combo = [axis, candidates[i], candidates[j]]
                    let key = combo.map { $0.waku }
                    let alreadyExists = bets.contains { $0.type == "3連単" && $0.combination == key }
                    if !alreadyExists {
                        let prob = estimateTrifectaProb(combo, allPredictions: top)
                        let ev = trifectaEV(combo, prob: prob)
                        appendBet(
                            type: "3連単",
                            combo: combo,
                            probability: prob,
                            confidence: confidence(probability: prob, expectedValue: ev, base: prob > 0.04 ? "A" : "B"),
                            expectedValue: ev,
                            rationale: "1着軸固定"
                        )
                    }
                }
            }
        }

        let top4 = Array(top.prefix(min(4, top.count)))
        for i in 0..<min(3, top4.count) {
            for j in 0..<top4.count where j != i {
                let prob = top4[i].winProb / 100 * top4[j].winProb / 100 * 3
                let conf = prob > 0.15 ? "S" : (prob > 0.08 ? "A" : "B")
                appendBet(
                    type: "2車単",
                    combo: [top4[i], top4[j]],
                    probability: prob,
                    confidence: conf,
                    expectedValue: nil,
                    rationale: "着順を絞る"
                )
            }
        }

        for i in 0..<min(4, top.count) {
            for j in (i + 1)..<min(4, top.count) {
                let prob = (top[i].winProb + top[j].winProb) / 100 * 0.6
                appendBet(
                    type: "ワイド",
                    combo: [top[i], top[j]],
                    probability: prob,
                    confidence: prob > 0.3 ? "S" : (prob > 0.15 ? "A" : "B"),
                    expectedValue: nil,
                    rationale: "安全寄り"
                )
            }
        }

        let confOrder: [String: Int] = ["S": 0, "A": 1, "B": 2, "C": 3]
        var seen: Set<String> = []
        return bets.sorted {
            let c1 = confOrder[$0.confidence] ?? 3
            let c2 = confOrder[$1.confidence] ?? 3
            if c1 != c2 { return c1 < c2 }
            if ($0.expectedValue ?? 0) != ($1.expectedValue ?? 0) {
                return ($0.expectedValue ?? 0) > ($1.expectedValue ?? 0)
            }
            return $0.probability > $1.probability
        }
        .filter { bet in
            let key = "\(bet.type)-\(bet.combination.map { String($0) }.joined(separator: "-"))"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        .prefix(24)
        .map { $0 }
    }

    private static func estimateTrifectaProb(_ trio: [PredictionResult], allPredictions: [PredictionResult]) -> Double {
        guard trio.count >= 3 else { return 0 }
        let p1 = trio[0].winProb / 100
        let remaining1 = max(0.01, 1 - p1)
        let p2 = min(1, (trio[1].winProb / 100) / remaining1)
        let remaining2 = max(0.01, remaining1 - trio[1].winProb / 100)
        let p3 = min(1, (trio[2].winProb / 100) / remaining2)
        return p1 * p2 * p3
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

    // MARK: - Line Formation Analysis
    struct LineFormation {
        let district: String
        let members: [(name: String, waku: Int, role: String, style: String)]
        var strength: Double
    }

    static func analyzeLines(
        entries: [RaceEntry],
        playerStats: [String: PlayerStats]
    ) -> [LineFormation] {
        var districtGroups: [String: [(entry: RaceEntry, stat: PlayerStats?)]] = [:]
        for entry in entries {
            let stat = playerStats[entry.name]
            let district = stat?.district ?? ""
            if !district.isEmpty {
                districtGroups[district, default: []].append((entry, stat))
            }
        }

        var lines: [LineFormation] = []
        for (district, group) in districtGroups where group.count >= 2 {
            let rolePriority: [String: Int] = ["逃": 0, "捲": 1, "両": 1, "差": 2, "追": 2]
            let sorted = group.sorted {
                let p0 = rolePriority[$0.stat?.style ?? ""] ?? 3
                let p1 = rolePriority[$1.stat?.style ?? ""] ?? 3
                if p0 != p1 { return p0 < p1 }
                return ($0.stat?.winRate ?? 0) > ($1.stat?.winRate ?? 0)
            }

            let roles = ["先行", "番手", "3番手", "4番手", "5番手"]
            var members: [(name: String, waku: Int, role: String, style: String)] = []
            var strength = 0.0

            for (index, item) in sorted.enumerated() {
                let role = index < roles.count ? roles[index] : "追走"
                let style = item.stat?.style ?? ""
                members.append((name: item.entry.name, waku: item.entry.waku, role: role, style: style))

                let classScore = classWeight[item.stat?.classRank ?? ""] ?? 0
                let winRate = item.stat?.winRate ?? 0
                let positionMultiplier = index == 0 ? 1.5 : (index == 1 ? 1.2 : 1.0)
                strength += (classScore + winRate * 20) * positionMultiplier
            }

            strength *= (1.0 + Double(members.count - 2) * 0.15)
            lines.append(LineFormation(district: district, members: members, strength: strength))
        }

        return lines.sorted { $0.strength > $1.strength }
    }

    static func simulateScenarios(
        lines: [LineFormation],
        bank: Int,
        entries: [RaceEntry],
        playerStats: [String: PlayerStats]
    ) -> [String: Double] {
        var bonuses: [String: Double] = [:]

        guard let strongestLine = lines.first else { return bonuses }

        if let leader = strongestLine.members.first {
            bonuses[leader.name, default: 0] += strongestLine.strength * 0.1
            if leader.style == "逃" && bank <= 335 {
                bonuses[leader.name, default: 0] += 5
            }

            if strongestLine.members.count >= 2 {
                let bante = strongestLine.members[1]
                bonuses[bante.name, default: 0] += strongestLine.strength * 0.08
                if bank == 400 {
                    bonuses[bante.name, default: 0] += 3
                }
            }
        }

        let soloRiders = entries.filter { entry in
            let district = playerStats[entry.name]?.district ?? ""
            return district.isEmpty || !lines.contains(where: { $0.district == district })
        }
        for solo in soloRiders {
            let stat = playerStats[solo.name]
            if bank >= 500 && (stat?.style == "追" || stat?.style == "差") {
                bonuses[solo.name, default: 0] += 4
            }
        }

        if lines.count >= 2 {
            let weakestLine = lines.last!
            for member in weakestLine.members {
                bonuses[member.name, default: 0] -= 2
            }
        }

        return bonuses
    }

    private static func styleBankBonus(style: String, bank: Int) -> Double {
        switch style {
        case "逃":
            if bank <= 335 { return 8 }
            if bank == 400 { return 2 }
            if bank >= 500 { return -4 }
        case "捲":
            if bank <= 335 { return 4 }
            if bank == 400 { return 5 }
            if bank >= 500 { return 2 }
        case "差":
            if bank <= 335 { return -2 }
            if bank == 400 { return 3 }
            if bank >= 500 { return 7 }
        case "追":
            if bank <= 335 { return -3 }
            if bank == 400 { return 2 }
            if bank >= 500 { return 8 }
        case "両":
            return 3
        default:
            return 0
        }
        return 0
    }

    private static func commentProfile(comment: String, style: String, bank: Int) -> (bonus: Double, label: String?) {
        guard !comment.isEmpty else { return (0, nil) }
        if comment.contains("自力") {
            let bonus = (style == "逃" || style == "捲" || style == "両") ? 2.0 : 0.8
            return (bank <= 335 ? bonus + 0.8 : bonus, "自力宣言")
        }
        if comment.contains("番手") || comment.contains("マーク") || comment.contains("任せ") || comment.contains("君") {
            return (bank >= 400 ? 1.8 : 1.1, "番手気配")
        }
        if comment.contains("自在") || comment.contains("前々") {
            return (1.1, "自在")
        }
        if comment.contains("単騎") || comment.contains("一人") || comment.contains("決めず") {
            return (bank >= 500 ? 0.8 : -1.0, "単騎")
        }
        return (0, nil)
    }

    private static func lineMatrixRate(_ left: String, _ right: String, lineMatrix: [String: LineEntry]) -> Double? {
        let direct = "\(left)_\(right)"
        let reverse = "\(right)_\(left)"
        if let entry = lineMatrix[direct], entry.t >= 50 { return entry.r }
        if let entry = lineMatrix[reverse], entry.t >= 50 { return entry.r }
        return nil
    }

    private static func estimateAxisHitRate(
        axis: PredictionResult,
        topGap: Double,
        chaosScore: Double,
        closePack: Int,
        darkHorseCount: Int,
        lines: [LineFormation]
    ) -> Double {
        var estimate = axis.winProb
        estimate += topGap * 1.15
        estimate -= chaosScore * 0.12
        estimate -= Double(max(0, closePack - 2)) * 1.7
        estimate -= Double(darkHorseCount) * 1.8
        if axis.riskLabel == "軸候補" { estimate += 3.5 }
        if axis.lineRole == "番手" { estimate += 1.8 }
        if let strongest = lines.first,
           strongest.members.contains(where: { $0.name == axis.name }),
           strongest.strength >= (lines.dropFirst().first?.strength ?? 0) + 14 {
            estimate += 2.5
        }
        return clamp(estimate, lower: 6, upper: 58)
    }

    private static func racePlayPlan(
        axisWinEstimate: Double,
        topGap: Double,
        chaosScore: Double,
        closePack: Int,
        darkHorseCount: Int
    ) -> (grade: String, advice: String, actionLabel: String, actionReason: String) {
        if chaosScore >= 72 || (topGap < 4 && closePack >= 4) {
            return ("見", "混戦。30%狙いから外す", "見送り", "荒れやすいので買わない")
        }
        if axisWinEstimate >= 36, topGap >= 11, chaosScore <= 48, closePack <= 3, darkHorseCount <= 1 {
            return ("S", "30%超え候補。軸から絞る", "買い", "軸が抜けていて荒れ指数も低い")
        }
        if axisWinEstimate >= 32, topGap >= 8, chaosScore <= 55, closePack <= 3, darkHorseCount <= 1 {
            return ("A", "勝負可。点数を増やしすぎない", "買い", "軸候補と2番手以下の差がある")
        }
        if axisWinEstimate >= 28, topGap >= 7, chaosScore <= 60 {
            return ("B", "薄め。押さえ中心", "見送り", "悪くないが50%狙いでは薄い")
        }
        if axisWinEstimate >= 25, chaosScore <= 66 {
            return ("C", "見送り寄り。妙味待ち", "見送り", "軸の勝ち切りが足りない")
        }
        return ("C", "見送り寄り。妙味待ち", "見送り", "買う条件に届かない")
    }

    private static func confidence(probability: Double, expectedValue: Double?, base: String) -> String {
        if let expectedValue = expectedValue {
            if expectedValue >= 1.6 { return "S" }
            if expectedValue >= 1.15 { return base == "B" ? "A" : base }
            if expectedValue < 0.85 { return "B" }
        }
        return base
    }

    private static func stakeUnits(confidence: String, expectedValue: Double?, probability: Double) -> Int {
        var units: Double
        switch confidence {
        case "S": units = 3
        case "A": units = 2
        default: units = 1
        }
        if let expectedValue = expectedValue {
            units += clamp((expectedValue - 1.0) * 1.5, lower: -0.5, upper: 2.0)
        }
        if probability >= 25 { units += 1 }
        return Int(clamp(units.rounded(), lower: 1, upper: 5))
    }

    private static func average<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        let array = Array(values)
        guard !array.isEmpty else { return 0 }
        return array.reduce(0, +) / Double(array.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let avg = average(values)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
