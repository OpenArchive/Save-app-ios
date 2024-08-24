//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options) {
        self.init()
        self.formatOptions = formatOptions
    }
}

extension Formatter {
    static let iso8601 = ISO8601DateFormatter([.withInternetDateTime])
}

extension Date {
    
    static var tomorrow:  Date { return Date().dayAfter }
    static var yesterday: Date { return Date().dayBefore }
    
    var iso8601: String { return Formatter.iso8601.string(from: self) }
    
    var millisecondsSince1970: Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    func asFriendlyTimestamp() -> String {
        let dateFormatter = DateFormatter()
        
        if Calendar.current.isDateInToday(self) {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
            return "Today at " + dateFormatter.string(from: self)
        } else if Calendar.current.isDateInYesterday(self) {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
            return "Yesterday at "  + dateFormatter.string(from: self)
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("d MMMM, YYYY - hh:mm")
            return dateFormatter.string(from: self)
        }
    }
    
    func dateToString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    var isMidnight: Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return components.hour == 0 && components.minute == 0
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: startOfDay)
        return Calendar.current.date(from: components)!
    }
    
    var dayBefore: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }
    
    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    
    var month: Int {
        return Calendar.current.component(.month, from: self)
    }
    
    var isLastDayOfMonth: Bool {
        return dayAfter.month != month
    }
    
    static func - (recent: Date, previous: Date) -> (month: Int?, day: Int?, hour: Int?, minute: Int?, second: Int?, nanosecond: Int?) {
        let day = Calendar.current.dateComponents([.day], from: previous, to: recent).day
        let month = Calendar.current.dateComponents([.month], from: previous, to: recent).month
        let hour = Calendar.current.dateComponents([.hour], from: previous, to: recent).hour
        let minute = Calendar.current.dateComponents([.minute], from: previous, to: recent).minute
        let second = Calendar.current.dateComponents([.second], from: previous, to: recent).second
        let nanosecond = Calendar.current.dateComponents([.nanosecond], from: previous, to: recent).nanosecond
        
        return (month: month, day: day, hour: hour, minute: minute, second: second, nanosecond: nanosecond)
    }
    
}
