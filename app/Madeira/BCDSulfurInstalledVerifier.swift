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

/// Conservative native utility gate, using this executable's adjacent Unity data.
/// Exact bytes identify reviewed defaults, not player remaps or guest UI state.
enum BCDSkaldUtilityVerifier {
    static func verify(_ executable:URL?) -> Bool {
        guard let executable,executable.lastPathComponent.lowercased().contains("skald"),
              executable.pathExtension.lowercased() == "exe",
              (try? executable.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile) == true else{return false}
        let root=executable.deletingLastPathComponent().resolvingSymlinksInPath()
        let data=root.appendingPathComponent(executable.deletingPathExtension().lastPathComponent+"_Data")
        let specs=[("Managed/SKALDAssembly.dll","a9929c9e7e7f06829692ae7c23df2c147d64ea050bdf18649adbd44e1fbcd075"),("globalgamemanagers","faca117d2bcfacc1ea980de701253fff20b8c7fb93e01b7033a1f3820697f6a8")]
        return specs.allSatisfy { path,hash in
            let file=data.appendingPathComponent(path)
            guard let size=try? file.resourceValues(forKeys:[.fileSizeKey]).fileSize else{return false}
            return BCDSulfurInstalledVerifier.matches(file:file,within:root,expectedSize:size,sha256:hash)
        }
    }
}

/// Only bytes carrying input definitions are read from the large PCK, not all
/// game assets. Both the PCK size and exact project block location are pinned.
enum BCDSpireUtilityVerifier {
    static func verify(_ executable:URL?) -> Bool {
        guard let executable,executable.lastPathComponent.lowercased() == "slaythespire2.exe" else{return false}
        let root=executable.deletingLastPathComponent().resolvingSymlinksInPath()
        let dll=root.appendingPathComponent("data_sts2_windows_x86_64/sts2.dll")
        guard BCDSulfurInstalledVerifier.matches(file:dll,within:root,expectedSize:9757184,sha256:"0861bfa1df347538d932f22d580e75420f08082792eb914e53b4882764acdbe9") else{return false}
        let pck=root.appendingPathComponent("SlayTheSpire2.pck").resolvingSymlinksInPath()
        guard pck.path.hasPrefix(root.path+"/"),
              let info=try? pck.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey]),info.isRegularFile == true,info.fileSize == 1990705700,
              let f=try? FileHandle(forReadingFrom:pck) else{return false}
        defer {try? f.close()}
        do {
            try f.seek(toOffset:1989151520)
            guard let bytes=try f.read(upToCount:24693),bytes.count == 24693 else{return false}
            return SHA256.hash(data:bytes).map {String(format:"%02x",$0)}.joined() == "88bc2e4f6a2627204b20a714cb8746a269c009e48255dcfc7a0eaef9503d2227"
        } catch {return false}
    }
}
