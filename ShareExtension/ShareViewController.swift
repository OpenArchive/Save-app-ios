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
import YapDatabase

class ShareViewController: SLComposeServiceViewController {

    lazy var writeConn: YapDatabaseConnection? = {
        Db.setup()

        return Db.newConnection()
    }()

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first as? NSItemProvider {

            if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { item, error in
                    if let url = item as? URL {
                        let (id, mimeType) = self.findPhAsset(url.lastPathComponent)

                        if let id = id, let mimeType = mimeType {
                            let image = Image(id: id,
                                              filename: url.lastPathComponent,
                                              mimeType: mimeType,
                                              created: nil)

                            self.writeConn?.asyncReadWrite() { transaction in
                                transaction.setObject(image, forKey: image.getKey(), inCollection: Asset.COLLECTION)
                            }
                        }
                    }
                }
            }
            else if provider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { item, error in
                    if let url = item as? URL {
                        let (id, mimeType) = self.findPhAsset(url.lastPathComponent)

                        if let id = id, let mimeType = mimeType {
                            let movie = Movie(id: id,
                                              filename: url.lastPathComponent,
                                              mimeType: mimeType,
                                              created: nil)

                            self.writeConn?.asyncReadWrite() { transaction in
                                transaction.setObject(movie, forKey: movie.getKey(), inCollection: Asset.COLLECTION)
                            }
                        }
                    }
                }
            }
        }

        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    // MARK: Private Methods

    /**
     Try to find the shared image/movie in the PHAsset library, so we can store a reference to that
     instead of the complete binary.

     This, of course, will only work, if the user shared from the "Photos" app. There could be
     collisions, since we search by filename, only.

     - parameter filename: The filename to search for.
     - returns: A tupel containing the localIdentifier of the asset and the MIME type.
    */
    private func findPhAsset(_ filename: String) -> (id: String?, mimeType: String?) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = true
        fetchOptions.includeAllBurstAssets = true

        let assets = PHAsset.fetchAssets(with: fetchOptions)

        for i in 0 ..< assets.count {
            if let current = assets[i].value(forKey: "filename") as? String {
                if filename == current {
                    let resources = PHAssetResource.assetResources(for: assets[i])

                    if resources.count > 0 {
                        return (assets[i].localIdentifier,
                                Asset.getMimeType(uti: resources[0].uniformTypeIdentifier))
                    }
                }
            }
        }

        return (nil, nil)
    }

}
