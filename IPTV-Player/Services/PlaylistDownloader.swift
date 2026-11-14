//
//  PlaylistDownloader.swift
//  IPTV-Player
//

import Foundation

enum PlaylistDownloader {
    static func text(from url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 40)
        request.setValue(XtreamClient.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw ResolverError.unreachable("Status \(http.statusCode).")
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw ResolverError.emptyPlaylist
    }
}
