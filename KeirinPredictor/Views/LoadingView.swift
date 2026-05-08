import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var dataLoader: DataLoader
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Color(hex: "#0A0E27").ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#FFD700").opacity(0.2), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color(hex: "#FFD700"), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(angle))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: angle)
                }

                Text("KEIRIN PREDICTOR")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFD700"))

                Text("データ読み込み中...")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .onAppear {
            angle = 360
            dataLoader.load()
        }
    }
}
