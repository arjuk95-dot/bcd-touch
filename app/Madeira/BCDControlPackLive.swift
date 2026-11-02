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
        var generation = "initial"
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
    private var personalKey: String?
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
    private func preferenceKey(_ entry: LibraryEntry) -> String {
        let i=request(entry).identity
        return "TouchPackGenerated."+Self.hash(Self.encoded([i.executable,i.storeID,i.edition]))
    }
    func applyLaunchPreference(_ entry: LibraryEntry) {
        let key=preferenceKey(entry)
        enabled=UserDefaults.standard.object(forKey:key) as? Bool ?? true
    }
    func setLaunchPreference(_ entry: LibraryEntry, generated: Bool) {
        UserDefaults.standard.set(generated,forKey:preferenceKey(entry))
        status="Input mode saved · next launch"
    }
    func preferStockNextLaunch() {
        guard let personalKey else { return }
        UserDefaults.standard.set(false,forKey:"TouchPackGenerated."+personalKey)
        status="Stock input profile saved · next launch"
    }
    private static func bindingText(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom:url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount:32769), data.count <= 32768 else { return nil }
        return String(data:data,encoding:.utf8)
    }
    func request(_ entry: LibraryEntry) -> Request {
        var bindings: [String: String] = [:]
        // Known input file only. Never forward full registry hives, saves, Steam accounts or credentials.
        if entry.title.localizedCaseInsensitiveContains("Chronicles of the Wolf") {
            let path = "users/mobile/AppData/Roaming/Chronicles of the Wolf/config"
            if let text = Self.bindingText(LibraryEntry.hostDrive.appendingPathComponent(path)) { bindings[path] = text }
        }
        // Bounded known input-file names in the selected install only. No directory crawl or account/registry export.
        if let selected = LibraryEntry.hostURL(ofWindowsPath:"C:\\" + entry.relativePath.replacingOccurrences(of:"/",with:"\\")) {
            let folder = (selected.pathExtension.lowercased() == "exe" ? selected.deletingLastPathComponent() : selected).resolvingSymlinksInPath()
            var bytes = bindings.values.reduce(0) { $0 + $1.utf8.count }
            var seen = Set<String>()
            for name in ["bindings.json", "controls.json", "input.cfg", "keybindings.ini", "config/input.json", "settings/input.json", "Config/DefaultInput.ini", "config/DefaultInput.ini"] {
                let url = folder.appendingPathComponent(name).resolvingSymlinksInPath()
                guard url.path.hasPrefix(folder.path + "/"), seen.insert(url.path).inserted,
                      let text = Self.bindingText(url), bytes + text.utf8.count <= 49152 else { continue }
                bindings["install/"+name] = text; bytes += text.utf8.count
            }
        }
        if let remaps = entry.controllerBinds { bindings["bcd-player-remaps"] = String(data: Self.encoded(remaps), encoding: .utf8) }
        let identity = BCDControlPack.Identity(executable: entry.launchRelativePath.lowercased(), storeID: entry.steamAppID.map { "steam:\($0)" } ?? "local",
            edition: "installed", build: entry.steamMetadataInstall ?? "unreported", bindingDigest: Self.hash(Self.encoded(bindings)))
        let wolf = entry.title.localizedCaseInsensitiveContains("Chronicles of the Wolf")
        let dread = entry.title.localizedCaseInsensitiveContains("Dread Delusion")
        return Request(identity: identity, title: entry.title, bindings: bindings, requirements: ["phone":"iPhone 16 Pro Max landscape safe area", "pad":"iPad landscape independent reach", "hud":"BLACK thin outlines; reserve continuous swipe rectangle first", "ownership":"touch-down until release", "genre":wolf ? "side-scroller" : (dread ? "first-person" : "identify from game/bindings"), "mode":wolf && !bindings.isEmpty ? "keyboardMouse using actual named key bindings in config; numeric controller mapping unresolved. Direction hold buttons low left, frequent attack/jump right, occasional actions peripheral/radial. No LS, RS or fireAim outputs." : "prefer controller; unresolved meanings labelled by actual output"])
    }
    func prepare(_ entry: LibraryEntry, regenerate: Bool = false) {
        guard entry.desktop != true else { return }
        var req = request(entry)
        let key = Self.hash(Self.encoded(req.identity))
        if !regenerate, cached(key, identity: req.identity) != nil { status = "Validated cached pack"; return }
        if jobs[key]?.state == "validated" { jobs[key]?.state = "queued" }
        guard !running.contains(key) else { return }
        if regenerate { jobs[key] = nil; req.generation = UUID().uuidString }
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
        // Changing a running HID session into XInput requires a new guest enumeration.
        if sessionID == entry.id && GamepadInput.sessionHIDKind != nil {
            let waiting = request(entry)
            let key = Self.hash(Self.encoded(waiting.identity))
            if cached(key,identity:waiting.identity) != nil { status = "Pack ready at next launch (controller identity)" }
            else { prepare(entry) }
            return
        }
        sessionID = entry.id
        let req = request(entry), key = Self.hash(Self.encoded(req.identity)); selectedKey = key
        base = cached(key, identity: req.identity); pack = base
        let editKey = Self.hash(Self.encoded([req.identity.executable, req.identity.storeID, req.identity.edition]))
        personalKey = editKey
        if let b = base, let personal = overrides[editKey] {
            var merged = b
            for device in [false, true] {
                var layout = device ? merged.pad : merged.phone
                let old = device ? personal.pad : personal.phone
                for i in layout.controls.indices {
                    if let c = old.controls.first(where: { $0.id == layout.controls[i].id }) {
                        layout.controls[i].x = c.x; layout.controls[i].y = c.y
                        layout.controls[i].radius = c.radius; layout.controls[i].hitRadius = c.hitRadius; layout.controls[i].opacity = c.opacity
                        if ["button", "fireAim"].contains(c.role) && ["button", "fireAim"].contains(layout.controls[i].role) { layout.controls[i].role = c.role }
                    }
                }
                if let duplicate = old.controls.first(where: { $0.id == "left-duplicate" }), b.actions.contains(where: { $0.id == duplicate.action }) { layout.controls.append(duplicate) }
                if device { merged.pad = layout } else { merged.phone = layout }
            }
            merged.aim = personal.aim
            if (try? merged.validate(for: b.identity)) != nil { pack = merged }
        }
        if let p = pack { if !p.contexts.contains(context) { context = p.contexts[0] }; status = "Validated · playtest required" }
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
        guard let key = personalKey, (try? value.validate()) != nil else { status = "Edit would cover reserved aim area"; return }
        pack = value; overrides[key] = value
        try? Self.encoded(overrides).write(to: folder.appendingPathComponent("overrides.json"), options: .atomic)
    }
    func reset() {
        guard let key = personalKey else { return }
        overrides[key] = nil; pack = base
        try? Self.encoded(overrides).write(to: folder.appendingPathComponent("overrides.json"), options: .atomic)
    }
}

