//
//  DarkroomHelper.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class DarkroomHelper {
   
    private static let locPlaceholder = NSLocalizedString("Add a location (optional)", comment: "")
    private static let notesPlaceholder = NSLocalizedString("Add notes (optional)", comment: "")

    let delegate: InfoBoxDelegate
    let location: InfoBox?
    let notes: InfoBox?
    
    
    init(_ delegate: InfoBoxDelegate, _ superview: UIView) {
        self.delegate = delegate
   
        location = InfoBox.instantiate("ic_location", superview)
        location?.delegate = delegate
        
        notes = InfoBox.instantiate("ic_edit", superview)
        notes?.delegate = delegate
    
        location?.addConstraints(superview, top: nil)
        
        notes?.addConstraints(superview, top: location)
        location?.nextResponderField = notes?.textView
        
    }
    
    
    // MARK: Public Methods
    
    func setInfos(_ asset: Asset?, defaults: Bool = false, isEditable: Bool = true,_ noteHeight: CGFloat) {
        // Preserve text in fields that are currently being edited
        let locationText = location?.textView.isFirstResponder ?? false ? location?.textView.text : asset?.location
        let notesText = notes?.textView.isFirstResponder ?? false ? notes?.textView.text : asset?.notes
        
        location?.set(locationText, with: defaults ? DarkroomHelper.locPlaceholder : nil, textHeightContraint: nil, hideIcon: true)
        location?.textView.isEditable = isEditable
        
        notes?.set(notesText, with: defaults ? DarkroomHelper.notesPlaceholder : nil, textHeightContraint: noteHeight, hideIcon: true)
        notes?.textView.isEditable = isEditable
      
    }
    
    func getFirstResponder() -> (infoBox: InfoBox?, value: String?) {
     
        if location?.textView.isFirstResponder ?? false {
            return (location, location?.textView.text)
        }
        
        if notes?.textView.isFirstResponder ?? false {
            return (notes, notes?.textView.text)
        }
        
        return (nil, nil)
    }
    
    func assign(_ info: (infoBox: InfoBox?, value: String?)?) -> ((_ asset: AssetProxy) -> Void)? {
        switch  info?.infoBox {
        case nil:
            return nil
         
        case location:
            return { asset in
                asset.location = info?.value
            }
            
        case notes:
            return { asset in
                asset.notes = info?.value
            }
            
        default:
            return nil
        }
    }
 

}
