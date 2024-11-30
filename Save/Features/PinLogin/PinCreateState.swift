//
//  Untitled.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

struct PinCreateState {
    private(set) var pin: String = ""
    private(set) var verifyPin: String = ""
    private(set) var isValid: Bool = false
    private(set) var isPinError: Bool = false
    private(set) var isBusy: Bool = false
    private(set) var pinErrorMessage: String = ""
    
    func copy(
        pin: String? = nil,
        verifyPin: String? = nil,
        isValid: Bool? = nil,
        isPinError: Bool? = nil,
        isBusy: Bool? = nil,
        pinErrorMessage: String? = nil
    ) -> PinCreateState {
        var copy = self
        copy.pin = pin ?? self.pin
        copy.verifyPin = verifyPin ?? self.verifyPin
        copy.isValid = isValid ?? self.isValid
        copy.isPinError = isPinError ?? self.isPinError
        copy.isBusy = isBusy ?? self.isBusy
        copy.pinErrorMessage = pinErrorMessage ?? self.pinErrorMessage
        return copy
    }
    
    struct Bindings {
        // Two-way bindings
        var pin: Binding<String>
        var verifyPin: Binding<String>
        let isValid: Bool
        let isPinError: Bool
        let isBusy: Bool
        let pinErrorMessage: String
    }
}


enum PinCreateAction {
    case SetPin
    case PinSetSuccess
    case PinSetError
    case UpdatePin(_ value: String)
    case UpdateVerifyPin(_ value: String)
    case UpdatePinErrorMessage(String)
    case Cancel
    case Next
}
