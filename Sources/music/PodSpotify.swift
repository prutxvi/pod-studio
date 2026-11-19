// Local Spotify integration. Spotify owns audio and offline downloads.
// GPL-3.0, 2026-11-15.
import AppKit
import Foundation
import Combine
final class PodSpotify: ObservableObject {
    static let shared = PodSpotify()
    @Published private(set) var snapshot: PodSpotifySnapshot?
    @Published private(set) var library = PodMusicLibrary()
    @Published private(set) var enabled = false
    @Published private(set) var busy = false
    @Published private(set) var status = "Connect Spotify to control music from Pod Studio."
    @Published private(set) var permissionBlocked = false
    private let queue = DispatchQueue(label: "local.podstudio.spotify")
    private var timer: Timer?
    private var storageHealthy = true
    private var lastItem = ""
    private var file: URL? { PodStorage.directory?.appendingPathComponent("music-library.json") }
    private var running: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty }
    init() {
        if let file, FileManager.default.fileExists(atPath: file.path) {
            do {
                library = try JSONDecoder().decode(PodMusicLibrary.self, from: Data(contentsOf: file))
                guard (library.saved + library.recent).allSatisfy({ PodSpotifyItem.uri(from: $0.uri) == $0.uri }) else { throw CocoaError(.coderReadCorrupt) }
            } catch { library = PodMusicLibrary(); storageHealthy = false; status = "Music shelf could not be read. Your file was preserved; saving is disabled." }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func connect() {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil else { status = "Spotify is not installed. Install Spotify to use this player."; return }
        permissionBlocked = false; enabled = true
        if running { refresh(); return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            DispatchQueue.main.async { if let error { self?.status = error.localizedDescription } else { self?.refresh() } }
        }
    }
    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") else { status = "Spotify is not installed."; return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }
    func openPermissions() { if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) } }
    private static let metadataScript = """
    tell application id "com.spotify.client"
        try
            set tr to current track
            set trackTitle to name of tr
        on error
            return "NO_TRACK"
        end try
        set art to ""
        try
            set art to artwork url of tr
        end try
        set fields to {trackTitle, artist of tr, album of tr, spotify url of tr, art, (duration of tr as text), (player state as text), (player position as text), (sound volume as text), (shuffling as text), (repeating as text), "v1"}
    end tell
    set AppleScript's text item delimiters to character id 31
    return fields as text
    """
    private func execute(_ source: String, done: @escaping (String?, String?) -> Void) {
        guard !busy else { return }
        busy = true
        queue.async {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "with timeout of 8 seconds\n" + source + "\nend timeout"]
            let out = Pipe(), err = Pipe(); process.standardOutput = out; process.standardError = err
            do {
                try process.run()
                let output = out.fileHandleForReading.readDataToEndOfFile()
                let error = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    self.busy = false
                    done(process.terminationStatus == 0 ? String(data: output, encoding: .utf8) : nil, process.terminationStatus == 0 ? nil : String(data: error, encoding: .utf8))
                }
            } catch { DispatchQueue.main.async { self.busy = false; done(nil,error.localizedDescription) } }
        }
    }
    private func handleError(_ error: String?) {
        if let url = PodStorage.directory?.appendingPathComponent("spotify-last-error.txt") {
            try? (error ?? "No details").write(to:url,atomically:true,encoding:.utf8)
        }
        if error?.contains("-1743") == true || error?.localizedCaseInsensitiveContains("not authorized") == true {
            permissionBlocked = true; enabled = false; snapshot = nil
            status = "Allow Pod Studio to control Spotify in System Settings → Privacy & Security → Automation, then reconnect."
        } else {
            enabled = false
            status = "Spotify could not complete that request. Open a song in Spotify, then reconnect."
        }
    }
    func refresh() {
        guard enabled, !busy else { return }
        guard running else { snapshot = nil; status = "Spotify is closed. Open it to continue."; return }
        execute(Self.metadataScript) { [weak self] output, error in
            guard let self else { return }
            guard let output else { self.handleError(error); return }
            if output.trimmingCharacters(in: .whitespacesAndNewlines) == "NO_TRACK" { self.snapshot = nil; self.status = "Choose a song or a downloaded playlist in Spotify to start."; return }
            guard let snapshot = PodSpotifySnapshot(output: output) else { self.snapshot = nil; self.status = "No readable song yet. Choose a song in Spotify."; return }
            self.snapshot = snapshot; self.status = snapshot.state == "playing" ? "Playing through Spotify" : "Paused in Spotify"
            if snapshot.item.uri != self.lastItem, !snapshot.item.uri.isEmpty {
                self.lastItem = snapshot.item.uri
                var next = self.library
                next.recent.removeAll { $0.uri == snapshot.item.uri }
                next.recent.insert(snapshot.item, at: 0); next.recent = Array(next.recent.prefix(40))
                self.persist(next)
            }
        }
    }
    func command(_ action: String) {
        let allowed: Set<String> = ["playpause", "next track", "previous track"]
        guard enabled, running, allowed.contains(action) else { return }
        execute("tell application id \"com.spotify.client\" to " + action) { [weak self] output, error in
            if output == nil { self?.handleError(error) } else { self?.refresh() }
        }
    }
    func seek(_ seconds: Double) {
        guard enabled, seconds.isFinite, let snapshot else { return }
        let value = max(0, min(snapshot.duration, seconds))
        execute("tell application id \"com.spotify.client\" to set player position to \(value)") { [weak self] output, error in
            if output == nil { self?.handleError(error) } else { self?.refresh() }
        }
    }
    func setShuffle(_ enabled: Bool) {
        guard self.enabled, running else { return }
        execute("tell application id \"com.spotify.client\" to set shuffling to \(enabled ? "true" : "false")") { [weak self] output, error in
            if output == nil { self?.handleError(error) } else { self?.refresh() }
        }
    }
    func play(_ item: PodSpotifyItem) {
        guard let uri = PodSpotifyItem.uri(from: item.uri), enabled, running else { status = "Connect Spotify first."; return }
        // Only validated base62 Spotify IDs can enter a script. No user text is executed.
        execute("tell application id \"com.spotify.client\" to play track \"\(uri)\"") { [weak self] output, error in
            if output == nil { self?.handleError(error) } else { self?.refresh() }
        }
    }
    func saveCurrent() {
        guard let item = snapshot?.item, !item.uri.isEmpty else { status = "This item has no supported Spotify link."; return }
        var next = library
        if let index = next.saved.firstIndex(where: { $0.uri == item.uri }) { next.saved[index] = item }
        else { next.saved.insert(item,at:0) }
        if persist(next) { status = "Saved to your Pod Studio shelf. This does not download the song." }
    }
    func addLink(name: String, link: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, let uri = PodSpotifyItem.uri(from: link) else { status = "Enter a name and a Spotify track, album or playlist link."; return false }
        let type = uri.components(separatedBy: ":")[1]
        guard type != "artist" else { status = "Use a track, album or playlist link for playback."; return false }
        var next = library
        let item = PodSpotifyItem(uri:uri,title:name,artist:"Saved \(type)",album:"",artwork:"",kind:type)
        if let i = next.saved.firstIndex(where: { $0.uri == uri }) { next.saved[i] = item } else { next.saved.insert(item,at:0) }
        if persist(next) { status = "Added to your shelf. Spotify manages downloads and playback."; return true }; return false
    }
    @discardableResult private func persist(_ next: PodMusicLibrary) -> Bool {
        guard storageHealthy, let file else { status = "Music shelf storage is unavailable; your existing file is preserved."; return false }
        do { try JSONEncoder().encode(next).write(to:file,options:.atomic); library = next; return true }
        catch { status = "Could not save the music shelf."; return false }
    }
}
