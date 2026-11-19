import Foundation
func packet(_ command: UInt16, _ payload: [UInt8], token: UInt8 = 0x81) -> [UInt8] {
    var data: [UInt8] = [0x55,0x60,1,UInt8(command & 255),UInt8(command >> 8),UInt8(payload.count),0,token] + payload
    let crc = CRC16.crc16(buffer: data)
    data += [UInt8(crc & 255),UInt8(crc >> 8)]
    return data
}
@main struct ProfileChecks {
    static func main() throws {
        var state = PodProfileReadback()
        state.ingest(packet(0x401e,[1,1],token:0x80),token:0x81)
        precondition(state.anc == nil, "stale token accepted")
        var broken = packet(0x401e,[1,1]); broken[9] = 5
        state.ingest(broken,token:0x81)
        precondition(state.anc == nil, "bad CRC accepted")
        state.ingest(Array(packet(0x401e,[1,1]).dropLast()),token:0x81)
        precondition(state.anc == nil, "partial packet accepted")
        state.ingest(packet(0x7004,[1,1]),token:0x81)
        precondition(state.anc == nil, "SET acknowledgement accepted as readback")
        state.ingest(packet(0x401e,[1,1]),token:0x81)
        state.ingest(packet(0x401f,[5,0]),token:0x81)
        precondition(state.settings == nil, "missing advanced-EQ state was assumed")
        state.ingest(packet(Commands.READ_ADVANCED_EQ.rawValue,[0,0]),token:0x81)
        var actualCMF = PodProfileReadback()
        func bytes(_ hex: String) -> [UInt8] { stride(from:0,to:hex.count,by:2).map { i in let a=hex.index(hex.startIndex,offsetBy:i);let b=hex.index(a,offsetBy:2);return UInt8(hex[a..<b],radix:16)! } }
        actualCMF.ingest(bytes("5560011e400600810201000101006c69"),token:0x81,listeningModeEQ:true)
        actualCMF.ingest(bytes("5560015040010081017e80"),token:0x81,listeningModeEQ:true)
        precondition(actualCMF.settings?.eq == 1 && actualCMF.settings?.anc == 1, "live-captured B172 payload checksums rejected")
        var badCMF = PodProfileReadback()
        badCMF.ingest(bytes("5560011e400600810205000101006c69"),token:0x81,listeningModeEQ:true)
        precondition(badCMF.anc == nil, "corrupt CMF payload accepted")
        badCMF.ingest(bytes("5560011e400600810201000101006c69"),token:0x82,listeningModeEQ:true)
        precondition(badCMF.anc == nil, "stale CMF reply accepted")
        print("PASS: live-captured CMF replies, payload CRC, corruption and stale-token rejection")
        var cmf = PodProfileReadback()
        cmf.ingest(packet(0x401e,[1,1]),token:0x81,listeningModeEQ:true)
        cmf.ingest(packet(0x401f,[1]),token:0x81,listeningModeEQ:true)
        precondition(cmf.settings == nil, "generic EQ response confirmed a CMF listening-mode preset")
        cmf.ingest(packet(0x4050,[5]),token:0x81,listeningModeEQ:true)
        precondition(cmf.settings?.eq == 5 && cmf.settings?.advanced == false, "CMF listening-mode reply rejected")
        var cmfCustomMode = PodProfileReadback()
        cmfCustomMode.ingest(packet(0x401e,[1,1]),token:0x81,listeningModeEQ:true)
        cmfCustomMode.ingest(packet(0x4050,[6]),token:0x81,listeningModeEQ:true)
        precondition(cmfCustomMode.settings == nil, "custom CMF profile confirmed without gains")
        precondition(state.settings?.anc == 1 && state.settings?.eq == 5, "raw CMF preset lost")
        precondition(!state.settings!.matches(PodEarbudSettings(anc:5,eq:5,advanced:false)), "ANC mismatch confirmed")
        precondition(!state.settings!.matches(PodEarbudSettings(anc:1,eq:2,advanced:false)), "EQ mismatch confirmed")
        print("PASS: fresh token, CRC, complete frame and real readback required")
        print("PASS: missing state and mismatched ANC/EQ cannot confirm")
        var custom = PodProfileReadback()
        custom.ingest(packet(0x401e,[1,7]),token:0x81)
        custom.ingest(packet(0x401f,[6,0]),token:0x81)
        custom.ingest(packet(Commands.READ_ADVANCED_EQ.rawValue,[1,0]),token:0x81)
        precondition(custom.settings == nil, "custom EQ confirmed without gains")
        var payload = [UInt8](repeating:0,count:36)
        func put(_ value: Float, at index: Int) { let b=value.bitPattern; for i in 0..<4 { payload[index+i]=UInt8((b >> (8*i)) & 255) } }
        put(1.5,at:6);put(-2,at:19);put(0.5,at:32)
        custom.ingest(packet(Commands.READ_CUSTOM_EQ.rawValue,payload),token:0x81)
        var cmfCustom = custom
        cmfCustom.gains = nil
        cmfCustom.ingest(packet(0x4024,payload),token:0x81)
        precondition(cmfCustom.settings?.bass == -2, "live-observed CMF custom-EQ reply rejected")
        precondition(custom.settings!.matches(PodEarbudSettings(anc:7,eq:6,advanced:true,bass:-2,mid:0.5,treble:1.5)))
        precondition(!custom.settings!.matches(PodEarbudSettings(anc:7,eq:6,advanced:true,bass:0,mid:0.5,treble:1.5)))
        print("PASS: custom EQ needs fresh gains and correct values")
        let profile = PodListeningProfile(name:"Focus",deviceAddress:"test-device",deviceName:"Test buds",outputUID:"test-output",inputUID:"test-input",inputName:"Test microphone",volume:0.42,protectMusic:true,settings:custom.settings!)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try JSONEncoder().encode([profile]).write(to:temporary,options:.atomic)
        let decoded = try JSONDecoder().decode([PodListeningProfile].self,from:Data(contentsOf:temporary))
        precondition(decoded == [profile], "profile roundtrip lost settings")
        print("PASS: saved profile roundtrip preserves identity, routes, volume and custom EQ")
    }
}
