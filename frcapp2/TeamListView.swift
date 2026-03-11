import SwiftUI
import Combine

class TeamListViewModel: ObservableObject {
    @Published var initialTeams: [FRCTeam] = []
    @Published var searchResults: [FRCTeam] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet { handleSearch() }
    }

    private let service = TBAService.shared
    private var searchTask: Task<Void, Never>?

    var displayTeams: [FRCTeam] {
        searchText.isEmpty ? initialTeams : searchResults
    }

    @MainActor
    func loadInitial() async {
        guard initialTeams.isEmpty else { return }
        isLoading = true
        do {
            // ITOBOT #6038 ile başla, sonra ilk 9 takımı ekle
            async let itobotData = try? service.fetchTeam(number: 6038)
            async let firstPageData = try service.fetchTeams(page: 0)
            let itobot = await itobotData
            let firstPage = try await firstPageData
            var teams = Array(firstPage.prefix(9))
            if let itobot = itobot, !teams.contains(where: { $0.team_number == 6038 }) {
                teams.insert(itobot, at: 0)
            }
            initialTeams = teams
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func handleSearch() {
        searchTask?.cancel()
        searchResults = []
        errorMessage = nil
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await search(query: searchText.trimmingCharacters(in: .whitespaces))
        }
    }

    @MainActor
    func search(query: String) async {
        isSearching = true
        errorMessage = nil

        if let number = Int(query) {
            do {
                let team = try await service.fetchTeam(number: number)
                searchResults = [team]
            } catch {
                searchResults = []
                errorMessage = "\(number) numaralı takım bulunamadı"
            }
            isSearching = false
            return
        }

        var found: [FRCTeam] = []
        let q = query.lowercased()
        do {
            for page in 0..<5 {
                guard !Task.isCancelled else { break }
                let teams = try await service.fetchTeams(page: page)
                if teams.isEmpty { break }
                let filtered = teams.filter {
                    $0.displayName.lowercased().contains(q) ||
                    ($0.city?.lowercased().contains(q) ?? false) ||
                    ($0.country?.lowercased().contains(q) ?? false) ||
                    ($0.state_prov?.lowercased().contains(q) ?? false)
                }
                found.append(contentsOf: filtered)
                if !found.isEmpty { searchResults = found }
            }
            searchResults = found
            if found.isEmpty { errorMessage = "Sonuç bulunamadı" }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }
}

struct TeamListView: View {
    @StateObject private var vm = TeamListViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(Color(hex: "#4fc3f7")).scaleEffect(1.4)
                        Text("Yükleniyor...").font(.system(size: 13)).foregroundColor(.gray).padding(.top, 12)
                        Spacer()
                    } else if let error = vm.errorMessage, vm.displayTeams.isEmpty {
                        errorView(error)
                    } else {
                        teamList
                    }
                }
            }
            .navigationTitle("Takımlar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await vm.loadInitial() }
        }
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(vm.isSearching ? Color(hex: "#4fc3f7") : .gray)
            TextField("Takım no, isim veya şehir ara...", text: $vm.searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if vm.isSearching {
                ProgressView().tint(Color(hex: "#4fc3f7")).scaleEffect(0.8)
            } else if !vm.searchText.isEmpty {
                Button { vm.searchText = ""; vm.errorMessage = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                    vm.searchText.isEmpty ? Color.white.opacity(0.1) : Color(hex: "#4fc3f7").opacity(0.4), lineWidth: 1))
        )
    }

    var teamList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack {
                    Text(vm.searchText.isEmpty ? "Öne Çıkan Takımlar" : "\(vm.displayTeams.count) sonuç")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(vm.searchText.isEmpty ? .gray : Color(hex: "#4fc3f7"))
                        .tracking(1)
                    Spacer()
                    if vm.searchText.isEmpty {
                        Text("Arama yapın").font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                    }
                }
                .padding(.horizontal, 4).padding(.bottom, 4)

                ForEach(vm.displayTeams) { team in
                    NavigationLink(destination: TeamDetailView(teamNumber: team.team_number, preloadedTeam: team)) {
                        TeamRowCard(team: team)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if !vm.isSearching && !vm.searchText.isEmpty && vm.displayTeams.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundColor(.gray.opacity(0.5))
                        Text("Sonuç bulunamadı").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Text("Takım numarasıyla aramayı deneyin.").font(.system(size: 13)).foregroundColor(.gray)
                    }
                    .padding(40)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash").font(.system(size: 44)).foregroundColor(.red.opacity(0.7))
            Text("Hata").font(.headline).foregroundColor(.white)
            Text(message).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button("Tekrar Dene") { Task { await vm.loadInitial() } }
                .buttonStyle(.borderedProminent).tint(Color(hex: "#4fc3f7"))
            Spacer()
        }
        .padding(40)
    }
}

