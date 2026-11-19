import Foundation
import CoreAudio
@main struct AudioSmoke {
    static func main() {
        let audio = PodAudio.shared
        audio.refresh()
        precondition(audio.devices.contains { $0.id == audio.output && $0.output }, "Output enumeration failed")
        precondition(audio.devices.contains { $0.id == audio.input && $0.input }, "Input enumeration failed")
        precondition(audio.channels > 0 && audio.rate > 0, "No active audio format")
        print("PASS: audio devices, default routes and stream format")
        print("Output: \(audio.devices.first { $0.id == audio.output }!.name); \(audio.channels) channels; \(audio.rate) Hz")
        if audio.volumeAvailable {
            let original = audio.volume
            audio.setVolume(max(0, original - 0.05))
            let changed = audio.volume
            audio.setVolume(original)
            precondition(abs(changed - max(0, original - 0.05)) < 0.02, "Volume did not change")
            precondition(abs(audio.volume - original) < 0.02, "Volume was not restored")
            print("PASS: hardware volume roundtrip and restoration")
        } else { print("SKIP: hardware volume unavailable") }
        audio.musicMode(); audio.refresh()
        precondition(audio.protect, "Music protection not saved")
        precondition(audio.devices.contains { $0.id == audio.input && $0.builtIn }, "Built-in microphone not selected")
        print("PASS: music preset and saved protection")
    }
}
