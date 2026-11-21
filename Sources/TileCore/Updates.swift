import Foundation
import CryptoKit

public struct SemanticVersion: Comparable, Hashable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]
    public init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let pattern = #"\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?\z"#
        guard text.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let precedence = text.split(separator: "+", maxSplits: 1)[0]
        let parts = precedence.split(separator: "-", maxSplits: 1)
        let numbers = parts[0].split(separator: ".")
        guard numbers.count == 3, let major = Int(numbers[0]), let minor = Int(numbers[1]), let patch = Int(numbers[2]) else { return nil }
        let suffix = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
        for component in suffix where Self.isNumber(component) {
            if component.count > 1 && component.first == "0" { return nil }
        }
        self.major = major; self.minor = minor; self.patch = patch; prerelease = suffix
    }
    private static func isNumber(_ value: String) -> Bool { value.utf8.allSatisfy { (48...57).contains($0) } }
    public static func < (a: Self, b: Self) -> Bool {
        if (a.major,a.minor,a.patch) != (b.major,b.minor,b.patch) { return (a.major,a.minor,a.patch) < (b.major,b.minor,b.patch) }
        if a.prerelease.isEmpty { return false }
        if b.prerelease.isEmpty { return true }
        for (left,right) in zip(a.prerelease,b.prerelease) where left != right {
            let ln = isNumber(left), rn = isNumber(right)
            if ln != rn { return ln }
            if ln && left.count != right.count { return left.count < right.count }
            return left < right
        }
        return a.prerelease.count < b.prerelease.count
    }
}

public struct GitHubAsset: Decodable, Sendable {
    public let name: String
    public let url: String
    public let size: Int64
    public let state: String
    public let digest: String?
    enum CodingKeys: String, CodingKey { case name, size, state, digest; case url = "browser_download_url" }
    public init(name: String, url: String, size: Int64, state: String, digest: String?) { self.name=name; self.url=url; self.size=size; self.state=state; self.digest=digest }
}
public struct GitHubRelease: Decodable, Sendable {
    public let tag: String
    public let draft: Bool
    public let prerelease: Bool
    public let notes: String?
    public let assets: [GitHubAsset]
    enum CodingKeys: String, CodingKey { case draft, prerelease, assets; case tag = "tag_name"; case notes = "body" }
    public init(tag: String, draft: Bool, prerelease: Bool, notes: String?, assets: [GitHubAsset]) { self.tag=tag; self.draft=draft; self.prerelease=prerelease; self.notes=notes; self.assets=assets }
}
public struct UpdateCandidate: Sendable, Equatable {
    public let tag: String
    public let notes: String
    public let fileName: String
    public let url: URL
    public let size: Int64
    public let sha256: String
    public var releasePage: URL { URL(string: "https://github.com/\(ReleasePolicy.repository)/releases/tag/\(tag)")! }
}
public enum ReleasePolicy {
    public static let repository = "hckmseduardo/MacCosmicTile"
    public static let maximumBytes: Int64 = 512 * 1024 * 1024
    public static func select(_ releases: [GitHubRelease], current: String, architecture: String, includePreviews: Bool = true) -> UpdateCandidate? {
        guard let installed = SemanticVersion(current), ["arm64","x86_64"].contains(architecture) else { return nil }
        let sorted = releases.compactMap { release -> (GitHubRelease,SemanticVersion)? in
            guard !release.draft, includePreviews || !release.prerelease, let version = SemanticVersion(release.tag), version > installed else { return nil }
            return (release,version)
        }.sorted { $0.1 > $1.1 }
        for (release,_) in sorted {
            let name = "CosmicTile-\(release.tag)-macOS-\(architecture).zip"
            for asset in release.assets where asset.name == name && asset.state == "uploaded" && asset.size > 0 && asset.size <= maximumBytes {
                guard let components = URLComponents(string: asset.url), components.scheme == "https", components.host == "github.com", components.port == nil,
                      components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
                      components.path == "/\(repository)/releases/download/\(release.tag)/\(name)",
                      let url = components.url, let digest = asset.digest, digest.hasPrefix("sha256:") else { continue }
                let hex = String(digest.dropFirst(7)).lowercased()
                guard hex.count == 64, hex.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { continue }
                return UpdateCandidate(tag: release.tag, notes: release.notes ?? "", fileName: name, url: url, size: asset.size, sha256: hex)
            }
        }
        return nil
    }
}

/// The only state transition returning download work requires an explicit approval.
public struct UpdateFlow: Sendable {
    private enum Phase: Sendable { case idle, checking, available(UpdateCandidate), downloading }
    private var phase: Phase = .idle
    public init() {}
    public var isChecking: Bool { if case .checking = phase { true } else { false } }
    public var isDownloading: Bool { if case .downloading = phase { true } else { false } }
    public mutating func beginCheck() -> Bool {
        guard case .idle = phase else { return false }
        phase = .checking; return true
    }
    public mutating func completeCheck(_ offer: UpdateCandidate?) { phase = offer.map(Phase.available) ?? .idle }
    public mutating func respond(approved: Bool) -> UpdateCandidate? {
        guard case .available(let candidate) = phase else { return nil }
        phase = approved ? .downloading : .idle
        return approved ? candidate : nil
    }
    public mutating func finish() { phase = .idle }
}

public enum UpdateFailure: Error, LocalizedError, Sendable {
    case invalidResponse, wrongSize, wrongDigest, busy
    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "GitHub returned an unexpected response. Please try again later."
        case .wrongSize: "The download size did not match the release metadata. The file was discarded."
        case .wrongDigest: "The download checksum did not match GitHub's SHA-256 digest. The file was discarded."
        case .busy: "An update operation is already in progress."
        }
    }
}
public enum UpdateIntegrity {
    public static func verify(_ file: URL, expectedSize: Int64, sha256: String) throws {
        guard expectedSize > 0, expectedSize <= ReleasePolicy.maximumBytes else { throw UpdateFailure.wrongSize }
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var digest = SHA256(); var bytes: Int64 = 0
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            bytes += Int64(data.count)
            guard bytes <= expectedSize else { throw UpdateFailure.wrongSize }
            digest.update(data: data)
        }
        guard bytes == expectedSize else { throw UpdateFailure.wrongSize }
        let actual = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == sha256.lowercased() else { throw UpdateFailure.wrongDigest }
    }
}

public enum UpdateNotes {
    public static func summary(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let excerpt = lines.prefix(12).joined(separator: "\n")
        let limited = String(excerpt.prefix(1200))
        return limited + (lines.count > 12 || excerpt.count > 1200 ? "\n…" : "")
    }
}
