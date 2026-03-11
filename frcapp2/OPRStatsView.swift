import SwiftUI
import Combine

// MARK: - OPR ViewModel

class OPRStatsViewModel: ObservableObject {
    @Published var stats: [TeamOPRStats] = []
    @Published var filteredStats: [TeamOPRStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sortBy: OPRSort = .opr
    @Published var searchText = ""
    @Published var selectedEvent: FRCEvent?
    @Published var events: [FRCEvent] = []

    private let service = TBAService.shared

    enum OPRSort: String, CaseIterable {
        case opr = "OPR"
        case dpr = "DPR"
        case ccwm = "CCWM"

        var description: String {
            switch self {
            case .opr: return "Hücum Gücü"
            case .dpr: return "Savunma Gücü"
            case .ccwm: return "Tahmini Güç"
            }
        }

        var icon: String {
            switch self {
            case .opr: return "bolt.fill"
            case .dpr: return "shield.fill"
            case .ccwm: return "star.fill"
            }
        }

        var color: Color {
            switch self {
            case .opr: return Color(hex: "#4fc3f7")
            case .dpr: return Color(hex: "#ef5350")
            case .ccwm: return Color(hex: "#f9a825")
            }
        }
    }

    @MainActor
    func loadEvents() async {
        guard events.isEmpty else { return }
        let year = Calendar.current.component(.year, from: Date())
        if let fetched = try? await service.fetchEvents(year: year) {
            events = fetched.sorted { ($0.start_date ?? "") > ($1.start_date ?? "") }
            if let first = events.first {
                selectedEvent = first
                await loadOPR(for: first)
            }
        }
    }

    @MainActor
    func loadOPR(for event: FRCEvent) async {
        isLoading = true
        errorMessage = nil
        stats = []
        filteredStats = []
        selectedEvent = event

        do {
            let opr = try await service.fetchEventOPRs(eventKey: event.key)
            var result: [TeamOPRStats] = []
            let oprs = opr.oprs ?? [:]
            let dprs = opr.dprs ?? [:]
            let ccwms = opr.ccwms ?? [:]

            for (key, oprVal) in oprs {
                let num = Int(key.replacingOccurrences(of: "frc", with: "")) ?? 0
                result.append(TeamOPRStats(
                    teamKey: key,
                    teamNumber: num,
                    opr: oprVal,
                    dpr: dprs[key] ?? 0,
                    ccwm: ccwms[key] ?? 0
                ))
            }

            stats = result
            applySort()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func applySort() {
        var sorted = stats
        switch sortBy {
        case .opr: sorted.sort { $0.opr > $1.opr }
        case .dpr: sorted.sort { $0.dpr < $1.dpr } // dpr düşük = iyi savunma
        case .ccwm: sorted.sort { $0.ccwm > $1.ccwm }
        }
        if searchText.isEmpty {
            filteredStats = sorted
        } else {
            let q = searchText.lowercased()
            filteredStats = sorted.filter { "\($0.teamNumber)".contains(q) }
        }
    }
}

// MARK: - OPR Stats View

struct OPRStatsView: View {
    @StateObject private var vm = OPRStatsViewModel()
    @State private var showEventPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                VStack(spacing: 0) {
                    headerBar
                    if vm.isLoading {
                        loadingView
                    } else if let err = vm.errorMessage {
                        errorView(err)
                    } else if vm.filteredStats.isEmpty {
                        emptyView
                    } else {
                        statsList
                    }
                }
            }
            .navigationTitle("OPR İstatistikleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await vm.loadEvents() }
            .sheet(isPresented: $showEventPicker) { eventPickerSheet }
            .onChange(of: vm.sortBy) { _ in vm.applySort() }
            .onChange(of: vm.searchText) { _ in vm.applySort() }
        }
    }

    // MARK: - Header Bar

    var headerBar: some View {
        VStack(spacing: 12) {
            // Etkinlik seçici
            Button { showEventPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#4fc3f7"))
                    Text(vm.selectedEvent?.name ?? "Etkinlik Seç")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(.gray)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4fc3f7").opacity(0.3), lineWidth: 1)))
            }

            // Sort seçici
            HStack(spacing: 8) {
                ForEach(OPRStatsViewModel.OPRSort.allCases, id: \.self) { sort in
                    sortButton(sort)
                }
                Spacer()
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.gray)
                    TextField("Takım no", text: $vm.searchText)
                        .font(.system(size: 12)).foregroundColor(.white)
                        .frame(width: 70)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
            }

            // Kolon başlıkları
            columnHeaders
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .background(Color(hex: "#0d1220"))
    }

    func sortButton(_ sort: OPRStatsViewModel.OPRSort) -> some View {
        let active = vm.sortBy == sort
        return Button { vm.sortBy = sort } label: {
            HStack(spacing: 4) {
                Image(systemName: sort.icon).font(.system(size: 10))
                Text(sort.rawValue).font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(active ? sort.color : .gray)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(active ? sort.color.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(Capsule().stroke(active ? sort.color.opacity(0.4) : Color.clear, lineWidth: 1)))
        }
    }

    var columnHeaders: some View {
        HStack {
            Text("SIRA").font(.system(size: 9, weight: .bold)).foregroundColor(.gray).frame(width: 32)
            Text("TAKIM").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
            Spacer()
            Text("OPR").font(.system(size: 9, weight: .bold)).foregroundColor(OPRStatsViewModel.OPRSort.opr.color).frame(width: 52, alignment: .trailing)
            Text("DPR").font(.system(size: 9, weight: .bold)).foregroundColor(OPRStatsViewModel.OPRSort.dpr.color).frame(width: 52, alignment: .trailing)
            Text("CCWM").font(.system(size: 9, weight: .bold)).foregroundColor(OPRStatsViewModel.OPRSort.ccwm.color).frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Stats List

    var statsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.filteredStats.enumerated()), id: \.element.id) { index, stat in
                    OPRStatRow(rank: index + 1, stat: stat, sortBy: vm.sortBy)
                    if index < vm.filteredStats.count - 1 {
                        Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - States

    var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().tint(Color(hex: "#4fc3f7")).scaleEffect(1.4)
            Text("İstatistikler yükleniyor...").font(.system(size: 13)).foregroundColor(.gray)
            Spacer()
        }
    }

    func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark").font(.system(size: 44)).foregroundColor(.gray.opacity(0.4))
            Text("Veri yüklenemedi").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(msg).font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { Task { if let e = vm.selectedEvent { await vm.loadOPR(for: e) } } } label: {
                Text("Tekrar Dene").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#4fc3f7"))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#4fc3f7").opacity(0.12)))
            }
            Spacer()
        }
    }

