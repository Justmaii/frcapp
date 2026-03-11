
import SwiftUI
import Combine

// MARK: - ScoutingReport Model

struct ScoutingReport: Identifiable, Codable {
    var id = UUID()
    let teamNumber: Int
    let teamName: String
    let eventName: String
    let matchNumber: Int
    let autoScore: Int
    let teleopScore: Int
    let endgameScore: Int
    let autonomousNotes: String
    let teleopNotes: String
    let generalNotes: String
    let drivingRating: Int
    let defenseRating: Int
    let consistencyRating: Int
    let canClimb: Bool
    let canShoot: Bool
    let canDefend: Bool
    let scoutedBy: String
    let timestamp: Date

    var totalScore: Int { autoScore + teleopScore + endgameScore }
    var averageRating: Double { Double(drivingRating + defenseRating + consistencyRating) / 3.0 }
}

// MARK: - Scouting Storage

class ScoutingStore: ObservableObject {
    static let shared = ScoutingStore()

    @Published var reports: [ScoutingReport] = []

    private let saveKey = "scouting_reports"

    init() {
        load()
    }

    func save(_ report: ScoutingReport) {
        reports.append(report)
        persist()
    }

    func delete(at offsets: IndexSet) {
        reports.remove(atOffsets: offsets)
        persist()
    }

    func deleteReport(_ report: ScoutingReport) {
        reports.removeAll { $0.id == report.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode([ScoutingReport].self, from: data) {
            reports = saved
        }
    }

    func reports(for teamNumber: Int) -> [ScoutingReport] {
        reports.filter { $0.teamNumber == teamNumber }
    }

    func averageScore(for teamNumber: Int) -> Double {
        let r = reports(for: teamNumber)
        guard !r.isEmpty else { return 0 }
        return Double(r.map(\.totalScore).reduce(0, +)) / Double(r.count)
    }
}

// MARK: - Main Scouting View

struct ScoutingView: View {
    @StateObject private var store = ScoutingStore.shared
    @State private var showNewReport = false
    @State private var searchText = ""
    @State private var selectedTab: ScoutTab = .reports

    enum ScoutTab { case reports, stats, search }

