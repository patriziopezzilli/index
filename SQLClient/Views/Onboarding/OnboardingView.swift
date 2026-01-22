import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var isAnimating = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "cylinder.fill",
            title: "Welcome to SQL Client",
            description: "A powerful, beautiful SQL client designed for iPad and iPhone. Connect to multiple databases with ease.",
            color: .blue
        ),
        OnboardingPage(
            icon: "bolt.fill",
            title: "Multiple Database Support",
            description: "Connect to PostgreSQL, MySQL, SQLite, and SQL Server. All your databases in one place.",
            color: .orange
        ),
        OnboardingPage(
            icon: "text.alignleft",
            title: "Powerful SQL Editor",
            description: "Write and execute queries with syntax highlighting and autocomplete. View results in a clean, organized way.",
            color: .green
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Beautiful & Minimal",
            description: "A carefully crafted interface that gets out of your way. Focus on what matters: your data.",
            color: .purple
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isAnimating: $isAnimating)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { oldValue, newValue in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isAnimating = true
                    }
                }

                VStack(spacing: 30) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? pages[index].color : Color.white.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .padding(.bottom, 20)

                    if currentPage == pages.count - 1 {
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                appState.completeOnboarding()
                            }
                        }) {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.white)
                                )
                        }
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isAnimating = true
                }
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var isAnimating: Bool

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .scaleEffect(isAnimating ? 1 : 0.5)

                Image(systemName: page.icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(page.color)
                    .scaleEffect(isAnimating ? 1 : 0.5)
            }
            .frame(height: 250)

            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)

                Text(page.description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }

            Spacer()
            Spacer()
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: isAnimating)
    }
}
