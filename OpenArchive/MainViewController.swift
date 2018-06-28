//
//  MainViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import MobileCoreServices

class MainViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    lazy var imagePicker: UIImagePickerController = {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeImage as String]
        imagePicker.modalPresentationStyle = .popover

        return imagePicker
    }()

    lazy var images = [UIImage]()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: actions

    @IBAction func add(_ sender: UIBarButtonItem) {
        imagePicker.popoverPresentationController?.barButtonItem = sender
        present(imagePicker, animated: true)
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageCell
        
        cell.img.image = images[indexPath.row]

        return cell
    }

    // MARK: UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage ??
            info[UIImagePickerControllerOriginalImage] as? UIImage
        {
            images.append(image)

            dismiss(animated: true, completion: nil)

            tableView.reloadData()
            tableView.scrollToRow(at: IndexPath(row: images.count - 1, section: 0),
                                  at: UITableViewScrollPosition.bottom, animated: true)
        }
    }
}

