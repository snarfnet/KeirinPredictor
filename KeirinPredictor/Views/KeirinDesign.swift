import SwiftUI

enum KeirinUI {
    static let ink = Color(hex: "#05070D")
    static let surface = Color(hex: "#0B1018")
    static let panel = Color(hex: "#101722")
    static let panelBright = Color(hex: "#172231")
    static let gold = Color(hex: "#F6C343")
    static let red = Color(hex: "#FF3B30")
    static let cyan = Color(hex: "#13D8FF")
    static let green = Color(hex: "#49E37A")
    static let muted = Color.white.opacity(0.58)
    static let scrollBottomPadding: CGFloat = 24
    static let lightBackground = Color(hex: "#050912")
    static let paper = Color(hex: "#F3E7C8")
    static let paperDark = Color(hex: "#D7C59A")
    static let deepGold = Color(hex: "#D7A842")

    static var actionGradient: LinearGradient {
        LinearGradient(
            colors: [red, Color(hex: "#FF7A18"), gold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var coolGradient: LinearGradient {
        LinearGradient(
            colors: [cyan.opacity(0.9), Color(hex: "#2155FF").opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CompactAwareScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 390
            let sidePadding: CGFloat = compact ? 18 : 20
            let leftInset = proxy.safeAreaInsets.leading + sidePadding
            let rightInset = proxy.safeAreaInsets.trailing + sidePadding
            let contentWidth = max(0, proxy.size.width - leftInset - rightInset)

            ScrollView {
                content
                    .frame(width: contentWidth, alignment: .topLeading)
                    .padding(.leading, leftInset)
                    .padding(.trailing, rightInset)
                    .padding(.top, compact ? 14 : 18)
                    .padding(.bottom, KeirinUI.scrollBottomPadding)
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
        }
    }
}

struct FixedTopAdView: View {
    var body: some View {
        VStack(spacing: 0) {
            BannerAdView()
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(.white)
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
        .background(.white)
    }
}

struct AdaptiveStack<Content: View>: View {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 8
    let content: Content

    init(
        horizontalSpacing: CGFloat = 10,
        verticalSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: horizontalSpacing) {
                content
            }

            VStack(alignment: .leading, spacing: verticalSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KeirinStageBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)

            ZStack {
                KeirinUI.ink

                Image("HeaderBg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(0.58)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color(hex: "#02050A").opacity(0.42),
                        Color(hex: "#06101C").opacity(0.82),
                        Color(hex: "#02050A")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 18) {
                    ForEach(0..<22, id: \.self) { _ in
                        Rectangle()
                            .fill(KeirinUI.gold.opacity(0.055))
                            .frame(height: 1)
                    }
                }
                .rotationEffect(.degrees(-11))
                .scaleEffect(1.35)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                KeirinUI.gold.opacity(0.16),
                                KeirinUI.red.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 1.25, height: 2)
                    .rotationEffect(.degrees(-18))
                    .offset(y: -height * 0.18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 18
    var borderColor: Color = Color.white.opacity(0.10)
    let content: Content

    init(
        cornerRadius: CGFloat = 18,
        borderColor: Color = Color.white.opacity(0.10),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(UIScreen.main.bounds.width < 390 ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [KeirinUI.panelBright.opacity(0.92), KeirinUI.panel.opacity(0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }
}

struct RacingPanel<Content: View>: View {
    var accent: Color = KeirinUI.red
    var cornerRadius: CGFloat = 8
    let content: Content

    init(
        accent: Color = KeirinUI.red,
        cornerRadius: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(UIScreen.main.bounds.width < 390 ? 11 : 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [KeirinUI.paper, Color(hex: "#E8D7AF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accent, KeirinUI.gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(.vertical, 8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(KeirinUI.gold.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.26), radius: 14, x: 0, y: 8)
    }
}

struct RacingPrimaryButtonLabel: View {
    let title: String
    var icon: String = "bolt.fill"
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
            }

            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .background(
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(hex: "#111111"), Color(hex: "#272727")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [KeirinUI.red, KeirinUI.gold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeirinUI.gold.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 8)
    }
}

struct RacingMetricBox: View {
    let title: String
    let value: String
    var color: Color = KeirinUI.red

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#111111").opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(color)
                .frame(height: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }
}

struct RacingIconButtonLabel: View {
    let icon: String
    var color: Color = Color(hex: "#111111")

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .black))
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(KeirinUI.gold.opacity(0.32), lineWidth: 1)
            )
    }
}

struct LaneBadge: View {
    let number: Int
    var size: CGFloat = 30

    var body: some View {
        Text("\(number)")
            .font(.system(size: size * 0.46, weight: .black, design: .rounded))
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(wakuColor(number))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
    }

    private var foreground: Color {
        [2, 3, 4, 6, 7, 8].contains(number) ? .white : .black
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    var color: Color = KeirinUI.cyan

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.42))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct MetricPillRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) {
                content
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 7)],
                alignment: .leading,
                spacing: 7
            ) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProbabilityBar: View {
    let value: Double
    var color: Color = KeirinUI.cyan

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, KeirinUI.gold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}
