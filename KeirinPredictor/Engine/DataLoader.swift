import Foundation

class DataLoader: ObservableObject {
    @Published var playerStats: [String: PlayerStats] = [:]
    @Published var venueStats: [String: VenueStats] = [:]
    @Published var lineMatrix: [String: LineEntry] = [:]
    @Published var todayRaces: [TodayRace] = []
    @Published var todayDateString: String = ""
    @Published var isLoaded = false

    static let shared = DataLoader()

    private static let remoteBaseURL = "https://snarfnet.github.io/keirin-data"

    private init() {}

    func load() {
        guard !isLoaded else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let ps = self.loadJSON(name: "player_stats", type: [String: PlayerStats].self) ?? [:]
            let vs = self.loadJSON(name: "venue_stats", type: [String: VenueStats].self) ?? [:]
            let lm = self.loadJSON(name: "line_matrix", type: [String: LineEntry].self) ?? [:]
            let today = self.loadTodayEntries()
            DispatchQueue.main.async {
                self.playerStats = ps
                self.venueStats = vs
                self.lineMatrix = lm
                if let today = today {
                    self.todayRaces = today.races
                    self.todayDateString = self.formatDateString(today.date)
                }
                self.isLoaded = true
                self.fetchRemoteTodayEntries()
            }
        }
    }

    private func loadTodayEntries() -> TodayRacesData? {
        // Try cached file first
        if let cached = loadCachedTodayEntries() {
            return cached
        }
        // Fall back to bundle
        return loadJSON(name: "today_entries", type: TodayRacesData.self)
    }

    private func loadCachedTodayEntries() -> TodayRacesData? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = cacheDir.appendingPathComponent("today_entries.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let result = try JSONDecoder().decode(TodayRacesData.self, from: data)
            // Only use if it's today's data
            let todayStr = Self.todayString()
            if result.date == todayStr {
                return result
            }
            return nil
        } catch {
            return nil
        }
    }

    func fetchRemoteTodayEntries() {
        guard let url = URL(string: "\(Self.remoteBaseURL)/today_entries.json") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse,
                  httpResp.statusCode == 200 else { return }
            do {
                let result = try JSONDecoder().decode(TodayRacesData.self, from: data)
                // Cache locally
                if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let fileURL = cacheDir.appendingPathComponent("today_entries.json")
                    try? data.write(to: fileURL)
                }
                DispatchQueue.main.async {
                    self.todayRaces = result.races
                    self.todayDateString = self.formatDateString(result.date)
                }
            } catch {
                print("Remote today_entries decode error: \(error)")
            }
        }.resume()
    }

    private func loadJSON<T: Decodable>(name: String, type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            print("Missing \(name).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Decode error \(name): \(error)")
            return nil
        }
    }

    private func formatDateString(_ yyyymmdd: String) -> String {
        guard yyyymmdd.count == 8,
              let y = Int(yyyymmdd.prefix(4)),
              let m = Int(yyyymmdd.dropFirst(4).prefix(2)),
              let d = Int(yyyymmdd.suffix(2)) else {
            return yyyymmdd
        }
        return "\(y)年\(m)月\(d)日"
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f.string(from: Date())
    }
}
