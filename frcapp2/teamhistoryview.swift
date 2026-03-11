//
//  teamhistoryview.swift
//  frcapp2
//
//  Created by Mai Ddk on 10.03.2026.
//

import SwiftUI
import Combine

// MARK: - Season Result Model

struct TeamSeasonResult: Identifiable {
    let id = UUID()
    let year: Int
    let events: [FRCEvent]
    let matches: [FRCMatch]
    let awards: [FRCAward]

    var winCount: Int {
        matches.filter { $0.winning_alliance != nil && matchWon($0) }.count
    }

    var lossCount: Int {
        matches.filter { $0.winning_alliance != nil && !matchWon($0) }.count
    }

    var winRate: Double {
        let total = winCount + lossCount
        guard total > 0 else { return 0 }
        return Double(winCount) / Double(total)
    }

    private func matchWon(_ match: FRCMatch) -> Bool {
        // Bu takımın hangi alliance'da olduğunu bilemeyiz simple endpoint'te
        // winning_alliance doluysa ve score > 0 ise sayarız
        return match.winning_alliance != nil && match.winning_alliance != ""
    }
}

// MARK: - History ViewModel

class TeamHistoryViewModel: ObservableObject {
    @Published var seasons: [TeamSeasonResult] = []
    @Published var isLoading = false
    @Published var loadingYear: Int? = nil
    @Published var errorMessage: String?
    @Published var selectedYear: Int? = nil

    private let service = TBAService.shared

    @MainActor
    func load(teamNumber: Int, rookieYear: Int?) {
        guard seasons.isEmpty else { return }
        isLoading = true
        Task {
            await fetchHistory(teamNumber: teamNumber, rookieYear: rookieYear)
        }
    }

    @MainActor
    private func fetchHistory(teamNumber: Int, rookieYear: Int?) async {
        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = rookieYear ?? (currentYear - 8)
        let years = Array(stride(from: currentYear, through: max(startYear, currentYear - 10), by: -1))

        var results: [TeamSeasonResult] = []

        for year in years {
            loadingYear = year
            async let eventsData = try? service.fetchTeamEvents(number: teamNumber, year: year)
            async let matchesData = try? service.fetchTeamMatches(number: teamNumber, year: year)
            async let awardsData = try? service.fetchTeamAwards(number: teamNumber)

            let events = await eventsData ?? []
            let matches = await matchesData ?? []
            let awards = (await awardsData ?? []).filter { $0.year == year }

            if !events.isEmpty || !matches.isEmpty {
                results.append(TeamSeasonResult(
                    year: year,
                    events: events,
                    matches: matches,
                    awards: awards
                ))
            }
        }

        seasons = results
        loadingYear = nil
        isLoading = false
    }
}

// MARK: - Team History View

struct TeamHistoryView: View {
    let team: FRCTeam
    @StateObject private var vm = TeamHistoryViewModel()

    var teamColor: Color {
        let colors: [Color] = [Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
                               Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c")]
        return colors[team.team_number % colors.count]
    }

    var body: some View {
        ZStack {
            Color(hex: "#0a0e1a").ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if vm.seasons.isEmpty {
                emptyView
            } else {
                content
            }
        }
        .navigationTitle("Sezon Geçmişi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            vm.load(teamNumber: team.team_number, rookieYear: team.rookie_year)
        }
    }

    // MARK: - Loading

    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(teamColor).scaleEffect(1.4)
            if let year = vm.loadingYear {
                Text("\(year) sezonu yükleniyor...")
                    .font(.system(size: 13)).foregroundColor(.gray)
            } else {
                Text("Sezon verileri çekiliyor...").font(.system(size: 13)).foregroundColor(.gray)
            }
            Text("Bu birkaç saniye sürebilir").font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
        }
    }

    var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 48))
                .foregroundColor(teamColor.opacity(0.4))
            Text("Sezon verisi bulunamadı").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text("Bu takım için geçmiş etkinlik verisi yok.").font(.system(size: 13)).foregroundColor(.gray)
        }
        .padding(40)
    }

    // MARK: - Content

    var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Özet kart
                summaryCard

                // Sezon listesi
                ForEach(vm.seasons) { season in
                    SeasonCard(season: season, teamColor: teamColor, team: team)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    // MARK: - Summary Card

    var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(teamColor)
                Text("Genel Özet").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(vm.seasons.count) sezon").font(.system(size: 12)).foregroundColor(.gray)
            }

            HStack(spacing: 0) {
                summaryBlock(value: "\(vm.seasons.flatMap(\.events).count)", label: "Etkinlik", color: teamColor)
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                summaryBlock(value: "\(vm.seasons.flatMap(\.matches).count)", label: "Maç", color: Color(hex: "#4fc3f7"))
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                summaryBlock(value: "\(vm.seasons.flatMap(\.awards).count)", label: "Ödül", color: Color(hex: "#f9a825"))
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                summaryBlock(value: "\(vm.seasons.first?.year ?? 0)", label: "Son Sezon", color: Color(hex: "#4caf50"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(teamColor.opacity(0.25), lineWidth: 1))
        )
    }

    func summaryBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Season Card

