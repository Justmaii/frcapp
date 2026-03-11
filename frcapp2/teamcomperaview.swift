import SwiftUI
import Combine

// MARK: - ViewModel

class TeamCompareViewModel: ObservableObject {
    @Published var team2: FRCTeam?
    @Published var awards1: [FRCAward] = []
    @Published var awards2: [FRCAward] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var searchResults: [FRCTeam] = []

    private let service = TBAService.shared
    private var searchTask: Task<Void, Never>?

    @MainActor
    func loadAwards(team1Number: Int) async {
        awards1 = (try? await service.fetchTeamAwards(number: team1Number)) ?? []
    }

    @MainActor
    func selectTeam2(_ team: FRCTeam) async {
        isLoading = true
        team2 = team
        awards2 = (try? await service.fetchTeamAwards(number: team.team_number)) ?? []
        isLoading = false
        searchText = ""
        searchResults = []
    }

    func handleSearch() {
        searchTask?.cancel()
        searchResults = []
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
        if let number = Int(query) {
            if let team = try? await service.fetchTeam(number: number) {
                searchResults = [team]
            }
        } else {
            var found: [FRCTeam] = []
            let q = query.lowercased()
            for page in 0..<3 {
                guard !Task.isCancelled else { break }
                if let teams = try? await service.fetchTeams(page: page) {
                    found.append(contentsOf: teams.filter {
                        $0.displayName.lowercased().contains(q) ||
                        ($0.city?.lowercased().contains(q) ?? false)
                    })
                    searchResults = found
                }
            }
        }
        isSearching = false
    }
}

// MARK: - Search Result Row

struct CompareSearchResultRow: View {
    let team: FRCTeam
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("#\(team.team_number)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.displayName).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    Text(team.location).font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundColor(accentColor).font(.system(size: 18))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.2), lineWidth: 1)))
        }
    }
}

// MARK: - Team Compare View

struct TeamCompareView: View {
    let team1: FRCTeam
    @StateObject private var vm = TeamCompareViewModel()
    @State private var appeared = false

    var team1Color: Color { teamAccentColor(team1.team_number) }
    var team2Color: Color { teamAccentColor(vm.team2?.team_number ?? 0) }