struct BCDPackLayer: View {
    @ObservedObject private var store = BCDPackStore.shared
    @ObservedObject private var library = LibraryModel.shared
    @ObservedObject private var focus = BCDPackFocus.shared
    var body: some View {
        if let p = store.pack, store.enabled {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    BCDPackSurface(pack: p, context: store.context, debug: store.debug, editing: store.editing)
                        .id(p.id + store.context + String(store.editing) + String(focus.gameFocused))
                    if store.editing {
                        BCDPackInspector().frame(width: min(380, geo.size.width * 0.46), height: max(120, geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom - 24))
                            .padding(.leading, geo.safeAreaInsets.leading + 8).padding(.top, geo.safeAreaInsets.top + 12)
                    }
                }
            }.onAppear { configure() }
                .onChange(of: p) { _, _ in configure() }
                .onChange(of: store.editing) { _, _ in configure() }
                .onChange(of: library.blocksGameplayTouch) { _, _ in configure() }
                .onChange(of: focus.gameFocused) { _, _ in configure() }
                .onDisappear { GamepadInput.shared.configurePack(enabled: library.current != nil && store.pack != nil && store.enabled && p.inputMode == "controller", accepting: false, calibration: p.aim) }
        }
    }
    private func configure() {
        guard let p = store.pack else { return }
        focus.setMonitoring(true)
        GamepadInput.shared.configurePack(enabled: p.inputMode == "controller", accepting: focus.gameFocused && !library.blocksGameplayTouch && !store.editing, calibration: p.aim)
    }
}

struct BCDPackInspector: View {
    @ObservedObject var store = BCDPackStore.shared
    @State var selected = ""
    @State var pad = UIDevice.current.userInterfaceIdiom == .pad
    func edit(_ f: (inout BCDControlPack) -> Void) { if var p = store.pack { f(&p); store.saveEdits(p) } }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Edit controls").font(.headline)
                Spacer()
                Button("Back to game", systemImage: "xmark") { store.editing = false }
                    .frame(minHeight: 44).accessibilityIdentifier("pack-editor-close")
            }
            ScrollView {
            VStack(spacing: 10) {
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
                    if p.actions.first(where: { $0.id == c.action })?.behavior == "hold", c.role != "move" {
                        Button(c.role == "fireAim" ? "Use press only" : "Allow hold-and-drag aim") { changeControl { $0.role = c.role == "fireAim" ? "button" : "fireAim" } }
                        Button("Add/remove left duplicate") {
                            edit { value in
                                var layout = pad ? value.pad : value.phone
                                if layout.controls.contains(where: { $0.id == "left-duplicate" }) { layout.controls.removeAll { $0.id == "left-duplicate" } }
                                else { var duplicate = c; duplicate.id = "left-duplicate"; duplicate.role = "button"; duplicate.x = 0.12; duplicate.y = 0.4; duplicate.radius = 0.06; duplicate.hitRadius = 0.06; layout.controls.append(duplicate) }
                                if pad { value.pad = layout } else { value.phone = layout }
                            }
                        }
                    }
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
            }
            }
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
            Button("Back to game", systemImage: "xmark") { store.editing = false }
            Button("Edit pack") { store.editing = true }
            Toggle("Show hit regions", isOn: $store.debug)
            if let p = store.pack {
                ForEach(p.contexts, id: \.self) { c in Button("Context: " + c) { store.context = c } }
            }
            Button("Reset layout and aim") { store.reset() }
            Button("Use stock input profile next launch") { store.preferStockNextLaunch() }
            Button("Use stock controls for this session") { store.enabled = false; BCDInputLive.shared.refresh() }
        } label: { Image(systemName: "hand.draw").padding(12).background(.black.opacity(0.2)).clipShape(Circle()) }
    }
}
