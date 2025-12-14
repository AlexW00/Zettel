//
//  FolderAccessManager.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Foundation

enum FolderAccessManager {
    @discardableResult
    static func withAccess<T>(to bookmarkData: Data, _ body: (URL) throws -> T) throws -> T {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(unimpErr), userInfo: [NSLocalizedDescriptionKey: "Security-scoped bookmark is stale."])
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body(url)
    }

    static func withAccessAsync<T>(to bookmarkData: Data, _ body: @escaping (URL) async throws -> T) async throws -> T {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(unimpErr), userInfo: [NSLocalizedDescriptionKey: "Security-scoped bookmark is stale."])
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await body(url)
    }

    static func withAccessAsyncIfNeeded<T>(to bookmarkData: Data?, fallbackURL: URL?, _ body: (URL) throws -> T) throws -> T {
        if let bookmarkData {
            return try withAccess(to: bookmarkData, body)
        } else if let fallbackURL {
            return try body(fallbackURL)
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errAuthorizationDenied), userInfo: [NSLocalizedDescriptionKey: "No accessible folder available."])
        }
    }
}