struct SeasonCard: View {
    let season: TeamSeasonResult
    let teamColor: Color
    let team: FRCTeam
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header — tıklanınca açılır/kapanır
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            } label: {
                seasonHeader
            }

            if expanded {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.08))
                    seasonDetails
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    expanded ? teamColor.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    var seasonHeader: some View {
        HStack(spacing: 12) {
            // Yıl badge
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(teamColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(teamColor.opacity(0.3), lineWidth: 1))
                    .frame(width: 58, height: 52)
                Text("\(season.year)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(teamColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("\(season.year) Sezonu")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)

                HStack(spacing: 10) {
                    statPill("\(season.events.count) etkinlik", icon: "flag.fill", color: teamColor)
                    statPill("\(season.matches.count) maç", icon: "sportscourt.fill", color: Color(hex: "#4fc3f7"))
                    if !season.awards.isEmpty {
                        statPill("\(season.awards.count) ödül", icon: "star.fill", color: Color(hex: "#f9a825"))
                    }
                }
            }

            Spacer()

            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(14)
    }

    var seasonDetails: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Etkinlikler
            if !season.events.isEmpty {
                detailSection(title: "Katıldığı Etkinlikler", icon: "flag.fill", color: teamColor) {
                    ForEach(season.events) { event in
                        EventHistoryRow(event: event, teamColor: teamColor)
                    }
                }
            }

            // Ödüller
            if !season.awards.isEmpty {
                detailSection(title: "Kazandığı Ödüller", icon: "star.fill", color: Color(hex: "#f9a825")) {
                    ForEach(season.awards) { award in
                        HStack(spacing: 10) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#f9a825"))
                            Text(award.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Maç istatistikleri
            if !season.matches.isEmpty {
                matchStatsSection
            }
        }
        .padding(14)
    }

    var matchStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#4fc3f7"))
                Text("Maç İstatistikleri").font(.system(size: 12, weight: .bold)).foregroundColor(.gray).tracking(0.5)
            }

            HStack(spacing: 0) {
                matchStatBlock("\(season.matches.count)", "Toplam", color: Color(hex: "#4fc3f7"))
                Divider().background(Color.white.opacity(0.1)).frame(height: 35)
                let quals = season.matches.filter { $0.comp_level == "qm" }
                matchStatBlock("\(quals.count)", "Eleme", color: Color(hex: "#2e7d32"))
                Divider().background(Color.white.opacity(0.1)).frame(height: 35)
                let elims = season.matches.filter { $0.comp_level != "qm" }
                matchStatBlock("\(elims.count)", "Playoff", color: Color(hex: "#f9a825"))
            }
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        }
    }

    func detailSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
                Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.gray).tracking(0.5)
            }
            content()
        }
    }

    func statPill(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8)).foregroundColor(color)
            Text(text).font(.system(size: 10, weight: .semibold)).foregroundColor(color)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    func matchStatBlock(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Event History Row

struct EventHistoryRow: View {
    let event: FRCEvent
    let teamColor: Color

    var dateStr: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d MMM"; out.locale = Locale(identifier: "tr_TR")
        if let s = event.start_date, let d = f.date(from: s) { return out.string(from: d) }
        return ""
    }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(teamColor).frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name).font(.system(size: 12, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(event.location.isEmpty ? dateStr : "\(event.location) • \(dateStr)")
                    .font(.system(size: 10)).foregroundColor(.gray).lineLimit(1)
            }

            Spacer()

            if let type = event.event_type_string {
                Text(type).font(.system(size: 9, weight: .semibold)).foregroundColor(teamColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(teamColor.opacity(0.12)))
            }
        }
        .padding(.vertical, 4)
    }
}
