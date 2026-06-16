//
//  UploadMemoryLog.swift
//  Save
//
//  DEBUG logging for upload count vs memory — filter Xcode console with "UploadMemory".
//

import Foundation

enum UploadMemoryLog {

    struct Context {
        var sessionStarted: Int = 0
        var sessionCompleted: Int = 0
        var sessionFailed: Int = 0
        var pendingUploads: Int = 0
        var filename: String?
        var fileSizeKB: Int64?
        var backend: String?
        var inBackground: Bool = false

        fileprivate var detailParts: [String] {
            var parts: [String] = []
            if sessionStarted > 0 { parts.append("started=\(sessionStarted)") }
            if sessionCompleted > 0 { parts.append("completed=\(sessionCompleted)") }
            if sessionFailed > 0 { parts.append("failed=\(sessionFailed)") }
            if pendingUploads > 0 { parts.append("pending=\(pendingUploads)") }
            if let filename, !filename.isEmpty { parts.append("file=\(filename)") }
            if let fileSizeKB, fileSizeKB > 0 { parts.append("sizeKB=\(fileSizeKB)") }
            if let backend, !backend.isEmpty { parts.append("backend=\(backend)") }
            if inBackground { parts.append("background=1") }
            return parts
        }
    }

    /// Log resident memory and optional upload counters. Only prints in DEBUG builds.
    static func log(_ event: String, _ context: Context = Context()) {
#if DEBUG
        let memory = residentMemoryMB()
        let details = context.detailParts.joined(separator: " ")
        if details.isEmpty {
            print("[UploadMemory] \(event) mem=\(String(format: "%.1f", memory))MB")
        } else {
            print("[UploadMemory] \(event) mem=\(String(format: "%.1f", memory))MB \(details)")
        }
#endif
    }

    static func pendingUploadCount() -> Int {
        var count = 0
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, _: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }
                count += 1
            }
        }
        return count
    }

    private static func residentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.resident_size) / 1024 / 1024
    }
}