struct TeamRowCard: View {
    let team: FRCTeam

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

    var teamColor: Color {
        let colors: [Color] = [Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
                               Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c")]
        return colors[team.team_number % colors.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(teamColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(teamColor.opacity(0.4), lineWidth: 1))
                    .frame(width: 60, height: 60)
                VStack(spacing: 1) {
                    Text(countryFlag).font(.system(size: 16))
                    Text("\(team.team_number)").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(teamColor)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(team.displayName).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                if !team.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 10)).foregroundColor(.gray)
                        Text(team.location).font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                }
                if let year = team.rookie_year {
                    Text("Kuruluş \(year)").font(.system(size: 11, weight: .medium)).foregroundColor(teamColor.opacity(0.8))
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @StateObject private var favorites = FavoritesStore.shared
    @State private var favoriteTeams: [FRCTeam] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(Color(hex: "#ef5350")).scaleEffect(1.4)
                        Text("Favoriler yükleniyor...").font(.system(size: 13)).foregroundColor(.gray)
                    }
                } else if favorites.favoriteTeamNumbers.isEmpty {
                    emptyFavoritesView
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            HStack {
                                Text("\(favoriteTeams.count) favori takım")
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.gray).tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            ForEach(favoriteTeams) { team in
                                NavigationLink(destination: TeamDetailView(teamNumber: team.team_number, preloadedTeam: team)) {
                                    FavoriteTeamCard(team: team)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Favoriler")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadFavorites() }
            .onChange(of: favorites.favoriteTeamNumbers) { _ in
                Task { await loadFavorites() }
            }
        }
    }

    func loadFavorites() async {
        isLoading = true
        var loaded: [FRCTeam] = []
        for num in favorites.favoriteTeamNumbers {
            if let team = try? await TBAService.shared.fetchTeam(number: num) {
                loaded.append(team)
            }
        }
        favoriteTeams = loaded.sorted { $0.team_number < $1.team_number }
        isLoading = false
    }

    var emptyFavoritesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 52)).foregroundColor(Color(hex: "#ef5350").opacity(0.4))
            Text("Henüz favori yok")
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text("Takım detay sayfasında ❤️ butonuna\nbasarak favorilere ekleyebilirsiniz.")
                .font(.system(size: 14)).foregroundColor(.gray).multilineTextAlignment(.center).lineSpacing(4)
        }
        .padding(40)
    }
}

struct FavoriteTeamCard: View {
    let team: FRCTeam
    @StateObject private var favorites = FavoritesStore.shared

    var teamColor: Color {
        let colors: [Color] = [Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
                               Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c")]
        return colors[team.team_number % colors.count]
    }

    var countryFlag: String {
        switch team.country?.lowercased() ?? "" {
        case "turkey", "türkiye": return "🇹🇷"
        case "united states":     return "🇺🇸"
        case "canada":            return "🇨🇦"
        default:                  return "🌐"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(teamColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(teamColor.opacity(0.4), lineWidth: 1))
                    .frame(width: 60, height: 60)
                VStack(spacing: 1) {
                    Text(countryFlag).font(.system(size: 16))
                    Text("\(team.team_number)").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(teamColor)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(team.displayName).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                if !team.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 10)).foregroundColor(.gray)
                        Text(team.location).font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                }
            }
            Spacer()
            Button {
                favorites.toggle(team.team_number)
            } label: {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color(hex: "#ef5350"))
                    .font(.system(size: 18))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#ef5350").opacity(0.15), lineWidth: 1)))
    }
}

