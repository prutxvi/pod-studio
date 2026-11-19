// Spotify metadata and local shelves. GPL-3.0, 2026-11-15.
import Foundation
struct PodSpotifyItem: Codable, Identifiable, Equatable {
    var id: String { uri }
    var uri: String
    var title: String
    var artist: String
    var album: String
    var artwork: String
    var kind: String
    var savedAt = Date()
    static func uri(from text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let types: Set<String> = ["track", "album", "playlist", "artist"]
        let parts: [String]
        if text.hasPrefix("spotify:") { parts = text.components(separatedBy: ":") }
        else {
            guard let url = URL(string: text), url.scheme == "https", url.host?.lowercased() == "open.spotify.com", url.user == nil, url.password == nil else { return nil }
            var path = url.pathComponents.filter { $0 != "/" }
            if path.first?.hasPrefix("intl-") == true { path.removeFirst() }
            guard path.count == 2 else { return nil }
            parts = ["spotify"] + path
        }
        guard parts.count == 3, parts[0] == "spotify", types.contains(parts[1]), parts[2].count == 22,
              parts[2].utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else { return nil }
        return parts.joined(separator: ":")
    }
}
struct PodSpotifySnapshot {
    let item: PodSpotifyItem
    let duration: Double
    let position: Double
    let state: String
    let volume: Int
    let shuffle: Bool
    let repeating: Bool
    init?(output: String) {
        let fields = output.trimmingCharacters(in: .newlines).components(separatedBy: "\u{1f}")
        guard fields.count == 12, let ms = Double(fields[5]), ms > 0, ms.isFinite,
              let position = Double(fields[7]), position.isFinite, position >= 0,
              let volume = Int(fields[8]), (0...100).contains(volume), ["playing", "paused", "stopped"].contains(fields[6]) else { return nil }
        let uri = PodSpotifyItem.uri(from: fields[3]) ?? ""
        item = PodSpotifyItem(uri: uri, title: fields[0], artist: fields[1], album: fields[2], artwork: fields[4], kind: "track")
        duration = ms / 1000; self.position = min(position, duration); state = fields[6]; self.volume = volume
        shuffle = fields[9] == "true"; repeating = fields[10] == "true"
    }
}
struct PodMusicLibrary: Codable {
    var saved: [PodSpotifyItem] = []
    var recent: [PodSpotifyItem] = []
}
