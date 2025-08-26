//
//  PinLoginFeature.swift
//  Save
//
//  Created by navoda on 2024-11-30.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Factory


extension Container {
    var passcodeSetupViewModel: Factory<PasscodeSetupViewModel> {
        self {
            PasscodeSetupViewModel()
        }
    }
}
