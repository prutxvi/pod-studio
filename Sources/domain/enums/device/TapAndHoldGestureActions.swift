//
//  TapAndHoldGestureActions.swift
//  Nothing X MacOS
//
//  Created by Daniel on 2025/3/7.
//

import Foundation
enum TapAndHoldGestureActions : UInt8, Codable {
    case NOISE_CONTROL = 10
    case NO_EXTRA_ACTION = 1
    case VOICE_ASSISTANT = 11
    case VOLUME_UP = 18
    case VOLUME_DOWN = 19
    case NOISE_CONTROL_ANC_OFF = 20
    case NOISE_CONTROL_TRANS_OFF = 21
    case NOISE_CONTROL_ANC_TRANS = 22

    var isNoiseControl: Bool {
        switch self {
        case .NOISE_CONTROL, .NOISE_CONTROL_ANC_OFF, .NOISE_CONTROL_TRANS_OFF, .NOISE_CONTROL_ANC_TRANS:
            return true
        default:
            return false
        }
    }

    /// Returns (anc, transparency, off) booleans for the noise control cycle
    var ancCycleState: (anc: Bool, transparency: Bool, off: Bool) {
        switch self {
        case .NOISE_CONTROL:
            return (true, true, true)
        case .NOISE_CONTROL_ANC_OFF:
            return (true, false, true)
        case .NOISE_CONTROL_TRANS_OFF:
            return (false, true, true)
        case .NOISE_CONTROL_ANC_TRANS:
            return (true, true, false)
        default:
            return (true, true, true)
        }
    }

    /// Creates action from cycle booleans. Requires at least 2 selected.
    static func fromCycleState(anc: Bool, transparency: Bool, off: Bool) -> TapAndHoldGestureActions {
        switch (anc, transparency, off) {
        case (true, false, true):
            return .NOISE_CONTROL_ANC_OFF
        case (false, true, true):
            return .NOISE_CONTROL_TRANS_OFF
        case (true, true, false):
            return .NOISE_CONTROL_ANC_TRANS
        default:
            return .NOISE_CONTROL
        }
    }
}
