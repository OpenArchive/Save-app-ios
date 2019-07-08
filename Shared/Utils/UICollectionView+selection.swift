//
//  UICollectionView+selection.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

extension UICollectionView {

    /**
     Evaluates the number of currently selected items.

     - returns: The number of currently selected items.
     */
    var numberOfSelectedItems: Int {
        return indexPathsForSelectedItems?.count ?? 0
    }

    /**
     Selects all items in the specified section and optionally scrolls them into view.

     If the allowsSelection property is false, calling this method has no effect.
     If there is an existing selection with a different index path and the
     allowsMultipleSelection property is false, calling this method replaces the previous selection.
     This method does not cause any selection-related delegate methods to be called.

     - parameter section: The section of the items to select.
     - parameter animated: Specify true to animate the changes in the selection or
        false to make the changes without animating it.
     - parameter scrollPosition:  An option that specifies where the items should
        be positioned when scrolling finishes.
    */
    func selectSection(_ section: Int, animated: Bool, scrollPosition: UICollectionView.ScrollPosition) {
        for i in 0 ... numberOfItems(inSection: section) - 1 {
            selectItem(at: IndexPath(item: i, section: section), animated: animated, scrollPosition: scrollPosition)
        }
    }

    /**
     Deselects all items of the specified section.

     If the allowsSelection property is false, calling this method has no effect.
     This method does not cause any selection-related delegate methods to be called.


     - parameter section: The section of the items to deselect.
     - parameter animated: Specify true to animate the changes in the selection or
        false to make the changes without animating it.
    */
    func deselectSection(_ section: Int, animated: Bool) {
        for i in 0 ... numberOfItems(inSection: section) - 1 {
            deselectItem(at: IndexPath(item: i, section: section), animated: animated)
        }
    }

    /**
     Tests, if all items in a section are selected.

     - parameter section: The section to test.
     - returns: true, if all items in that section are selected, false if not.
    */
    func isSectionSelected(_ section: Int) -> Bool {
        let numberOfItems = self.numberOfItems(inSection: section)

        guard numberOfItems > 0,
            let selectedItems = indexPathsForSelectedItems else {
            return false
        }

        return selectedItems.filter { $0.section == section }.count == numberOfItems
    }
}
