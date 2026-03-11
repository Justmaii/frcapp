import SwiftUI

struct ContentView: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        TabView {
            SplashHomeView()
                .tabItem { Label("Ana Sayfa", systemImage: "house.fill") }

            TeamListView()
                .tabItem { Label("Takımlar", systemImage: "person.3.fill") }

            FavoritesView()
                .tabItem { Label("Favoriler", systemImage: "heart.fill") }

            EventsView()
                .tabItem { Label("Etkinlikler", systemImage: "calendar") }

            OPRStatsView()
                .tabItem { Label("İstatistik", systemImage: "chart.bar.fill") }

            ScoutingView()
                .tabItem { Label("Scouting", systemImage: "clipboard.fill") }

            AboutView()
                .tabItem { Label("Hakkında", systemImage: "info.circle.fill") }
        }
        .accentColor(Color("ITOBlue"))
        .preferredColorScheme(theme.colorScheme)
    }
}

