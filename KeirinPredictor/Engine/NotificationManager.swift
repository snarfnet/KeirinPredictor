import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
    }

    /// Schedule a local notification for a high-EV race
    func notifyHighEV(raceId: String, venue: String, raceNo: Int, message: String, fireIn: TimeInterval = 1) {
        let content = UNMutableNotificationContent()
        content.title = "\(venue) \(raceNo)R - 高期待値"
        content.body = message
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireIn), repeats: false)
        let request = UNNotificationRequest(identifier: "ev_\(raceId)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Check today's races for high-EV opportunities and notify
    func scanForHighEV(races: [TodayRace], playerStats: [String: PlayerStats],
                       venueStats: [String: VenueStats], odds: [String: RaceOdds]) {
        for race in races {
            guard let raceOdds = odds[race.race_id] else { continue }

            let entries = race.entries.map { RaceEntry(name: $0.name, waku: $0.umaban) }
            var entryScores: [String: Double] = [:]
            for e in race.entries { entryScores[e.name] = e.score }

            let predictions = PredictionEngine.predict(
                entries: entries, venue: race.venue,
                playerStats: playerStats, venueStats: venueStats,
                entryScores: entryScores
            )
            let bets = PredictionEngine.generateBets(predictions: predictions, odds: raceOdds.trifecta)

            // Find high-EV bets (EV > 1.5)
            let highEV = bets.filter { ($0.expectedValue ?? 0) > 1.5 }
            if let best = highEV.first {
                let combo = best.combination.map { "\($0)" }.joined(separator: "-")
                let msg = "\(best.type) \(combo) EV\(String(format: "%.1f", best.expectedValue ?? 0)) 期待値が高い買い目です"
                notifyHighEV(raceId: race.race_id, venue: race.venue, raceNo: race.raceNo, message: msg)
            }
        }
    }
}
