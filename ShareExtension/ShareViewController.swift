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

        navigationItem.title = "OpenArchive".localize()

        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first {

            if provider.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                provider.loadPreviewImage(options: providerOptions) { thumbnail, error in
                    provider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { item, error in
                        if let url = item as? URL {
                            AssetFactory.create(fromFileUrl: url, thumbnail: thumbnail as? UIImage) { asset in
                                self.asset = asset

                                // Trigger database store.
                                self.contentChanged(self.titleTf)

                                self.render()
                            }
                        }
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
}
