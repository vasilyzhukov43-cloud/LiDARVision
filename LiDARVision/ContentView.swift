
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = LiDARScanner()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("LiDAR Vision")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(scanner.status)
                    .font(.subheadline)
                    .foregroundStyle(.green)

                PointCloudView(points: scanner.points)
                    .frame(maxWidth: .infinity)
                    .frame(height: 430)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Точек: \(scanner.points.count)")
                    .foregroundStyle(.white)

                Button {
                    if scanner.isScanning {
                        scanner.stopScanning()
                    } else {
                        scanner.startScanning()
                    }
                } label: {
                    Text(scanner.isScanning
                         ? "ОСТАНОВИТЬ СКАНИРОВАНИЕ"
                         : "НАЧАТЬ СКАНИРОВАНИЕ")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
    }
}
