// Pod Studio additions, 2026-11-15. GPL-3.0.
import SwiftUI
struct PodAudioScreen: View {
    @EnvironmentObject var device: MainViewViewModel
    @ObservedObject var audio = PodAudio.shared
    @State private var level: Double = 0
    @State private var adjustingVolume = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                hero
                HStack(alignment: .top, spacing: 16) {
                    routing.frame(maxWidth: .infinity)
                    protection.frame(width: 250)
                }
                volume
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").padding(.top, 1)
                    Text(audio.message.isEmpty ? "Music mode uses your Mac microphone. Earbud ANC and EQ are in Device and Equaliser. Sample rate describes the connection, not how good the audio sounds." : audio.message)
                        .fixedSize(horizontal: false, vertical: true)
                }.font(.system(size: 11)).foregroundStyle(NX.textSecondary)
            }.padding(32)
        }.background(Color(nx: 0x131314)).foregroundStyle(NX.textPrimary)
        .onAppear { audio.refresh(); level = audio.volume }
        .onReceive(audio.$volume) { if !adjustingVolume { level = $0 } }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SOUND / 01").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(NX.textSecondary)
                Text("MAC AUDIO").font(NX.ndot(36)).tracking(1)
            }
            Spacer()
            Button { audio.refresh() } label: { Label("REFRESH", systemImage: "arrow.clockwise") }.buttonStyle(PodPillButton())
        }
    }
    private var hero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) {
                    Circle().fill(audio.isMusic ? NX.red : NX.textSecondary).frame(width: 6, height: 6)
                    Text(audio.isPodsOutput ? "EARBUDS CONNECTED" : "MAC OUTPUT").font(.system(size: 9, design: .monospaced)).tracking(1.8).foregroundStyle(NX.textSecondary)
                }
                Text(audio.isMusic ? "READY TO\nGET LOST." : "MAKE IT\nSOUND RIGHT.")
                    .font(NX.ndot(32)).tracking(1).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 0) {
                    metric("CHANNELS", audio.channels == 2 ? "STEREO" : audio.channels == 1 ? "MONO" : "—")
                    metric("SAMPLE RATE", audio.rate > 0 ? String(format: "%.1f kHz", audio.rate / 1000) : "—")
                }
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(NX.cardBorder, lineWidth: 1).frame(width: 204, height: 204)
                Circle().stroke(NX.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [2, 5])).frame(width: 178, height: 178)
                PodDotField().frame(width: 158, height: 158).clipShape(Circle())
                NXBudsImage(codename: device.nothingDevice?.codename, height: 154)
            }.frame(width: 210, height: 210).accessibilityLabel(device.nothingDevice?.name ?? "Audio device")
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading).nxCard()
    }
    private var routing: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("LISTENING SETUP").font(.system(size: 10, design: .monospaced)).tracking(1.8)
                Spacer()
                Image(systemName: "arrow.triangle.branch").foregroundStyle(NX.red)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("SOUND OUTPUT").font(.system(size: 9, design: .monospaced)).foregroundStyle(NX.textSecondary)
                Picker("Sound output", selection: Binding(get: { audio.output }, set: { audio.setDevice($0, input: false); audio.refresh() })) {
                    ForEach(audio.devices.filter(\.output)) { Text($0.name).tag($0.id) }
                }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().overlay(NX.cardBorder)
            VStack(alignment: .leading, spacing: 6) {
                Text("MICROPHONE").font(.system(size: 9, design: .monospaced)).foregroundStyle(NX.textSecondary)
                Picker("Microphone", selection: Binding(get: { audio.input }, set: { audio.setDevice($0, input: true); audio.refresh() })) {
                    ForEach(audio.devices.filter(\.input)) { Text($0.name).tag($0.id) }
                }.labelsHidden().disabled(audio.protect && audio.isPodsOutput).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(22).frame(height: 240, alignment: .top).nxCard()
    }
    private var protection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MUSIC GUARD").font(.system(size: 10, design: .monospaced)).tracking(1.4)
                Spacer()
                Toggle("Music guard", isOn: $audio.protect).labelsHidden().toggleStyle(.switch).tint(NX.red)
            }
            Text(audio.protect ? "LESS FUSS.\nMORE MUSIC." : "YOUR MIC.\nYOUR CALL.")
                .font(NX.ndot(22)).lineSpacing(3)
            Text("Keeps the Mac microphone selected when your buds reconnect. Works while this app is open; apps may override it.")
                .font(.system(size: 11)).foregroundStyle(NX.textSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { audio.musicMode() } label: {
                HStack { Text("USE MUSIC MODE"); Spacer(); Image(systemName: "arrow.up.right") }
            }.buttonStyle(PodPillButton(filled: true))
        }.padding(22).frame(height: 240, alignment: .top).nxCard()
    }
    private var volume: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("VOLUME").font(.system(size: 9, design: .monospaced)).tracking(1.6).foregroundStyle(NX.textSecondary)
                Text(audio.volumeAvailable ? "\(Int(level * 100))%" : "—")
                    .font(NX.ndot(32)).foregroundStyle(NX.red).frame(width: 88, alignment: .leading)
            }
            Image(systemName: "speaker.wave.1").foregroundStyle(NX.textSecondary)
            Slider(value: $level, in: 0...1, onEditingChanged: { editing in
                adjustingVolume = editing
                if !editing { audio.setVolume(level) }
            }).disabled(!audio.volumeAvailable).tint(NX.red).accessibilityLabel("Output volume")
            Image(systemName: "speaker.wave.3").foregroundStyle(NX.textSecondary)
        }.padding(22).nxCard()
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 8, design: .monospaced)).tracking(1.2).foregroundStyle(NX.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
        }.frame(width: 130, alignment: .leading)
    }
}
