//
//  Formatters.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class Formatters: NSObject {

    public static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        return formatter
    }()

}
