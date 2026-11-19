// Pod Studio additions, 2026-11-15. GPL-3.0, see LICENSE.
import SwiftUI
import CoreAudio

struct PodAudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let input: Bool
    let output: Bool
    let builtIn: Bool
}
final class PodAudio: ObservableObject {
    static let shared = PodAudio()
    @Published var devices: [PodAudioDevice] = []
    @Published var input: AudioDeviceID = 0
    @Published var output: AudioDeviceID = 0
    @Published var rate: Double = 0
    @Published var channels: UInt32 = 0
    @Published var volume: Double = 0
    @Published var volumeAvailable = false
    @Published var message = ""
    @Published var protect: Bool = UserDefaults.standard.bool(forKey: "podMusicProtection") {
        didSet { UserDefaults.standard.set(protect, forKey: "podMusicProtection"); refresh() }
    }
    private var timer: Timer?
    private var enforcing = false
    private var volumeElements: [UInt32] = []
    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func scalar<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, element: UInt32 = 0, initial: T) -> T? {
        var a = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }
    func hasChannels(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: 0)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr, size > 0 else { return false }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, buffer) == noErr else { return false }
        return UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self)).contains { $0.mNumberChannels > 0 }
    }
    var isPodsOutput: Bool {
        let name = devices.first { $0.id == output }?.name.lowercased() ?? ""
        return name.contains("cmf") || name.contains("nothing")
    }
    var isMusic: Bool { isPodsOutput && channels == 2 && rate >= 44100 }
    func refresh() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr else { return }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return }
        devices = ids.compactMap { id in
            var n = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
            var value: CFString = "" as CFString
            var s = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(id, &n, 0, nil, &s, &value) == noErr else { return nil }
            let transport = scalar(id, kAudioDevicePropertyTransportType, initial: UInt32(0)) ?? 0
            var u = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
            var uid: CFString = "" as CFString
            var us = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(id, &u, 0, nil, &us, &uid) == noErr else { return nil }
            return PodAudioDevice(id: id, name: value as String, uid: uid as String, input: hasChannels(id, scope: kAudioDevicePropertyScopeInput), output: hasChannels(id, scope: kAudioDevicePropertyScopeOutput), builtIn: transport == kAudioDeviceTransportTypeBuiltIn)
        }
        input = scalar(system, kAudioHardwarePropertyDefaultInputDevice, initial: AudioDeviceID(0)) ?? 0
        output = scalar(system, kAudioHardwarePropertyDefaultOutputDevice, initial: AudioDeviceID(0)) ?? 0
        let format = scalar(output, kAudioDevicePropertyStreamFormat, scope: kAudioDevicePropertyScopeOutput, initial: AudioStreamBasicDescription())
        rate = format?.mSampleRate ?? 0; channels = format?.mChannelsPerFrame ?? 0
        func canSetVolume(_ element: UInt32) -> Bool {
            var va = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            var writable: DarwinBoolean = false
            return AudioObjectIsPropertySettable(output, &va, &writable) == noErr && writable.boolValue
        }
        volumeElements = canSetVolume(0) ? [0] : (canSetVolume(1) && canSetVolume(2) ? [1, 2] : [])
        let levels: [Float32] = volumeElements.compactMap { scalar(output, kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: $0, initial: Float32(0)) }
        volumeAvailable = !levels.isEmpty
        volume = levels.isEmpty ? 0 : Double(levels.reduce(0,+)) / Double(levels.count)
        if protect && isPodsOutput && !enforcing, let builtIn = devices.first(where: { $0.input && $0.builtIn }), input != builtIn.id {
            enforcing = true
            setDevice(builtIn.id, input: true)
            enforcing = false
        }
    }
    func setDevice(_ id: AudioDeviceID, input: Bool) {
        var a = AudioObjectPropertyAddress(mSelector: input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var value = id
        let err = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &value)
        message = err == noErr ? "\(input ? "Microphone" : "Sound output") updated." : "macOS could not change this device (\(err))."
        if err == noErr { if input { self.input = id } else { output = id } }
    }
    func musicMode() {
        if let buds = devices.first(where: { $0.output && ($0.name.lowercased().contains("cmf") || $0.name.lowercased().contains("nothing")) }) { setDevice(buds.id, input: false) }
        guard let mic = devices.first(where: { $0.input && $0.builtIn }) else { message = "No built-in microphone is available."; return }
        setDevice(mic.id, input: true)
        protect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refresh() }
    }
    func setVolume(_ value: Double) {
        for element in volumeElements {
            var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            var v = Float32(max(0, min(1, value)))
            let err = AudioObjectSetPropertyData(output, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
            if err != noErr { message = "Volume is controlled by the selected device (\(err))." }
        }
        refresh()
    }
}
