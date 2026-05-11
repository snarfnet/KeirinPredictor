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
                        betCombination: [Int]? = nil, betAmount: Int? = nil) {
        let record = PredictionRecord(
            raceId: raceId, venue: venue, raceNo: raceNo, date: date,
            predictedTop3: predictedTop3, actualTop3: [],
            betType: betType, betCombination: betCombination,
            betAmount: betAmount, payout: nil
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
            betAmount: old.betAmount, payout: payout
        )
        if let p = payout {
            bankroll.returned += p
        }
        save()
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

    var hitRate: Double {
        totalPredictions > 0 ? Double(winCount) / Double(totalPredictions) * 100 : 0
    }

    var top3HitRate: Double {
        totalPredictions > 0 ? Double(top3HitCount) / Double(totalPredictions) * 100 : 0
    }

    var recentRecords: [PredictionRecord] {
        records.sorted { $0.date > $1.date }.prefix(30).map { $0 }
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
}
