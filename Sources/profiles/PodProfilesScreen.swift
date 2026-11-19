// Listening profiles UI. GPL-3.0, 2026-11-15.
import SwiftUI
struct PodProfilesScreen: View {
    @ObservedObject var store = PodProfiles.shared
    @State private var name = "My music"
    @State private var renaming: PodListeningProfile?
    @State private var renameText = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LISTENING / 02").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(NX.textSecondary)
                        Text("YOUR PROFILES").font(NX.ndot(34))
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3").font(.system(size: 28)).foregroundStyle(NX.red)
                }
                VStack(alignment: .leading, spacing: 15) {
                    Text("ONE CLICK. YOUR SETUP.").font(NX.ndot(24))
                    Text("Set your noise control, EQ, microphone and volume, then save them together. Every application is checked against fresh readings from the earbuds and your Mac.")
                        .font(.system(size: 12)).foregroundStyle(NX.textSecondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        TextField("Profile name", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("New profile name").onSubmit { store.saveCurrent(name: name) }
                        Button { store.saveCurrent(name: name) } label: { Label("SAVE CURRENT", systemImage: "plus") }.buttonStyle(PodPillButton(filled: true))
                    }.disabled(store.busy)
                }.padding(24).nxCard()
                status
                if store.profiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "square.stack").font(.system(size: 28)).foregroundStyle(NX.red)
                        Text("NOTHING SAVED. YET.").font(NX.ndot(23))
                        Text("Your real setup goes here. Connect your earbuds, choose your settings and save your first profile above.").font(.system(size: 12)).foregroundStyle(NX.textSecondary)
                    }.padding(28).frame(maxWidth: .infinity, alignment: .leading).nxCard()
                }
                ForEach(store.profiles) { profile in profileCard(profile) }
                Text("Profiles are stored locally and belong to the earbuds they were saved from. Applying can partially change settings if the connection fails. Confirmation checks reported settings; it does not measure audible quality.")
                    .font(.system(size: 11)).foregroundStyle(NX.textSecondary).fixedSize(horizontal: false, vertical: true)
            }.padding(32)
        }.background(Color(nx: 0x131314)).foregroundStyle(NX.textPrimary)
        .sheet(item: $renaming) { profile in
            VStack(alignment: .leading, spacing: 20) {
                Text("RENAME PROFILE").font(NX.ndot(24))
                TextField("Name", text: $renameText).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { renaming = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save name") { store.rename(profile, name: renameText); renaming = nil }.keyboardShortcut(.defaultAction)
                }
            }.padding(28).frame(width: 380)
        }
    }
    private var status: some View {
        HStack(alignment: .top, spacing: 12) {
            if store.busy { ProgressView().controlSize(.small) }
            else { Image(systemName: store.result == "confirmed" ? "checkmark.circle.fill" : store.result == "failed" ? "exclamationmark.circle" : "info.circle").foregroundStyle(store.result == "confirmed" ? Color.green : NX.red) }
            Text(store.status).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true).accessibilityLabel("Profile status: \(store.status)")
            Spacer(minLength: 0)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(NX.track).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func profileCard(_ profile: PodListeningProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name).font(.system(size: 21, weight: .medium))
                    Text(profile.deviceName.uppercased()).font(.system(size: 9, design: .monospaced)).tracking(1.3).foregroundStyle(NX.textSecondary)
                }
                Spacer()
                if store.lastApplied == profile.id { Label("LAST CONFIRMED", systemImage: "checkmark.circle").font(.system(size: 9, design: .monospaced)).foregroundStyle(NX.red) }
                Button { renameText = profile.name; renaming = profile } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).help("Rename \(profile.name)").accessibilityLabel("Rename \(profile.name)").disabled(store.busy)
            }
            HStack(alignment: .top, spacing: 18) {
                detail("NOISE CONTROL", noiseName(profile.settings.anc))
                detail("EARBUD EQ", profile.settings.advanced ? "Custom 3-band" : "Saved device preset")
                detail("VOLUME", "\(Int(profile.volume * 100))%")
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.inputName).font(.system(size: 11))
                    Text(profile.protectMusic ? "Music Guard on" : "Music Guard off").font(.system(size: 10)).foregroundStyle(NX.textSecondary)
                }
                Spacer()
                Button { store.apply(profile) } label: { Label("APPLY & CHECK", systemImage: "arrow.up.right") }.buttonStyle(PodPillButton(filled: true)).disabled(store.busy)
            }
        }.padding(24).nxCard()
    }
    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(NX.textSecondary)
            Text(value).font(.system(size: 12, weight: .medium))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func noiseName(_ code: UInt8) -> String {
        guard let anc = ANC(rawValue: code) else { return "Unavailable" }
        return anc.isNoiseCancellationActive ? "ANC · \(anc.displayName)" : anc.displayName
    }
}
struct PodProfilesQuickMenu: View {
    @ObservedObject var store = PodProfiles.shared
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                if store.profiles.isEmpty { Text("Save your first profile in the app") }
                ForEach(store.profiles) { profile in
                    Button(profile.name) { store.apply(profile) }.disabled(store.busy)
                }
            } label: { Label("Listening profiles", systemImage: "square.stack") }.disabled(store.profiles.isEmpty || store.busy)
            if store.busy { ProgressView("Checking profile…").controlSize(.small) }
            else if store.result != "idle" { Text(store.status).font(.system(size: 10)).foregroundStyle(NX.textSecondary).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
