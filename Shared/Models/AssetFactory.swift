//
//  AssetFactory.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices

/**
 Factory class to create `Asset`s.
*/
class AssetFactory {

    /**
     - parameter asset: The created `Asset`.
    */
    typealias ResultHandler = (_ asset: Asset?) -> Void

    static var imageManager = PHImageManager()
    static var thumbnailSize = CGSize(width: 320, height: 240)

    private static var loResOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        return options
    }()

    private static var hiResOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        return options
    }()

    private static var avOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        return options
    }()

    private static let thumbnailOptions = [
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: AssetFactory.thumbnailSize.width
    ] as CFDictionary



    /**
     Create an `Asset` object from a given `PHAsset` object and store it in the database.

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter phasset: The `PHAsset`.
     - parameter collection: The collection the asset will belong to.
     */
    class func create(fromPhasset phasset: PHAsset, _ collection: Collection) {
        load(from: phasset, into: Asset(collection))
    }

    /**
     Reloads the `PHAsset` for a given `Asset`.

     - returns: true, if possible, false if not.
    */
    class func reload(for asset: Asset) -> Bool {
        guard let phassetId = asset.phassetId,
            let phasset = PHAsset.fetchAssets(withLocalIdentifiers: [phassetId], options: nil).firstObject else {
            return false
        }

        load(from: phasset, into: asset)

        return true
    }

    /**
     Load the content of a `PHAsset` and store it with the given `Asset`.

     - parameter phasset: The `PHAsset` to read from.
     - parameter asset: The `Asset` to write to.
    */
    class func load(from phasset: PHAsset, into asset: Asset) {

        // Try to acquire a proper address from metadata.
        Geocoder.shared.fetchAddress(from: phasset) { address in
            if let address = address {
                asset.location = address
                store(asset)
            }
        }

        if phasset.mediaType == .image {
            // Fetch non-resized version first. We need the UTI, the filename and the original
            // image data.

            imageManager.requestImageData(for: phasset, options: hiResOptions) {
                data, uti, orientation, info in

                if let data = data, let uti = uti {
                    asset.uti = uti
                    asset.phassetId = phasset.localIdentifier

                    if let info = info, let fileUrl = info["PHImageFileURLKey"] as? URL {
                        asset.filename = fileUrl.lastPathComponent
                    }

                    if let file = asset.file,
                        createParentDir(file: file) && (try? data.write(to: file)) != nil {

                        fetchThumb(phasset, asset) // asynchronous

                        asset.isReady = true

                        store(asset) // asynchronous
                    }
                }
            }
        }
        else if phasset.mediaType == .video || phasset.mediaType == .audio {
            imageManager.requestAVAsset(forVideo: phasset, options: avOptions) {
                avAsset, audioMix, info in

                if let avAsset = avAsset {
                    let presets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)

                    if presets.count > 0 {
                        imageManager.requestExportSession(forVideo: phasset,
                                                          options: avOptions,
                                                          exportPreset: presets[0])
                        { exportSession, info in
                            let uti: AVFileType = phasset.mediaType == .audio ? .mp3 : .mp4

                            asset.uti = uti.rawValue
                            asset.phassetId = phasset.localIdentifier
                            
                            // Store asset before export, so display of it
                            // isn't displayed too long without notice.
                            // Else it would lead to strange bugs, when users
                            // upload a collection before the asset is ready.
                            fetchThumb(phasset, asset) // asynchronous
                            store(asset) // asynchronous

                            if let exportSession = exportSession,
                                createParentDir(file: asset.file) {

                                exportSession.outputURL = asset.file
                                exportSession.outputFileType = uti

                                exportSession.exportAsynchronously {
                                    switch exportSession.status {
                                    case .unknown, .waiting, .exporting:
                                        break

                                    case .completed:
                                        if let thumb = asset.thumb?.path,
                                            !FileManager.default.fileExists(atPath: thumb) {

                                            createThumb(asset)
                                        }

                                        asset.isReady = true

                                        store(asset)

                                    case .failed, .cancelled:
                                        asset.remove()

                                    @unknown default:
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     Create an `Asset` object from a given `AIAssetUrl` as returned by
     `imagePickerController:didFinishPickingMediaWithInfo` and store it in the database.

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter url: The URL as received in `UIImagePickerControllerReferenceURL`
     - parameter collection: The collection the asset will belong to.
     */
    class func create(fromAlAssetUrl url: URL, _ collection: Collection) {
        if let phasset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {
            create(fromPhasset: phasset, collection)
        }
    }

    /**
     Create an `Asset` object from a given file `URL` and store it in the database.

     Will try to generate a thumbnail from the asset's file, if `thumbnail` is `nil` or could not
     be written to the proper location for whatever reason.

     If an error happened, your `resultHandler` will receive nil as `asset`.

     - parameter url: A file URL.
     - parameter thumbnail: A `UIImage` which represents a thumbnail of this asset.
     - parameter collection: The collection the asset will belong to.
     - parameter resultHandler: Callback with the created `Asset` object.
     */
    class func create(fromFileUrl url: URL, thumbnail: UIImage? = nil,
                      _ collection: Collection, _ resultHandler: @escaping ResultHandler) {
        if let uti = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier {
            let asset = Asset(collection, uti: uti)
            asset.filename = url.lastPathComponent

            if  let file = asset.file, createParentDir(file: file)
                // BEWARE: Using move in the ShareExtension will only work in the simulator!
                && (try? FileManager.default.copyItem(at: url, to: file)) != nil {

                self.fetchLocation(asset)

                if let thumb = asset.thumb,
                    createParentDir(file: thumb) {

                    if let thumbnail = thumbnail {
                        try? thumbnail.jpegData(compressionQuality: 0.5)?.write(to: thumb)
                    }

                    if !FileManager.default.fileExists(atPath: thumb.path) {
                        self.createThumb(asset)
                    }
                }

                store(asset, resultHandler)
            }
            else {
                resultHandler(nil)
            }
        }
        else {
            resultHandler(nil)
        }
    }

    /**
     Fetch a thumbnail image for the given `PHAsset`. Store that thumbnail at the according path
     for the given `Asset`.

     - parameter phasset: The `PHAsset` to fetch the thumbnail from.
     - parameter asset: The `Asset` to store the thumbnail with.
    */
    private class func fetchThumb(_ phasset: PHAsset, _ asset: Asset) {
        imageManager.requestImage(for: phasset, targetSize: thumbnailSize,
                                  contentMode: .default,
                                  options: loResOptions)
        { image, info in

            // If we don't get one, fine. A default will be provided.
            if let image = image, let thumb = asset.thumb,
                createParentDir(file: thumb) {
                try? image.jpegData(compressionQuality: 0.5)?.write(to: thumb)

                if !FileManager.default.fileExists(atPath: thumb.path) {
                    self.createThumb(asset)
                }
            }
        }
    }

    /**
     Fetch address using an images EXIF GPS metadata, if any available.

     - parameter asset: The `Asset` to fetch the address for.
    */
    private class func fetchLocation(_ asset: Asset) {
        if let file = asset.file as CFURL?,
            let source = CGImageSourceCreateWithURL(file, nil),
            let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString : AnyObject],
            let gps = metadata[kCGImagePropertyGPSDictionary] as? [CFString : AnyObject],
            let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
            let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {

            // Try to acquire a proper address from metadata.
            Geocoder.shared.fetchAddress(from: CLLocation(latitude: latitude, longitude: longitude)) { address in
                if let address = address {
                    asset.location = address
                    store(asset)
                }
            }
        }
    }

    /**
     Create a thumbnail for an asset from its file. The file must be already set to its destination
     and be readable, obviously.

     - parameter asset: The `Asset` to read the file from and store the thumbnail with.
    */
    private class func createThumb(_ asset: Asset) {
        if let file = asset.file as CFURL?,
            let thumb = asset.thumb,
            let source = CGImageSourceCreateWithURL(file, nil),
            let cgThumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) {

            let thumbnail = UIImage(cgImage: cgThumbnail)
            try? thumbnail.jpegData(compressionQuality: 0.5)?.write(to: thumb)
        }
    }

    /**
     Create all parent directories, if not there, yet.

     - parameter file: The file, which needs its parent directories available.
     - returns: true, if successful, false, if not.
    */
    private class func createParentDir(file: URL?) -> Bool {
        if var dir = file {
            dir.deleteLastPathComponent()

            return (try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true, attributes: nil)) != nil
        }

        return false
    }

    /**
     Store an asset in the database. When done, call a handler on the main queue.

     - parameter asset: The asset to store.
     - parameter resultHandler: The handler to call after storing.
    */
    private class func store(_ asset: Asset, _ resultHandler: ResultHandler? = nil) {
        Db.writeConn?.asyncReadWrite { transaction in
            transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)

            if let resultHandler = resultHandler {
                DispatchQueue.main.async {
                    resultHandler(asset)
                }
            }
        }
    }
}