    var body: some View {
        ZStack {
            // Arka plan gradient
            LinearGradient(
                colors: [Color(hex: "#060810"), Color(hex: "#0a0e1a"), Color(hex: "#060810")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroHeader
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)

                    if vm.team2 == nil {
                        pickerCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)
                    } else if vm.isLoading {
                        loadingCard
                    } else {
                        compareCards
                    }

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Karşılaştır")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.loadAwards(team1Number: team1.team_number) }
        .onChange(of: vm.searchText) { _ in vm.handleSearch() }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero Header

    var heroHeader: some View {
        ZStack {
            // Glow efektleri
            Circle().fill(team1Color.opacity(0.12)).frame(width: 160, height: 160)
                .blur(radius: 40).offset(x: -60, y: 0)
            if vm.team2 != nil {
                Circle().fill(team2Color.opacity(0.12)).frame(width: 160, height: 160)
                    .blur(radius: 40).offset(x: 60, y: 0)
            }

            HStack(spacing: 0) {
                // Takım 1
                teamHeroCard(team: team1, color: team1Color, awards: vm.awards1.count)

                // VS orta
                vsIndicator

                // Takım 2
                if let t2 = vm.team2 {
                    teamHeroCard(team: t2, color: team2Color, awards: vm.awards2.count)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                        .onTapGesture { withAnimation(.spring()) { vm.team2 = nil } }
                } else {
                    emptySlot
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    func teamHeroCard(team: FRCTeam, color: Color, awards: Int) -> some View {
        VStack(spacing: 10) {
            // Numara badge
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [color.opacity(0.3), color.opacity(0.1)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.3), radius: 10)
                Text("#\(team.team_number)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(color)
            }

            Text(team.displayName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            Text(team.location.isEmpty ? "—" : team.location)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Ödül pill
            if awards > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(Color(hex: "#f9a825"))
                    Text("\(awards)").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "#f9a825"))
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: "#f9a825").opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20).padding(.horizontal, 12)
    }

    var vsIndicator: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "#1a1f35"), Color(hex: "#0d1120")],
                                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 8)
                Text("VS")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .zIndex(1)
    }

    var emptySlot: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .foregroundColor(Color.white.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            Text("Takım Seç")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            Text("aşağıdan ara")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20).padding(.horizontal, 12)
    }

    // MARK: - Picker Card

    var pickerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 18)).foregroundColor(Color(hex: "#4fc3f7"))
                Text("Karşılaştırılacak Takımı Seç")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            pickerSearchBar
            pickerResults
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#4fc3f7").opacity(0.2), lineWidth: 1))
        )
    }

    var pickerSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
            TextField("Takım no veya isim...", text: $vm.searchText)
                .foregroundColor(.white).autocorrectionDisabled()
            if vm.isSearching {
                ProgressView().tint(Color(hex: "#4fc3f7")).scaleEffect(0.8)
            } else if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4fc3f7").opacity(0.3), lineWidth: 1))
        )
    }

    var pickerResults: some View {
        Group {
            if !vm.searchResults.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(vm.searchResults.filter { $0.team_number != team1.team_number }) { team in
                        CompareSearchResultRow(team: team, accentColor: teamAccentColor(team.team_number)) {
                            Task { await vm.selectTeam2(team) }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4), value: vm.searchResults.count)
            } else if !vm.searchText.isEmpty && !vm.isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                    Text("Sonuç bulunamadı").font(.system(size: 13)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
    }

    // MARK: - Loading

    var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView().tint(team2Color).scaleEffect(1.3)
            Text("Veriler yükleniyor...").font(.system(size: 13)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(40)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Compare Cards

    var compareCards: some View {
        VStack(spacing: 14) {
            compareStatCard(title: "Ödül Sayısı", icon: "star.fill",
                            v1: vm.awards1.count, v2: vm.awards2.count,
                            format: { "\($0)" }, higherWins: true, color1: team1Color, color2: team2Color)
            .transition(.move(edge: .leading).combined(with: .opacity))

            compareStatCard(title: "Kuruluş Yılı", icon: "calendar",
                            v1: team1.rookie_year ?? 0, v2: vm.team2?.rookie_year ?? 0,
                            format: { $0 == 0 ? "—" : "\($0)" }, higherWins: false, color1: team1Color, color2: team2Color)
            .transition(.move(edge: .trailing).combined(with: .opacity))

            compareTextCard(title: "Ülke", icon: "globe",
                            v1: team1.country ?? "—", v2: vm.team2?.country ?? "—",
                            color1: team1Color, color2: team2Color)
            .transition(.move(edge: .leading).combined(with: .opacity))

            compareTextCard(title: "Şehir", icon: "mappin.fill",
                            v1: team1.city ?? "—", v2: vm.team2?.city ?? "—",
                            color1: team1Color, color2: team2Color)
            .transition(.move(edge: .trailing).combined(with: .opacity))

            scoutingCard
            .transition(.move(edge: .leading).combined(with: .opacity))

            changeButton
            .transition(.opacity)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.team2?.team_number)
    }

    // MARK: - Stat Card (sayısal, kazanan belirlenir)

    func compareStatCard(title: String, icon: String, v1: Int, v2: Int,
                         format: (Int) -> String, higherWins: Bool,
                         color1: Color, color2: Color) -> some View {
        let winner: Int = v1 == v2 ? 0 : (higherWins ? (v1 > v2 ? 1 : 2) : (v1 < v2 ? 1 : 2))
        return VStack(spacing: 12) {
            // Başlık
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(.gray)
                Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.gray).tracking(1)
            }

            // Bar karşılaştırma
            if v1 > 0 || v2 > 0 {
                compareBar(v1: Double(v1), v2: Double(v2), color1: color1, color2: color2)
            }

            // Değerler
            HStack(spacing: 0) {
                statValueBlock(text: format(v1), color: color1, isWinner: winner == 1)
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                statValueBlock(text: format(v2), color: color2, isWinner: winner == 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                    winner == 1 ? color1.opacity(0.3) : winner == 2 ? color2.opacity(0.3) : Color.white.opacity(0.07),
                    lineWidth: 1))
        )
    }

    func compareBar(v1: Double, v2: Double, color1: Color, color2: Color) -> some View {
        let total = v1 + v2
        let r1 = total > 0 ? v1 / total : 0.5
        let r2 = total > 0 ? v2 / total : 0.5
        return GeometryReader { geo in
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [color1, color1.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(r1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [color2.opacity(0.6), color2], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(r2))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: v1)
    }

    // MARK: - Text Card (kazanan yok)

    func compareTextCard(title: String, icon: String, v1: String, v2: String,
                         color1: Color, color2: Color) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(.gray)
                Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.gray).tracking(1)
            }
            HStack(spacing: 0) {
                textValueBlock(text: v1, color: color1)
                Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                textValueBlock(text: v2, color: color2)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 1)))
    }

    // MARK: - Scouting Card

    var scoutingCard: some View {
        let r1 = ScoutingStore.shared.reports(for: team1.team_number)
        let r2 = ScoutingStore.shared.reports(for: vm.team2?.team_number ?? -1)
        let avg1 = r1.isEmpty ? 0 : r1.map(\.totalScore).reduce(0, +) / r1.count
        let avg2 = r2.isEmpty ? 0 : r2.map(\.totalScore).reduce(0, +) / r2.count
        let winner = avg1 == avg2 ? 0 : (avg1 > avg2 ? 1 : 2)

        return VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clipboard.fill").font(.system(size: 11)).foregroundColor(.gray)
                Text("SCOUTING ORTALAMASI").font(.system(size: 10, weight: .bold)).foregroundColor(.gray).tracking(1)
            }

            if avg1 > 0 || avg2 > 0 {
                compareBar(v1: Double(avg1), v2: Double(avg2), color1: team1Color, color2: team2Color)
            }

            HStack(spacing: 0) {
                statValueBlock(text: r1.isEmpty ? "Yok" : "\(avg1)", color: team1Color, isWinner: winner == 1)
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                statValueBlock(text: r2.isEmpty ? "Yok" : "\(avg2)", color: team2Color, isWinner: winner == 2)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                winner == 1 ? team1Color.opacity(0.3) : winner == 2 ? team2Color.opacity(0.3) : Color.white.opacity(0.07),
                lineWidth: 1)))
    }

    // MARK: - Change Button

    var changeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                vm.team2 = nil
                vm.searchText = ""
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Farklı Takımla Karşılaştır")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.6))
            .padding(.vertical, 14).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1)))
        }
    }

    // MARK: - Helper Views

    func statValueBlock(text: String, color: Color, isWinner: Bool) -> some View {
        HStack(spacing: 4) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#f9a825"))
                    .transition(.scale.combined(with: .opacity))
            }
            Text(text)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(isWinner ? color : color.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isWinner ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isWinner)
    }

    func textValueBlock(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Color Helper

    func teamAccentColor(_ number: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
            Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c"),
            Color(hex: "#00838f"), Color(hex: "#ad1457")
        ]
        return colors[abs(number) % colors.count]
    }
}

