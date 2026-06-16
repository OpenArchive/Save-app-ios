//
//  IaCooldownLog.swift
//  Save
//
//  DEBUG logging for IA 503 cooldown — filter Xcode console with "IaCooldown".
//

import Foundation

enum IaCooldownLog {

    static func log(
        _ event: String,
        minutes: Int? = nil,
        remainingSec: Int? = nil,
        pendingIa503: Int? = nil,
        reason: String? = nil
    ) {
#if DEBUG
        var parts: [String] = []
        if let minutes { parts.append("minutes=\(minutes)") }
        if let remainingSec { parts.append("remainingSec=\(remainingSec)") }
        if let pendingIa503 { parts.append("pendingIa503=\(pendingIa503)") }
        if let reason, !reason.isEmpty { parts.append("reason=\(reason)") }
        let details = parts.isEmpty ? "" : " " + parts.joined(separator: " ")
        print("[IaCooldown] \(event)\(details)")
#endif
    }
}
