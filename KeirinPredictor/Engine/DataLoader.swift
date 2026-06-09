import Foundation

class DataLoader: ObservableObject {
    @Published var playerStats: [String: PlayerStats] = [:]
    @Published var venueStats: [String: VenueStats] = [:]
    @Published var lineMatrix: [String: LineEntry] = [:]
    @Published var todayRaces: [TodayRace] = []
    @Published var resultRaces: [TodayRace] = []
    @Published var todayResults: [TodayRaceResult] = []
    @Published var todayOdds: [String: RaceOdds] = [:] // race_id -> RaceOdds
    @Published var todayDateString: String = ""
    @Published var todayDataWarning: String? = nil
    @Published var todayResultsDateString: String = ""
    @Published var isResultsLoading = false
    @Published var resultsLoadError: String? = nil
    @Published var dataStatusTitle: String = "データ確認中"
    @Published var dataStatusDetail: String = "最新データを確認しています"
    @Published var dataLastUpdatedText: String = ""
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
                self.fetchRemotePlayerStats()
                self.fetchRemoteTodayEntries()
                self.fetchRemoteTodayResults()
                self.fetchRemoteTodayOdds()
            }
        }
    }

    func fetchRemotePlayerStats() {
        guard let url = Self.remoteURL("player_stats.json") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        performDataRequest(request) { data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse,
                  httpResp.statusCode == 200 else { return }
            do {
                let result = try JSONDecoder().decode([String: PlayerStats].self, from: data)
                guard !result.isEmpty else { return }
                DispatchQueue.main.async {
                    self.playerStats = result
                }
            } catch {
                print("Remote player_stats decode error: \(error)")
            }
        }
    }

    private func loadTodayEntries() -> TodayRacesData? {
        // Try cached file first
        if let cached = loadCachedTodayEntries() {
            return cached
        }
        // Fall back to bundle only if date matches today
        if let bundle = loadJSON(name: "today_entries", type: TodayRacesData.self) {
            let todayStr = Self.todayString()
            if bundle.date == todayStr {
                return bundle
            }
        }
        return nil
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
        DispatchQueue.main.async {
            self.dataStatusTitle = "出走表を更新中"
            self.dataStatusDetail = "最新の出走表を確認しています"
        }
        // First try upcoming_entries.json (multi-day)
        guard let upcomingURL = Self.remoteURL("upcoming_entries.json") else { return }
        var request = URLRequest(url: upcomingURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        performDataRequest(request) { data, response, error in
            if let data = data,
               let httpResp = response as? HTTPURLResponse,
               httpResp.statusCode == 200 {
                do {
                    let result = try JSONDecoder().decode(UpcomingRacesData.self, from: data)
                    if !result.races.isEmpty {
                        // Show only today or a future race day. Never show stale previous-day races as today's races.
                        let todayStr = Self.todayString()
                        let displayDays = result.days.sorted().filter { $0 >= todayStr }
                        guard let displayDay = displayDays.first else {
                            DispatchQueue.main.async {
                                self.todayRaces = []
                                self.todayDateString = self.formatDateString(todayStr)
                                self.todayDataWarning = "今日の出走表はまだ配信されていません"
                            }
                            return
                        }
                        let racesForDays = result.races.filter { race in
                            let raceDay = race.date ?? displayDay
                            let hasEntries = !race.entries.isEmpty
                            let isFutureSchedule = raceDay > todayStr
                            return displayDays.contains(raceDay) && (hasEntries || isFutureSchedule)
                        }
                        DispatchQueue.main.async {
                            self.todayRaces = racesForDays
                            self.todayDateString = self.formatDateString(displayDay)
                            self.todayDataWarning = racesForDays.isEmpty ? "今日以降の出走表はまだ配信されていません" : nil
                            self.dataStatusTitle = "出走表 取得済み"
                            self.dataStatusDetail = "\(racesForDays.count)レースを表示中"
                            self.dataLastUpdatedText = self.formatRefreshTime(Date())
                        }
                        let todayRacesOnly = result.races.filter { ($0.date ?? displayDay) == todayStr && !$0.entries.isEmpty }
                        if !todayRacesOnly.isEmpty {
                            self.cacheTodayEntries(TodayRacesData(date: todayStr, races: todayRacesOnly))
                        }
                        return
                    }
                } catch {
                    print("Remote upcoming_entries decode error: \(error)")
                }
            }
            // Fallback to today_entries.json
            self.fetchTodayEntriesFallback()
        }
    }

    private func fetchTodayEntriesFallback() {
        guard let url = Self.remoteURL("today_entries.json") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        performDataRequest(request) { data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse,
                  httpResp.statusCode == 200 else {
                DispatchQueue.main.async {
                    if self.applyCachedTodayEntries() {
                        self.dataStatusTitle = "前回データを表示"
                        self.dataStatusDetail = "通信に失敗したため前回成功分を使っています"
                    } else {
                        self.dataStatusTitle = "出走表 取得失敗"
                        self.dataStatusDetail = "時間を置いて再取得してください"
                    }
                }
                return
            }
            do {
                let result = try JSONDecoder().decode(TodayRacesData.self, from: data)
                let todayStr = Self.todayString()
                guard result.date == todayStr else {
                    DispatchQueue.main.async {
                        self.todayRaces = []
                        self.todayDateString = self.formatDateString(todayStr)
                        self.todayDataWarning = "今日の出走表はまだ配信されていません"
                        self.dataStatusTitle = "本日分は未配信"
                        self.dataStatusDetail = "前日データは表示していません"
                    }
                    return
                }
                self.cacheTodayEntries(result)
                DispatchQueue.main.async {
                    self.todayRaces = result.races
                    self.todayDateString = self.formatDateString(result.date)
                    self.todayDataWarning = result.races.isEmpty ? "今日の出走表はまだ配信されていません" : nil
                    self.dataStatusTitle = "出走表 取得済み"
                    self.dataStatusDetail = "\(result.races.count)レースを表示中"
                    self.dataLastUpdatedText = self.formatRefreshTime(Date())
                }
            } catch {
                print("Remote today_entries decode error: \(error)")
                DispatchQueue.main.async {
                    _ = self.applyCachedTodayEntries()
                    self.dataStatusTitle = "前回データを表示"
                    self.dataStatusDetail = "読み込み失敗のため前回成功分を使っています"
                }
            }
        }
    }

    func fetchRemoteTodayOdds() {
        guard let url = Self.remoteURL("today_odds.json") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        performDataRequest(request) { data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse,
                  httpResp.statusCode == 200 else { return }
            do {
                let result = try JSONDecoder().decode(TodayOddsData.self, from: data)
                var oddsMap: [String: RaceOdds] = [:]
                for race in result.races {
                    oddsMap[race.race_id] = race
                }
                DispatchQueue.main.async {
                    self.todayOdds = oddsMap
                    NotificationManager.shared.scanForHighEV(
                        races: self.todayRaces,
                        playerStats: self.playerStats,
                        venueStats: self.venueStats,
                        lineMatrix: self.lineMatrix,
                        odds: oddsMap
                    )
                }
            } catch {
                print("Remote today_odds decode error: \(error)")
            }
        }
    }

    func fetchRemoteTodayResults() {
        DispatchQueue.main.async {
            self.isResultsLoading = true
            self.resultsLoadError = nil
        }

        guard let url = Self.remoteURL("today_results.json") else {
            DispatchQueue.main.async {
                self.isResultsLoading = false
                self.resultsLoadError = "結果データのURLを確認できませんでした"
            }
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        performDataRequest(request) { data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse,
                  httpResp.statusCode == 200 else {
                DispatchQueue.main.async {
                    if self.applyCachedTodayResults() {
                        self.resultsLoadError = nil
                        self.dataStatusTitle = "前回結果を表示"
                        self.dataStatusDetail = "結果データは前回成功分です"
                    } else {
                        self.resultsLoadError = "結果データに接続できませんでした"
                    }
                    self.isResultsLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(TodayResultsData.self, from: data)
                if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let fileURL = cacheDir.appendingPathComponent("today_results.json")
                    try? data.write(to: fileURL)
                }
                DispatchQueue.main.async {
                    self.todayResults = result.results
                    self.todayResultsDateString = self.formatDateString(result.date)
                    self.isResultsLoading = false
                    self.resultsLoadError = nil
                }
                if !result.results.isEmpty {
                    self.fetchRemoteEntriesForResultDate(result.date)
                }
            } catch {
                print("Remote today_results decode error: \(error)")
                DispatchQueue.main.async {
                    _ = self.applyCachedTodayResults()
                    self.isResultsLoading = false
                    self.resultsLoadError = "結果データを読み込めませんでした"
                }
            }
        }
    }

    private func fetchRemoteEntriesForResultDate(_ dateString: String) {
        guard let url = Self.remoteURL("entries_\(dateString).json") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        performDataRequest(request) { data, response, error in
            guard let data = data,
                  let httpResp = response as? HTTPURLResponse,
                  httpResp.statusCode == 200 else { return }
            do {
                let result = try JSONDecoder().decode(TodayRacesData.self, from: data)
                DispatchQueue.main.async {
                    self.resultRaces = result.races
                }
            } catch {
                print("Remote entries_\(dateString) decode error: \(error)")
            }
        }
    }

    private func performDataRequest(
        _ request: URLRequest,
        attempts: Int = 2,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let succeeded = error == nil && (200..<300).contains(statusCode) && data != nil
            if succeeded || attempts <= 1 {
                completion(data, response, error)
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
                self.performDataRequest(request, attempts: attempts - 1, completion: completion)
            }
        }.resume()
    }

    private func cacheTodayEntries(_ result: TodayRacesData) {
        guard !result.races.isEmpty,
              let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(result) else { return }
        let fileURL = cacheDir.appendingPathComponent("today_entries.json")
        try? data.write(to: fileURL)
    }

    @discardableResult
    private func applyCachedTodayEntries() -> Bool {
        guard let cached = loadCachedTodayEntries(), !cached.races.isEmpty else { return false }
        todayRaces = cached.races
        todayDateString = formatDateString(cached.date)
        todayDataWarning = nil
        return true
    }

    @discardableResult
    private func applyCachedTodayResults() -> Bool {
        guard let cached = loadCachedTodayResults(), !cached.results.isEmpty else { return false }
        todayResults = cached.results
        todayResultsDateString = formatDateString(cached.date)
        return true
    }

    private func loadCachedTodayResults() -> TodayResultsData? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = cacheDir.appendingPathComponent("today_results.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let result = try JSONDecoder().decode(TodayResultsData.self, from: data)
            guard result.date >= Self.expectedResultsDateString() else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return result
        } catch {
            return nil
        }
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
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        components.year = y
        components.month = m
        components.day = d

        guard let date = components.date else {
            return "\(y)年\(m)月\(d)日"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日（E）"
        return formatter.string(from: date)
    }

    private func formatRefreshTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f.string(from: Date())
    }

    private static func expectedResultsDateString() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let now = Date()
        let hour = calendar.dateComponents(in: timeZone, from: now).hour ?? 0
        let target = hour >= 21 ? now : calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = timeZone
        return f.string(from: target)
    }

    private static func remoteURL(_ fileName: String) -> URL? {
        var components = URLComponents(string: "\(remoteBaseURL)/\(fileName)")
        components?.queryItems = [
            URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))
        ]
        return components?.url
    }
}
