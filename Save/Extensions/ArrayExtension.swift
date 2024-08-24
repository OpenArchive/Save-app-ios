//
//  Created by Richard Puckett on 4/2/23.
//

import Foundation

extension Array where Element: Comparable {
    func containsSameElements(as other: [Element]) -> Bool {
        return self.count == other.count && self.sorted() == other.sorted()
    }
    
    var indexOfMinElement: Int? {
        guard count > 0 else { return nil }
        var min = first
        var index = 0
        indices.forEach { i in
            let currentItem = self[i]
            if let minumum = min, currentItem < minumum {
                min = currentItem
                index = i
            }
        }
        return index
    }
}

extension Array where Element: Equatable {
    func containedBy(array: [Element]) -> Bool {
        return self.allSatisfy(array.contains)
    }
}

extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}
