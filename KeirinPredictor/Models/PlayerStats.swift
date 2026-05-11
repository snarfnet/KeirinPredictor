import Foundation

// MARK: - Player Stats (from player_stats.json compressed keys)
struct PlayerStats: Codable {
    let d: String   // 地区
    let p: String   // 県
    let s: String   // 脚質
    let c: String   // 級班
    let g: Int      // 卒業期
    let r: Int      // 出走数
    let w: Int      // 勝数
    let wr: Double  // 勝率
    let t2: Double  // 連対率
    let t3: Double  // 3連対率
    let rr: [Int]   // 直近着順
    let rk: [String] // 直近決まり手
    let vs: [String: VenueRecord] // 場別成績
    let bk: [String: BankRecord]? // バンク別成績 (s=333m, m=400m, l=500m)
    let fm: Double?  // フォームスコア (加重直近調子)
    let dk: String?  // 得意決まり手

    var district: String { d }
    var prefecture: String { p }
    var style: String { s }
    var classRank: String { c }
    var graduation: Int { g }
    var races: Int { r }
    var wins: Int { w }
    var winRate: Double { wr }
    var top2Rate: Double { t2 }
    var top3Rate: Double { t3 }
    var recentRanks: [Int] { rr }
    var recentKimarite: [String] { rk }
    var venueStats: [String: VenueRecord] { vs }
    var bankStats: [String: BankRecord] { bk ?? [:] }
    var formScore: Double { fm ?? 0 }
    var dominantKimarite: String { dk ?? "" }
}

struct VenueRecord: Codable {
    let r: Int  // 出走数
    let w: Int  // 勝数

    var races: Int { r }
    var wins: Int { w }
    var winRate: Double { r > 0 ? Double(w) / Double(r) : 0 }
}

struct BankRecord: Codable {
    let r: Int   // 出走数
    let w: Int   // 勝数
    let t3: Int  // 3着以内

    var races: Int { r }
    var wins: Int { w }
    var top3: Int { t3 }
    var winRate: Double { r > 0 ? Double(w) / Double(r) : 0 }
    var top3Rate: Double { r > 0 ? Double(t3) / Double(r) : 0 }
}

// MARK: - Venue Stats (from venue_stats.json)
struct VenueStats: Codable {
    let bank: Int       // 周長
    let races: Int      // レース数
    let km: [String: Double] // 決まり手分布
}

// MARK: - Line Matrix (from line_matrix.json)
struct LineEntry: Codable {
    let w: Int      // 1-2着組数
    let t: Int      // 同レース数
    let r: Double   // 率
}

// MARK: - Today's Race (from today_entries.json)
struct TodayRacesData: Codable {
    let date: String
    let races: [TodayRace]
}

struct UpcomingRacesData: Codable {
    let updated: String
    let days: [String]
    let races: [TodayRace]
}

struct TodayRace: Codable, Identifiable, Hashable {
    var id: String { race_id }
    let race_id: String
    let venue: String
    let venue_cd: String
    let race_no: Int
    let entries: [TodayRaceEntry]
    let date: String?

    var raceNo: Int { race_no }
    var dateString: String { date ?? "" }

    static func == (lhs: TodayRace, rhs: TodayRace) -> Bool { lhs.race_id == rhs.race_id }
    func hash(into hasher: inout Hasher) { hasher.combine(race_id) }
}

struct TodayRaceEntry: Codable, Identifiable {
    var id: String { "\(umaban)_\(name)" }
    let waku: Int
    let umaban: Int
    let name: String
    let name_kana: String
    let score: Double
    let style: String
    let win_rate: Double
    let top2_rate: Double
    let top3_rate: Double
    let gear: String
    let comment: String

    var winRate: Double { win_rate }
}

// MARK: - Today's Race Results (from today_results.json)
struct TodayResultsData: Codable {
    let date: String
    let results: [TodayRaceResult]
}

struct TodayRaceResult: Codable, Identifiable {
    var id: String { race_id }
    let race_id: String
    let venue: String
    let race_no: Int
    let finishers: [Finisher]
    let paybacks: [Payback]
}

struct Finisher: Codable {
    let rank: Int
    let waku: Int
    let umaban: Int
    let name: String
    let kimarite: String
}

struct Payback: Codable {
    let type: String    // 3連単, 3連複, 2車単, 2車複, ワイド
    let combination: String
    let payout: Int
}

// MARK: - Odds Data (from today_odds.json)
struct TodayOddsData: Codable {
    let date: String
    let updated: String
    let races: [RaceOdds]
}

struct RaceOdds: Codable {
    let race_id: String
    let venue: String
    let race_no: Int
    let trifecta: [String: Double]  // "1-2-3": 7.7
}

// MARK: - Race Entry (UI model)
struct RaceEntry: Identifiable {
    let id = UUID()
    var name: String
    var waku: Int
}

// MARK: - Prediction Result
struct PredictionResult: Identifiable {
    let id = UUID()
    let name: String
    let waku: Int
    let score: Double
    let winProb: Double
    let predRank: Int
    let district: String
    let style: String
    let winRate: Double
    let top3Rate: Double
    let recentAvg: Double?
    let formScore: Double
    let classRank: String
    let isDarkHorse: Bool
}

// MARK: - Prediction Tracking
struct PredictionRecord: Codable, Identifiable {
    var id: String { raceId }
    let raceId: String
    let venue: String
    let raceNo: Int
    let date: String
    let predictedTop3: [Int]  // umaban
    let actualTop3: [Int]     // umaban (empty until result)
    let betType: String?
    let betCombination: [Int]?
    let betAmount: Int?
    let payout: Int?

    var isHit: Bool {
        guard !actualTop3.isEmpty, !predictedTop3.isEmpty else { return false }
        return predictedTop3[0] == actualTop3[0]  // 1着的中
    }
    var isTop3Hit: Bool {
        guard actualTop3.count >= 3, predictedTop3.count >= 3 else { return false }
        return Set(predictedTop3.prefix(3)) == Set(actualTop3.prefix(3))
    }
    var profit: Int {
        (payout ?? 0) - (betAmount ?? 0)
    }
}

// MARK: - Bankroll
struct BankrollState: Codable {
    var budget: Int = 10000
    var spent: Int = 0
    var returned: Int = 0

    var balance: Int { budget - spent + returned }
    var roi: Double { spent > 0 ? Double(returned - spent) / Double(spent) * 100 : 0 }
}

// MARK: - Bet Recommendation
struct BetRecommendation: Identifiable {
    let id = UUID()
    let type: String        // 3連単, 2車単, 2車複, ワイド
    let combination: [Int]  // umaban list
    let names: [String]
    let probability: Double
    let confidence: String  // S, A, B, C
    let expectedValue: Double? // odds × probability (nil if no odds)
}

// MARK: - Class rank display
extension String {
    var classDisplayName: String {
        switch self {
        case "S1": return "S級1班"
        case "S2": return "S級2班"
        case "A1": return "A級1班"
        case "A2": return "A級2班"
        default: return self.isEmpty ? "未格付" : self
        }
    }

    var classBadgeColor: String {
        switch self {
        case "S1", "S2": return "gold"
        case "A1": return "silver"
        case "A2": return "bronze"
        default: return "gray"
        }
    }
}
