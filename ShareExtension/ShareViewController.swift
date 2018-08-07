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

    private lazy var providerOptions = {
        return [NSItemProviderPreferredImageSizeKey: NSValue(cgSize: AssetFactory.thumbnailSize)]
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add done button.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(done(_:)))

        navigationItem.title = NSLocalizedString("OpenArchive", comment: "The title of the app.")

        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first as? NSItemProvider {

            provider.loadPreviewImage(options: providerOptions) { thumbnail, error in
                let completionHandler: NSItemProvider.CompletionHandler = { item, error in
                    if let url = item as? URL {
                        AssetFactory.create(fromFileUrl: url, thumbnail: thumbnail as? UIImage) { asset in
                            self.asset = asset

                            // Trigger database store.
                            self.contentChanged(self.titleTf)

                            self.render()
                        }
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil,
                                      completionHandler: completionHandler)
                }
                else if provider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                    provider.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil,
                                      completionHandler: completionHandler)
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
}
