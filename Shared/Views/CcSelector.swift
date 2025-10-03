//
//  CcSelector.swift
//  Save
//
//  Created by Benjamin Erhart on 09.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import Eureka

import Eureka

class CcSelector {
    
    static let ccDomain = "creativecommons.org"
    static let ccUrl = "https://%@/licenses/%@/4.0/"
    static let cc0Url = "https://creativecommons.org/publicdomain/zero/1.0/"
    var isUpdatingValues = false
    lazy var ccSw = SwitchRow("cc") {
        $0.title = individual
        ? NSLocalizedString("Set creative commons licenses for folders on this server.", comment: "")
        : NSLocalizedString("Set the same Creative Commons license for ALL folders on this server.", comment: "")
        $0.cell.backgroundColor = .clear
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent
        $0.cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }
    
    lazy var cc0Sw = SwitchRow("cc0") {
        $0.title = NSLocalizedString("Waive all restrictions, requirements, and attribution (CC0).", comment: "")
        $0.cell.backgroundColor = .clear
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent
        $0.cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }
    
    lazy var remixSw = SwitchRow("remixSw") {
        $0.title = NSLocalizedString("Allow anyone to remix and share?", comment: "")
        
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.backgroundColor = .clear
        $0.cell.switchControl.onTintColor = .accent
        $0.cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }
    
    lazy var shareAlikeSw = SwitchRow() {
        $0.title = NSLocalizedString("Require them to share like you have?", comment: "")
        
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.backgroundColor = .clear
        $0.cell.switchControl.onTintColor = .accent
        $0.cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc", "remixSw"], { [weak self] _ in
            !(self?.enabled ?? false) || !(self?.remixSw.value ?? false)
        })
    }
    
    lazy var commercialSw = SwitchRow() {
        $0.title = NSLocalizedString("Allow commercial use?", comment: "")
        
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.backgroundColor = .clear
        $0.cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
        $0.cell.switchControl.onTintColor = .accent
        
        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }
    
    let licenseRow = LinkRow() {
        $0.cell.textLabel?.adjustsFontSizeToFitWidth = true
        $0.cell.backgroundColor = .clear
        $0.hidden = "$cc != true"
    }.cellUpdate { cell, row in
        cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
    }
    
    let learnMoreRow = LinkRow() {
        $0.title = NSLocalizedString("Learn more about Creative Commons.", comment: "")
        $0.value = URL(string: "https://creativecommons.org/about/cclicenses/")
        $0.cell.backgroundColor = .clear
        $0.cell.textLabel?.numberOfLines = 0
        
    }.cellUpdate { cell, row in
        cell.textLabel?.font = .montserrat(forTextStyle: .subheadline)
    }
    
    
    private let individual: Bool
    
    private var enabled = true
    
    
    init(individual: Bool) {
        self.individual = individual
    }
    
    
    // MARK: Methods
    
    func set(_ license: String?, enabled: Bool = true) {
        if let license = license, license.localizedCaseInsensitiveContains(Self.ccDomain) {
            ccSw.value = true
            
            if license.localizedCaseInsensitiveContains("publicdomain/zero") {
                cc0Sw.value = true
                remixSw.value = false
                shareAlikeSw.value = false
                commercialSw.value = false
            } else {
                cc0Sw.value = false
                remixSw.value = !license.localizedCaseInsensitiveContains("-nd")
                shareAlikeSw.value = !shareAlikeSw.isDisabled && license.localizedCaseInsensitiveContains("-sa")
                commercialSw.value = !license.localizedCaseInsensitiveContains("-nc")
                
                // If any other toggle is on, make sure CC0 is off
                if remixSw.value == true || shareAlikeSw.value == true || commercialSw.value == true {
                    cc0Sw.value = false
                }
            }
            
            licenseRow.title = license
            licenseRow.value = URL(string: license)
        }
        else {
            ccSw.value = false
            cc0Sw.value = false
        }
        
        self.enabled = enabled
        ccSw.evaluateDisabled()
        cc0Sw.evaluateDisabled()
        remixSw.evaluateDisabled()
        shareAlikeSw.evaluateDisabled()
        commercialSw.evaluateDisabled()
    }
    
    func get() -> String? {
        var license: String? = nil
        
        if ccSw.value ?? false {
            if cc0Sw.value ?? false {
                // CC0 license
                license = Self.cc0Url
            } else {
                // Regular CC license
                license = "by"
                
                if remixSw.value ?? false {
                    if !(commercialSw.value ?? false) {
                        license! += "-nc"
                    }
                    
                    if shareAlikeSw.value ?? false {
                        license! += "-sa"
                    }
                } else {
                    shareAlikeSw.value = false
                    
                    if !(commercialSw.value ?? false) {
                        license! += "-nc"
                    }
                    
                    license! += "-nd"
                }
                
                license = String(format: Self.ccUrl, Self.ccDomain, license!)
            }
        }
        
        licenseRow.title = license
        licenseRow.value = license != nil ? URL(string: license!) : nil
        licenseRow.updateCell()
        
        return license
    }
    
    func handleCC0Toggle() {
        guard !isUpdatingValues else { return }
        
        if cc0Sw.value ?? false {
            isUpdatingValues = true
            
            remixSw.value = false
            shareAlikeSw.value = false
            commercialSw.value = false
            
            (remixSw.cell)?.switchControl.setOn(false, animated: true)
            (shareAlikeSw.cell)?.switchControl.setOn(false, animated: true)
            (commercialSw.cell)?.switchControl.setOn(false, animated: true)
            
            isUpdatingValues = false
        }
    }
    
    func handleOtherToggle() {
        guard !isUpdatingValues else { return }
        
        if remixSw.value == true || shareAlikeSw.value == true || commercialSw.value == true {
            isUpdatingValues = true
            
            cc0Sw.value = false
            (cc0Sw.cell)?.switchControl.setOn(false, animated: true)
            
            isUpdatingValues = false
        }
    }
}
