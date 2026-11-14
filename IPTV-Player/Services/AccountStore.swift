//
//  AccountStore.swift
//  IPTV-Player
//

import Foundation
import SwiftUI

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var account: Account?

    private let storageKey = "service.account"

    init() {
        if let data = KeychainStore.load(key: storageKey),
           let saved = try? JSONDecoder().decode(Account.self, from: data) {
            account = saved
        }
    }

    func signIn(_ account: Account) throws {
        let data = try JSONEncoder().encode(account)
        try KeychainStore.save(data, key: storageKey)
        self.account = account
    }

    func signOut() {
        KeychainStore.delete(key: storageKey)
        account = nil
    }
}
