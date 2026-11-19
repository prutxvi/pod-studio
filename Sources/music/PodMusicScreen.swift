// Music player UI. GPL-3.0, 2026-11-15.
import SwiftUI
struct PodMusicScreen: View {
    @ObservedObject var spotify = PodSpotify.shared
    @ObservedObject var audio = PodAudio.shared
    @State private var shelf = "saved"
    @State private var search = ""
    @State private var adding = false
    @State private var link = ""
    @State private var title = ""
    @State private var position: Double = 0
    @State private var seeking = false
    @State private var volume: Double = 0
    @State private var changingVolume = false
    private var now: PodSpotifySnapshot? { spotify.snapshot }
    private var items: [PodSpotifyItem] {
        let source = shelf == "saved" ? spotify.library.saved : spotify.library.recent
        return source.filter { search.isEmpty || ($0.title + " " + $0.artist + " " + $0.album).localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                player
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: spotify.permissionBlocked ? "lock.circle" : "info.circle")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(spotify.status).font(.system(size: 12))
                        Text("Spotify handles audio and downloads. This shelf stores links; it cannot list or copy all offline downloads.").font(.system(size: 10)).foregroundStyle(NX.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if spotify.permissionBlocked { Button("Allow access") { spotify.openPermissions() } }
                }.foregroundStyle(NX.textSecondary)
                HStack(spacing: 16) {
                    Picker("Library", selection: $shelf) {
                        Text("Your shelf").tag("saved"); Text("Recent on this Mac").tag("recent")
                    }.pickerStyle(.segmented).frame(width: 300)
                    Spacer()
                    TextField("Search your music", text: $search).textFieldStyle(.roundedBorder).frame(width: 200)
                    Button { adding = true } label: { Image(systemName: "plus") }.buttonStyle(.borderless).help("Add a Spotify link").accessibilityLabel("Add a Spotify link")
                }
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(search.isEmpty ? "BUILD YOUR ROTATION." : "NO MATCHES.").font(NX.ndot(24))
                        Text(search.isEmpty ? "Save the current song or add links to your favourite Spotify playlists and albums. Recent songs appear after you connect." : "Try a different title or artist.")
                            .font(.system(size: 12)).foregroundStyle(NX.textSecondary)
                        if search.isEmpty { Button("ADD SPOTIFY LINK") { adding = true }.buttonStyle(PodPillButton()) }
                    }.padding(25).frame(maxWidth: .infinity, alignment: .leading).nxCard()
                } else {
                    VStack(spacing: 0) {
                        HStack { Text("TITLE / ARTIST"); Spacer(); Text("SOURCE") }.font(.system(size: 8, design: .monospaced)).tracking(1.5).foregroundStyle(NX.textSecondary).padding(.horizontal, 18).padding(.vertical, 12)
                        ForEach(items) { item in
                            Button { spotify.play(item) } label: {
                                HStack(spacing: 14) {
                                    artwork(item, size: 42)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        Text(item.artist.isEmpty ? item.kind.capitalized : item.artist).font(.system(size: 10)).foregroundStyle(NX.textSecondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(item.kind.uppercased()).font(.system(size: 8, design: .monospaced)).foregroundStyle(NX.textSecondary)
                                    Image(systemName: "play.circle").font(.system(size: 20)).foregroundStyle(NX.red)
                                }.padding(14).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(spotify.busy)
                            if item.id != items.last?.id { Divider().overlay(NX.cardBorder).padding(.leading, 70) }
                        }
                    }.nxCard()
                }
            }.padding(32)
        }.background(Color(nx: 0x131314)).foregroundStyle(NX.textPrimary)
        .onAppear { audio.refresh(); volume = audio.volume; spotify.refresh(); position = now?.position ?? 0 }
        .onReceive(spotify.$snapshot) { if !seeking { position = $0?.position ?? 0 } }
        .onReceive(audio.$volume) { if !changingVolume { volume = $0 } }
        .sheet(isPresented: $adding) {
            VStack(alignment: .leading, spacing: 18) {
                Text("ADD TO YOUR SHELF").font(NX.ndot(26))
                Text("Paste a Spotify playlist, album or track link. This saves a shortcut, not an audio download.").font(.system(size: 12)).foregroundStyle(NX.textSecondary)
                TextField("Name", text: $title).textFieldStyle(.roundedBorder)
                TextField("https://open.spotify.com/…", text: $link).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { adding = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save link") { if spotify.addLink(name:title,link:link) { adding = false; title = ""; link = "" } }.keyboardShortcut(.defaultAction)
                }
                Text(spotify.status).font(.system(size: 10)).foregroundStyle(NX.textSecondary)
            }.padding(28).frame(width: 440)
        }
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text("LISTEN / 03").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(NX.textSecondary)
                Text("YOUR ROTATION").font(NX.ndot(34))
            }
            Spacer()
            Button { spotify.openSpotify() } label: { Label("OPEN SPOTIFY", systemImage:"arrow.up.right") }.buttonStyle(PodPillButton())
        }
    }
    private var player: some View {
        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 28) {
                artwork(now?.item, size: 190)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 7) {
                        Circle().fill(now?.state == "playing" ? Color.green : NX.textSecondary).frame(width: 5,height: 5)
                        Text(now == nil ? "SPOTIFY PLAYER" : now?.state == "playing" ? "NOW PLAYING · SPOTIFY" : "PAUSED · SPOTIFY")
                            .font(.system(size: 8, design: .monospaced)).tracking(1.5).foregroundStyle(NX.textSecondary)
                    }
                    Text(now?.item.title ?? "PRESS PLAY.\nFIND YOUR FLOW.").font(now == nil ? NX.ndot(28) : .system(size: 26,weight:.semibold)).lineLimit(3).fixedSize(horizontal: false,vertical:true)
                    Text(now?.item.artist ?? "Your music. Your buds. One place.").font(.system(size: 13)).foregroundStyle(NX.textSecondary).lineLimit(2)
                    if let album = now?.item.album, !album.isEmpty { Text(album).font(.system(size: 10)).foregroundStyle(NX.textSecondary).lineLimit(1) }
                    if spotify.enabled {
                        Button { spotify.saveCurrent() } label: { Label("SAVE TO SHELF", systemImage:"plus.circle") }.buttonStyle(PodPillButton()).disabled(now?.item.uri.isEmpty != false)
                    } else {
                        Button { spotify.connect() } label: { Label("CONNECT SPOTIFY", systemImage:"link") }.buttonStyle(PodPillButton(filled:true)).disabled(spotify.busy)
                    }
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
            if now != nil {
                VStack(spacing: 5) {
                    Slider(value:$position,in:0...max(1,now?.duration ?? 1),onEditingChanged:{ editing in seeking = editing; if !editing { spotify.seek(position) } }).tint(NX.red).disabled(spotify.busy).accessibilityLabel("Song progress")
                    HStack { Text(time(position)); Spacer(); Text(time(now?.duration ?? 0)) }.font(.system(size: 9,design:.monospaced)).foregroundStyle(NX.textSecondary)
                }
            }
            HStack(spacing: 22) {
                Button { spotify.setShuffle(!(now?.shuffle ?? false)) } label: { Image(systemName:"shuffle").foregroundStyle(now?.shuffle == true ? NX.red : NX.textSecondary) }.buttonStyle(.plain).accessibilityLabel("Toggle Spotify shuffle").disabled(now == nil || spotify.busy)
                Spacer()
                Button { spotify.command("previous track") } label: { Image(systemName:"backward.end.fill").font(.system(size:20)) }.buttonStyle(.plain).accessibilityLabel("Previous song").disabled(now == nil || spotify.busy)
                Button { spotify.command("playpause") } label: {
                    Image(systemName:now?.state == "playing" ? "pause.fill" : "play.fill").font(.system(size:22)).foregroundStyle(Color.black).frame(width:54,height:54).background(Circle().fill(NX.red))
                }.buttonStyle(.plain).accessibilityLabel(now?.state == "playing" ? "Pause Spotify" : "Play Spotify").disabled(now == nil || spotify.busy)
                Button { spotify.command("next track") } label: { Image(systemName:"forward.end.fill").font(.system(size:20)) }.buttonStyle(.plain).accessibilityLabel("Next song").disabled(now == nil || spotify.busy)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName:"speaker.wave.2").foregroundStyle(NX.textSecondary)
                    Slider(value:$volume,in:0...1,onEditingChanged:{ editing in changingVolume=editing; if !editing { audio.setVolume(volume) } }).frame(width:90).tint(NX.red).disabled(!audio.volumeAvailable).accessibilityLabel("Mac output volume")
                }
            }
        }.padding(26).nxCard()
    }
    private func artwork(_ item: PodSpotifyItem?, size: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors:[NX.red.opacity(0.24),NX.track],startPoint:.topLeading,endPoint:.bottomTrailing)
            PodDotField()
            Image(systemName: item?.kind == "playlist" ? "music.note.list" : "music.note").font(.system(size:size*0.28,weight:.light)).foregroundStyle(NX.red)
            if let raw=item?.artwork,let url=URL(string:raw),url.scheme=="https" {
                AsyncImage(url:url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
            }
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size>100 ? 16 : 7)).accessibilityLabel(item == nil ? "Music artwork placeholder" : "Cover artwork")
    }
    private func time(_ seconds:Double)->String { let s=Int(max(0,seconds));return String(format:"%d:%02d",s/60,s%60) }
}
struct PodMusicQuickPlayer: View {
    @ObservedObject var music = PodSpotify.shared
    var body: some View {
        if let now = music.snapshot {
            HStack {
                VStack(alignment:.leading,spacing:4) { Text(now.item.title).font(.system(size:11,weight:.medium)).lineLimit(1);Text(now.item.artist).font(.system(size:9)).foregroundStyle(NX.textSecondary).lineLimit(1) }
                Spacer()
                Button { music.command("playpause") } label: { Image(systemName:now.state == "playing" ? "pause.fill" : "play.fill") }.buttonStyle(.borderless).accessibilityLabel("Toggle Spotify playback").disabled(music.busy)
            }.padding(.vertical,8)
        }
    }
}
