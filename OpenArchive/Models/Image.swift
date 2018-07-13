//
//  Image.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Photos

class Image: Asset {

    private static var cachingImageManager = PHCachingImageManager()
    private static var thumbnailSize = CGSize(width: 320, height: 240)
    private static var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.version = .current

        return options
    }()

    let id: String
    let filename: String

    /**
     Create an `Image` object from a given `AIAssetUrl` as returned by
     `imagePickerController:didFinishPickingMediaWithInfo`.

     It will try to fetch the according `PHAsset` immediately trigger the caching of a thumbnail
     image for that asset and fetch more info for the asset, so we can evaluate the filename,
     which is needed for later upload.

     You will *only* receive the `resultHandler` callback, if a `PHAsset` can be found and the
     original image for it requested!

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter url: The url as received in `UIImagePickerControllerReferenceURL`
     - parameter resultHandler: Callback with the created `Image` object.
     - parameter image: The created image.
    */
    class func create(fromAlAssetUrl url: URL, resultHandler: @escaping (_ image: Image) -> Void) {
        if let asset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {

            // Immediately kick off thumbnail generation.
            Image.cachingImageManager.startCachingImages(for: [asset],
                                                         targetSize: Image.thumbnailSize,
                                                         contentMode: .default,
                                                         options: Image.requestOptions)

            // Fetch non-resized version, so we can get to the "info" array ASAP.
            Image.cachingImageManager.requestImageData(for: asset, options: Image.requestOptions) {
                data, uti, orientation, info in

                let mimeType = Asset.getMimeType(uti: uti)

                var filename: String

                if let info = info,
                    let fileUrl = info["PHImageFileURLKey"] as? URL {

                    filename = fileUrl.lastPathComponent
                }
                else {
                    // If we really don't get this, create an arbitrary filename using a UUID
                    // and assume JPEG, as that's the normal type.
                    let ext = Asset.getFileExt(uti: uti) ?? "JPG"
                    filename = "\(UUID().uuidString).\(ext)"
                }

                resultHandler(Image(id: asset.localIdentifier, filename: filename,
                                    mimeType: mimeType, created: nil))
            }
        }
    }

    private init(id: String, filename: String, mimeType: String, created: Date?) {
        self.id = id
        self.filename = filename

        super.init(created: created, mimeType: mimeType)
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        self.id = decoder.decodeObject() as! String
        self.filename = decoder.decodeObject() as! String

        super.init(coder: decoder)
    }

    override func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(filename)

        super.encode(with: coder)
    }

    /**
     Fetch a thumbnail from a PHCachingImageManager which is suitable for general UI presentation.

     - parameter resultHandler: A block to be called when image loading is complete, providing the
       requested image or information about the status of the request.
     - parameter image: The `UIImage` thumbnail.
     - parameter info: A dictionary providing information about the status of the request.
    */
    func fetchThumbnail(_ resultHandler: @escaping (_ image: UIImage?, _ info: [AnyHashable : Any]?) -> Void) {
        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            Image.cachingImageManager.requestImage(for: asset, targetSize: Image.thumbnailSize,
                                                   contentMode: .default,
                                                   options: Image.requestOptions,
                                                   resultHandler: resultHandler)
        }
    }

    /**
     Fetch the original data stream of an image usable for uploading to a service.

     - parameter resultHandler: A block to be called when image loading is complete, providing the
       requested image or information about the status of the request.
     - parameter imageData: The requested image.
     - parameter dataUTI: The requested image.
     - parameter orientation: The intended display orientation for the image.
     - parameter info: A dictionary providing information about the status of the request.
    */
    func fetchData(_ resultHandler: @escaping (_ imageData: Data?, _ dataUTI: String?, _ orientation: UIImageOrientation, _ info: [AnyHashable : Any]?) -> Void) {

        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true

            Image.cachingImageManager.requestImageData(for: asset,
                                                   options: options,
                                                   resultHandler: resultHandler)
        }
    }
}
