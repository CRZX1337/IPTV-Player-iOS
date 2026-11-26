//
//  Components.swift
//  IPTV-Player
//

import SwiftUI

/// The glass switch the sign-in screen uses to pick a service kind.
struct GlassSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.26, extraBounce: 0.05)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.blue.opacity(0.9))
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

/// One labelled text field inside the glass card.
struct FieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var isSecure = false

    @State private var revealed = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Group {
                    if isSecure && !revealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.callout)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
            }

            if isSecure {
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

/// The initials a channel shows while its logo is missing or still loading.
enum ChannelInitials {
    private static let qualitySuffixes: Set<String> = ["HD", "FHD", "UHD", "SD", "4K", "8K", "HEVC"]

    static func of(_ name: String) -> String {
        let words = name
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "|" || $0 == "." || $0 == ":" })
            .map(String.init)
            .filter { !qualitySuffixes.contains($0.uppercased()) }

        let letters = words.prefix(2).compactMap(\.first)
        if letters.count >= 2 {
            return String(letters).uppercased()
        }
        if let word = words.first {
            return String(word.prefix(2)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

/// Channel artwork in the 16:9 shape a logo tile has.
struct ChannelArtwork: View {
    let channel: Channel
    var cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay { logo }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var logo: some View {
        if let url = channel.logoURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Text(ChannelInitials.of(channel.name))
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

/// One channel as a row: a wide logo tile, the name and the category it lives in.
struct ChannelRow: View {
    let channel: Channel
    var category: String?
    var isFavourite = false

    var body: some View {
        HStack(spacing: 14) {
            ChannelArtwork(channel: channel, cornerRadius: 14)
                .frame(width: 104)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if isFavourite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                ChannelLiveLine(category: category)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

/// One channel as a tile in the two column grid.
struct ChannelGridTile: View {
    let channel: Channel
    var category: String?
    var isFavourite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChannelArtwork(channel: channel, cornerRadius: 20)

            HStack(spacing: 6) {
                Text(channel.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if isFavourite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            ChannelLiveLine(category: category)
        }
        .contentShape(Rectangle())
    }
}

/// The red dot with "Live" and the category, under a channel's name.
struct ChannelLiveLine: View {
    var category: String?

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)

            Text("Live")
                .foregroundStyle(.secondary)

            if let category, !category.isEmpty {
                Text("·")
                    .foregroundStyle(.tertiary)

                Text(category)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.caption)
    }
}

/// One channel tile in the Recently Watched row.
struct RecentlyWatchedCard: View {
    let channel: Channel

    var body: some View {
        VStack(spacing: 8) {
            ChannelArtwork(channel: channel, cornerRadius: 14)
                .frame(width: 96)

            Text(channel.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 96)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Fades and lifts a row or tile in when it first appears, a little later for each one.
struct SoftAppear: ViewModifier {
    let index: Int

    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
            .onAppear {
                guard !visible else { return }
                let delay = min(Double(index) * 0.03, 0.3)
                withAnimation(.easeOut(duration: 0.32).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func softAppear(index: Int) -> some View {
        modifier(SoftAppear(index: index))
    }
}
