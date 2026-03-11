import SwiftUI
import Combine

// MARK: - Events ViewModel

class EventsViewModel: ObservableObject {
    @Published var upcomingEvents: [FRCEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private let service = TBAService.shared
    private let currentYear = Calendar.current.component(.year, from: Date())

    var filteredEvents: [FRCEvent] {
        if searchText.isEmpty { return upcomingEvents }
        let q = searchText.lowercased()
        return upcomingEvents.filter {
            $0.name.lowercased().contains(q) ||
            ($0.city?.lowercased().contains(q) ?? false) ||
            ($0.country?.lowercased().contains(q) ?? false)
        }
    }

    @MainActor
    func load() async {
        guard upcomingEvents.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let all = try await service.fetchEvents(year: currentYear)
            let today = Date()
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let upcoming = all.filter { event in
                guard let s = event.start_date, let sd = f.date(from: s) else { return false }
                if let e = event.end_date, let ed = f.date(from: e) { return ed >= today }
                return sd >= today
            }
            .sorted {
                let d1 = f.date(from: $0.start_date ?? "") ?? .distantFuture
                let d2 = f.date(from: $1.start_date ?? "") ?? .distantFuture
                return d1 < d2
            }
            upcomingEvents = upcoming
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    @MainActor
    func refresh() async { upcomingEvents = []; await load() }
}

// MARK: - Events View

struct EventsView: View {
    @StateObject private var vm = EventsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
                    if vm.isLoading { loadingView }
                    else if let error = vm.errorMessage { errorView(error) }
                    else if vm.filteredEvents.isEmpty { emptyView }
                    else { eventList }
                }
            }
            .navigationTitle("Etkinlikler")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(Calendar.current.component(.year, from: Date()))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#4fc3f7"))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: "#4fc3f7").opacity(0.15)))
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.refresh() }
        }
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Etkinlik adı veya şehir ara...", text: $vm.searchText)
                .foregroundColor(.white).autocorrectionDisabled()
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1)))
    }

    var eventList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                HStack {
                    Text("\(vm.filteredEvents.count) yaklaşan etkinlik")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.gray).tracking(0.5)
                    Spacer()
                }
                .padding(.horizontal, 4)
                ForEach(vm.filteredEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventCard(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
    }

    var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(Color(hex: "#4fc3f7")).scaleEffect(1.4)
            Text("Etkinlikler yükleniyor...").font(.system(size: 13)).foregroundColor(.gray)
            Spacer()
        }
    }

    var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 48)).foregroundColor(Color(hex: "#4fc3f7").opacity(0.4))
            Text("Yaklaşan etkinlik bulunamadı").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(vm.searchText.isEmpty ? "Bu yıl için etkinlik verisi yok." : "'\(vm.searchText)' ile eşleşen etkinlik yok.")
                .font(.system(size: 13)).foregroundColor(.gray)
            Spacer()
        }
        .padding(40)
    }

    func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash").font(.system(size: 44)).foregroundColor(.red.opacity(0.7))
            Text("Bağlantı Hatası").font(.headline).foregroundColor(.white)
            Text(msg).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button("Tekrar Dene") { Task { await vm.refresh() } }.buttonStyle(.borderedProminent).tint(Color(hex: "#4fc3f7"))
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: FRCEvent

    var eventColor: Color {
        switch event.event_type_string?.lowercased() ?? "" {
        case let s where s.contains("championship"): return Color(hex: "#f9a825")
        case let s where s.contains("regional"):     return Color(hex: "#1565c0")
        case let s where s.contains("district"):     return Color(hex: "#2e7d32")
        case let s where s.contains("offseason"):    return Color(hex: "#6a1b9a")
        default:                                      return Color(hex: "#4fc3f7")
        }
    }

    var countryFlag: String {
        switch event.country?.lowercased() ?? "" {
        case "turkey", "türkiye": return "🇹🇷"
        case "united states":     return "🇺🇸"
        case "canada":            return "🇨🇦"
        case "israel":            return "🇮🇱"
        case "mexico":            return "🇲🇽"
        default:                  return "🌐"
        }
    }

    var dateRange: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d MMM"; out.locale = Locale(identifier: "tr_TR")
        if let s = event.start_date, let e = event.end_date,
           let sd = f.date(from: s), let ed = f.date(from: e) {
            return "\(out.string(from: sd)) – \(out.string(from: ed))"
        }
        return event.start_date ?? ""
    }

    var daysUntil: Int? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let s = event.start_date, let sd = f.date(from: s) else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: sd).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3).fill(eventColor).frame(width: 4)
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(countryFlag)
                        Text(event.location.isEmpty ? "Konum bilinmiyor" : event.location)
                            .font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                }
                Spacer()
                if let days = daysUntil {
                    VStack(spacing: 2) {
                        if days == 0 {
                            Text("BUGÜN").font(.system(size: 9, weight: .black)).foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Color(hex: "#ef5350")))
                        } else {
                            Text("\(days)").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(eventColor)
                            Text("gün").font(.system(size: 9)).foregroundColor(.gray)
                        }
                    }
                    .frame(minWidth: 40)
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(.system(size: 10)).foregroundColor(eventColor)
                    Text(dateRange).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                if let type = event.event_type_string {
                    Text(type).font(.system(size: 10, weight: .semibold)).foregroundColor(eventColor)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(eventColor.opacity(0.15)))
                }
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(eventColor.opacity(0.2), lineWidth: 1)))
    }
}