    var filteredReports: [ScoutingReport] {
        if searchText.isEmpty { return store.reports.sorted { $0.timestamp > $1.timestamp } }
        let q = searchText.lowercased()
        return store.reports.filter {
            "\($0.teamNumber)".contains(q) ||
            $0.teamName.lowercased().contains(q) ||
            $0.eventName.lowercased().contains(q)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Selector
                    tabSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    switch selectedTab {
                    case .reports:
                        reportsTab
                    case .stats:
                        statsTab
                    case .search:
                        teamSearchTab
                    }
                }
            }
            .navigationTitle("Scouting")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if selectedTab == .reports {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showNewReport = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hex: "#4fc3f7"))
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewReport) {
                NewScoutingReportView(store: store)
            }
        }
    }

    // MARK: - Tab Selector

    var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Raporlar", icon: "doc.text.fill", tab: .reports)
            tabButton("İstatistik", icon: "chart.bar.fill", tab: .stats)
            tabButton("Takım Ara", icon: "magnifyingglass", tab: .search)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
    }

    func tabButton(_ label: String, icon: String, tab: ScoutTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(selectedTab == tab ? Color(hex: "#4fc3f7") : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTab == tab ? Color(hex: "#4fc3f7").opacity(0.15) : Color.clear)
            )
        }
    }

    // MARK: - Reports Tab

    var reportsTab: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Takım, etkinlik ara...", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if filteredReports.isEmpty {
                emptyReportsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredReports) { report in
                            NavigationLink(destination: ScoutingReportDetailView(report: report, store: store)) {
                                ScoutingReportCard(report: report)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    var emptyReportsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(Color(hex: "#4fc3f7").opacity(0.4))
            Text("Henüz scouting raporu yok")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Text("Sağ üstteki + butonuna basarak\nilk raporunuzu oluşturun")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button {
                showNewReport = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Yeni Rapor Oluştur")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(colors: [Color(hex: "#1565c0"), Color(hex: "#4fc3f7")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                )
            }
            Spacer()
        }
        .padding(40)
    }

    // MARK: - Stats Tab

    var statsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if store.reports.isEmpty {
                    VStack(spacing: 16) {
                        Spacer(minLength: 60)
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#4fc3f7").opacity(0.4))
                        Text("İstatistik için rapor ekleyin")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    // Summary Cards
                    summaryStatsRow

                    // Top Teams
                    topTeamsSection

                    // Recent Activity
                    recentActivitySection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    var summaryStatsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(store.reports.count)", label: "Rapor", icon: "doc.text.fill", color: Color(hex: "#4fc3f7"))
            statCard(value: "\(Set(store.reports.map(\.teamNumber)).count)", label: "Takım", icon: "person.3.fill", color: Color(hex: "#f9a825"))
            statCard(value: "\(Set(store.reports.map(\.eventName)).count)", label: "Etkinlik", icon: "flag.fill", color: Color(hex: "#ef5350"))
        }
    }

    func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
        )
    }

    var topTeamNumbers: [Int] {
        let nums = Set(store.reports.map(\.teamNumber))
        return nums.sorted { store.averageScore(for: $0) > store.averageScore(for: $1) }
    }

    var topTeamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("En Yüksek Puanlı Takımlar")
            ForEach(Array(topTeamNumbers.prefix(5).enumerated()), id: \.offset) { index, teamNum in
                TopTeamRow(index: index, teamNum: teamNum, store: store)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Son Aktivite")

            ForEach(store.reports.sorted { $0.timestamp > $1.timestamp }.prefix(3)) { report in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: "#4fc3f7").opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("\(report.teamNumber)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color(hex: "#4fc3f7"))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.teamName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(report.eventName)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(report.totalScore)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(Color(hex: "#4fc3f7"))
                        Text(timeAgo(report.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    // MARK: - Team Search Tab

    var teamSearchTab: some View {
        TeamSearchScoutView()
    }

    // MARK: - Helpers

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.gray)
            .textCase(.uppercase)
            .tracking(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Az önce" }
        if seconds < 3600 { return "\(seconds / 60)dk önce" }
        if seconds < 86400 { return "\(seconds / 3600)sa önce" }
        return "\(seconds / 86400)g önce"
    }
}

// MARK: - Team Search with TBA (for Scouting)

class TeamSearchScoutViewModel: ObservableObject {
    @Published var teams: [FRCTeam] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            if searchText.count >= 2 {
                debounceSearch()
            } else if searchText.isEmpty {
                teams = []
            }
        }
    }
    @Published var currentPage = 0
    @Published var allLoaded: [FRCTeam] = []
    @Published var hasMore = true
    @Published var isLoadingAll = false
    @Published var loadedCount = 0

    private let service = TBAService.shared
    private var searchTask: Task<Void, Never>?

    var filteredTeams: [FRCTeam] {
        guard !searchText.isEmpty else { return allLoaded }
        let q = searchText.lowercased()
        return allLoaded.filter {
            $0.displayName.lowercased().contains(q) ||
            "\($0.team_number)".contains(q) ||
            ($0.city?.lowercased().contains(q) ?? false) ||
            ($0.country?.lowercased().contains(q) ?? false)
        }
    }

    func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            // Search within already loaded teams or fetch specific page
            await searchByNumber()
        }
    }

    @MainActor
    func searchByNumber() async {
        // If query looks like a number, try direct lookup
        if let num = Int(searchText.trimmingCharacters(in: .whitespaces)) {
            isLoading = true
            do {
                let team = try await service.fetchTeamFull(number: num)
                teams = [team]
                if !allLoaded.contains(where: { $0.team_number == num }) {
                    allLoaded.append(team)
                }
            } catch {
                teams = filteredTeams
            }
            isLoading = false
        }
    }

    @MainActor
    func loadNextPage() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        do {
            let newTeams = try await service.fetchTeams(page: currentPage)
            if newTeams.isEmpty {
                hasMore = false
            } else {
                allLoaded.append(contentsOf: newTeams)
                currentPage += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func loadAllTeams() async {
        guard !isLoadingAll else { return }
        isLoadingAll = true
        loadedCount = allLoaded.count
        do {
            var page = currentPage
            while true {
                let teams = try await service.fetchTeams(page: page)
                if teams.isEmpty { break }
                allLoaded.append(contentsOf: teams)
                loadedCount = allLoaded.count
                page += 1
                currentPage = page
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            hasMore = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingAll = false
    }
}

struct TeamSearchScoutView: View {
    @StateObject private var vm = TeamSearchScoutViewModel()
    @State private var showNewReportForTeam: FRCTeam? = nil

    var displayTeams: [FRCTeam] {
        vm.searchText.isEmpty ? vm.allLoaded : vm.filteredTeams
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Takım adı, numarası veya ülke ara...", text: $vm.searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .keyboardType(.default)
                if !vm.searchText.isEmpty {
                    Button { vm.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Status bar
            if vm.isLoadingAll {
                HStack(spacing: 8) {
                    ProgressView().tint(Color(hex: "#4fc3f7")).scaleEffect(0.8)
                    Text("\(vm.loadedCount) takım yüklendi...")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#4fc3f7"))
                }
                .padding(.vertical, 6)
            } else if !vm.allLoaded.isEmpty {
                HStack {
                    Text("\(vm.allLoaded.count) takım yüklendi")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    if vm.hasMore {
                        Button {
                            Task { await vm.loadAllTeams() }
                        } label: {
                            Text("Tüm Takımları Yükle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#f9a825"))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 13))
                    .padding()
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(displayTeams) { team in
                        ScoutTeamRow(team: team) {
                            showNewReportForTeam = team
                        }
                    }

                    if vm.isLoading && !vm.isLoadingAll {
                        ProgressView().tint(Color(hex: "#4fc3f7")).padding()
                    } else if vm.hasMore && !vm.isLoadingAll && vm.searchText.isEmpty {
                        Button {
                            Task { await vm.loadNextPage() }
                        } label: {
                            Text("Daha Fazla Yükle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#4fc3f7"))
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "#4fc3f7").opacity(0.1))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4fc3f7").opacity(0.3), lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 16)
                    }

                    if displayTeams.isEmpty && !vm.isLoading && !vm.searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.gray)
                            Text("Sonuç bulunamadı").foregroundColor(.white).font(.headline)
                        }
                        .padding(40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .task {
            if vm.allLoaded.isEmpty {
                await vm.loadNextPage()
            }
        }
        .sheet(item: $showNewReportForTeam) { team in
            NewScoutingReportView(store: ScoutingStore.shared, prefilledTeam: team)
        }
    }
}

struct ScoutTeamRow: View {
    let team: FRCTeam
    let onScout: () -> Void

    var teamColor: Color {
        let colors: [Color] = [Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
                               Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c")]
        return colors[team.team_number % colors.count]
    }

    var countryFlag: String {
        guard let country = team.country else { return "🌐" }
        switch country.lowercased() {
        case "turkey", "türkiye": return "🇹🇷"
        case "united states", "usa": return "🇺🇸"
        case "canada": return "🇨🇦"
        case "israel": return "🇮🇱"
        case "mexico": return "🇲🇽"
        case "china": return "🇨🇳"
        case "brazil": return "🇧🇷"
        case "australia": return "🇦🇺"
        case "india": return "🇮🇳"
        default: return "🌐"
        }
    }

    var reportsCount: Int {
        ScoutingStore.shared.reports(for: team.team_number).count
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(teamColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(teamColor.opacity(0.4), lineWidth: 1))
                    .frame(width: 54, height: 54)
                VStack(spacing: 1) {
                    Text(countryFlag).font(.system(size: 14))
                    Text("\(team.team_number)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(teamColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(team.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !team.location.isEmpty {
                    Text(team.location)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if reportsCount > 0 {
                    Text("\(reportsCount) rapor")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "#4fc3f7"))
                }
            }

            Spacer()

            Button(action: onScout) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Scout")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(colors: [Color(hex: "#1565c0"), Color(hex: "#4fc3f7")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }
}

// MARK: - Top Team Row Helper

struct TopTeamRow: View {
    let index: Int
    let teamNum: Int
    let store: ScoutingStore

    var body: some View {
        let reports = store.reports(for: teamNum)
        let teamName = reports.first?.teamName ?? "Team \(teamNum)"
        let avg = store.averageScore(for: teamNum)

        HStack(spacing: 12) {
            Text("#\(index + 1)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(index == 0 ? Color(hex: "#f9a825") : .gray)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(teamName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("Takım #\(teamNum) • \(reports.count) rapor")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(String(format: "%.0f", avg))
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#4fc3f7"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }
}

// MARK: - Scouting Report Card

struct ScoutingReportCard: View {
    let report: ScoutingReport

    var ratingColor: Color {
        let avg = report.averageRating
        if avg >= 4 { return Color(hex: "#4caf50") }
        if avg >= 3 { return Color(hex: "#f9a825") }
        return Color(hex: "#ef5350")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(report.teamName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Takım #\(report.teamNumber) • \(report.eventName)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(report.totalScore)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#4fc3f7"))
                    Text("puan")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 12) {
                scoreChip("Auto", score: report.autoScore, color: Color(hex: "#1565c0"))
                scoreChip("Teleop", score: report.teleopScore, color: Color(hex: "#2e7d32"))
                scoreChip("Endgame", score: report.endgameScore, color: Color(hex: "#6a1b9a"))
                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < Int(report.averageRating.rounded()) ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#f9a825"))
                    }
                }
            }

            HStack(spacing: 8) {
                if report.canClimb { capBadge("🧗 Tırmanma") }
                if report.canShoot { capBadge("🎯 Atış") }
                if report.canDefend { capBadge("🛡 Savunma") }
            }

            HStack {
                Text("Maç #\(report.matchNumber)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Spacer()
                Text(formatDate(report.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    func scoreChip(_ label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.1)))
    }

    func capBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: "#4fc3f7"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(hex: "#4fc3f7").opacity(0.1)))
    }

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: date)
    }
}

// MARK: - Report Detail View

struct ScoutingReportDetailView: View {
    let report: ScoutingReport
    let store: ScoutingStore
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color(hex: "#0a0e1a").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(report.teamName)
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                        Text("Takım #\(report.teamNumber) • Maç #\(report.matchNumber)")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#4fc3f7"))
                        Text(report.eventName)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 10)

                    // Score breakdown
                    scoreBreakdownCard

                    // Ratings
                    ratingsCard

                    // Capabilities
                    capabilitiesCard

                    // Notes
                    if !report.autonomousNotes.isEmpty || !report.teleopNotes.isEmpty || !report.generalNotes.isEmpty {
                        notesCard
                    }

                    // Meta
                    metaCard

                    // Delete
                    Button {
                        store.deleteReport(report)
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Raporu Sil")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.red.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Rapor Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    var scoreBreakdownCard: some View {
        VStack(spacing: 16) {
            Text("PUAN DAĞILIMI")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                bigScoreBlock("Otonom", score: report.autoScore, color: Color(hex: "#1565c0"))
                Divider().background(Color.white.opacity(0.1))
                bigScoreBlock("Teleop", score: report.teleopScore, color: Color(hex: "#2e7d32"))
                Divider().background(Color.white.opacity(0.1))
                bigScoreBlock("Endgame", score: report.endgameScore, color: Color(hex: "#6a1b9a"))
                Divider().background(Color.white.opacity(0.1))
                bigScoreBlock("TOPLAM", score: report.totalScore, color: Color(hex: "#4fc3f7"))
            }
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    func bigScoreBlock(_ label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    var ratingsCard: some View {
        VStack(spacing: 14) {
            Text("DEĞERLENDİRME")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            ratingRow("Sürüş", rating: report.drivingRating)
            ratingRow("Savunma", rating: report.defenseRating)
            ratingRow("Tutarlılık", rating: report.consistencyRating)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    func ratingRow(_ label: String, rating: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 80, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundColor(i <= rating ? Color(hex: "#f9a825") : Color.white.opacity(0.2))
                }
            }
            Spacer()
            Text("\(rating)/5")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "#f9a825"))
        }
    }

    var capabilitiesCard: some View {
        VStack(spacing: 14) {
            Text("KABİLİYETLER")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                capabilityItem("🧗", "Tırmanma", enabled: report.canClimb)
                capabilityItem("🎯", "Atış", enabled: report.canShoot)
                capabilityItem("🛡", "Savunma", enabled: report.canDefend)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    func capabilityItem(_ emoji: String, _ label: String, enabled: Bool) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.system(size: 24))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(enabled ? .white : .gray)
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? Color(hex: "#4caf50") : Color.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(enabled ? Color(hex: "#4caf50").opacity(0.08) : Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                    enabled ? Color(hex: "#4caf50").opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    var notesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NOTLAR")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)

            if !report.autonomousNotes.isEmpty {
                noteSection("Otonom", text: report.autonomousNotes, color: Color(hex: "#1565c0"))
            }
            if !report.teleopNotes.isEmpty {
                noteSection("Teleop", text: report.teleopNotes, color: Color(hex: "#2e7d32"))
            }
            if !report.generalNotes.isEmpty {
                noteSection("Genel", text: report.generalNotes, color: Color(hex: "#4fc3f7"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    func noteSection(_ label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
    }

    var metaCard: some View {
        VStack(spacing: 10) {
            metaRow("Scout", value: report.scoutedBy)
            metaRow("Tarih", value: {
                let f = DateFormatter()
                f.dateStyle = .long
                f.timeStyle = .short
                f.locale = Locale(identifier: "tr_TR")
                return f.string(from: report.timestamp)
            }())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - New Scouting Report Form

struct NewScoutingReportView: View {
    @ObservedObject var store: ScoutingStore
    var prefilledTeam: FRCTeam? = nil
    @Environment(\.presentationMode) var presentationMode

    // Form state
    @State private var teamNumberText = ""
    @State private var teamName = ""
    @State private var eventName = ""
    @State private var matchNumberText = "1"
    @State private var autoScore = 0
    @State private var teleopScore = 0
    @State private var endgameScore = 0
    @State private var drivingRating = 3
    @State private var defenseRating = 3
    @State private var consistencyRating = 3
    @State private var canClimb = false
    @State private var canShoot = false
    @State private var canDefend = false
    @State private var autonomousNotes = ""
    @State private var teleopNotes = ""
    @State private var generalNotes = ""
    @State private var scoutedBy = ""
    @State private var isLookingUp = false
    @State private var lookupError = ""
    @State private var currentStep = 0
    @State private var teamEvents: [FRCEvent] = []
    @State private var showEventPicker = false
    @State private var lookupTask: Task<Void, Never>? = nil

    let steps = ["Takım", "Puanlar", "Değerlendirme", "Notlar"]

    var isValid: Bool {
        !teamNumberText.isEmpty && !teamName.isEmpty && !eventName.isEmpty && !scoutedBy.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator
                    stepIndicator
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    // Form content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch currentStep {
                            case 0: teamStep
                            case 1: scoresStep
                            case 2: ratingsStep
                            case 3: notesStep
                            default: EmptyView()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }

                    // Navigation buttons
                    navButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        .padding(.top, 12)
                        .background(Color(hex: "#0a0e1a"))
                }
            }
            .navigationTitle("Yeni Scouting Raporu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#ef5350"))
                }
            }
            .onAppear {
                if let team = prefilledTeam {
                    teamNumberText = "\(team.team_number)"
                    teamName = team.displayName
                }
            }
        }
    }

    // MARK: - Step Indicator

    var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(i <= currentStep ? Color(hex: "#4fc3f7") : Color.white.opacity(0.1))
                                .frame(width: 28, height: 28)
                            if i < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(i == currentStep ? .white : .gray)
                            }
                        }
                        Text(steps[i])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(i == currentStep ? Color(hex: "#4fc3f7") : .gray)
                    }

                    if i < steps.count - 1 {
                        Rectangle()
                            .fill(i < currentStep ? Color(hex: "#4fc3f7") : Color.white.opacity(0.1))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
    }

    // MARK: - Step 0: Team

    var teamStep: some View {
        VStack(spacing: 16) {
            formCard {
                VStack(spacing: 14) {
                    formLabel("Takım Numarası")
                    HStack(spacing: 10) {
                        formTextField("Örn: 6038", text: $teamNumberText)
                            .keyboardType(.numberPad)
                            .onChange(of: teamNumberText) { val in
                                autoLookup(val)
                            }
                        if isLookingUp {
                            ProgressView().tint(Color(hex: "#4fc3f7")).frame(width: 32, height: 32)
                        } else if !teamName.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "#4caf50")).font(.system(size: 22))
                        }
                    }
                    if !teamName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill").foregroundColor(Color(hex: "#4fc3f7")).font(.system(size: 12))
                            Text(teamName).font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#4fc3f7"))
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#4fc3f7").opacity(0.08)))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if !lookupError.isEmpty {
                        Text(lookupError).font(.system(size: 12)).foregroundColor(.red)
                    }
                }
            }

            formCard {
                VStack(spacing: 14) {
                    // Etkinlik seçimi
                    VStack(alignment: .leading, spacing: 8) {
                        formLabel("Etkinlik")
                        if !teamEvents.isEmpty {
                            Button { showEventPicker = true } label: {
                                HStack {
                                    Image(systemName: "flag.fill").foregroundColor(Color(hex: "#f9a825")).font(.system(size: 12))
                                    Text(eventName.isEmpty ? "Etkinlik seç..." : eventName)
                                        .font(.system(size: 13)).foregroundColor(eventName.isEmpty ? .gray : .white)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down").foregroundColor(.gray).font(.system(size: 11))
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#f9a825").opacity(0.3), lineWidth: 1)))
                            }
                            .sheet(isPresented: $showEventPicker) {
                                eventPickerSheet
                            }
                        } else {
                            formTextField("Örn: İstanbul Bölgesi 2025", text: $eventName)
                        }
                    }
                    Divider().background(Color.white.opacity(0.08))
                    formLabelAndField("Maç Numarası", placeholder: "1", text: $matchNumberText)
                        .keyboardType(.numberPad)
                    Divider().background(Color.white.opacity(0.08))
                    formLabelAndField("Scout Adı", placeholder: "Adınız", text: $scoutedBy)
                }
            }
        }
    }

    var eventPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                List(teamEvents) { event in
                    Button {
                        eventName = event.name
                        showEventPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                Text(event.location).font(.system(size: 11)).foregroundColor(.gray)
                            }
                            Spacer()
                            if eventName == event.name {
                                Image(systemName: "checkmark").foregroundColor(Color(hex: "#4fc3f7"))
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Etkinlik Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { showEventPicker = false }.foregroundColor(Color(hex: "#4fc3f7"))
                }
            }
        }
    }

    func autoLookup(_ text: String) {
        lookupTask?.cancel()
        teamName = ""
        teamEvents = []
        eventName = ""
        lookupError = ""
        guard let num = Int(text), text.count >= 3 else { return }
        lookupTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce
            guard !Task.isCancelled else { return }
            await lookupTeam(number: num)
        }
    }

    @MainActor
    func lookupTeam(number: Int) async {
        isLookingUp = true
        lookupError = ""
        do {
            let team = try await TBAService.shared.fetchTeam(number: number)
            withAnimation { teamName = team.displayName }
            // Takımın bu yılki etkinliklerini çek
            let year = Calendar.current.component(.year, from: Date())
            teamEvents = (try? await TBAService.shared.fetchTeamEvents(number: number, year: year)) ?? []
            if teamEvents.count == 1 { eventName = teamEvents[0].name }
        } catch {
            lookupError = "Takım bulunamadı (#\(number))"
        }
        isLookingUp = false
    }

    @MainActor
    func lookupTeam() async {
        guard let num = Int(teamNumberText) else {
            lookupError = "Geçerli bir numara girin"
            return
        }
        await lookupTeam(number: num)
    }

    // MARK: - Step 1: Scores

    var scoresStep: some View {
        VStack(spacing: 16) {
            formCard {
                VStack(spacing: 20) {
                    scoreSlider("Otonom Puanı", value: $autoScore, color: Color(hex: "#1565c0"), max: 30)
                    Divider().background(Color.white.opacity(0.08))
                    scoreSlider("Teleop Puanı", value: $teleopScore, color: Color(hex: "#2e7d32"), max: 100)
                    Divider().background(Color.white.opacity(0.08))
                    scoreSlider("Endgame Puanı", value: $endgameScore, color: Color(hex: "#6a1b9a"), max: 30)
                }
            }

            // Total
            HStack {
                Text("Toplam Puan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(autoScore + teleopScore + endgameScore)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#4fc3f7"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#4fc3f7").opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4fc3f7").opacity(0.25), lineWidth: 1))
            )

            // Capabilities
            formCard {
                VStack(spacing: 14) {
                    formLabel("Kabiliyetler")
                    HStack(spacing: 12) {
                        capabilityToggle("🧗 Tırmanma", isOn: $canClimb)
                        capabilityToggle("🎯 Atış", isOn: $canShoot)
                        capabilityToggle("🛡 Savunma", isOn: $canDefend)
                    }
                }
            }
        }
    }

    func scoreSlider(_ label: String, value: Binding<Int>, color: Color, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(color)
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: 0...Double(max), step: 1)
            .tint(color)
        }
    }

    func capabilityToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isOn.wrappedValue ? Color(hex: "#4fc3f7") : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isOn.wrappedValue ? Color(hex: "#4fc3f7").opacity(0.15) : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            isOn.wrappedValue ? Color(hex: "#4fc3f7").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
                )
        }
    }

    // MARK: - Step 2: Ratings

    var ratingsStep: some View {
        formCard {
            VStack(spacing: 20) {
                ratingSelector("🕹 Sürüş Kalitesi", rating: $drivingRating)
                Divider().background(Color.white.opacity(0.08))
                ratingSelector("🛡 Savunma Kalitesi", rating: $defenseRating)
                Divider().background(Color.white.opacity(0.08))
                ratingSelector("🎯 Tutarlılık", rating: $consistencyRating)
            }
        }
    }

    func ratingSelector(_ label: String, rating: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(rating.wrappedValue)/5")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#f9a825"))
            }
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        rating.wrappedValue = i
                    } label: {
                        Image(systemName: i <= rating.wrappedValue ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundColor(i <= rating.wrappedValue ? Color(hex: "#f9a825") : Color.white.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Step 3: Notes

    var notesStep: some View {
        VStack(spacing: 16) {
            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Otonom Notları")
                    TextEditor(text: $autonomousNotes)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 70)
                }
            }

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Teleop Notları")
                    TextEditor(text: $teleopNotes)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 70)
                }
            }

            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Genel Notlar")
                    TextEditor(text: $generalNotes)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 70)
                }
            }
        }
    }

    // MARK: - Nav Buttons

    var navButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Geri")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }

            Button {
                if currentStep < steps.count - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    saveReport()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentStep == steps.count - 1 ? "Kaydet" : "İleri")
                    Image(systemName: currentStep == steps.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#1565c0"), Color(hex: "#4fc3f7")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(currentStep == 0 && (teamNumberText.isEmpty || teamName.isEmpty || eventName.isEmpty || scoutedBy.isEmpty))
            .opacity(currentStep == 0 && (teamNumberText.isEmpty || teamName.isEmpty || eventName.isEmpty || scoutedBy.isEmpty) ? 0.5 : 1)
        }
    }

    func saveReport() {
        guard let teamNum = Int(teamNumberText), !teamName.isEmpty else { return }
        let report = ScoutingReport(
            teamNumber: teamNum,
            teamName: teamName,
            eventName: eventName,
            matchNumber: Int(matchNumberText) ?? 1,
            autoScore: autoScore,
            teleopScore: teleopScore,
            endgameScore: endgameScore,
            autonomousNotes: autonomousNotes,
            teleopNotes: teleopNotes,
            generalNotes: generalNotes,
            drivingRating: drivingRating,
            defenseRating: defenseRating,
            consistencyRating: consistencyRating,
            canClimb: canClimb,
            canShoot: canShoot,
            canDefend: canDefend,
            scoutedBy: scoutedBy,
            timestamp: Date()
        )
        store.save(report)
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Form Helpers

    func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
    }

    func formLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.gray)
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func formTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundColor(.white)
            .autocorrectionDisabled()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
    }

    func formLabelAndField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel(label)
            formTextField(placeholder, text: text)
        }
    }
}
