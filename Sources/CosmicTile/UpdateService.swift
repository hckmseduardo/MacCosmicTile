import Foundation
import TileCore

struct UpdateService: Sendable {
    static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }
    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("CosmicTile (macOS)", forHTTPHeaderField: "User-Agent")
        return request
    }
    func check(current: String) async throws -> UpdateCandidate? {
        let url = URL(string: "https://api.github.com/repos/\(ReleasePolicy.repository)/releases?per_page=100")!
        var request = request(url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let session = makeSession(); defer { session.invalidateAndCancel() }
        let (bytes,response) = try await session.bytes(for: request)
        let limit = 16 * 1024 * 1024
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= Int64(limit) else { throw UpdateFailure.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw UpdateFailure.invalidResponse }
            data.append(byte)
        }
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        return ReleasePolicy.select(releases, current: current, architecture: Self.architecture)
    }
    /// Called only after UpdateFlow returns an explicitly authorized candidate.
    func download(_ candidate: UpdateCandidate, to target: URL) async throws {
        let manager = FileManager.default
        let partial = target.appendingPathExtension("part")
        defer { try? manager.removeItem(at: partial) }
        let session = makeSession(); defer { session.invalidateAndCancel() }
        var downloadRequest = request(candidate.url)
        downloadRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let (bytes,response) = try await session.bytes(for: downloadRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw UpdateFailure.invalidResponse }
        guard response.expectedContentLength < 0 || response.expectedContentLength == candidate.size else { throw UpdateFailure.wrongSize }
        guard manager.createFile(atPath: partial.path, contents: nil) else { throw UpdateFailure.invalidResponse }
        let file = try FileHandle(forWritingTo: partial); defer { try? file.close() }
        var buffer = Data(); buffer.reserveCapacity(65536)
        var received: Int64 = 0
        for try await byte in bytes {
            received += 1
            guard received <= candidate.size && received <= ReleasePolicy.maximumBytes else { throw UpdateFailure.wrongSize }
            buffer.append(byte)
            if buffer.count == 65536 { try file.write(contentsOf: buffer); buffer.removeAll(keepingCapacity: true) }
        }
        if !buffer.isEmpty { try file.write(contentsOf: buffer) }
        try file.synchronize(); try file.close()
        guard received == candidate.size else { throw UpdateFailure.wrongSize }
        try UpdateIntegrity.verify(partial, expectedSize: candidate.size, sha256: candidate.sha256)
        // moveItem fails rather than overwriting a destination created in the meantime.
        try manager.moveItem(at: partial, to: target)
    }
}