// MARK: - Event Detail ViewModel

class EventDetailViewModel: ObservableObject {
    @Published var teams: [FRCTeam] = []
    @Published var matches: [FRCMatch] = []
    @Published var isLoadingTeams = false
    @Published var isLoadingMatches = false
    @Published var errorMessage: String?
    @Published var teamsError: String?
    @Published var searchText = ""
    @Published var selectedTab: EventDetailTab = .teams

    enum EventDetailTab { case teams, matches }

    private let service = TBAService.shared

    var filteredTeams: [FRCTeam] {
        if searchText.isEmpty { return teams }
        let q = searchText.lowercased()
        return teams.filter {
            $0.displayName.lowercased().contains(q) ||
            "\($0.team_number)".contains(q) ||
            ($0.city?.lowercased().contains(q) ?? false)
        }
    }

    var qualMatches: [FRCMatch] { matches.filter { $0.comp_level == "qm" }.sorted { $0.match_number < $1.match_number } }
    var elimMatches: [FRCMatch] { matches.filter { $0.comp_level != "qm" } }

    func fetchTeamsForEvent(eventKey: String) async throws -> [FRCTeam] {
        let apiKey = "btS0x1jQq89NoYboSW2TGf911f7fQ9aPQ2HYZZMyEj6XPKzGQEyh5pnFglp6a7vR"

        // Önce /teams/simple endpoint
        let url = URL(string: "https://www.thebluealliance.com/api/v3/event/\(eventKey)/teams/simple")!
        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "X-TBA-Auth-Key")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            // /teams endpoint'ini dene (simple olmadan)
            let url2 = URL(string: "https://www.thebluealliance.com/api/v3/event/\(eventKey)/teams")!
            var req2 = URLRequest(url: url2)
            req2.setValue(apiKey, forHTTPHeaderField: "X-TBA-Auth-Key")
            req2.timeoutInterval = 15
            let (data2, _) = try await URLSession.shared.data(for: req2)
            let fetched = try JSONDecoder().decode([FRCTeam].self, from: data2)
            return fetched.sorted { $0.team_number < $1.team_number }
        }

        // JSON decode — başarısız olursa ham yanıtı hata olarak at
        do {
            let fetched = try JSONDecoder().decode([FRCTeam].self, from: data)
            return fetched.sorted { $0.team_number < $1.team_number }
        } catch {
            // Boş array mı geldi?
            if let arr = try? JSONDecoder().decode([String].self, from: data), arr.isEmpty {
                return []
            }
            let raw = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw NSError(domain: "TBA", code: 0, userInfo: [NSLocalizedDescriptionKey: "Decode hatası. Yanıt: \(raw)"])
        }
    }

    @MainActor
    func load(eventKey: String) async {
        isLoadingTeams = true
        isLoadingMatches = true
        errorMessage = nil
        teamsError = nil

        // Takımları yükle — önce /teams/simple dene, olmassa /teams
        do {
            teams = try await fetchTeamsForEvent(eventKey: eventKey)
        } catch {
            teamsError = "\(error.localizedDescription)"
        }
        isLoadingTeams = false

        // Maçları yükle
        do {
            let url = URL(string: "https://www.thebluealliance.com/api/v3/event/\(eventKey)/matches/simple")!
            var req = URLRequest(url: url)
            req.setValue("btS0x1jQq89NoYboSW2TGf911f7fQ9aPQ2HYZZMyEj6XPKzGQEyh5pnFglp6a7vR", forHTTPHeaderField: "X-TBA-Auth-Key")
            req.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: req)
            matches = try JSONDecoder().decode([FRCMatch].self, from: data)
        } catch {
            // Maç yüklenemedi — sessizce geç
        }
        isLoadingMatches = false
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: FRCEvent
    @StateObject private var vm = EventDetailViewModel()

    var eventColor: Color {
        switch event.event_type_string?.lowercased() ?? "" {
        case let s where s.contains("championship"): return Color(hex: "#f9a825")
        case let s where s.contains("regional"):     return Color(hex: "#1565c0")
        case let s where s.contains("district"):     return Color(hex: "#2e7d32")
        default:                                      return Color(hex: "#4fc3f7")
        }
    }

    var dateRange: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d MMMM yyyy"; out.locale = Locale(identifier: "tr_TR")
        if let s = event.start_date, let e = event.end_date,
           let sd = f.date(from: s), let ed = f.date(from: e) {
            return "\(out.string(from: sd)) – \(out.string(from: ed))"
        }
        return event.start_date ?? ""
    }

    var body: some View {
        ZStack {
            Color(hex: "#0a0e1a").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    eventHeader
                    VStack(spacing: 16) {
                        tbaLink
                        tabSelector
                        switch vm.selectedTab {
                        case .teams: teamsSection
                        case .matches: matchesSection
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Etkinlik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.load(eventKey: event.key) }
    }

    var eventHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [eventColor.opacity(0.35), eventColor.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).frame(minHeight: 160)
            VStack(alignment: .leading, spacing: 8) {
                if let type = event.event_type_string {
                    Text(type.uppercased()).font(.system(size: 10, weight: .black)).foregroundColor(eventColor).tracking(1.5)
                }
                Text(event.name).font(.system(size: 22, weight: .black)).foregroundColor(.white)
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill").foregroundColor(eventColor).font(.system(size: 12))
                    Text(event.location.isEmpty ? "Konum bilinmiyor" : event.location)
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                }
                HStack(spacing: 5) {
                    Image(systemName: "calendar").foregroundColor(eventColor).font(.system(size: 12))
                    Text(dateRange).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
    }

    var tabSelector: some View {
        HStack(spacing: 0) {
            tabBtn("Takımlar (\(vm.teams.count))", tab: .teams, icon: "person.3.fill")
            tabBtn("Maçlar (\(vm.matches.count))", tab: .matches, icon: "sportscourt.fill")
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    func tabBtn(_ label: String, tab: EventDetailViewModel.EventDetailTab, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { vm.selectedTab = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(vm.selectedTab == tab ? eventColor : .gray)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(vm.selectedTab == tab ? eventColor.opacity(0.15) : Color.clear))
        }
    }

    var tbaLink: some View {
        Link(destination: URL(string: "https://www.thebluealliance.com/event/\(event.key)")!) {
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill").foregroundColor(Color(hex: "#4fc3f7"))
                Text("The Blue Alliance'da Görüntüle").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#4fc3f7"))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#4fc3f7").opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4fc3f7").opacity(0.25), lineWidth: 1)))
        }
    }

    // MARK: - Teams Section

    var teamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            teamsSectionHeader
            if vm.isLoadingTeams {
                HStack { Spacer(); ProgressView().tint(eventColor).scaleEffect(1.2); Spacer() }.padding(30)
            } else if vm.teams.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3").font(.system(size: 32)).foregroundColor(.gray.opacity(0.4))
                    if let err = vm.teamsError {
                        Text(err).font(.system(size: 12)).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal, 8)
                    } else {
                        Text("Bu etkinlik için takım verisi bulunamadı").font(.system(size: 13)).foregroundColor(.gray)
                    }
                    Button {
                        Task { await vm.load(eventKey: event.key) }
                    } label: {
                        Text("Tekrar Dene").font(.system(size: 13, weight: .semibold)).foregroundColor(eventColor)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(eventColor.opacity(0.12)))
                    }
                }
                .frame(maxWidth: .infinity).padding(20)
            } else {
                teamsSearchBar
                teamsListRows
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1)))
    }

    var teamsSectionHeader: some View {
        HStack {
            Image(systemName: "person.3.fill").foregroundColor(eventColor)
            Text(vm.isLoadingTeams ? "Takımlar yükleniyor..." : "\(vm.filteredTeams.count) Katılımcı Takım")
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            Spacer()
            if vm.isLoadingTeams { ProgressView().tint(eventColor).scaleEffect(0.8) }
        }
    }

    var teamsSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 13))
            TextField("Takım ara...", text: $vm.searchText)
                .foregroundColor(.white).font(.system(size: 13)).autocorrectionDisabled()
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1)))
    }

    var teamsListRows: some View {
        LazyVStack(spacing: 8) {
            ForEach(vm.filteredTeams) { team in
                NavigationLink(destination: TeamDetailView(teamNumber: team.team_number, preloadedTeam: team)) {
                    EventTeamRow(team: team, accentColor: eventColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Matches Section

    var matchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if vm.isLoadingMatches {
                HStack(spacing: 10) {
                    ProgressView().tint(eventColor).scaleEffect(0.9)
                    Text("Maçlar yükleniyor...").font(.system(size: 13)).foregroundColor(.gray)
                }
                .padding(.vertical, 20)
            } else if vm.matches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sportscourt").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("Maç verisi henüz yok").font(.system(size: 14)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                if !vm.qualMatches.isEmpty {
                    matchGroup(title: "Eleme Maçları", matches: vm.qualMatches)
                }
                if !vm.elimMatches.isEmpty {
                    matchGroup(title: "Playoff Maçları", matches: vm.elimMatches)
                }
            }
        }
    }

    func matchGroup(title: String, matches: [FRCMatch]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                .tracking(1).textCase(.uppercase)
            ForEach(matches) { match in
                MatchResultCard(match: match, accentColor: eventColor)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1)))
    }
}

