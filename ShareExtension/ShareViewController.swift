//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Benjamin Erhart on 01.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Social
import MobileCoreServices
import Photos

class ShareViewController: BaseDetailsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add done button.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(done(_:)))

        navigationItem.title = NSLocalizedString("OpenArchive", comment: "The title of the app.")

        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first as? NSItemProvider {

            let resultHandler: AssetFactory.ResultHandler = { asset in
                self.asset = asset

                // Trigger database store.
                self.contentChanged(self.titleTf)

                self.render()
            }

            if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { item, error in
                    if let url = item as? URL,
                        let phasset = self.findPhAsset(url.lastPathComponent) {

                        AssetFactory.create(fromPhasset: phasset, mediaType: kUTTypeImage as String,
                                            resultHandler: resultHandler)
                    }
                }
            }
            else if provider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { item, error in
                    if let url = item as? URL,
                        let phasset = self.findPhAsset(url.lastPathComponent) {

                        AssetFactory.create(fromPhasset: phasset, mediaType: kUTTypeMovie as String,
                                            resultHandler: resultHandler)
                    }
                }
            }
        }
    }

    /**
     Inform the host that we're done, so it un-blocks its UI.
    */
    @objc func done(_ sender: UIBarButtonItem) {
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: Private Methods

    /**
     Try to find the shared image/movie in the PHAsset library, so we can store a reference to that
     instead of the complete binary.

     This, of course, will only work, if the user shared from the "Photos" app. There could be
     collisions, since we search by filename, only.

     - parameter filename: The filename to search for.
     - returns: An eventually found `PHAsset`.
    */
    private func findPhAsset(_ filename: String) -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = true
        fetchOptions.includeAllBurstAssets = true

        let assets = PHAsset.fetchAssets(with: fetchOptions)

        for i in 0 ..< assets.count {
            if let current = assets[i].value(forKey: "filename") as? String {
                if filename == current {
                    return assets[i]
                }
            }
        }

        return nil
    }

}
