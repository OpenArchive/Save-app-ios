//
//  UIApplicationExtension.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//
import UIKit

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
