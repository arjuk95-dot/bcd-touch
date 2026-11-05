// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001, 2026-11-01. Codex credentials stay on the desktop.
import Combine
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    @Published var placingControls = false
    @Published var selectedControl = ""
    @Published var context = "onFoot"
    @Published var enabled = true
    private var jobs: [String: Job] = [:]
    private var running = Set<String>()
    private var selectedKey: String?
    private var personalKey: String?
    private var sessionID: UUID?
    private var sessionUsesLocal = false
    struct PersonalEdit: Codable { var pack: BCDControlPack; var baseline: BCDControlPack? }
    private var overrides: [String: PersonalEdit] = [:]
    private var undoHistory: [BCDControlPack] = []
    private var gameKey: String?
    private var base: BCDControlPack?
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TouchPacks", isDirectory: true)
    private init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: folder.appendingPathComponent("jobs.json")), let j = try? JSONDecoder().decode([String: Job].self, from: d) { jobs = j }
        if let d = try? Data(contentsOf: folder.appendingPathComponent("personal-edits-v2.json")), let o = try? JSONDecoder().decode([String: PersonalEdit].self, from: d) { overrides = o }
        else if let d = try? Data(contentsOf: folder.appendingPathComponent("overrides.json")), let old = try? JSONDecoder().decode([String: BCDControlPack].self, from: d) {
            overrides = old.mapValues { PersonalEdit(pack: $0, baseline: nil) }
        }
        var migrated = false
        for k in jobs.keys {
            if jobs[k]?.state == "requesting" { jobs[k]?.state = "queued"; migrated = true }
            if (Int(jobs[k]?.request.requirements["packVersion"] ?? "1") ?? 1) < 3 {
                jobs[k]?.request.requirements["packVersion"] = "3"; migrated = true
            }
        }
        if migrated { try? Self.encoded(jobs).write(to: folder.appendingPathComponent("jobs.json"), options: .atomic) }
    }
    nonisolated static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    nonisolated static func encoded<T: Encodable>(_ value: T) -> Data {
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
        if generated { UserDefaults.standard.set(false, forKey: "TouchPackLocal." + identityKey(entry)) }
        status="Input mode saved · next launch"
    }
    func preferStockNextLaunch() {
        guard let gameKey else { return }
        UserDefaults.standard.set(false,forKey:"TouchPackGenerated."+gameKey)
        status="Stock input profile saved · next launch"
    }
    private func identityKey(_ entry: LibraryEntry) -> String {
        let i = request(entry).identity
        return Self.hash(Self.encoded([i.executable, i.storeID, i.edition]))
    }
    func authoringChoice(_ entry: LibraryEntry, key: String) -> String {
        UserDefaults.standard.string(forKey: "TouchPack." + key + "." + entry.launchRelativePath.lowercased()) ?? "auto"
    }
    func setAuthoringChoice(_ entry: LibraryEntry, key: String, value: String) {
        UserDefaults.standard.set(value, forKey: "TouchPack." + key + "." + entry.launchRelativePath.lowercased())
        status = "Preparation preference saved"
    }
    func usePreset(_ entry: LibraryEntry) {
        let req = request(entry)
        let proposed = req.requirements["genre"] ?? "first-person"
        let genre = BCDPackCatalog.genres.contains { $0.0 == proposed } ? proposed : "third-person"
        let choice = authoringChoice(entry, key: "mode")
        let mode = choice == "keyboardMouse" || (choice == "auto" && req.requirements["mode"]?.hasPrefix("keyboardMouse") == true) ? "keyboardMouse" : "controller"
        let preset = BCDNoitaPack.matches(req.identity) ? BCDNoitaPack.make(identity:req.identity,bindings:req.bindings) : BCDPackAuthoring.preset(identity: req.identity, title: entry.title, genre: genre, mode: mode)
        do {
            try preset.validate(for: req.identity)
            let key = identityKey(entry)
            try Self.encoded(preset).write(to: folder.appendingPathComponent("local-" + key + ".json"), options: .atomic)
            UserDefaults.standard.set(true, forKey: "TouchPackLocal." + key)
            UserDefaults.standard.set(true, forKey: preferenceKey(entry))
            status = "Customizable preset ready · next launch. Verify its raw bindings in the game."
        } catch { status = "Preset could not be saved: \(error)" }
    }
    func summary(_ entry: LibraryEntry) -> String {
        let req = request(entry), key = Self.hash(Self.encoded(req.identity))
        if UserDefaults.standard.bool(forKey: "TouchPackLocal." + identityKey(entry)) { return "Personal preset selected · edit in game" }
        if let p = cached(key, identity: req.identity) { return "Validated · \(p.actions.count) actions · physical test required" }
        if let job = jobs[key] { return "Preparation \(job.state) · stock controls remain available" }
        return "Prepare researched controls or start from an offline preset"
    }
    private static func bindingText(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom:url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount:32769), data.count <= 32768 else { return nil }
        return String(data:data,encoding:.utf8)
    }
    func request(_ entry: LibraryEntry) -> Request {
        var bindings: [String: String] = [:]
        if entry.steamAppID == 881100 || entry.title.caseInsensitiveCompare("Noita") == .orderedSame {
            bindings.merge(BCDNoitaPack.inputMetadata(drive:LibraryEntry.hostDrive)) { first,_ in first }
        }
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
        let genre = authoringChoice(entry, key: "genre"), mode = authoringChoice(entry, key: "mode")
        return Request(identity: identity, title: entry.title, bindings: bindings, requirements: ["phone":"iPhone 16 Pro Max landscape safe area", "pad":"iPad landscape independent reach", "hud":"BLACK thin outlines; reserve continuous swipe rectangle first", "ownership":"touch-down until release", "genre":genre == "auto" ? (wolf ? "side-scroller" : (dread ? "first-person" : "identify from game/bindings")) : genre, "packVersion":"3", "inputMode":mode, "mode":mode != "auto" ? mode : wolf && !bindings.isEmpty ? "keyboardMouse using actual named key bindings in config; numeric controller mapping unresolved. Direction hold buttons low left, frequent attack/jump right, occasional actions peripheral/radial. No LS, RS or fireAim outputs." : "prefer controller; unresolved meanings labelled by actual output"])
    }
    func prepare(_ entry: LibraryEntry, regenerate: Bool = false) {
        guard entry.desktop != true else { return }
        if BCDNoitaPack.matches(request(entry).identity) { usePreset(entry);return }
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
        guard let entry else { sessionID = nil; pack = nil; base = nil; personalKey = nil; gameKey = nil; selectedControl = ""; undoHistory.removeAll(); return }
        let sameSession = sessionID == entry.id
        if !sameSession { selectedControl = "" }
        if sessionID == entry.id && !LibraryModel.shared.blocksGameplayTouch { return }
        // Changing a running HID session into XInput requires a new guest enumeration.
        if sessionID == entry.id && GamepadInput.sessionHIDKind != nil {
            let waiting = request(entry)
            let key = Self.hash(Self.encoded(waiting.identity))
            if cached(key,identity:waiting.identity) != nil { status = "Pack ready at next launch (controller identity)" }
            else { prepare(entry) }
            return
        }
        let req = request(entry), key = Self.hash(Self.encoded(req.identity)); selectedKey = key
        gameKey = Self.hash(Self.encoded([req.identity.executable, req.identity.storeID, req.identity.edition]))
        if !sameSession { sessionUsesLocal = UserDefaults.standard.bool(forKey: "TouchPackLocal." + gameKey!) }
        let localSelected = sessionUsesLocal
        var local: BCDControlPack?
        if localSelected && sameSession { local = base }
        else if localSelected, let data = try? Data(contentsOf: folder.appendingPathComponent("local-" + gameKey! + ".json")), var candidate = try? BCDControlPack.decode(data, placement: .personal) {
            candidate.identity = req.identity // A player-selected template follows this installation; generated caches never bypass identity matching.
            if (try? candidate.validate(for: req.identity, placement: .personal)) != nil { local = candidate }
        }
        let candidate = local ?? (BCDNoitaPack.matches(req.identity) ? BCDNoitaPack.make(identity:req.identity,bindings:req.bindings) : cached(key, identity: req.identity))
        if sameSession, let current = pack, let candidate, current.inputMode != candidate.inputMode {
            status = "Prepared input mode saved · next launch"; return
        }
        sessionID = entry.id
        base = candidate; pack = base
        personalKey = local.map { gameKey! + "." + $0.id } ?? gameKey
        undoHistory.removeAll()
        var editFailure: String?
        if let b = base, let personal = overrides[personalKey!] {
            do { pack = try BCDPackAuthoring.merge(base: b, personal: personal.pack, baseline: personal.baseline) }
            catch { editFailure = "Personal edits need review · validated base active: \(error)" }
        }
        if let p = pack {
            if !p.contexts.contains(context) { context = p.contexts[0] }
            status = p.cursorControls != nil ? "Cursor pack · expected bindings need confirmation · playtest required" : "Validated · playtest required"
        }
        else { status = "Stock fallback · pack pending"; prepare(entry) }
        if let editFailure { status = editFailure }
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
                let returned = try BCDControlPack.decode(data, for: j.request.identity)
                if let selectedMode = j.request.requirements["inputMode"], ["controller", "keyboardMouse"].contains(selectedMode), returned.inputMode != selectedMode {
                    throw BCDControlPack.Invalid.reason("Worker pack does not match selected input mode")
                }
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
    @discardableResult func saveEdits(_ value: BCDControlPack, recordUndo: Bool = true) -> Bool {
        guard let key = personalKey, let base else { return false }
        do {
            try value.validate(for: base.identity, placement: .personal)
            guard value.inputMode == base.inputMode else { throw BCDControlPack.Invalid.reason("Changing input mode requires a preset and a new launch.") }
            var updated = overrides
            updated[key] = PersonalEdit(pack: value, baseline: base)
            try Self.encoded(updated).write(to: folder.appendingPathComponent("personal-edits-v2.json"), options: .atomic)
            if recordUndo, let current = pack { undoHistory.append(current); if undoHistory.count > 20 { undoHistory.removeFirst() } }
            overrides = updated; pack = value
            if !value.contexts.contains(context) { context = value.contexts[0] }
            status = "Personal controls saved · this game"
            return true
        } catch { status = "Edit not saved: \(error)"; return false }
    }
    func undoEdit() {
        guard let previous = undoHistory.last else { return }
        if saveEdits(previous, recordUndo: false) { undoHistory.removeLast() }
    }
    func reset() {
        guard let key = personalKey else { return }
        do {
            var updated = overrides; updated[key] = nil
            try Self.encoded(updated).write(to: folder.appendingPathComponent("personal-edits-v2.json"), options: .atomic)
            if let current = pack { undoHistory.append(current) }
            overrides = updated; pack = base; status = "Preset restored · personal edits can be undone"
            if let base, !base.contexts.contains(context) { context = base.contexts[0] }
        } catch { status = "Reset not saved: \(error)" }
    }

}

