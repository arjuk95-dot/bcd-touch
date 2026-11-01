// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001, 2026-11-01. Codex credentials stay on the desktop.
import Combine
import CryptoKit
import Foundation
import SwiftUI
import UIKit

@MainActor final class BCDPackStore: ObservableObject {
    static let shared = BCDPackStore()
    struct Request: Codable {
        var version = 1
        var identity: BCDControlPack.Identity
        var title: String
        var bindings: [String: String]
        var requirements: [String: String]
    }
    struct Job: Codable {
        var request: Request
        var state = "queued"
        var attempts = 0
        var retryAfter = Date.distantPast
    }
    struct Worker: Codable { var url: String; var token: String }
    @Published var pack: BCDControlPack?
    @Published var status = "Stock controls"
    @Published var debug = false
    @Published var editing = false
    @Published var context = "onFoot"
    @Published var enabled = true
    private var jobs: [String: Job] = [:]
    private var running = Set<String>()
    private var selectedKey: String?
    private var sessionID: UUID?
    private var overrides: [String: BCDControlPack] = [:]
    private var base: BCDControlPack?
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TouchPacks", isDirectory: true)
    private init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: folder.appendingPathComponent("jobs.json")), let j = try? JSONDecoder().decode([String: Job].self, from: d) { jobs = j }
        if let d = try? Data(contentsOf: folder.appendingPathComponent("overrides.json")), let o = try? JSONDecoder().decode([String: BCDControlPack].self, from: d) { overrides = o }
        for k in jobs.keys where jobs[k]?.state == "requesting" { jobs[k]?.state = "queued" }
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func encoded<T: Encodable>(_ value: T) -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? e.encode(value)) ?? Data()
    }
    func request(_ entry: LibraryEntry) -> Request {
        var bindings: [String: String] = [:]
        // Known input file only. Never forward full registry hives, saves, Steam accounts or credentials.
        if entry.title.localizedCaseInsensitiveContains("Chronicles of the Wolf") {
            let path = "users/mobile/AppData/Roaming/Chronicles of the Wolf/config"
            if let d = try? Data(contentsOf: LibraryEntry.hostDrive.appendingPathComponent(path)), d.count <= 32768,
               let s = String(data: d, encoding: .utf8) { bindings[path] = s }
        }
        if let remaps = entry.controllerBinds { bindings["bcd-player-remaps"] = String(data: Self.encoded(remaps), encoding: .utf8) }
        let identity = BCDControlPack.Identity(executable: entry.launchRelativePath.lowercased(), storeID: entry.steamAppID.map { "steam:\($0)" } ?? "local",
            edition: "installed", build: entry.steamMetadataInstall ?? "unreported", bindingDigest: Self.hash(Self.encoded(bindings)))
        return Request(identity: identity, title: entry.title, bindings: bindings, requirements: ["phone":"iPhone 16 Pro Max landscape safe area", "pad":"iPad landscape independent reach", "hud":"BLACK thin outlines; reserve continuous swipe rectangle first", "ownership":"touch-down until release", "mode":"prefer controller; unresolved meanings labelled by actual output"])
    }
    func prepare(_ entry: LibraryEntry, regenerate: Bool = false) {
        guard entry.desktop != true else { return }
        let req = request(entry), key = Self.hash(Self.encoded(request(entry).identity))
        if !regenerate, cached(key, identity: req.identity) != nil { status = "Validated cached pack"; return }
        guard !running.contains(key) else { return }
        if regenerate { jobs[key] = nil }
        if jobs[key] == nil { jobs[key] = Job(request: req) }
        persist(); resume(key)
    }
    private func persist() { try? Self.encoded(jobs).write(to: folder.appendingPathComponent("jobs.json"), options: .atomic) }
    private func cached(_ key: String, identity: BCDControlPack.Identity) -> BCDControlPack? {
        guard let d = try? Data(contentsOf: folder.appendingPathComponent(key + ".json")) else { return nil }
        return try? BCDControlPack.decode(d, for: identity)
    }
    func activate(_ entry: LibraryEntry?) {
        guard let entry else { sessionID = nil; pack = nil; base = nil; return }
        if sessionID == entry.id && !LibraryModel.shared.blocksGameplayTouch { return }
        sessionID = entry.id
        let req = request(entry), key = Self.hash(Self.encoded(req.identity)); selectedKey = key
        base = cached(key, identity: req.identity); pack = base
        if let b = base, let personal = overrides[key], personal.identity == b.identity {
            var merged = b
            for device in [false, true] {
                var layout = device ? merged.pad : merged.phone
                let old = device ? personal.pad : personal.phone
                for i in layout.controls.indices {
                    if let c = old.controls.first(where: { $0.id == layout.controls[i].id }) {
                        layout.controls[i].x = c.x; layout.controls[i].y = c.y
                        layout.controls[i].radius = c.radius; layout.controls[i].hitRadius = c.hitRadius; layout.controls[i].opacity = c.opacity
                    }
                }
                if device { merged.pad = layout } else { merged.phone = layout }
            }
            merged.aim = personal.aim
            if (try? merged.validate(for: b.identity)) != nil { pack = merged }
        }
        if let p = pack { if !p.contexts.contains(context) { context = p.contexts[0] }; status = "Validated · physical test pending" }
        else { status = "Stock fallback · pack pending"; prepare(entry) }
        for k in jobs.keys where jobs[k]?.state != "validated" { resume(k) }
    }
    private func resume(_ key: String) {
        guard !running.contains(key), let j = jobs[key], j.state != "validated", j.retryAfter <= Date() else { return }
        guard let d = try? Data(contentsOf: folder.appendingPathComponent("worker.json")), let worker = try? JSONDecoder().decode(Worker.self, from: d),
              let url = URL(string: worker.url), ["https", "http"].contains(url.scheme ?? ""), url.user == nil, url.password == nil else { status = "Stock fallback · configure TouchPacks/worker.json"; return }
        running.insert(key); jobs[key]?.state = "requesting"; persist()
        Task {
            do {
                var r = URLRequest(url: url.appendingPathComponent("v1/packs/" + key))
                r.httpMethod = "POST"; r.httpBody = Self.encoded(j.request); r.timeoutInterval = 20
                r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                r.setValue("Bearer " + worker.token, forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: r)
                guard let http = response as? HTTPURLResponse else { throw BCDControlPack.Invalid.reason("No response") }
                if http.statusCode == 202 { throw BCDControlPack.Invalid.reason("Generation queued") }
                guard http.statusCode == 200 else { throw BCDControlPack.Invalid.reason("Worker HTTP \(http.statusCode)") }
                _ = try BCDControlPack.decode(data, for: j.request.identity)
                try data.write(to: folder.appendingPathComponent(key + ".json"), options: .atomic)
                jobs[key]?.state = "validated"; status = "Generated and validated · next menu/launch activates"
            } catch {
                let attempts = (jobs[key]?.attempts ?? 0) + 1
                jobs[key]?.state = "queued"; jobs[key]?.attempts = attempts
                jobs[key]?.retryAfter = Date().addingTimeInterval(min(300, pow(2, Double(min(attempts, 8)))))
                status = "Stock/cached fallback · \(error)"
            }
            persist(); running.remove(key)
            if jobs[key]?.state == "queued" {
                let delay = max(2, jobs[key]!.retryAfter.timeIntervalSinceNow)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)); resume(key)
            }
        }
    }
    func saveEdits(_ value: BCDControlPack) {
        guard let key = selectedKey, (try? value.validate()) != nil else { status = "Edit would cover reserved aim area"; return }
        pack = value; overrides[key] = value
        try? Self.encoded(overrides).write(to: folder.appendingPathComponent("overrides.json"), options: .atomic)
    }
    func reset() {
        guard let key = selectedKey else { return }
        overrides[key] = nil; pack = base
        try? Self.encoded(overrides).write(to: folder.appendingPathComponent("overrides.json"), options: .atomic)
    }
}