// MARK: - Match Result Card

struct MatchResultCard: View {
    let match: FRCMatch
    let accentColor: Color

    var redScore: Int { match.alliances?.red?.score ?? 0 }
    var blueScore: Int { match.alliances?.blue?.score ?? 0 }
    var redWon: Bool { match.winning_alliance == "red" }
    var blueWon: Bool { match.winning_alliance == "blue" }

    var redTeams: [String] { match.alliances?.red?.team_keys.map { $0.replacingOccurrences(of: "frc", with: "#") } ?? [] }
    var blueTeams: [String] { match.alliances?.blue?.team_keys.map { $0.replacingOccurrences(of: "frc", with: "#") } ?? [] }

    var body: some View {
        HStack(spacing: 0) {
            // Kırmızı Alliance
            allianceBlock(teams: redTeams, score: redScore, color: Color(hex: "#c62828"), won: redWon, alignment: .leading)

            // Maç numarası ortada
            VStack(spacing: 2) {
                Text(match.compLevelDisplay).font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.5)
                Text("\(match.match_number)").font(.system(size: 13, weight: .black)).foregroundColor(.white)
            }
            .frame(width: 44)

            // Mavi Alliance
            allianceBlock(teams: blueTeams, score: blueScore, color: Color(hex: "#1565c0"), won: blueWon, alignment: .trailing)
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1)))
    }

    func allianceBlock(teams: [String], score: Int, color: Color, won: Bool, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 4) {
                if won {
                    Image(systemName: "crown.fill").font(.system(size: 9)).foregroundColor(Color(hex: "#f9a825"))
                }
                Text(score > 0 ? "\(score)" : "—")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(won ? color : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)

            HStack(spacing: 3) {
                ForEach(teams, id: \.self) { team in
                    Text(team).font(.system(size: 9, weight: .semibold))
                        .foregroundColor(color.opacity(0.9))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)))
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Event Team Row

struct EventTeamRow: View {
    let team: FRCTeam
    let accentColor: Color

    var countryFlag: String {
        switch team.country?.lowercased() ?? "" {
        case "turkey", "türkiye": return "🇹🇷"
        case "united states":     return "🇺🇸"
        case "canada":            return "🇨🇦"
        case "israel":            return "🇮🇱"
        default:                  return "🌐"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(accentColor.opacity(0.3), lineWidth: 1))
                    .frame(width: 50, height: 44)
                VStack(spacing: 0) {
                    Text(countryFlag).font(.system(size: 12))
                    Text("\(team.team_number)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(accentColor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(team.displayName).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                if !team.location.isEmpty {
                    Text(team.location).font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1)))
    }
}

