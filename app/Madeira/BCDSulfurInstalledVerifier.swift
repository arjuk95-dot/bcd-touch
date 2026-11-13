// SPDX-License-Identifier: GPL-3.0-or-later
// Additional permission: Madeira Converter Exception v1, LICENSE-EXCEPTION.md.
import Foundation
import CryptoKit

/// Installed bytes, not live input settings. Call once at session activation,
/// never from a view redraw or input tick. No persistent trust cache is used.
enum BCDSulfurInstalledVerifier {
    struct Proof: Equatable, Sendable {
        var buildVerified: Bool
        /// Exact shipped Windows Hold-default asset. Does not read PlayerPrefs,
        /// prove the currently selected mode, or establish guest sprint state.
        var defaultVerified: Bool
        static let unverified = Proof(buildVerified: false, defaultVerified: false)
    }

    static func verify(executableURL: URL?, verifyShippedDefault: Bool = true) -> Proof {
        guard let executableURL else { return .unverified }
        let executable = executableURL.resolvingSymlinksInPath().standardizedFileURL
        guard executable.lastPathComponent.lowercased() == "sulfur.exe",
              let info = try? executable.resourceValues(forKeys: [.isRegularFileKey]),
              info.isRegularFile == true else { return .unverified }
        let root = executable.deletingLastPathComponent()
        let build = BCDSulfurPack.reviewedFiles.allSatisfy { spec in
            matches(file: root.appendingPathComponent(spec.path), within: root,
                    expectedSize: spec.size, sha256: spec.sha256)
        }
        guard build else { return .unverified }
        let spec = BCDSulfurPack.sprintDefaultsFile
        let defaults = verifyShippedDefault && matches(file: root.appendingPathComponent(spec.path),
            within: root, expectedSize: spec.size, sha256: spec.sha256)
        return Proof(buildVerified: true, defaultVerified: defaults)
    }

    /// Shared by the production verifier and small synthetic host fixtures.
    /// Canonical containment and exact hash/size are all required. A symlink to
    /// another directory, truncation, extra bytes or an I/O failure fails closed.
    static func matches(file: URL, within root: URL, expectedSize: Int, sha256: String) -> Bool {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let file = file.resolvingSymlinksInPath().standardizedFileURL
        guard expectedSize >= 0, expectedSize <= 242_104_512, sha256.count == 64,
              sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
              file.path.hasPrefix(root.path + "/"),
              let info = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              info.isRegularFile == true, info.fileSize == expectedSize,
              let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        var hash = SHA256(), total = 0
        do {
            while let bytes = try handle.read(upToCount: 1_048_576), !bytes.isEmpty {
                guard bytes.count <= expectedSize - total else { return false }
                total += bytes.count
                hash.update(data: bytes)
            }
        } catch { return false }
        return total == expectedSize && hash.finalize().map { String(format: "%02x", $0) }.joined() == sha256
    }
}