struct BCDPackLayer: View {
    @ObservedObject private var store = BCDPackStore.shared
    @ObservedObject private var library = LibraryModel.shared
    @ObservedObject private var focus = BCDPackFocus.shared
    @State private var placementBarAtBottom = false
    var body: some View {
        if let p = store.pack, store.enabled {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    BCDPackSurface(pack: p, context: store.context, debug: store.debug, editing: store.editing)
                        .id(p.id + store.context + String(store.editing) + String(focus.gameFocused))
                    if store.editing && !store.placingControls {
                        BCDPackInspector().frame(width: min(380, geo.size.width * 0.46), height: max(120, geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom - 64))
                            .padding(.leading, geo.safeAreaInsets.leading + 8).padding(.top, geo.safeAreaInsets.top + 52)
                    }
                    if store.editing && store.placingControls {
                        VStack {
                            if placementBarAtBottom { Spacer() }
                            HStack {
                                Button("Edit controls", systemImage: "slider.horizontal.3") { store.placingControls = false }
                                Button("Undo", systemImage: "arrow.uturn.backward") { store.undoEdit() }
                                Button(placementBarAtBottom ? "Toolbar to top" : "Toolbar to bottom", systemImage: placementBarAtBottom ? "arrow.up" : "arrow.down") { placementBarAtBottom.toggle() }
                                    .labelStyle(.iconOnly)
                                Button("Back to game", systemImage: "xmark") { store.editing = false }
                            }.buttonStyle(.bordered).padding(6).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                            if !placementBarAtBottom { Spacer() }
                        }.padding(.horizontal, 8).padding(.top, geo.safeAreaInsets.top + 52).padding(.bottom, geo.safeAreaInsets.bottom + 6)
                            .frame(maxWidth: .infinity)
                    }
                }
            }.onAppear { configure() }
                .onChange(of: p) { _, _ in configure() }
                .onChange(of: store.editing) { _, editing in if !editing { store.placingControls = false }; configure() }
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
    @State var pad = UIDevice.current.userInterfaceIdiom == .pad
    @State private var exporting = false
    @State private var importing = false
    func edit(_ f: (inout BCDControlPack) -> Void) { if var p = store.pack { f(&p); store.saveEdits(p) } }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Edit controls").font(.headline)
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward") { store.undoEdit() }
                Button("Back to game", systemImage: "xmark") { store.editing = false }
                    .frame(minHeight: 44).accessibilityIdentifier("pack-editor-close")
            }
            ScrollView {
            VStack(spacing: 10) {
            Text(store.status).font(.caption)
            Button("Move buttons", systemImage: "hand.draw") { store.placingControls = true }
            Text("Drag anywhere, including over other controls. Front buttons receive overlapping taps.").font(.caption)
            Toggle("iPad layout", isOn: $pad).onChange(of: pad) { _, _ in store.selectedControl = "" }
            if let p = store.pack {
                Text(p.inputMode == "controller" ? "Xbox controller controls" : "Keyboard and mouse controls").font(.subheadline)
                Menu {
                    Section(p.inputMode == "controller" ? "Choose Xbox input" : "Choose key or mouse input") {
                        ForEach(BCDPackCatalog.addableOutputs(mode: p.inputMode), id: \.self) { output in
                            Button(BCDPackCatalog.outputLabel(output)) {
                                do {
                                    let updated = try BCDPackAuthoring.addButton(to: p, context: store.context, output: output)
                                    if store.saveEdits(updated) {
                                        store.selectedControl = updated.phone.controls.last?.id ?? ""
                                        store.placingControls = true
                                    }
                                } catch { store.status = String(describing: error) }
                            }.accessibilityIdentifier("pack-add-" + output)
                        }
                    }
                } label: { Label("Add button", systemImage: "plus.circle") }
                    .accessibilityIdentifier("pack-add-button")
                Picker("Control", selection: $store.selectedControl) {
                    Text("Choose").tag("")
                    ForEach((pad ? p.pad : p.phone).controls, id: \.id) { c in Text(controlTitle(c, in: p)).tag(c.id) }
                }
                if let c = (pad ? p.pad : p.phone).controls.first(where: { $0.id == store.selectedControl }) {
                    Text("Binding: " + (p.actions.first { $0.id == c.action }.map { BCDPackCatalog.outputLabel($0.output) } ?? "Radial"))
                    Button("Bring to front", systemImage: "square.3.layers.3d.top.filled") {
                        edit { value in
                            var layout = pad ? value.pad : value.phone
                            layout.controls.removeAll { $0.id == c.id }; layout.controls.append(c)
                            if pad { value.pad = layout } else { value.phone = layout }
                        }
                    }
                    Text("Button size").font(.caption)
                    Slider(value: Binding(get: { c.radius }, set: { v in changeControl { $0.radius = v; $0.hitRadius = v } }), in: 0.035...0.2)
                    Text("Opacity").font(.caption)
                    Slider(value: Binding(get: { c.opacity }, set: { v in changeControl { $0.opacity = v } }), in: 0.1...1)
                    if p.version >= 4 {
                        Toggle("Show label",isOn:Binding(get:{ c.showLabel ?? true },set:{ on in changeControl { $0.showLabel=on } }))
                    }
                    Toggle("Label inside button", isOn: Binding(get: { c.labelPlacement == "inside" }, set: { on in edit { value in
                        value.version = max(value.version,3)
                        if pad, let i = value.pad.controls.firstIndex(where: { $0.id == c.id }) { value.pad.controls[i].labelPlacement = on ? "inside" : "below" }
                        if !pad, let i = value.phone.controls.firstIndex(where: { $0.id == c.id }) { value.phone.controls[i].labelPlacement = on ? "inside" : "below" }
                    } }))
                    if p.actions.first(where: { $0.id == c.action })?.behavior == "toggle" {
                        Picker("Slide to tap", selection: Binding(get: { c.slideToAction ?? "" }, set: { target in changeControl { $0.slideToAction = target.isEmpty ? nil : target } })) {
                            Text("None").tag("")
                            ForEach(p.actions.filter { $0.behavior == "tap" && $0.id != c.action }, id: \.id) { a in Text(a.label).tag(a.id) }
                        }
                    }
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
                BCDPackActionEditor(preferredAction: (pad ? p.pad : p.phone).controls.first { $0.id == store.selectedControl }?.action ?? "")
                if p.cursorControls != nil { BCDCursorPackSettings(pad:pad) }
                Text(p.inputMode == "controller" ? "Swipe response \(p.aim.sensitivity, specifier: "%.2f")×" : "Mouse sensitivity \(p.aim.sensitivity, specifier: "%.2f")×")
                Slider(value: Binding(get: { p.aim.sensitivity }, set: { v in edit { $0.aim.sensitivity = v } }), in: 0.1...8)
                if p.inputMode == "controller" {
                    Text("Controls how quickly a swipe reaches full stick. Set maximum camera speed in the game's look-sensitivity settings.").font(.caption)
                }
                Text("Vertical scale")
                Slider(value: Binding(get: { p.aim.vertical }, set: { v in edit { $0.aim.vertical = v } }), in: 0.25...2)
                Toggle("Invert vertical", isOn: Binding(get: { p.aim.invertY }, set: { v in edit { $0.aim.invertY = v } }))
                Text("Dead-zone compensation")
                Slider(value: Binding(get: { p.aim.deadZone }, set: { v in edit { $0.aim.deadZone = v } }), in: 0...0.4)
            }
            Toggle("Show actual hit regions", isOn: $store.debug)
            Button("Export controls", systemImage: "square.and.arrow.up") { exporting = true }
            Button("Import controls for this game", systemImage: "square.and.arrow.down") { importing = true }
            HStack { Button("Reset") { store.reset() }; Button("Done") { store.editing = false } }
            }
            }
        }.padding(12).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
        .fileExporter(isPresented: $exporting, document: BCDPackDocument(pack: store.pack), contentType: .json, defaultFilename: "game-touch-controls") { result in
            if case .failure(let error) = result { store.status = "Export failed: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let data = try handle.read(upToCount: 262145) ?? Data()
                let value = try BCDControlPack.decode(data, for: store.pack?.identity, placement: .personal)
                guard value.inputMode == store.pack?.inputMode else { throw BCDControlPack.Invalid.reason("Choose a preset with the imported input mode before launching the game.") }
                _ = store.saveEdits(value)
            } catch { store.status = "Import not applied: \(error)" }
        }
    }
    func changeControl(_ f: (inout BCDControlPack.Control) -> Void) {
        edit { p in
            if pad, let i = p.pad.controls.firstIndex(where: { $0.id == store.selectedControl }) { f(&p.pad.controls[i]) }
            if !pad, let i = p.phone.controls.firstIndex(where: { $0.id == store.selectedControl }) { f(&p.phone.controls[i]) }
        }
    }
    private func controlTitle(_ c: BCDControlPack.Control, in p: BCDControlPack) -> String {
        let controls = pad ? p.pad.controls : p.phone.controls
        let number = (controls.firstIndex { $0.id == c.id } ?? 0) + 1
        guard let a = p.actions.first(where: { $0.id == c.action }) else { return "\(number). Actions radial" }
        let binding = BCDPackCatalog.outputLabel(a.output)
        return "\(number). " + (a.label == binding ? a.label : "\(a.label) (\(binding))")
    }
}

