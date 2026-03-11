import SwiftUI

struct AboutView: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0a0e1a").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        appLogoSection
                        themeCard
                        aboutCard(icon: "trophy.fill", iconColor: Color(hex: "#f9a825"),
                                  title: "FIRST Robotics Competition",
                                  body: "FIRST (For Inspiration and Recognition of Science and Technology), Dean Kamen tarafından 1989 yılında kurulmuş, kâr amacı gütmeyen bir kuruluştur.\n\nFRC (FIRST Robotics Competition), lise öğrencilerinin profesyonel mühendisler ve bilim insanlarının rehberliğinde, altı hafta içinde robot tasarlayıp inşa ettiği uluslararası bir yarışmadır.")
                        aboutCard(icon: "server.rack", iconColor: Color(hex: "#4fc3f7"),
                                  title: "The Blue Alliance (TBA)",
                                  body: "The Blue Alliance, FRC topluluğu tarafından geliştirilen açık kaynaklı bir veri platformudur.\n\nBu uygulama, takım ve etkinlik verilerini thebluealliance.com/api/v3 üzerinden çekmektedir.")
                        itobotCard
                        apiSetupCard
                        tbaPoweredBadge
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20).padding(.top, 16)
                }
            }
            .navigationTitle("Hakkında")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Theme Card

    var themeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "paintbrush.fill").font(.title3).foregroundColor(Color(hex: "#ce93d8"))
                Text("Tema").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            }

            HStack(spacing: 10) {
                themeButton(name: "dark", label: "Karanlık", icon: "moon.fill", color: Color(hex: "#1565c0"))
                themeButton(name: "light", label: "Aydınlık", icon: "sun.max.fill", color: Color(hex: "#f9a825"))
                themeButton(name: "system", label: "Sistem", icon: "circle.lefthalf.filled", color: Color(hex: "#4fc3f7"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "#ce93d8").opacity(0.25), lineWidth: 1))
        )
    }

    func themeButton(name: String, label: String, icon: String, color: Color) -> some View {
        let active = theme.currentThemeName == name
        return Button { theme.apply(name) } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(active ? color : .gray)
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(active ? .white : .gray)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(active ? color.opacity(0.15) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: active ? 1.5 : 1))
            )
        }
    }

    // MARK: - Sections

    var appLogoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: "#1565c0"), Color(hex: "#4fc3f7")],
                    startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 88, height: 88)
                Image(systemName: "cpu.fill").font(.system(size: 38)).foregroundColor(.white)
            }
            .shadow(color: Color(hex: "#4fc3f7").opacity(0.4), radius: 20)
            Text("FRC Scout Hub").font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(.white)
            Text("by ITOBOT #6038").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#4fc3f7"))
            Text("v1.0.0").font(.system(size: 11)).foregroundColor(.gray)
        }
        .padding(.top, 20)
    }

    var itobotCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.circle.fill").font(.title3).foregroundColor(Color(hex: "#4fc3f7"))
                Text("ITOBOT — Takım #6038").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            }
            Text("Bayrampaşa, İstanbul, Türkiye").font(.system(size: 12)).foregroundColor(.gray)
            Text("ITO Academy bünyesindeki ITOBOT, 2017 yılında kurulan bir FRC takımıdır. Robotik ve teknolojiye tutkuyla bağlı gençleri bir araya getirerek STEM alanına ilham vermeyi ve Türkiye'de FRC kültürünü yaygınlaştırmayı hedefler.")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.8)).lineSpacing(5)
            Divider().background(Color.white.opacity(0.1))
            Link(destination: URL(string: "https://team6038.com")!) {
                HStack {
                    Image(systemName: "globe"); Text("team6038.com"); Spacer()
                    Image(systemName: "arrow.up.right").font(.caption)
                }
                .font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#4fc3f7"))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#0d1b3e"))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "#4fc3f7").opacity(0.3), lineWidth: 1)))
    }

    var apiSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill").font(.title3).foregroundColor(Color(hex: "#f9a825"))
                Text("API Anahtarı Kurulumu").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            }
            Text("Bu uygulamayı kullanmak için The Blue Alliance'dan ücretsiz bir API anahtarı alın:")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.8)).lineSpacing(4)
            VStack(alignment: .leading, spacing: 8) {
                apiStep(number: "1", text: "thebluealliance.com'a gidin")
                apiStep(number: "2", text: "Ücretsiz hesap oluşturun")
                apiStep(number: "3", text: "Account > Read API Keys kısmından anahtar alın")
                apiStep(number: "4", text: "TBAService.swift dosyasındaki apiKey değişkenini güncelleyin")
            }
            Link(destination: URL(string: "https://www.thebluealliance.com/account")!) {
                HStack {
                    Text("API Anahtarı Al").font(.system(size: 14, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right.circle.fill")
                }
                .foregroundColor(Color(hex: "#f9a825")).padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#f9a825").opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#f9a825").opacity(0.3), lineWidth: 1)))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1)))
    }

    var tbaPoweredBadge: some View {
        Link(destination: URL(string: "https://www.thebluealliance.com")!) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundColor(Color(hex: "#4fc3f7"))
                Text("Powered by The Blue Alliance").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#4fc3f7"))
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundColor(.gray)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#4fc3f7").opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4fc3f7").opacity(0.2), lineWidth: 1)))
        }
    }

    func aboutCard(icon: String, iconColor: Color, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.title3).foregroundColor(iconColor)
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            }
            Text(body).font(.system(size: 13)).foregroundColor(.white.opacity(0.8)).lineSpacing(5)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1)))
    }

    func apiStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#f9a825")).frame(width: 20, height: 20)
                .background(Circle().fill(Color(hex: "#f9a825").opacity(0.15)))
            Text(text).font(.system(size: 12)).foregroundColor(.white.opacity(0.8)).lineSpacing(3)
        }
    }
}

