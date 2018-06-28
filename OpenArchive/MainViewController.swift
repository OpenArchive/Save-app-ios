//
//  MainViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class MainViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func add(_ sender: UIBarButtonItem) {
        print("Add pressed!")
    }

}

