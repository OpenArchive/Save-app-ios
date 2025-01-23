//
//  AppIcon.swift
//  Save
//
//  Created by navoda on 2025-01-21.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUICore


enum AppIcon: CaseIterable {
  case `default`
  case updateOne
  
  var name: String? {
    switch self {
    case .default:
      return nil
    case .updateOne:
      return "AppIcon-Update-1"
    }
  }
  
  var description: String {
    switch self {
    case .default:
      return "Default"
    case .updateOne:
      return "Alternative Icon"
    }
  }
  
  var icon: Image {
    switch self {
    case .default:
      return Image("AppIcon-Icon")
    case .updateOne:
      return Image("AppIcon-Update-1-Icon")
    }
  }
}

extension AppIcon {
    init(from name: String) {
        switch name {
        case "AppIcon-Update-1": self = .updateOne
        default: self = .default
        }
    }
}
