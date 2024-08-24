//
//  Created by Richard Puckett on 5/30/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension String {
    func camelCased(with separator: Character = "_") -> String {
        return self.lowercased()
            .split(separator: separator)
            .enumerated()
            .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() }
            .joined()
    }
    
    func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }
    
    func base64Decoded() -> Data? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return data
    }
    
    func asDate() -> Date? {
        ISO8601DateFormatter().date(from: self)
    }
    
    func asDateString() -> String {
        guard let date = self.asDate() else {
            return "Unknown"
        }
        
        return date.asFriendlyTimestamp()
    }
    
    func levenshteinDistanceScore(to string: String, ignoreCase: Bool = true, trimWhiteSpacesAndNewLines: Bool = true) -> Double {
        let separators = CharacterSet(charactersIn: " /")
        let componentScore = components(separatedBy: separators).reduce(0) { max($0, levenshteinBetweenWords(word1: String($1), word2: string)) }
        let wholeWordScore = levenshteinBetweenWords(word1: self, word2: string)
        return max(componentScore, wholeWordScore)
    }
    
    func levenshteinBetweenWords(word1: String, word2: String) -> Double {
        if word1.isEmpty || word2.isEmpty { return 0 }
        if word1 == "[none]" || word2 == "[none]" { return 0 }
        
        var firstString = word1
        var secondString = word2
        
        firstString = firstString.lowercased().trimmingCharacters(in: .alphanumerics.inverted)
        secondString = secondString.lowercased().trimmingCharacters(in: .alphanumerics.inverted)
        
        // log.debug("firstString = \(firstString)")
        
        let empty = [Int](repeating:0, count: secondString.count)
        var last = [Int](0...secondString.count)
        
        for (i, tLett) in firstString.enumerated() {
            var cur = [i + 1] + empty
            for (j, sLett) in secondString.enumerated() {
                cur[j + 1] = tLett == sLett ? last[j] : Swift.min(last[j], last[j + 1], cur[j])+1
            }
            last = cur
        }
        
        // maximum string length between the two
        let lowestScore = max(firstString.count, secondString.count)
        
        if let validDistance = last.last {
            return  1 - (Double(validDistance) / Double(lowestScore))
        }
        
        return 0.0
    }
    
    func localize() -> String {
        return NSLocalizedString(self, comment: "")
    }
    
    func padLeft(totalWidth: Int, byString:String) -> String {
        let toPad = totalWidth - self.count
        
        if toPad < 1 {
            return self
        }
        
        return "".padding(toLength: toPad, withPad: byString, startingAt: 0) + self
    }
    
    func save(at directory: FileManager.SearchPathDirectory,
              pathAndImageName: String,
              createSubdirectoriesIfNeed: Bool = true) -> URL? {
        do {
            let documentsDirectory = try FileManager.default.url(for: directory, in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: false)
            return save(at: documentsDirectory.appendingPathComponent(pathAndImageName),
                        createSubdirectoriesIfNeed: createSubdirectoriesIfNeed)
        } catch {
            print("-- Error: \(error)")
            return nil
        }
    }
    
    func save(at url: URL,
              createSubdirectoriesIfNeed: Bool = true) -> URL? {
        do {
            if createSubdirectoriesIfNeed {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            }
            try self.write(to: url, atomically: true, encoding: String.Encoding.utf8)
            return url
        } catch {
            log.warning("\(error)")
            return nil
        }
    }
    
    func loadPNG() -> UIImage? {
        let uri = Utils.getDocumentsDirectory().appendingPathComponent(self)
        return UIImage(fileURLWithPath: uri)
    }
    
    func stringByAddingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~?"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: unreserved)
        return addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
    }
    
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        return sizeOfString(usingFont: font).width
    }
    
    func heightOfString(usingFont font: UIFont) -> CGFloat {
        return sizeOfString(usingFont: font).height
    }
    
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin],
            attributes: [NSAttributedString.Key.font: font],
            context: nil)
        return ceil(boundingBox.height)
    }
    
    func sizeOfString(usingFont font: UIFont) -> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: fontAttributes)
    }
}
