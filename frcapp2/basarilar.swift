//
//  basarilar.swift
//  frcapp2
//
//  Created by Mai Ddk on 11.03.2026.
//

import SwiftUI
import Combine

// MARK: - Achievements ViewModel

class AchievementsViewModel: ObservableObject {
    @Published var awards: [FRCAward] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedYear: Int? = nil

    private let service = TBAService.shared
    private let currentYear = Calendar.current.component(.year, from: Date())

    var years: [Int] { Array(Set(awards.map(\.year))).sorted(by: >) }

    var filteredAwards: [FRCAward] {
        guard let y = selectedYear else { return awards }
        return awards.filter { $0.year == y }
    }

    var groupedByYear: [(Int, [FRCAward])] {
        let grouped = Dictionary(grouping: filteredAwards) { $0.year }
        return grouped.sorted { $0.key > $1.key }
    }

    @MainActor
    func load(teamNumber: Int) async {
        guard awards.isEmpty else { return }
        isLoading = true
        awards = (try? await service.fetchTeamAwards(number: teamNumber)) ?? []
        isLoading = false
    }
}

// MARK: - Achievements View (TeamDetailView'den açılır)

struct AchievementsView: View {
    let team: FRCTeam
    @StateObject private var vm = AchievementsViewModel()

    var teamColor: Color {
        let c: [Color] = [Color(hex: "#1565c0"), Color(hex: "#c62828"), Color(hex: "#2e7d32"),
                          Color(hex: "#6a1b9a"), Color(hex: "#e65100"), Color(hex: "#00695c")]
        return c[team.team_number % c.count]
    }

    var body: some View {
        ZStack {
            Color(hex: "#0a0e1a").ignoresSafeArea()
            if vm.isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(teamColor).scaleEffect(1.4)
                    Text("Ödüller yükleniyor...").font(.system(size: 13)).foregroundColor(.gray)
                }
            } else if vm.awards.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "trophy").font(.system(size: 48)).foregroundColor(.gray.opacity(0.3))
                    Text("Henüz ödül yok").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text("Bu takım için kayıtlı ödül bulunamadı.").font(.system(size: 13)).foregroundColor(.gray)
                }
            } else {
                content
            }
        }
        .navigationTitle("Başarılar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.load(teamNumber: team.team_number) }
    }

    var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Özet
                summaryRow
                // Yıl filtresi
                if vm.years.count > 1 { yearFilter }
                // Ödül listesi
                ForEach(vm.groupedByYear, id: \.0) { year, awards in
                    yearSection(year: year, awards: awards)
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
    }

    var summaryRow: some View {
        HStack(spacing: 0) {
            summaryBlock("\(vm.awards.count)", "Toplam Ödül", color: Color(hex: "#f9a825"))
            Divider().background(Color.white.opacity(0.1)).frame(height: 40)
            summaryBlock("\(vm.years.count)", "Farklı Sezon", color: teamColor)
            Divider().background(Color.white.opacity(0.1)).frame(height: 40)
            let wins = vm.awards.filter { $0.name.lowercased().contains("winner") || $0.name.lowercased().contains("champion") }.count
            summaryBlock("\(wins)", "Şampiyonluk", color: Color(hex: "#ef5350"))
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#f9a825").opacity(0.2), lineWidth: 1)))
    }

    func summaryBlock(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    var yearFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                yearChip(nil, label: "Tümü")
                ForEach(vm.years, id: \.self) { year in
                    yearChip(year, label: "\(year)")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    func yearChip(_ year: Int?, label: String) -> some View {
        let active = vm.selectedYear == year
        return Button { vm.selectedYear = year } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(active ? .white : .gray)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(active ? teamColor : Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(active ? teamColor.opacity(0.5) : Color.clear, lineWidth: 1)))
        }
    }

    func yearSection(year: Int, awards: [FRCAward]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(year)").font(.system(size: 14, weight: .black)).foregroundColor(teamColor)
                Text("Sezonu").font(.system(size: 12)).foregroundColor(.gray)
                Spacer()
                Text("\(awards.count) ödül").font(.system(size: 11)).foregroundColor(.gray)
            }
            ForEach(awards) { award in
                awardRow(award)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(teamColor.opacity(0.15), lineWidth: 1)))
    }

    func awardRow(_ award: FRCAward) -> some View {
        let isChamp = award.name.lowercased().contains("winner") || award.name.lowercased().contains("champion")
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(isChamp ? Color(hex: "#f9a825").opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: isChamp ? "trophy.fill" : "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isChamp ? Color(hex: "#f9a825") : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(award.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(2)
                Text(award.event_key.uppercased()).font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
