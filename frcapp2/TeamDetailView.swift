import SwiftUI
import Combine

class TeamDetailViewModel: ObservableObject {
    @Published var team: FRCTeam
    @Published var awards: [FRCAward] = []
    @Published var isLoadingExtra = false

    private let service = TBAService.shared

    init(team: FRCTeam) {
        self.team = team
    }

    @MainActor
    func loadExtras() async {
        isLoadingExtra = true
        awards = (try? await service.fetchTeamAwards(number: team.team_number)) ?? []
        if let full = try? await service.fetchTeamFull(number: team.team_number) {
            team = full
        }
        isLoadingExtra = false
    }
}

struct TeamDetailView: View {
    let initialTeam: FRCTeam
    @StateObject private var vm: TeamDetailViewModel
    @ObservedObject private var favorites = FavoritesStore.shared

    init(teamNumber: Int, preloadedTeam: FRCTeam) {
        self.initialTeam = preloadedTeam
        _vm = StateObject(wrappedValue: TeamDetailViewModel(team: preloadedTeam))
    }

    var teamNumber: Int { vm.team.team_number }

    var teamColor: Color {
        let colors: [Color] = [
            Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
            Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c")
        ]
        return colors[teamNumber % colors.count]
    }

    var isFav: Bool { favorites.isFavorite(teamNumber) }

    var body: some View {
        ZStack {
            Color(hex: "#0a0e1a").ignoresSafeArea()
            teamContent(vm.team)
        }
        .navigationTitle("Takım #\(teamNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { favorites.toggle(teamNumber) } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .foregroundColor(isFav ? Color(hex: "#ef5350") : .gray)
                        .font(.system(size: 18))
                }
            }
        }
        .task { await vm.loadExtras() }
    }

    // MARK: - Content

    func teamContent(_ team: FRCTeam) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                teamHeroCard(team)
                infoGrid(team)
                historyButton(team)
                achievementsButton(team)
                compareButton(team)
                if let url = team.website, let u = URL(string: url) {
                    websiteButton(url: u, site: url)
                }
                if !vm.awards.isEmpty { awardsSection }
                if vm.isLoadingExtra {
                    HStack(spacing: 8) {
                        ProgressView().tint(.gray).scaleEffect(0.7)
                        Text("Detaylar yükleniyor...").font(.system(size: 11)).foregroundColor(.gray)
                    }
                }
                tbaLinkButton(team)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    // MARK: - Hero Card

    func teamHeroCard(_ team: FRCTeam) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(teamColor.opacity(0.15))
                    .overlay(Circle().stroke(teamColor.opacity(0.4), lineWidth: 2))
                    .frame(width: 80, height: 80)
                Text("#\(teamNumber)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(teamColor)
            }
            Text(team.displayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            if !team.location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill").foregroundColor(teamColor).font(.system(size: 13))
                    Text(team.location).font(.system(size: 13)).foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(teamColor.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Info Grid

    func infoGrid(_ team: FRCTeam) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let year = team.rookie_year {
                infoCell(icon: "calendar", label: "Kuruluş", value: "\(year)", color: teamColor)
            }
            if let country = team.country {
                infoCell(icon: "globe", label: "Ülke", value: country, color: Color(hex: "#4fc3f7"))
            }
            if let city = team.city {
                infoCell(icon: "building.2", label: "Şehir", value: city, color: Color(hex: "#f9a825"))
            }
            infoCell(icon: "star.fill", label: "Ödüller", value: "\(vm.awards.count)", color: Color(hex: "#f9a825"))
        }
    }

    func infoCell(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10)).foregroundColor(.gray)
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1)))
    }

    // MARK: - Buttons

    func achievementsButton(_ team: FRCTeam) -> some View {
        NavigationLink(destination: AchievementsView(team: team)) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill").foregroundColor(Color(hex: "#f9a825"))
                Text("Başarılar & Ödüller").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#f9a825"))
                Spacer()
                if !vm.awards.isEmpty {
                    Text("\(vm.awards.count)").font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#f9a825"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#f9a825").opacity(0.15)))
                }
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#f9a825").opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#f9a825").opacity(0.25), lineWidth: 1)))
        }
    }

    func historyButton(_ team: FRCTeam) -> some View {
        NavigationLink(destination: TeamHistoryView(team: team)) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath").foregroundColor(Color(hex: "#4fc3f7"))
                Text("Sezon Geçmişi").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#4fc3f7"))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#4fc3f7").opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4fc3f7").opacity(0.25), lineWidth: 1)))
        }
    }

    func compareButton(_ team: FRCTeam) -> some View {
        NavigationLink(destination: TeamCompareView(team1: team)) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right.circle.fill").foregroundColor(Color(hex: "#f9a825"))
                Text("Başka Takımla Karşılaştır").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#f9a825"))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#f9a825").opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#f9a825").opacity(0.25), lineWidth: 1)))
        }
    }

    func websiteButton(url: URL, site: String) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: "globe").foregroundColor(Color(hex: "#4caf50"))
                Text(site).font(.system(size: 13)).foregroundColor(Color(hex: "#4caf50")).lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundColor(.gray)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#4caf50").opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4caf50").opacity(0.2), lineWidth: 1)))
        }
    }

    // MARK: - Awards

    var awardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill").foregroundColor(Color(hex: "#f9a825"))
                Text("Ödüller").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(vm.awards.count)").font(.system(size: 12)).foregroundColor(.gray)
            }
            ForEach(vm.awards.prefix(10)) { award in
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#f9a825"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(award.name).font(.system(size: 12, weight: .semibold)).foregroundColor(.white).lineLimit(2)
                        Text("\(award.year)").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#f9a825").opacity(0.2), lineWidth: 1)))
    }

    func tbaLinkButton(_ team: FRCTeam) -> some View {
        Link(destination: URL(string: "https://www.thebluealliance.com/team/\(teamNumber)")!) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundColor(Color(hex: "#4fc3f7"))
                Text("The Blue Alliance'da Görüntüle").font(.system(size: 13)).foregroundColor(Color(hex: "#4fc3f7"))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundColor(.gray)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#4fc3f7").opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4fc3f7").opacity(0.15), lineWidth: 1)))
        }
    }
}

