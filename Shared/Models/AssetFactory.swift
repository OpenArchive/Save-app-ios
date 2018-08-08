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
    typealias ResultHandler = (_ asset: Asset) -> Void

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

    private static var videoOptions: PHVideoRequestOptions = {
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
     Create an `Asset` object from a given `PHAsset` object.

     You will *only* receive the `resultHandler` callback, if the original image or a video export
     can be processed successfully!

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter phasset: The `PHAsset`.
     - parameter mediaType: The media type. (e.g. `kUTTypeImage`)
     - parameter resultHandler: Callback with the created `Asset` object.
     */
    class func create(fromPhasset phasset: PHAsset, mediaType: String, resultHandler: @escaping ResultHandler) {
        if mediaType == kUTTypeImage as String {
            // Fetch non-resized version first. We need the UTI, the filename and the original
            // image data.

            imageManager.requestImageData(for: phasset, options: hiResOptions) {
                data, uti, orientation, info in

                if let data = data, let uti = uti {
                    let asset = Asset(uti: uti)

                    if let info = info, let fileUrl = info["PHImageFileURLKey"] as? URL {
                        asset.filename = fileUrl.lastPathComponent
                    }

                    if let file = asset.file,
                        createParentDir(file: file) && (try? data.write(to: file)) != nil {

                        fetchThumb(phasset, asset, resultHandler)
                    }
                }
            }
        }
        else if mediaType == kUTTypeMovie as String {
            imageManager.requestAVAsset(forVideo: phasset, options: videoOptions) {
                avAsset, audioMix, info in

                if let avAsset = avAsset {
                    let presets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)

                    if presets.count > 0 {
                        imageManager.requestExportSession(forVideo: phasset,
                                                          options: videoOptions,
                                                          exportPreset: presets[0])
                        { exportSession, info in
                            let asset = Asset(uti: kUTTypeMPEG4 as String)

                            if let exportSession = exportSession,
                                createParentDir(file: asset.file) {

                                exportSession.outputURL = asset.file
                                exportSession.outputFileType = .mp4

                                exportSession.exportAsynchronously {
                                    if exportSession.status == .completed {
                                        fetchThumb(phasset, asset, resultHandler)
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
     `imagePickerController:didFinishPickingMediaWithInfo`.

     You will *only* receive the `resultHandler` callback, if a `PHAsset` can be found and the
     original image or a video export can be processed successfully!

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter url: The URL as received in `UIImagePickerControllerReferenceURL`
     - parameter mediaType: The media type. (e.g. `kUTTypeImage`)
     - parameter resultHandler: Callback with the created `Asset` object.
     */
    class func create(fromAlAssetUrl url: URL, mediaType: String, resultHandler: @escaping ResultHandler) {
        if let phasset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {
            create(fromPhasset: phasset, mediaType: mediaType, resultHandler: resultHandler)
        }
    }

    /**
     Create an `Asset` object from a given file `URL`.

     Will try to generate a thumbnail from the asset's file, if `thumbnail` is `nil` or could not
     be written to the proper location for whatever reason.

     You will *only* receive the `resultHandler` callback, if the given file can be successfully
     *moved* to its new location inside the app!

     - parameter url: A file URL.
     - parameter thumbnail: A `UIImage` which represents a thumbnail of this asset.
     - parameter resultHandler: Callback with the created `Asset` object.
     */
    class func create(fromFileUrl url: URL, thumbnail: UIImage?, resultHandler: @escaping ResultHandler) {
        if let uti = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier {
            let asset = Asset(uti: uti)
            asset.filename = url.lastPathComponent

            if  let file = asset.file,
                createParentDir(file: file) &&
                    // BEWARE: Move will only work in Simulator!
                    (try? FileManager.default.copyItem(at: url, to: file)) != nil {

                if let thumb = asset.thumb,
                    createParentDir(file: thumb) {

                    if let thumbnail = thumbnail {
                        try? UIImageJPEGRepresentation(thumbnail, 0.5)?.write(to: thumb)
                    }

                    if !FileManager.default.fileExists(atPath: thumb.path) {
                        self.createThumb(asset)
                    }
                }

                resultHandler(asset)
            }
        }
    }

    /**
     Create an `Asset` object from a given file `URL`.

     Will try to generate a thumbnail from the asset's file.

     You will *only* receive the `resultHandler` callback, if the given file can be successfully
     *moved* to its new location inside the app!

     - parameter url: A file URL.
     - parameter resultHandler: Callback with the created `Asset` object.
     */
    class func create(fromFileUrl url: URL, resultHandler: @escaping ResultHandler) {
        create(fromFileUrl: url, thumbnail: nil, resultHandler: resultHandler)
    }

    /**
     Fetch a thumbnail image for the given `PHAsset`. Store that thumbnail at the according path
     for the given `Asset` and call the resultHandler, when done, regardless, if the thumbnail could
     be fetched or not.

     - parameter phasset: The `PHAsset` to fetch the thumbnail from.
     - parameter asset: The `Asset` to store the thumbnail with.
     - parameter resultHandler: Callback with the created `Asset` object.
    */
    private class func fetchThumb(_ phasset: PHAsset, _ asset: Asset, _ resultHandler: @escaping ResultHandler) {
        imageManager.requestImage(for: phasset, targetSize: thumbnailSize,
                                  contentMode: .default,
                                  options: loResOptions)
        { image, info in

            // If we don't get one, fine. A default will be provided.
            if let image = image, let thumb = asset.thumb,
                createParentDir(file: thumb) {
                try? UIImageJPEGRepresentation(image, 0.5)?.write(to: thumb)

                if !FileManager.default.fileExists(atPath: thumb.path) {
                    self.createThumb(asset)
                }
            }

            resultHandler(asset)
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
            try? UIImageJPEGRepresentation(thumbnail, 0.5)?.write(to: thumb)
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

            return (try? FileManager.default.createDirectory(at: dir,
                                                             withIntermediateDirectories: true,
                                                             attributes: nil)) != nil
        }

        return false
    }
}
