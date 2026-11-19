import Foundation
@main struct MusicChecks {
    static func main() throws {
        let id="0123456789ABCDEFGHIJKL"
        precondition(PodSpotifyItem.uri(from:"https://open.spotify.com/playlist/\(id)?si=test") == "spotify:playlist:\(id)")
        precondition(PodSpotifyItem.uri(from:"https://open.spotify.com/intl-en/track/\(id)") == "spotify:track:\(id)")
        precondition(PodSpotifyItem.uri(from:"spotify:album:\(id)") == "spotify:album:\(id)")
        for bad in ["spotify:track:\(id)\" & do shell script \"bad", "https://evil.test/track/\(id)", "http://open.spotify.com/track/\(id)", "https://open.spotify.com.evil.test/track/\(id)", "spotify:track:short", "spotify:local:unsafe"] {
            precondition(PodSpotifyItem.uri(from:bad) == nil,"Unsafe or unsupported link accepted")
        }
        print("PASS: Spotify links normalize; script injection and non-Spotify URLs rejected")
        let fields=["Song, with punctuation", "Artist", "Album", "spotify:track:\(id)", "", "240000", "paused", "42.5", "60", "true", "false", "v1"]
        let output=fields.joined(separator:"\u{1f}")+"\n"
        let snapshot=PodSpotifySnapshot(output:output)!
        precondition(snapshot.item.title == fields[0] && snapshot.duration == 240 && snapshot.position == 42.5 && snapshot.state == "paused" && snapshot.shuffle)
        precondition(PodSpotifySnapshot(output:"NO_TRACK") == nil)
        precondition(PodSpotifySnapshot(output:fields.dropLast().joined(separator:"\u{1f}")) == nil)
        var broken=fields; broken[7]="nan"
        precondition(PodSpotifySnapshot(output:broken.joined(separator:"\u{1f}")) == nil)
        broken=fields; broken[6]="invented state"
        precondition(PodSpotifySnapshot(output:broken.joined(separator:"\u{1f}")) == nil)
        print("PASS: metadata, duration, seek position and playback state parsing; invalid data rejected")
        let library=PodMusicLibrary(saved:[snapshot.item],recent:[snapshot.item])
        let decoded=try JSONDecoder().decode(PodMusicLibrary.self,from:JSONEncoder().encode(library))
        precondition(decoded.saved == library.saved && decoded.recent == library.recent)
        print("PASS: saved music and recent metadata JSON roundtrip")
    }
}
