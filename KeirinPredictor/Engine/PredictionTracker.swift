import Foundation

class PredictionTracker: ObservableObject {
    @Published var records: [PredictionRecord] = []
    @Published var bankroll: BankrollState = BankrollState()

    private let recordsKey = "prediction_records"
    private let bankrollKey = "bankroll_state"

    init() {
        load()
    }

    // MARK: - Record Management

    func savePrediction(raceId: String, venue: String, raceNo: Int, date: String,
                        predictedTop3: [Int], betType: String? = nil,
                        betCombination: [Int]? = nil, betAmount: Int? = nil,
                        playGrade: String? = nil, axisWinEstimate: Double? = nil) {
        let record = PredictionRecord(
            raceId: raceId, venue: venue, raceNo: raceNo, date: date,
            predictedTop3: predictedTop3, actualTop3: [],
            betType: betType, betCombination: betCombination,
            betAmount: betAmount, payout: nil,
            playGrade: playGrade, axisWinEstimate: axisWinEstimate
        )
        records.removeAll { $0.raceId == raceId }
        records.append(record)

        if let amount = betAmount {
            bankroll.spent += amount
        }
        save()
    }

    func updateResult(raceId: String, actualTop3: [Int], payout: Int? = nil) {
        guard let idx = records.firstIndex(where: { $0.raceId == raceId }) else { return }
        let old = records[idx]
        records[idx] = PredictionRecord(
            raceId: old.raceId, venue: old.venue, raceNo: old.raceNo, date: old.date,
            predictedTop3: old.predictedTop3, actualTop3: actualTop3,
            betType: old.betType, betCombination: old.betCombination,
            betAmount: old.betAmount, payout: payout,
            playGrade: old.playGrade, axisWinEstimate: old.axisWinEstimate
        )
        if let p = payout {
            bankroll.returned += p
        }
        save()
    }

    func syncResults(_ results: [TodayRaceResult]) {
        guard !results.isEmpty else { return }

        var changed = false
        for result in results {
            guard let idx = records.firstIndex(where: { $0.raceId == result.race_id }) else { continue }
            let finishers = result.finishers
                .sorted { $0.rank < $1.rank }
                .prefix(3)
                .map { $0.umaban }
            guard finishers.count >= 3 else { continue }

            let old = records[idx]
            if old.actualTop3 == finishers { continue }

            records[idx] = PredictionRecord(
                raceId: old.raceId, venue: old.venue, raceNo: old.raceNo, date: old.date,
                predictedTop3: old.predictedTop3, actualTop3: Array(finishers),
                betType: old.betType, betCombination: old.betCombination,
                betAmount: old.betAmount, payout: matchedPayout(record: old, result: result),
                playGrade: old.playGrade, axisWinEstimate: old.axisWinEstimate
            )
            changed = true
        }

        if changed {
            recalculateBankrollFromRecords()
            save()
        }
    }

    func setBudget(_ amount: Int) {
        bankroll.budget = amount
        save()
    }

    func resetBankroll() {
        bankroll = BankrollState()
        save()
    }

    // MARK: - Stats

    var totalPredictions: Int { records.filter { !$0.actualTop3.isEmpty }.count }

    var winCount: Int { records.filter { $0.isHit }.count }

    var top3HitCount: Int { records.filter { $0.isTop3Hit }.count }

    var trifectaHitCount: Int { records.filter { $0.isTrifectaHit }.count }

    var exactaHitCount: Int { records.filter { $0.isExactaHit }.count }

    var wideHitCount: Int { records.filter { $0.isWideHit }.count }

    var actionPredictions: [PredictionRecord] {
        records.filter { !$0.actualTop3.isEmpty && $0.isActionRace }
    }

    var actionPredictionCount: Int { actionPredictions.count }

    var actionWinCount: Int { actionPredictions.filter { $0.isHit }.count }

    var actionHitRate: Double {
        actionPredictionCount > 0 ? Double(actionWinCount) / Double(actionPredictionCount) * 100 : 0
    }

    var targetHitRate: Double { 30 }

    var actionTargetGap: Double { actionHitRate - targetHitRate }

    var actionSampleLabel: String {
        actionPredictionCount >= 30 ? "判定可能" : "あと\(max(0, 30 - actionPredictionCount))件"
    }

    var actionTuningAdvice: String {
        if actionPredictionCount < 10 {
            return "まずS/Aを10件ためる"
        }
        if actionHitRate >= 34 {
            return "勝負範囲を少し広げてもいい"
        }
        if actionHitRate >= 30 {
            return "今の絞り方を維持"
        }
        if actionHitRate >= 24 {
            return "S中心に寄せる"
        }
        return "見送り基準を強める"
    }

    var hitRate: Double {
        totalPredictions > 0 ? Double(winCount) / Double(totalPredictions) * 100 : 0
    }

