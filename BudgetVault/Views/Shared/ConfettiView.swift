import SwiftUI

/// Reusable confetti/coin shower overlay. Trigger by setting `isActive = true`.
struct ConfettiView: View {
    let isActive: Bool
    var style: Style = .confetti
    var particleCount: Int = 40
    var duration: Double = 2.5

    enum Style {
        case confetti
        case coins
    }

    @State private var particles: [Particle] = []
    @State private var animationPhase: Double = 0

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat          // 0...1 horizontal position
        let delay: Double       // animation delay
        let size: CGFloat
        let color: Color
        let rotation: Double
        let speed: Double       // fall speed multiplier
        let wobble: CGFloat     // horizontal wobble amplitude
    }

    private static let confettiColors: [Color] = [
        Color(hex: "#FBBF24"), // amber
        Color(hex: "#2563EB"), // blue
        Color(hex: "#10B981"), // green
        Color(hex: "#F43F5E"), // rose
        Color(hex: "#8B5CF6"), // purple
        Color(hex: "#FB923C"), // orange
    ]

    var body: some View {
        if isActive {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince1970 - animationPhase

                    for particle in particles {
                        let t = (elapsed - particle.delay) / duration
                        guard t > 0 && t < 1 else { continue }

                        let x = particle.x * size.width + sin(t * .pi * 3) * particle.wobble
                        let y = -20 + t * (size.height + 40) * particle.speed
                        let opacity = t < 0.1 ? t / 0.1 : (t > 0.7 ? (1 - t) / 0.3 : 1.0)
                        let rotation = Angle.degrees(particle.rotation + t * 720)
                        let scale = t < 0.1 ? t / 0.1 : (t > 0.8 ? 1.0 - (t - 0.8) * 2.5 : 1.0)

                        context.opacity = opacity
                        context.translateBy(x: x, y: y)
                        context.rotate(by: rotation)
                        context.scaleBy(x: scale, y: scale)

                        switch style {
                        case .confetti:
                            let rect = CGRect(x: -particle.size / 2, y: -particle.size / 2,
                                              width: particle.size, height: particle.size * 0.6)
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 1.5),
                                with: .color(particle.color)
                            )
                        case .coins:
                            let text = Text("🪙").font(.system(size: particle.size))
                            context.draw(text, at: .zero)
                        }

                        // Reset transforms
                        context.scaleBy(x: 1 / scale, y: 1 / scale)
                        context.rotate(by: -rotation)
                        context.translateBy(x: -x, y: -y)
                        context.opacity = 1
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear {
                animationPhase = Date().timeIntervalSince1970
                particles = (0..<particleCount).map { _ in
                    Particle(
                        x: CGFloat.random(in: 0.05...0.95),
                        delay: Double.random(in: 0...0.4),
                        size: style == .coins ? CGFloat.random(in: 14...20) : CGFloat.random(in: 6...12),
                        color: Self.confettiColors.randomElement()!,
                        rotation: Double.random(in: 0...360),
                        speed: Double.random(in: 0.7...1.3),
                        wobble: CGFloat.random(in: 10...30)
                    )
                }
            }
        }
    }
}

/// Milestone celebration card shown as a sheet for streak milestones
struct StreakMilestoneView: View {
    let milestone: Int
    let onDismiss: () -> Void

    @State private var showConfetti = false

    private var title: String {
        switch milestone {
        case 7: return "Week Warrior!"
        case 30: return "Monthly Master!"
        case 100: return "Century Club!"
        default: return "Milestone!"
        }
    }

    private var message: String {
        switch milestone {
        case 7: return "You've logged expenses every day for a week. Keep the momentum going!"
        case 30: return "A full month of consistent budgeting. You're building a powerful financial habit."
        case 100: return "100 days of tracking. You're in an elite group of budgeters. Incredible discipline."
        default: return "Amazing streak! Keep it going."
        }
    }

    private var badgeEmoji: String {
        milestone >= 100 ? "👑" : (milestone >= 30 ? "🏆" : "🔥")
    }

    private var badgeGradient: [Color] {
        switch milestone {
        case 100...: return [Color(hex: "#FFD700"), Color(hex: "#DAA520")]
        case 30...: return [Color(hex: "#C0C0C0"), Color(hex: "#808080")]
        default: return [Color(hex: "#FBBF24"), Color(hex: "#D97706")]
        }
    }

    private var accentColor: Color {
        switch milestone {
        case 100...: return Color(hex: "#FFD700")
        case 30...: return Color(hex: "#C0C0C0")
        default: return Color(hex: "#FBBF24")
        }
    }

    var body: some View {
        ZStack {
            BudgetVaultTheme.navyDark.ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacingLG) {
                Spacer()

                // Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: badgeGradient.map { $0.opacity(0.15) },
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(
                            Circle().strokeBorder(accentColor.opacity(0.4), lineWidth: 2)
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: accentColor.opacity(0.2), radius: 20)

                    Text(badgeEmoji)
                        .font(.system(size: 36))
                }

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("\(milestone)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(accentColor)

                Text("day logging streak")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text(milestone >= 100 ? "Legendary" : (milestone >= 30 ? "Incredible" : "Keep Going"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: badgeGradient, startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                        )
                }
                .accessibilityHint("Dismisses this celebration")
                .padding(.horizontal, BudgetVaultTheme.spacing2XL)
                .padding(.bottom, BudgetVaultTheme.spacingPage)
            }

            ConfettiView(isActive: showConfetti, style: .coins, particleCount: 30, duration: 3.0)
        }
        .onAppear {
            HapticManager.notification(.success)
            showConfetti = true
        }
    }
}
