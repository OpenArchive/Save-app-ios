//
//  RuleFilename.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Eureka

/**
 Eureka rule to ensure a field contains a valid filename.
 */
class RuleFilename: RuleType {

    private static let invalidChars: CharacterSet = {
        var invalid = CharacterSet(charactersIn: ":/\\")
        invalid.formUnion(.newlines)
        invalid.formUnion(.illegalCharacters)
        invalid.formUnion(.controlCharacters)

        return invalid
    }()

    typealias RowValueType = String

    var id: String? = nil

    /*
     msg is not displayed currently, so no localization and no user-friendly wording.
    */
    var validationError: ValidationError = ValidationError(msg: "Not a valid filename.")

    func isValid(value: String?) -> ValidationError? {
        let value = value ?? ""

        if value.trimmingCharacters(in: .whitespacesAndNewlines).count < 1 {
            return validationError
        }

        return value.rangeOfCharacter(from: RuleFilename.invalidChars) != nil
            ? validationError
            : nil
    }
}
