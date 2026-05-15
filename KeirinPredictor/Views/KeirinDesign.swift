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
    static let scrollBottomPadding: CGFloat = 84

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
                    .padding(.top, compact ? 8 : 12)
                    .padding(.bottom, KeirinUI.scrollBottomPadding)
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
        }
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

                LinearGradient(
                    colors: [
                        Color(hex: "#101827"),
                        Color(hex: "#05070D"),
                        Color(hex: "#120A0C")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 22) {
                    ForEach(0..<18, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.035))
                            .frame(height: 1)
                    }
                }
                .rotationEffect(.degrees(-8))
                .scaleEffect(1.35)

                Circle()
                    .stroke(KeirinUI.cyan.opacity(0.11), lineWidth: 32)
                    .frame(width: min(520, width * 1.35), height: min(300, width * 0.78))
                    .offset(x: width * 0.28, y: -height * 0.22)

                Circle()
                    .stroke(KeirinUI.red.opacity(0.10), lineWidth: 24)
                    .frame(width: min(420, width * 1.12), height: min(250, width * 0.67))
                    .offset(x: -width * 0.35, y: height * 0.56)
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
