// Pod Studio profile data and device-report validation. GPL-3.0, 2026-11-15.
import Foundation

struct PodListeningProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var deviceAddress: String
    var deviceName: String
    var outputUID: String
    var inputUID: String
    var inputName: String
    var volume: Double
    var protectMusic: Bool
    var settings: PodEarbudSettings
    var createdAt = Date()
}
struct PodEarbudSettings: Codable, Equatable {
    var anc: UInt8
    var eq: UInt8
    var advanced: Bool
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    func matches(_ other: Self) -> Bool {
        guard anc == other.anc, advanced == other.advanced else { return false }
        if advanced { return abs(bass-other.bass) < 0.1 && abs(mid-other.mid) < 0.1 && abs(treble-other.treble) < 0.1 }
        return eq == other.eq
    }
}
struct PodProfileReadback {
    var anc: UInt8?
    var eq: UInt8?
    var advanced: Bool?
    var gains: (Float, Float, Float)?
    var settings: PodEarbudSettings? {
        guard let anc, let eq, let advanced else { return nil }
        if advanced, gains == nil { return nil }
        return PodEarbudSettings(anc: anc, eq: eq, advanced: advanced, bass: gains?.0 ?? 0, mid: gains?.1 ?? 0, treble: gains?.2 ?? 0)
    }
    // Only CRC-valid complete read responses are evidence. SET acknowledgements,
    // cached entities and unsolicited updates never confirm a profile.
    mutating func ingest(_ packet: [UInt8], token: UInt8, listeningModeEQ: Bool = false) {
        guard packet.count >= 10, packet[0] == 0x55, packet[7] == token else { return }
        let length = Int(packet[5]) | Int(packet[6]) << 8
        guard packet.count == 10 + length else { return }
        let payload = Array(packet[8..<(8+length)])
        let expected = UInt16(packet[packet.count-2]) | UInt16(packet[packet.count-1]) << 8
        let frameCRC = CRC16.crc16(buffer: Array(packet.dropLast(2)))
        // B172 firmware 1.0.1.74 was observed live using a payload-only
        // checksum on replies. Keep this fallback restricted to that model path.
        let cmfPayloadCRC = listeningModeEQ && CRC16.crc16(buffer: payload) == expected
        guard frameCRC == expected || cmfPayloadCRC else { return }
        let command = UInt16(packet[3]) | UInt16(packet[4]) << 8
        switch command {
        case Commands.READ_ANC_TWO.rawValue:
            guard payload.count >= 2, [1,2,3,4,5,7].contains(payload[1]) else { return }
            anc = payload[1]
        case Commands.READ_EQ_ONE.rawValue:
            guard !listeningModeEQ, let code = payload.first else { return }; eq = code
        case Commands.READ_EQ_TWO.rawValue:
            guard let code = payload.first else { return }
            if listeningModeEQ {
                guard code <= 6 else { return }
                eq = code; advanced = code == 6
            } else { eq = code }
        case Commands.READ_ADVANCED_EQ.rawValue, 0x402c:
            guard let mode = payload.first, mode <= 1 else { return }; advanced = mode == 1
        case Commands.READ_CUSTOM_EQ.rawValue, 0x4024:
            guard length >= 36 else { return }
            func float(_ offset: Int) -> Float {
                let bytes = Array(packet[offset..<(offset+4)])
                return Float(bitPattern: UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
            }
            let bass = float(27), mid = float(40), treble = float(14)
            guard [bass,mid,treble].allSatisfy({ $0.isFinite && abs($0) <= 24 }) else { return }
            gains = (bass,mid,treble)
        default: return
        }
    }
}
extension Notification.Name { static let podProfilePacket = Notification.Name("PodStudio.profilePacket") }
