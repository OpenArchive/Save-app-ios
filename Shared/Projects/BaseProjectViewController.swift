//
//  BaseProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class BaseProjectViewController: FormViewController {

    private static let invalidChars: CharacterSet = {
        var invalid = CharacterSet(charactersIn: ":/\\")
        invalid.formUnion(.newlines)
        invalid.formUnion(.illegalCharacters)
        invalid.formUnion(.controlCharacters)

        return invalid
    }()

    var project: Project

    let nameRow = TextRow() {
        $0.placeholder = "Name your project".localize()
        $0.cell.textField.accessibilityIdentifier = "tfProjectName"

        let ruleFilename = RuleClosure<String> { value in
            return (value ?? "").rangeOfCharacter(from: invalidChars) != nil
                ? ValidationError(msg: "Invalid character contained.") // Is not displayed currently.
                : nil
        }

        $0.add(rule: RuleRequired())
        $0.add(rule: ruleFilename)
        $0.validationOptions = .validatesAlways
    }


    init(_ project: Project) {
        self.project = project

        super.init()
    }

    required init?(coder decoder: NSCoder) {
        project = decoder.decodeObject() as! Project

        super.init(coder: decoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        form.validate()
        enableDone()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: Actions

    @objc func connect() {
        if let spaceId = project.spaceId,
            let name = nameRow.value {

            let alert = DuplicateProjectAlert(nil)

            if alert.exists(spaceId: spaceId, name: name) {
                present(alert, animated: true)
                return
            }
        }
        else {
            return
        }

        project.name = nameRow.value

        store()

        dismiss(animated: true)
    }


    // MARK: Private Methods

    func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = nameRow.isValid
    }

    func store() {
        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(self.project, forKey: self.project.id,
                                  inCollection: Project.collection)
        }
    }
}
