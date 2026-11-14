//
//  AppBackground.swift
//  IPTV-Player
//

import SwiftUI

/// A blurred wall of TV tiles, the quiet stage the glass surfaces sit on.
struct AppBackground: View {
    private let tiles: [Color] = [
        Color(red: 0.18, green: 0.34, blue: 0.55),
        Color(red: 0.48, green: 0.28, blue: 0.16),
        Color(red: 0.12, green: 0.42, blue: 0.42),
        Color(red: 0.42, green: 0.18, blue: 0.32),
        Color(red: 0.24, green: 0.26, blue: 0.38),
        Color(red: 0.52, green: 0.40, blue: 0.16),
        Color(red: 0.10, green: 0.24, blue: 0.42),
        Color(red: 0.38, green: 0.16, blue: 0.16)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.08)

            GeometryReader { proxy in
                tileWall(in: proxy.size)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.black.opacity(0.62)],
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
        .blur(radius: 22)
    }
}

#Preview {
    AppBackground()
}
