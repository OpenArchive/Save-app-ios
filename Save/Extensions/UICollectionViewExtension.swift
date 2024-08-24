//
//  Created by Richard Puckett on 10/23/23.
//

import UIKit

extension UICollectionView {
    var isTopVisible: Bool {
        get {
            return indexPathsForVisibleItems.first?.row == 0
        }
    }
    
    func getVisibleItems<T>(ofType: T.Type) -> [T] {
        var items: [T] = []
        
        for item in visibleCells {
            if let item = item as? T {
                items.append(item)
            }
        }
        
        return items
    }
    
    func reloadData(_ completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0, animations: { self.reloadData() }, completion: { _ in completion() })
    }
    
    func selectWorkflowView(at index: Int) {
        isPagingEnabled = false
        selectItem(
            at: IndexPath(row: index, section: 0),
            animated: false,
            scrollPosition: .centeredHorizontally)
        isPagingEnabled = true
    }
}