struct BCDPackDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var pack: BCDControlPack?
    init(pack: BCDControlPack?) { self.pack = pack }
    init(configuration: ReadConfiguration) throws {
        pack = try BCDControlPack.decode(configuration.file.regularFileContents ?? Data(), placement: .personal)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let pack else { throw BCDControlPack.Invalid.reason("No controls to export") }
        try pack.validate(placement: .personal)
        return FileWrapper(regularFileWithContents: BCDPackStore.encoded(pack))
    }
}

/// The same action editor serves generated packs and offline templates.
struct BCDPackActionEditor: View {
    @ObservedObject private var store = BCDPackStore.shared
    var preferredAction: String
    @State private var selected = ""
    @State private var label = ""
    @State private var icon = "hand.tap"
    @State private var output = "A"
    @State private var behavior = "tap"
    @State private var contexts = Set<String>()
    @State private var modifiers = Set<Int32>()
    @State private var showIcons = false
    @State private var iconSearch = ""
    @State private var onRadial = false
    private var action: BCDControlPack.Action? { store.pack?.actions.first { $0.id == selected } }
    private var outputs: [String] {
        guard let p = store.pack else { return [] }
        if p.inputMode == "controller" {
            if action?.output == "LS" || action?.output == "RS" { return [action!.output] }
            return BCDPackCatalog.buttons
        }
        var choices = BCDPackCatalog.keys.map { "key:\($0.0)" } + ["mouse:left", "mouse:right", "mouse:middle", "mouse:wheelUp", "mouse:wheelDown"]
        if !choices.contains(output) { choices.append(output) }
        return choices
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Picker("Action", selection: $selected) {
                Text("Choose action").tag("")
                ForEach(store.pack?.actions ?? [], id: \.id) { a in Text(a.label).tag(a.id) }
            }.accessibilityIdentifier("pack-action-picker")
            if let a = action, let p = store.pack {
                TextField("Button label", text: $label).textFieldStyle(.roundedBorder)
                Picker("Sends", selection: $output) {
                    ForEach(outputs, id: \.self) { value in Text(BCDPackCatalog.outputLabel(value)).tag(value) }
                }
                if p.inputMode == "keyboardMouse", output.hasPrefix("key:") {
                    HStack {
                        ForEach([Int32(17),16,18], id: \.self) { key in
                            Toggle(BCDPackCatalog.outputLabel("key:\(key)"), isOn: Binding(get: { modifiers.contains(key) }, set: { on in
                                if on { modifiers.insert(key) } else { modifiers.remove(key) }
                            })).toggleStyle(.button)
                        }
                    }
                }
                if p.inputMode == "keyboardMouse" {
                    TextField("Advanced binding, e.g. keys:17+67", text: $output).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                }
                if !["LS", "RS"].contains(a.output) {
                    Picker("Press behavior", selection: $behavior) {
                        Text("Hold while touched").tag("hold"); Text("Tap on touch").tag("tap"); Text("Tap on release").tag("release")
                        if !a.output.hasPrefix("mouse:wheel") { Text("Tap to toggle").tag("toggle") }
                    }
                    if behavior != "toggle" { Toggle("Also available on Actions radial", isOn: $onRadial) }
                }
                Button { showIcons.toggle() } label: {
                    HStack {
                        if let image = BCDPackIcons.image(icon) { Image(uiImage:image).resizable().scaledToFit().frame(width:22,height:22) }
                        Text("Icon: " + (BCDPackCatalog.icons.first { $0.id == icon }?.label ?? icon))
                    }
                }
                if showIcons {
                    TextField("Find icon", text: $iconSearch).textFieldStyle(.roundedBorder)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(BCDPackCatalog.icons.filter { iconSearch.isEmpty || $0.label.localizedCaseInsensitiveContains(iconSearch) }) { entry in
                            Button { icon = entry.id; showIcons = false } label: {
                                VStack { if let image = BCDPackIcons.image(entry.id) { Image(uiImage:image).resizable().scaledToFit().frame(width:24,height:24) }; Text(entry.label).font(.caption2) }.frame(maxWidth: .infinity, minHeight: 48)
                            }.accessibilityLabel(entry.label)
                        }
                    }
                }
                Text("Show in contexts").font(.caption)
                ForEach(p.contexts, id: \.self) { c in
                    Toggle(c, isOn: Binding(get: { contexts.contains(c) }, set: { on in
                        if on { contexts.insert(c) } else { contexts.remove(c) }
                    }))
                }
                Text("Current binding: " + BCDPackCatalog.outputLabel(a.output)).font(.caption)
                Button("Save action", systemImage: "checkmark") { save() }.accessibilityIdentifier("pack-action-save")
                if !["LS", "RS"].contains(a.output) {
                    Button("Remove action", role: .destructive) {
                        var changed = p; BCDPackAuthoring.removeAction(a.id, from: &changed)
                        if store.saveEdits(changed) { selected = "" }
                    }
                }
            }
            Divider()
        }
        .onAppear { selected = preferredAction.isEmpty ? (store.pack?.actions.first?.id ?? "") : preferredAction; load() }
        .onChange(of: preferredAction) { _, value in if !value.isEmpty { selected = value; load() } }
        .onChange(of: selected) { _, _ in load() }
        .onChange(of: store.pack?.actions) { _, _ in load() }
    }
    private func load() {
        guard let a = action else { return }
        label = a.label; icon = a.icon; behavior = a.behavior; contexts = Set(a.contexts)
        modifiers = []
        if let keys = BCDPackCatalog.keyCodes(a.output), keys.count > 1, keys.dropLast().allSatisfy({ [17,16,18].contains($0) }) {
            output = "key:\(keys.last!)"; modifiers = Set(keys.dropLast())
        } else { output = a.output }
        onRadial = store.pack?.radial.contains(a.id) == true
    }
    private func save() {
        guard var p = store.pack, let i = p.actions.firstIndex(where: { $0.id == selected }) else { return }
        var binding = output
        if p.inputMode == "keyboardMouse", output.hasPrefix("key:"), let key = BCDPackCatalog.keyCodes(output)?.first {
            let chord = [Int32(17),16,18].filter { modifiers.contains($0) && $0 != key } + [key]
            binding = chord.count == 1 ? "key:\(key)" : "keys:" + chord.map(String.init).joined(separator: "+")
        }
        BCDPackAuthoring.ensurePlayerEvidence(&p)
        p.version = max(p.version, behavior == "toggle" || icon.hasPrefix("bcd.") ? 3 : 2)
        if binding != p.actions[i].output { p.actions[i].evidence = "player-binding" }
        p.actions[i].label = label; p.actions[i].icon = icon; p.actions[i].output = binding
        p.actions[i].behavior = behavior; p.actions[i].contexts = p.contexts.filter { contexts.contains($0) }
        if onRadial && behavior != "toggle", !p.radial.contains(selected) { p.radial.append(selected) }
        if !onRadial || behavior == "toggle" { p.radial.removeAll { $0 == selected } }
        for pad in [false,true] {
            var layout = pad ? p.pad : p.phone
            for j in layout.controls.indices where layout.controls[j].action == selected && layout.controls[j].role == "fireAim" && behavior != "hold" { layout.controls[j].role = "button" }
            for j in layout.controls.indices {
                if layout.controls[j].action == selected && behavior != "toggle" { layout.controls[j].slideToAction = nil }
                if layout.controls[j].slideToAction == selected && behavior != "tap" { layout.controls[j].slideToAction = nil }
            }
            if pad { p.pad = layout } else { p.phone = layout }
        }
        _ = store.saveEdits(p)
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