struct BCDPackLayer: View {
    @ObservedObject private var store = BCDPackStore.shared
    @ObservedObject private var library = LibraryModel.shared
    var body: some View {
        if let p = store.pack, store.enabled {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    BCDPackSurface(pack: p, context: store.context, debug: store.debug, editing: store.editing)
                        .id(p.id + store.context + String(store.editing))
                    if store.editing { BCDPackInspector().frame(width: min(360, geo.size.width * 0.42)).padding(.leading, geo.safeAreaInsets.leading + 8).padding(.top, 12) }
                }
            }.onAppear { configure() }
                .onChange(of: p) { _, _ in configure() }
                .onChange(of: store.editing) { _, _ in configure() }
                .onChange(of: library.blocksGameplayTouch) { _, _ in configure() }
                .onDisappear { GamepadInput.shared.configurePack(enabled: false, accepting: false, calibration: p.aim) }
        }
    }
    private func configure() {
        guard let p = store.pack else { return }
        GamepadInput.shared.configurePack(enabled: p.inputMode == "controller", accepting: !library.blocksGameplayTouch && !store.editing, calibration: p.aim)
    }
}

private struct BCDPackInspector: View {
    @ObservedObject var store = BCDPackStore.shared
    @State var selected = ""
    @State var pad = false
    func edit(_ f: (inout BCDControlPack) -> Void) { if var p = store.pack { f(&p); store.saveEdits(p) } }
    var body: some View {
        VStack {
            Text("Touch pack · drag to move").font(.headline)
            Text(store.status).font(.caption)
            Toggle("iPad layout", isOn: $pad)
            if let p = store.pack {
                Picker("Control", selection: $selected) {
                    Text("Choose").tag("")
                    ForEach((pad ? p.pad : p.phone).controls, id: \.id) { c in Text("\(c.id): \(p.actions.first { $0.id == c.action }?.label ?? "Radial")").tag(c.id) }
                }
                if let c = (pad ? p.pad : p.phone).controls.first(where: { $0.id == selected }) {
                    Text(p.actions.first { $0.id == c.action }?.output ?? "Radial")
                    Slider(value: Binding(get: { c.radius }, set: { v in changeControl { $0.radius = v; $0.hitRadius = v } }), in: 0.035...0.2)
                    Slider(value: Binding(get: { c.opacity }, set: { v in changeControl { $0.opacity = v } }), in: 0.1...1)
                }
                Text("Aim sensitivity \(p.aim.sensitivity, specifier: "%.2f")")
                Slider(value: Binding(get: { p.aim.sensitivity }, set: { v in edit { $0.aim.sensitivity = v } }), in: 0.1...8)
                Text("Vertical scale")
                Slider(value: Binding(get: { p.aim.vertical }, set: { v in edit { $0.aim.vertical = v } }), in: 0.25...2)
                Toggle("Invert vertical", isOn: Binding(get: { p.aim.invertY }, set: { v in edit { $0.aim.invertY = v } }))
                Text("Dead-zone compensation")
                Slider(value: Binding(get: { p.aim.deadZone }, set: { v in edit { $0.aim.deadZone = v } }), in: 0...0.4)
            }
            Toggle("Show actual hit regions", isOn: $store.debug)
            HStack { Button("Reset") { store.reset() }; Button("Done") { store.editing = false } }
        }.padding(12).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    func changeControl(_ f: (inout BCDControlPack.Control) -> Void) {
        edit { p in
            if pad, let i = p.pad.controls.firstIndex(where: { $0.id == selected }) { f(&p.pad.controls[i]) }
            if !pad, let i = p.phone.controls.firstIndex(where: { $0.id == selected }) { f(&p.phone.controls[i]) }
        }
    }
}

struct BCDPackTools: View {
    @ObservedObject var store = BCDPackStore.shared
    var body: some View {
        Menu {
            Button("Edit pack") { store.editing = true }
            Toggle("Show hit regions", isOn: $store.debug)
            if let p = store.pack {
                ForEach(p.contexts, id: \.self) { c in Button("Context: " + c) { store.context = c } }
            }
            Button("Reset layout and aim") { store.reset() }
            Button("Use stock controls for this session") { store.enabled = false; BCDInputLive.shared.refresh() }
        } label: { Image(systemName: "hand.draw").padding(12).background(.black.opacity(0.2)).clipShape(Circle()) }
    }
}
