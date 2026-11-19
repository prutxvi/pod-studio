// Saved listening profiles with fresh hardware readback. GPL-3.0, 2026-11-15.
import Foundation
import Combine

final class PodProfiles: ObservableObject {
    static let shared = PodProfiles()
    @Published private(set) var profiles: [PodListeningProfile] = []
    @Published private(set) var busy = false
    @Published private(set) var status = "Save your current setup, then switch it from here or the menu bar."
    @Published private(set) var result: String = "idle"
    @Published private(set) var lastApplied: UUID?
    private var currentDevice: NothingDeviceEntity?
    private var token: UInt8 = 0x80
    private var readback = PodProfileReadback()
    private var listeningModeEQ = false
    private var completion: ((PodEarbudSettings) -> Void)?
    private var timeout: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var storageHealthy = true
    private var fileURL: URL? { PodStorage.directory?.appendingPathComponent("listening-profiles.json") }
    private let service = NothingServiceImpl.shared
    private let audio = PodAudio.shared

    init() {
        load()
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name(DataNotifications.REPOSITORY_DATA_UPDATED.rawValue), object: nil, queue: .main) { [weak self] event in
            self?.currentDevice = event.object as? NothingDeviceEntity
        })
        observers.append(NotificationCenter.default.addObserver(forName: .podProfilePacket, object: nil, queue: .main) { [weak self] event in
            guard let self, self.busy, let packet = event.object as? [UInt8] else { return }
            self.readback.ingest(packet, token: self.token, listeningModeEQ: self.listeningModeEQ)
            if let settings = self.readback.settings, let done = self.completion {
                self.completion = nil
                self.timeout?.cancel()
                done(settings)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name(BluetoothNotifications.CLOSED_RFCOMM_CHANNEL.rawValue), object: nil, queue: .main) { [weak self] _ in
            self?.currentDevice = nil
            self?.lastApplied = nil
            if self?.busy == true { self?.finish("Disconnected before confirmation. Some settings may have changed; reconnect and apply again.", success: false) }
        })
        NotificationCenter.default.post(name: Notification.Name(DataNotifications.REQUEST_STATE.rawValue), object: nil)
    }
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) }; timeout?.cancel() }
    private func fail(_ message: String) { finish(message, success: false) }
    private func finish(_ message: String, success: Bool) {
        timeout?.cancel(); completion = nil; busy = false
        status = message; result = success ? "confirmed" : "failed"
        if !success { lastApplied = nil }
    }
    private func probe(status: String, completion: @escaping (PodEarbudSettings) -> Void) {
        busy = true; result = "applying"; self.status = status
        listeningModeEQ = currentDevice?.codename == .ESPEON
        readback = PodProfileReadback(); token = token == 0xff ? 0x80 : token + 1
        self.completion = completion
        let work = DispatchWorkItem { [weak self] in
            self?.fail("Not confirmed: the earbuds did not return all required settings. Some settings may have changed. Reconnect and retry.")
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 24, execute: work)
        service.readProfileSettings(token: token, listeningModeEQ: listeningModeEQ)
    }
    private func load() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([PodListeningProfile].self, from: data)
            guard loaded.allSatisfy(Self.valid) else { throw CocoaError(.coderReadCorrupt) }
            profiles = loaded
        } catch {
            storageHealthy = false
            result = "failed"; status = "Saved profiles could not be read. Your file has been preserved; new saves are disabled."
        }
    }
    static func valid(_ profile: PodListeningProfile) -> Bool {
        !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && profile.name.count <= 40 &&
        !profile.deviceAddress.isEmpty && !profile.inputUID.isEmpty && !profile.outputUID.isEmpty &&
        profile.volume.isFinite && (0...1).contains(profile.volume) && ANC(rawValue: profile.settings.anc) != nil &&
        [profile.settings.bass, profile.settings.mid, profile.settings.treble].allSatisfy { $0.isFinite && (-6...6).contains($0) }
    }
    private func persist(_ candidate: [PodListeningProfile]) -> Bool {
        guard storageHealthy, let url = fileURL else { fail("Could not open the profile storage folder."); return false }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(candidate).write(to: url, options: .atomic)
            profiles = candidate; return true
        } catch { fail("Could not save the profile. Existing profiles are unchanged."); return false }
    }
    func rename(_ profile: PodListeningProfile, name: String) {
        guard !busy else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { fail("Use a profile name between 1 and 40 characters."); return }
        var candidate = profiles
        guard let i = candidate.firstIndex(where: { $0.id == profile.id }) else { return }
        candidate[i].name = name
        if persist(candidate) { finish("Renamed to “\(name)”.", success: true) }
    }
    func saveCurrent(name: String) {
        guard !busy else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { fail("Use a profile name between 1 and 40 characters."); return }
        guard storageHealthy else { fail("Profile storage needs repair before saving. Your existing file is preserved."); return }
        guard service.isNothingConnected(), let device = currentDevice else { fail("Connect your earbuds before saving a profile."); return }
        audio.refresh()
        guard let output = audio.devices.first(where: { $0.id == audio.output }),
              let input = audio.devices.first(where: { $0.id == audio.input }), audio.volumeAvailable else { fail("Choose an output with readable volume and a microphone first."); return }
        let compact = { (s: String) in s.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "") }
        guard compact(output.uid).contains(compact(device.bluetoothDetails.mac)) else { fail("Choose these earbuds as your Mac sound output before saving."); return }
        let originalVolume = audio.volume
        let originalProtection = audio.protect
        probe(status: "Reading current settings from your earbuds…") { [weak self] settings in
            guard let self else { return }
            self.audio.refresh()
            guard self.currentDevice?.bluetoothDetails.mac == device.bluetoothDetails.mac,
                  self.audio.devices.first(where: { $0.id == self.audio.output })?.uid == output.uid,
                  self.audio.devices.first(where: { $0.id == self.audio.input })?.uid == input.uid,
                  abs(self.audio.volume - originalVolume) < 0.02, self.audio.protect == originalProtection else {
                self.fail("Your listening setup changed while saving. Keep it steady and retry."); return
            }
            let profile = PodListeningProfile(name: name, deviceAddress: device.bluetoothDetails.mac, deviceName: device.name, outputUID: output.uid, inputUID: input.uid, inputName: input.name, volume: originalVolume, protectMusic: originalProtection, settings: settings)
            guard Self.valid(profile) else { self.fail("These reported settings cannot be safely saved in a profile."); return }
            if self.persist(self.profiles + [profile]) { self.finish("Saved “\(name)” from fresh earbud readings.", success: true) }
        }
    }
    func apply(_ profile: PodListeningProfile) {
        guard !busy else { return }
        guard Self.valid(profile), service.isNothingConnected(), let device = currentDevice,
              device.bluetoothDetails.mac == profile.deviceAddress else { fail("Connect the earbuds this profile belongs to before applying it."); return }
        audio.refresh()
        guard let output = audio.devices.first(where: { $0.output && $0.uid == profile.outputUID }),
              let input = audio.devices.first(where: { $0.input && $0.uid == profile.inputUID }) else { fail("The saved output or microphone is unavailable. No settings were applied."); return }
        if profile.protectMusic && !input.builtIn { fail("This profile conflicts with Music Guard. Save it again with the Mac microphone."); return }
        lastApplied = nil
        let previousProtection = audio.protect
        audio.protect = false
        audio.setDevice(output.id, input: false)
        audio.setDevice(input.id, input: true)
        audio.refresh()
        guard audio.output == output.id, audio.input == input.id, audio.volumeAvailable else { audio.protect = previousProtection; fail("macOS did not confirm the saved audio routes. Earbud settings were not applied."); return }
        audio.setVolume(profile.volume)
        audio.protect = profile.protectMusic
        service.switchANC(mode: ANC(rawValue: profile.settings.anc)!)
        let usesListeningMode = device.codename == .ESPEON
        if usesListeningMode { service.setProfileEQ(code: profile.settings.eq, listeningModeEQ: true) }
        else { service.setAdvancedEQ(enabled: profile.settings.advanced) }
        if profile.settings.advanced {
            service.switchCustomEQ(bass: profile.settings.bass, mid: profile.settings.mid, treble: profile.settings.treble)
        } else if !usesListeningMode { service.setProfileEQ(code: profile.settings.eq) }
        probe(status: "Applying “\(profile.name)” · waiting for earbud read-back…") { [weak self] actual in
            guard let self else { return }
            self.audio.refresh()
            let routesMatch = self.audio.output == output.id && self.audio.input == input.id && self.audio.protect == profile.protectMusic
            let volumeMatches = self.audio.volumeAvailable && abs(self.audio.volume - profile.volume) < 0.02
            guard profile.settings.matches(actual), routesMatch, volumeMatches else {
                var failed: [String] = []
                if profile.settings.anc != actual.anc { failed.append("noise control") }
                if !profile.settings.matches(PodEarbudSettings(anc: profile.settings.anc, eq: actual.eq, advanced: actual.advanced, bass: actual.bass, mid: actual.mid, treble: actual.treble)) { failed.append("EQ") }
                if !routesMatch { failed.append("audio routes") }
                if !volumeMatches { failed.append("volume") }
                self.fail("Not confirmed: \(failed.joined(separator: ", ")). Some settings may have changed; retry this profile."); return
            }
            self.lastApplied = profile.id
            self.finish("Confirmed “\(profile.name)” · ANC and EQ read back from the earbuds; microphone and volume checked on your Mac.", success: true)
        }
    }
}
