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
                        createParentDir(file: file),
                        (try? data.write(to: file)) != nil {

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

                                var isExporting = true

                                exportSession.exportAsynchronously {
                                    switch exportSession.status {
                                    case .completed:
                                        fallthrough
                                    case .failed:
                                        fallthrough
                                    case .cancelled:
                                        isExporting = false
                                    default:
                                        break
                                    }
                                }

                                while isExporting {
                                    sleep(1)
                                }

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

    /**
     Create an `Asset` object from a given `AIAssetUrl` as returned by
     `imagePickerController:didFinishPickingMediaWithInfo`.

     You will *only* receive the `resultHandler` callback, if a `PHAsset` can be found and the
     original image or a video export can be processed successfully!

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter url: The url as received in `UIImagePickerControllerReferenceURL`
     - parameter mediaType: The media type. (e.g. `kUTTypeImage`)
     - parameter resultHandler: Callback with the created `Asset` object.
     */
    class func create(fromAlAssetUrl url: URL, mediaType: String, resultHandler: @escaping ResultHandler) {
        if let phasset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {
            create(fromPhasset: phasset, mediaType: mediaType, resultHandler: resultHandler)
        }
    }

    /**
     Fetch a thumbnail image for the given `PHAsset`. Store that thumbnail at the according path
     for the given `Asset` and call the resultHandler, when done, regardless, if the thumbnail could
     be fetched or not.

     - parameter phasset: The `PHAsset` to fetch the thumbnail from.
     - parameter asset: The `Asset` to store the thumbnail with.
     - parameter resultHandler: Callback with the created `Image` object.
     - parameter asset: The created `Asset`.
    */
    private class func fetchThumb(_ phasset: PHAsset, _ asset: Asset, _ resultHandler: @escaping (_ asset: Asset) -> Void) {
        imageManager.requestImage(for: phasset, targetSize: thumbnailSize,
                                  contentMode: .default,
                                  options: loResOptions)
        { image, info in

            // If we don't get one, fine. A default will be provided.
            if let image = image, let thumb = asset.thumb,
                createParentDir(file: thumb) {
                try! UIImageJPEGRepresentation(image, 0.5)?.write(to: thumb)
            }

            resultHandler(asset)
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