    var top3HitRate: Double {
        totalPredictions > 0 ? Double(top3HitCount) / Double(totalPredictions) * 100 : 0
    }

    var trifectaHitRate: Double {
        totalPredictions > 0 ? Double(trifectaHitCount) / Double(totalPredictions) * 100 : 0
    }

    var exactaHitRate: Double {
        totalPredictions > 0 ? Double(exactaHitCount) / Double(totalPredictions) * 100 : 0
    }

    var wideHitRate: Double {
        totalPredictions > 0 ? Double(wideHitCount) / Double(totalPredictions) * 100 : 0
    }

    var recentRecords: [PredictionRecord] {
        records.sorted { $0.date > $1.date }.prefix(30).map { $0 }
    }

    func conditionInsight(
        venue: String,
        raceNo: Int,
        playGrade: String,
        axisWinEstimate: Double
    ) -> PredictionConditionInsight {
        let completed = records
            .filter { !$0.actualTop3.isEmpty }
            .sorted { $0.date > $1.date }
            .prefix(240)

        guard completed.count >= 10 else {
            return .neutral
        }

        let baseline = max(18, min(42, Double(completed.filter { $0.isHit }.count) / Double(completed.count) * 100))
        let raceBand = raceNoBand(raceNo)
        let axisBand = axisEstimateBand(axisWinEstimate)
        var adjustment = 0.0
        var notes: [String] = []

        func apply(_ sample: [PredictionRecord], label: String, weight: Double, minCount: Int) {
            guard sample.count >= minCount else { return }
            let wins = sample.filter { $0.isHit }.count
            let rate = Double(wins) / Double(sample.count) * 100
            let confidence = min(1.0, Double(sample.count) / 24.0)
            let edge = rate - baseline
            adjustment += (edge / 10.0) * weight * confidence

            if abs(edge) >= 6, notes.count < 2 {
                notes.append("\(label)の過去1着 \(wins)/\(sample.count)")
            }
        }

        apply(completed.filter { $0.playGrade == playGrade }, label: "グレード\(playGrade)", weight: 8.0, minCount: 3)
        apply(completed.filter { axisEstimateBand($0.axisWinEstimate ?? 0) == axisBand }, label: axisBand, weight: 6.0, minCount: 4)
        apply(completed.filter { raceNoBand($0.raceNo) == raceBand }, label: raceBand, weight: 4.5, minCount: 4)
        apply(completed.filter { $0.venue == venue }, label: venue, weight: 3.5, minCount: 3)

        let capped = min(max(adjustment, -10), 10)
        return PredictionConditionInsight(
            qualityAdjustment: capped * 2.4,
            estimateAdjustment: capped * 0.55,
            notes: notes
        )
    }

    /// Kelly criterion: optimal bet fraction
    func kellyFraction(winProb: Double, odds: Double) -> Double {
        guard odds > 0, winProb > 0, winProb < 1 else { return 0 }
        let b = odds - 1
        let kelly = (b * winProb - (1 - winProb)) / b
        return max(0, min(kelly * 0.5, 0.1)) // Half-Kelly capped at 10%
    }

    func suggestedBet(winProb: Double, odds: Double) -> Int {
        let fraction = kellyFraction(winProb: winProb, odds: odds)
        let amount = Double(bankroll.balance) * fraction
        return max(0, Int(amount / 100) * 100) // Round to 100 yen
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
        if let data = try? JSONEncoder().encode(bankroll) {
            UserDefaults.standard.set(data, forKey: bankrollKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([PredictionRecord].self, from: data) {
            records = decoded
        }
        if let data = UserDefaults.standard.data(forKey: bankrollKey),
           let decoded = try? JSONDecoder().decode(BankrollState.self, from: data) {
            bankroll = decoded
        }
    }

    private func matchedPayout(record: PredictionRecord, result: TodayRaceResult) -> Int? {
        guard let betType = record.betType,
              let betCombination = record.betCombination,
              !betCombination.isEmpty else {
            return record.payout
        }

        let key = betCombination.map { String($0) }.joined(separator: "-")
        return result.paybacks.first { payback in
            payback.type == betType && payback.combination == key
        }?.payout
    }

    private func recalculateBankrollFromRecords() {
        bankroll.spent = records.compactMap { $0.betAmount }.reduce(0, +)
        bankroll.returned = records.compactMap { $0.payout }.reduce(0, +)
    }

    private func axisEstimateBand(_ value: Double) -> String {
        if value >= 36 { return "軸36%以上" }
        if value >= 32 { return "軸32-35%" }
        if value >= 28 { return "軸28-31%" }
        return "軸28%未満"
    }

    private func raceNoBand(_ raceNo: Int) -> String {
        if raceNo <= 3 { return "序盤レース" }
        if raceNo <= 6 { return "中盤レース" }
        return "後半レース"
    }
}
