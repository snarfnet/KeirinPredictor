import Foundation

class DataLoader: ObservableObject {
    @Published var playerStats: [String: PlayerStats] = [:]
    @Published var venueStats: [String: VenueStats] = [:]
    @Published var lineMatrix: [String: LineEntry] = [:]
    @Published var isLoaded = false

    static let shared = DataLoader()

    private init() {}

    func load() {
        guard !isLoaded else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let ps = self.loadJSON(name: "player_stats", type: [String: PlayerStats].self) ?? [:]
            let vs = self.loadJSON(name: "venue_stats", type: [String: VenueStats].self) ?? [:]
            let lm = self.loadJSON(name: "line_matrix", type: [String: LineEntry].self) ?? [:]
            DispatchQueue.main.async {
                self.playerStats = ps
                self.venueStats = vs
                self.lineMatrix = lm
                self.isLoaded = true
            }
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
}
