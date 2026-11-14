//
//  AccountResolver.swift
//  IPTV-Player
//

import Foundation

enum ResolverError: LocalizedError {
    case badAddress
    case emptyPlaylist
    case unreachable(String)

    var errorDescription: String? {
        switch self {
        case .badAddress:
            return "That doesn't look like a valid address."
        case .emptyPlaylist:
            return "The playlist is empty or not readable."
        case .unreachable(let detail):
            return detail.isEmpty ? "The server cannot be reached." : "Cannot reach the server. \(detail)"
        }
    }
}

/// Turns what the user typed into a working account, trying both plain HTTP and HTTPS.
enum AccountResolver {
    static func xtream(server: String, username: String, password: String) async throws -> Account {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw XtreamClient.Failure.invalidCredentials }
        guard let normalized = normalize(server) else { throw ResolverError.badAddress }

        var lastError: Error?
        for candidate in schemeVariants(normalized) {
            guard let url = URL(string: candidate) else { continue }
            let client = XtreamClient(baseURL: url, username: name, password: password)
            do {
                try await client.authenticate()
                return Account(
                    kind: .xtream,
                    server: url.absoluteString,
                    username: name,
                    password: password,
                    displayName: url.host ?? name
                )
            } catch let failure as XtreamClient.Failure {
                throw failure
            } catch {
                lastError = error
            }
        }
        throw ResolverError.unreachable(describe(lastError))
    }

    static func playlist(urlString: String) async throws -> (account: Account, groups: [ChannelGroup]) {
        guard let normalized = normalize(urlString) else { throw ResolverError.badAddress }

        var lastError: Error?
        for candidate in schemeVariants(normalized) {
            guard let url = URL(string: candidate) else { continue }
            do {
                let text = try await PlaylistDownloader.text(from: url)
                let groups = M3UParser.parse(text)
                guard !groups.isEmpty else { throw ResolverError.emptyPlaylist }

                let account = Account(
                    kind: .m3u,
                    server: url.absoluteString,
                    username: "",
                    password: "",
                    displayName: url.host ?? "Playlist"
                )
                return (account, groups)
            } catch let error as ResolverError {
                throw error
            } catch {
                lastError = error
            }
        }
        throw ResolverError.unreachable(describe(lastError))
    }

    // MARK: - Address handling

    static func normalize(_ raw: String) -> String? {
        var text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return nil }

        let lowered = text.lowercased()
        if !lowered.hasPrefix("http://") && !lowered.hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") {
            text.removeLast()
        }
        if let range = text.lowercased().range(of: "/player_api.php") {
            text = String(text[text.startIndex..<range.lowerBound])
        }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return text
    }

    static func schemeVariants(_ address: String) -> [String] {
        let lowered = address.lowercased()
        if lowered.hasPrefix("https://") {
            return [address, "http://" + String(address.dropFirst(8))]
        }
        if lowered.hasPrefix("http://") {
            return [address, "https://" + String(address.dropFirst(7))]
        }
        return [address]
    }

    private static func describe(_ error: Error?) -> String {
        guard let error else { return "" }
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return error.localizedDescription
    }
}
