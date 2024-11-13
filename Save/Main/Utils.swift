
import UIKit

class Utils {
    static func doesMatchExist(regularExpression: String, inputText: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: regularExpression) else {
            return false
        }
        
        return regex.firstMatch(in: inputText, range: NSRange(location: 0, length: inputText.utf16.count)) != nil
    }
    
    class func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    class func getCameraRollDirectory() -> URL {
        let paths = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    class func getBuildNumber() -> UInt? {
        if let info = Bundle.main.infoDictionary as? Dictionary<String, AnyObject> {
            if let build = info["CFBundleVersion"] as? String {
                return UInt(build)
            }
        }
        
        return nil
    }
    
    class func getVersion(withBuild: Bool = true) -> String {
        var version = "Unknown"
        
        if let info = Bundle.main.infoDictionary as? Dictionary<String, AnyObject> {
            if let v = info["CFBundleShortVersionString"] as? String {
                version = "\(v)"
                
                if withBuild {
                    if let build = info["CFBundleVersion"] as? String {
                        version = version.appending(".\(build)")
                    }
                }
            }
        }
        
        return version
    }
    
    class func doesHaveNotificationPermissions() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings() { (settings) in
                switch (settings.authorizationStatus) {
                    case .notDetermined:
                        continuation.resume(returning: false)
                    case .denied:
                        continuation.resume(returning: false)
                    case .authorized:
                        continuation.resume(returning: true)
                    case .provisional:
                        continuation.resume(returning: true)
                    case .ephemeral:
                        continuation.resume(returning: true)
                    @unknown default:
                        continuation.resume(returning: false)
                }
            }
        }
    }
    
    class func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        
        return nil
    }
    
    class func getMemoryUsedAndDeviceTotalInMegabytes() -> (Float, Float) {
        
        // https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget/19692719#19692719
        // https://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info/27559770#27559770
        
        var used_megabytes: Float = 0
        
        let total_bytes = Float(ProcessInfo.processInfo.physicalMemory)
        let total_megabytes = total_bytes / 1024.0 / 1024.0
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used_bytes: Float = Float(info.resident_size)
            used_megabytes = used_bytes / 1024.0 / 1024.0
        }
        
        return (used_megabytes, total_megabytes)
    }
    
    class func destructure(interval: TimeInterval) -> (days: Int, hours: Int, minutes: Int) {
        let numDays = floor(interval / .day)
        let numHours = floor((interval - (numDays * .day)) / .hour)
        let numMinutes = floor(((interval - (numDays * .day)) - (numHours * .hour)) / .minute)
        return (Int(numDays), Int(numHours), Int(numMinutes))
    }
    
    class func setDarkMode() {
        Utils.setInterfaceStyle(.dark)
    }
    
    class func setLightMode() {
        Utils.setInterfaceStyle(.light)
    }
    
    class func setUnspecifiedMode() {
        Utils.setInterfaceStyle(.unspecified)
    }
    
    class func setInterfaceStyle(_ style: UIUserInterfaceStyle) {
        UIApplication.shared.windows.forEach { window in
            Settings.interfaceStyle = style
            window.overrideUserInterfaceStyle = style
        }
    }
}
