import SwiftUI

struct SplashHomeView: View {
    @State private var animateHeader = false
    @State private var animateCards = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "#0a0e1a"), Color(hex: "#0d1b3e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Section
                        heroSection
                            .opacity(animateHeader ? 1 : 0)
                            .offset(y: animateHeader ? 0 : -30)

                        // FIRST Info Cards
                        firstInfoSection
                            .opacity(animateCards ? 1 : 0)
                            .offset(y: animateCards ? 0 : 40)

                        // ITOBOT Section
                        itobotSection
                            .opacity(animateCards ? 1 : 0)
                            .offset(y: animateCards ? 0 : 40)

                        // Stats Bar
                        statsSection
                            .opacity(animateCards ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) {
                    animateHeader = true
                }
                withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                    animateCards = true
                }
            }
        }
    }

    // MARK: - Hero Section

    var heroSection: some View {
        VStack(spacing: 16) {
            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POWERED BY")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("ITOBOT #6038")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#4fc3f7"))
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#f9a825"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)

            // Main title
            VStack(spacing: 8) {
                Text("FRC")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#4fc3f7"), Color(hex: "#1565c0")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("SCOUT HUB")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(8)

                Text("thebluealliance.com Verisiyle")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#4fc3f7").opacity(0.8))
            }
            .padding(.vertical, 20)

            // Divider line
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.clear, Color(hex: "#4fc3f7"), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 40)
        }
    }

    // MARK: - FIRST Info Section

    var firstInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "trophy.fill", title: "FIRST Robotics Competition Nedir?", color: Color(hex: "#f9a825"))

            Text("FIRST (For Inspiration and Recognition of Science and Technology), lise öğrencilerinin takımlar halinde 6 haftada robot tasarlayıp inşa ettiği, dünyaca ünlü bir mühendislik yarışmasıdır.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(5)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                firstCard(
                    icon: "globe.americas.fill",
                    title: "Küresel",
                    desc: "50+ ülkeden 17.000+ takım",
                    color: Color(hex: "#1565c0")
                )
                firstCard(
                    icon: "wrench.and.screwdriver.fill",
                    title: "6 Hafta",
                    desc: "Tasarım ve inşa süreci",
                    color: Color(hex: "#c62828")
                )
                firstCard(
                    icon: "person.3.fill",
                    title: "Takım Ruhu",
                    desc: "Gracious Professionalism",
                    color: Color(hex: "#2e7d32")
                )
                firstCard(
                    icon: "star.fill",
                    title: "Şampiyona",
                    desc: "Houston & Detroit'te finale",
                    color: Color(hex: "#6a1b9a")
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 28)
    }

    // MARK: - ITOBOT Section

    var itobotSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "cpu.fill", title: "ITOBOT — Takım 6038", color: Color(hex: "#4fc3f7"))

            VStack(spacing: 0) {
                // Team number badge
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("#6038")
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundColor(Color(hex: "#4fc3f7"))
                            VStack(alignment: .leading) {
                                Text("ITOBOT")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Bayrampasa, İstanbul, Türkiye")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }

                        Text("ITO Academy bünyesindeki öğrencilerden oluşan ITOBOT, 2017 yılında kurulan bir FRC takımıdır. Robotik ve teknolojiye tutkuyla bağlı gençleri bir araya getirerek STEM alanına ilham vermeyi hedefler.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#0d1b3e"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#4fc3f7").opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                // Mission chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(["🤖 Robotik", "💡 STEM", "🏆 Yarışma", "🌍 Küresel", "🎓 Eğitim"], id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#4fc3f7"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#4fc3f7").opacity(0.12))
                                        .overlay(Capsule().stroke(Color(hex: "#4fc3f7").opacity(0.3), lineWidth: 1))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
            }
        }
        .padding(.top, 28)
    }

    // MARK: - Stats Section

    var statsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "chart.bar.fill", title: "FRC'de Türkiye", color: Color(hex: "#ef5350"))

            HStack(spacing: 12) {
                statBubble(value: "80+", label: "TR Takımı", color: Color(hex: "#ef5350"))
                statBubble(value: "2003", label: "İlk Yıl", color: Color(hex: "#f9a825"))
                statBubble(value: "5", label: "Bölgesel", color: Color(hex: "#4caf50"))
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 28)
    }

    // MARK: - Helpers

    func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
    }

    func firstCard(icon: String, title: String, desc: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(desc)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

