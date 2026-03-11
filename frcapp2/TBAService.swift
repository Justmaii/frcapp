import Foundation
import Combine

// MARK: - Models

struct FRCTeam: Identifiable, Codable {
    let key: String
    let team_number: Int
    let nickname: String?
    let name: String?
    let city: String?
    let state_prov: String?
    let country: String?
    let rookie_year: Int?
    let website: String?

    var id: String { key }

    var displayName: String {
        nickname ?? "Team \(team_number)"
    }

    var location: String {
        [city, state_prov, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var rookieYearText: String {
        if let year = rookie_year {
            return "Kuruluş: \(year)"
        }
        return ""
    }
}

struct FRCEvent: Identifiable, Codable {
    let key: String
    let name: String
    let event_type_string: String?
    let city: String?
    let country: String?
    let start_date: String?
    let end_date: String?
    let year: Int

    var id: String { key }

    var location: String {
        [city, country].compactMap { $0 }.joined(separator: ", ")
    }
}

struct FRCAward: Identifiable, Codable {
    let name: String
    let event_key: String
    let year: Int

    var id: String { "\(event_key)-\(name)" }
}

struct FRCMatch: Identifiable, Codable {
    let key: String
    let comp_level: String
    let match_number: Int
    let set_number: Int
    let alliances: MatchAlliances?
    let winning_alliance: String?
    let event_key: String
    let time: Int?

    var id: String { key }

    var compLevelDisplay: String {
        switch comp_level {
        case "qm": return "Eleme"
        case "ef": return "Çeyrek Final"
        case "qf": return "Çeyrek Final"
        case "sf": return "Yarı Final"
        case "f": return "Final"
        default: return comp_level.uppercased()
        }
    }
}

struct MatchAlliances: Codable {
    let red: AllianceTeams?
    let blue: AllianceTeams?
}

struct AllianceTeams: Codable {
    let team_keys: [String]
    let score: Int?
}

// MARK: - TBA API Service

class TBAService: ObservableObject {
    static let shared = TBAService()

    // NOTE: Replace with your TBA Read API key from thebluealliance.com/account
    private let apiKey = "btS0x1jQq89NoYboSW2TGf911f7fQ9aPQ2HYZZMyEj6XPKzGQEyh5pnFglp6a7vR"
    private let baseURL = "https://www.thebluealliance.com/api/v3"

    private var headers: [String: String] {
        ["X-TBA-Auth-Key": apiKey]
    }

    // MARK: - Teams

    func fetchTeams(page: Int) async throws -> [FRCTeam] {
        let url = URL(string: "\(baseURL)/teams/\(page)/simple")!
        return try await fetch(url: url)
    }

    func fetchTeam(number: Int) async throws -> FRCTeam {
        let url = URL(string: "\(baseURL)/team/frc\(number)/simple")!
        return try await fetch(url: url)
    }

    func fetchTeamFull(number: Int) async throws -> FRCTeam {
        let url = URL(string: "\(baseURL)/team/frc\(number)")!
        return try await fetch(url: url)
    }

    func fetchTeamAwards(number: Int) async throws -> [FRCAward] {
        let url = URL(string: "\(baseURL)/team/frc\(number)/awards")!
        return try await fetch(url: url)
    }

    func fetchTeamEvents(number: Int, year: Int) async throws -> [FRCEvent] {
        let url = URL(string: "\(baseURL)/team/frc\(number)/events/\(year)/simple")!
        return try await fetch(url: url)
    }

    func fetchTeamMatches(number: Int, year: Int) async throws -> [FRCMatch] {
        let url = URL(string: "\(baseURL)/team/frc\(number)/matches/\(year)/simple")!
        return try await fetch(url: url)
    }

    // MARK: - All Teams (multi-page)

    /// Fetches ALL teams across all pages. Use with care — this is ~200+ pages.
    func fetchAllTeams(progressHandler: ((Int) -> Void)? = nil) async throws -> [FRCTeam] {
        var allTeams: [FRCTeam] = []
        var page = 0

        while true {
            let teams = try await fetchTeams(page: page)
            if teams.isEmpty { break }
            allTeams.append(contentsOf: teams)
            progressHandler?(allTeams.count)
            page += 1

            // Small delay to be respectful to the API
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        return allTeams
    }

    /// Fetches teams by country (filters locally from first N pages for speed)
    func fetchTeamsByCountry(_ country: String, maxPages: Int = 20) async throws -> [FRCTeam] {
        var result: [FRCTeam] = []
        for page in 0..<maxPages {
            let teams = try await fetchTeams(page: page)
            if teams.isEmpty { break }
            let filtered = teams.filter {
                $0.country?.lowercased() == country.lowercased() ||
                $0.country?.lowercased().contains(country.lowercased()) == true
            }
            result.append(contentsOf: filtered)
        }
        return result
    }

    func searchTeams(query: String, page: Int = 0) async throws -> [FRCTeam] {
        let teams: [FRCTeam] = try await fetchTeams(page: page)
        if query.isEmpty { return teams }
        let q = query.lowercased()
        return teams.filter {
            $0.displayName.lowercased().contains(q) ||
            "\($0.team_number)".contains(q) ||
            ($0.city?.lowercased().contains(q) ?? false) ||
            ($0.country?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Events

    func fetchEvents(year: Int) async throws -> [FRCEvent] {
        let url = URL(string: "\(baseURL)/events/\(year)/simple")!
        return try await fetch(url: url)
    }

    func fetchEventTeams(eventKey: String) async throws -> [FRCTeam] {
        let url = URL(string: "\(baseURL)/event/\(eventKey)/oprs")!
        return try await fetch(url: url)
    }

    func fetchEventOPRs(eventKey: String) async throws -> EventOPR {
        let url = URL(string: "\(baseURL)/event/\(eventKey)/oprs")!
        return try await fetch(url: url)
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-TBA-Auth-Key")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TBAError.invalidResponse
        }

        if http.statusCode == 401 {
            throw TBAError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            throw TBAError.serverError(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum TBAError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Geçersiz sunucu yanıtı"
        case .unauthorized: return "API anahtarı geçersiz. Lütfen thebluealliance.com'dan bir anahtar alın."
        case .serverError(let code): return "Sunucu hatası: \(code)"
        }
    }
}

// MARK: - OPR Models

struct EventOPR: Codable {
    let oprs: [String: Double]?
    let dprs: [String: Double]?
    let ccwms: [String: Double]?
}

struct TeamOPRStats: Identifiable {
    let id = UUID()
    let teamKey: String
    let teamNumber: Int
    let opr: Double
    let dpr: Double
    let ccwm: Double

    var displayNumber: String { "frc\(teamNumber)" }
}

