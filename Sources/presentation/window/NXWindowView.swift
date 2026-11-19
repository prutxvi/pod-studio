//
//  NXWindowView.swift
//  Nothing X MacOS
//
//  Root of the full-window interface: sidebar navigation + detail screens.
//

import SwiftUI

enum NXSection: String, CaseIterable, Identifiable {
    case music = "MUSIC"
    case audio = "MAC AUDIO"
    case profiles = "PROFILES"
    case dashboard = "DASHBOARD"
    case equaliser = "EQUALISER"
    case controls = "CONTROLS"
    case findMyBuds = "FIND MY BUDS"
    case earTipFit = "EAR TIP FIT TEST"
    case settings = "SETTINGS"
    case devices = "MY DEVICES" // reached from the sidebar device card, not the nav list

    var id: String { rawValue }
}

struct NXWindowView: View {
    @EnvironmentObject var mainViewModel: MainViewViewModel
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow
    @AppStorage("podAppearance") private var appearance = "cmf"
    @State private var section: NXSection = .music

    private var capabilities: DeviceCapabilities? {
        mainViewModel.nothingDevice.map { DeviceCapabilities.capabilities(for: $0.codename) }
    }

    private var sections: [NXSection] {
        NXSection.allCases.filter {
            switch $0 {
            case .controls, .findMyBuds: return capabilities?.isSingleUnit != true
            case .earTipFit: return capabilities?.supportsEarTipTest == true
            case .devices: return false
            default: return true
            }
        }
    }

    var body: some View {
        Group {
            if mainViewModel.isConnected {
                HStack(spacing: 0) {
                    sidebar
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                TabView {
                    PodMusicScreen().tabItem { Label("Music", systemImage: "music.note") }
                    PodProfilesScreen().tabItem { Label("Profiles", systemImage: "square.stack") }
                    PodAudioScreen().tabItem { Label("Mac audio", systemImage: "waveform") }
                    NXConnectScreen().tabItem { Label("Connect device controls", systemImage: "earbuds") }
                }
            }
        }
        .id(appearance)
        .frame(width: 1120, height: 760)
        .background(Color(nx: 0x131314))
        .tint(NX.red)
        .preferredColorScheme(.dark)
        .onAppear {
            // The connect card's panel sits outside the scene graph
            NXConnectPopupController.shared.openMainWindow = { [openWindow] in openWindow(id: "nothing-x") }
        }
        .onChange(of: mainViewModel.nothingDevice?.codename) { _ in
            // Switching devices can remove the current section from the nav
            if !sections.contains(section) && section != .devices {
                section = .dashboard
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .music: PodMusicScreen()
        case .profiles: PodProfilesScreen()
        case .audio: PodAudioScreen()
        case .dashboard: NXDashboardScreen(section: $section)
        case .equaliser: NXEqualizerScreen()
        case .controls: NXControlsScreen()
        case .findMyBuds: NXFindMyBudsScreen()
        case .earTipFit: NXEarTipTestScreen()
        case .settings: NXSettingsScreen()
        case .devices: NXMyDevicesScreen()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("pod studio").font(NX.ndot(27)).foregroundStyle(NX.textPrimary)
                Text("NOTHING / CMF COMPANION").font(.system(size: 8, design: .monospaced)).tracking(1.8).foregroundStyle(NX.textSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 46).padding(.bottom, 22)
            deviceCard
                .padding(.horizontal, 12)
                .padding(.top, 0)
                .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(sections) { item in
                    navRow(item)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("APPEARANCE").font(.system(size: 9, design: .monospaced)).tracking(1.6).foregroundStyle(NX.textSecondary)
                Picker("Appearance", selection: $appearance) {
                    Text("CMF").tag("cmf")
                    Text("Nothing").tag("nothing")
                }.pickerStyle(.segmented).labelsHidden()
            }.padding(20)
            footer
        }
        .frame(width: 240)
        .frame(maxHeight: .infinity)
        .background(NX.sidebar)
        .overlay(alignment: .trailing) { NX.sidebarBorder.frame(width: 1) }
    }

    private var deviceCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { section = .devices }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    NXBudsImage(codename: mainViewModel.nothingDevice?.codename, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deviceName)
                            .font(NX.ndot(14))
                            .tracking(1)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(NX.textPrimary)
                        HStack(spacing: 6) {
                            Circle().fill(NX.red).frame(width: 5, height: 5)
                            Text("CONNECTED")
                                .font(.system(size: 9))
                                .tracking(1.4)
                                .foregroundColor(NX.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nx: 0x5A5A5C))
                }
                Divider().overlay(NX.deviceCardBorder)
                Text(batteryLine)
                    .font(NX.pixel(10))
                    .tracking(1)
                    .foregroundColor(NX.textSecondary)
            }
            .padding(14)
            .background(NX.deviceCard)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NX.deviceCardBorder))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func navRow(_ item: NXSection) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { section = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: navIcon(item))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(section == item ? NX.red : NX.textSecondary)
                    .frame(width: 22)
                Text(item.rawValue)
                    .font(.system(size: 11))
                    .tracking(1.8)
                    .foregroundColor(section == item ? NX.textPrimary : NX.textTertiary)
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(section == item ? NX.track : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func navIcon(_ item: NXSection) -> String {
        switch item {
        case .music: return "music.note"
        case .profiles: return "square.stack"
        case .audio: return "waveform"
        case .dashboard: return "earbuds"
        case .equaliser: return "slider.vertical.3"
        case .controls: return "hand.tap"
        case .findMyBuds: return "dot.radiowaves.left.and.right"
        case .earTipFit: return "ear"
        case .settings: return "gearshape"
        case .devices: return "square.stack.3d.up"
        }
    }

    private var footer: some View {
        HStack {
            Text("POD STUDIO · \(appVersion)")
                .font(NX.pixel(9))
                .tracking(1.6)
                .foregroundColor(NX.textFaint)
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(NX.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Quit Pod Studio")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { NX.hairline.frame(height: 1) }
    }

    private var deviceName: String {
        mainViewModel.nothingDevice?.nxShortName ?? "NOTHING"
    }

    private var batteryLine: String {
        mainViewModel.nxBatteryLine
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }
}
