//
//  AppBackground.swift
//  IPTV-Player
//

import SwiftUI

/// A blurred wall of TV tiles, the quiet stage the glass surfaces sit on.
struct AppBackground: View {
    private let tiles: [Color] = [
        Color(red: 0.12, green: 0.22, blue: 0.35),
        Color(red: 0.30, green: 0.18, blue: 0.12),
        Color(red: 0.10, green: 0.28, blue: 0.26),
        Color(red: 0.26, green: 0.12, blue: 0.20),
        Color(red: 0.16, green: 0.16, blue: 0.24),
        Color(red: 0.32, green: 0.26, blue: 0.12),
        Color(red: 0.08, green: 0.14, blue: 0.24),
        Color(red: 0.22, green: 0.10, blue: 0.10)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.08)

            GeometryReader { proxy in
                tileWall(in: proxy.size)
            }
            .opacity(0.9)

            LinearGradient(
                colors: [Color.black.opacity(0.30), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func tileWall(in size: CGSize) -> some View {
        let columns = 4
        let spacing: CGFloat = 8
        let tileWidth = max((size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns), 40)
        let tileHeight = tileWidth * 0.62
        let rows = Int(ceil((size.height + 140) / (tileHeight + spacing)))

        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tiles[(row * columns + column) % tiles.count])
                            .frame(width: tileWidth, height: tileHeight)
                    }
                }
            }
        }
        .padding(spacing)
        .blur(radius: 26)
    }
}

#Preview {
    AppBackground()
}