    var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "chart.bar.xaxis").font(.system(size: 44)).foregroundColor(.gray.opacity(0.3))
            Text("Veri bulunamadı").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text("Bu etkinlik için OPR verisi mevcut değil.").font(.system(size: 13)).foregroundColor(.gray)
            Spacer()
        }
    }

    // MARK: - Event Picker Sheet

    var eventPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.events) { event in
                            Button {
                                showEventPicker = false
                                Task { await vm.loadOPR(for: event) }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                                        Text(event.location).font(.system(size: 11)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if vm.selectedEvent?.key == event.key {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#4fc3f7"))
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(
                                    vm.selectedEvent?.key == event.key ? Color(hex: "#4fc3f7").opacity(0.1) : Color.white.opacity(0.04)))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Etkinlik Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { showEventPicker = false }.foregroundColor(Color(hex: "#4fc3f7"))
                }
            }
        }
    }
}

// MARK: - OPR Stat Row

struct OPRStatRow: View {
    let rank: Int
    let stat: TeamOPRStats
    let sortBy: OPRStatsViewModel.OPRSort

    var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#f9a825")
        case 2: return Color(hex: "#9e9e9e")
        case 3: return Color(hex: "#8d6e63")
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Rank
            Group {
                if rank <= 3 {
                    Image(systemName: "crown.fill").font(.system(size: 11)).foregroundColor(rankColor)
                } else {
                    Text("\(rank)").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                }
            }
            .frame(width: 32)

            // Team number
            Text("#" + String(stat.teamNumber))
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(sortBy.color)
            Spacer()

            // OPR
            statValue(String(format: "%.1f", stat.opr), highlight: sortBy == .opr, color: OPRStatsViewModel.OPRSort.opr.color)
            // DPR
            statValue(String(format: "%.1f", stat.dpr), highlight: sortBy == .dpr, color: OPRStatsViewModel.OPRSort.dpr.color)
            // CCWM
            statValue(String(format: "%.1f", stat.ccwm), highlight: sortBy == .ccwm, color: OPRStatsViewModel.OPRSort.ccwm.color)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(rank % 2 == 0 ? Color.white.opacity(0.02) : Color.clear)
    }

    func statValue(_ text: String, highlight: Bool, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: highlight ? .black : .regular, design: .monospaced))
            .foregroundColor(highlight ? color : .gray.opacity(0.7))
            .frame(width: 52, alignment: .trailing)
    }
}

