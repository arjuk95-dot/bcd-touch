// Actual production file/hash verifier, synthetic bytes only; no game data.
import Foundation
func checkSulfurInstalledVerifier() throws {
    let manager = FileManager.default
    let base = manager.temporaryDirectory.appendingPathComponent("bcd-sulfur-proof-" + UUID().uuidString)
    let root = base.appendingPathComponent("game")
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: base) }
    assert(!BCDSkaldUtilityVerifier.verify(nil))
    let skald=root.appendingPathComponent("SKALD.exe")
    try Data("fixture".utf8).write(to:skald)
    assert(!BCDSkaldUtilityVerifier.verify(skald), "Missing installed proofs must disable native utilities")
    let data=root.appendingPathComponent("SKALD_Data/Managed")
    try manager.createDirectory(at:data,withIntermediateDirectories:true)
    try Data("not reviewed assembly".utf8).write(to:data.appendingPathComponent("SKALDAssembly.dll"))
    try Data("not reviewed inputs".utf8).write(to:data.deletingLastPathComponent().appendingPathComponent("globalgamemanagers"))
    assert(!BCDSkaldUtilityVerifier.verify(skald), "Unreviewed exact files must fail closed")
    let file = root.appendingPathComponent("fixture.bin")
    let outside = base.appendingPathComponent("outside.bin")
    let bytes = Data("abc".utf8)
    let digest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    try bytes.write(to: file); try bytes.write(to: outside)
    func check(_ candidate: URL, _ size: Int = 3, _ hash: String? = nil) -> Bool {
        BCDSulfurInstalledVerifier.matches(file: candidate, within: root, expectedSize: size, sha256: hash ?? digest)
    }
    assert(check(file))
    assert(!check(file, 2) && !check(file, 4) && !check(file, -1) && !check(file, 242_104_513))
    assert(!check(file, 3, String(repeating: "0", count: 64)) && !check(file, 3, "not-a-hash"))
    assert(!check(root) && !check(outside))
    let escape = root.appendingPathComponent("escape.bin")
    try manager.createSymbolicLink(at: escape, withDestinationURL: outside)
    assert(!check(escape), "symlink outside the game must not satisfy proof")
    try Data("abd".utf8).write(to: file)
    assert(!check(file), "same size but changed content fails")
    let executable = root.appendingPathComponent("Sulfur.exe")
    try Data().write(to: executable)
    assert(BCDSulfurInstalledVerifier.verify(executableURL: nil) == .unverified)
    assert(BCDSulfurInstalledVerifier.verify(executableURL: executable) == .unverified,
           "a named executable without all exact DLLs is not a reviewed build")
    print("PASS: production SULFUR verifier exact hash/size, containment, symlink, absent-build and corrupted-content checks")
}
