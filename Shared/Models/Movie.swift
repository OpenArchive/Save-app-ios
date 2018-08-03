//
//  Movie.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Photos

class Movie: Image {

    /**
     Create a `Movie` object from a given `AIAssetUrl` as returned by
     `imagePickerController:didFinishPickingMediaWithInfo`.

     It will try to fetch the according `PHAsset` immediately and trigger the caching of a thumbnail
     image for that asset. mimeType and filename will be video/mpeg rsp "<random>.mp4" always,
     since we can't get the filename of the video and you should always export using that format.

     You will *only* receive the `resultHandler` callback, if a `PHAsset` can be found and the
     original movie for it requested!

     [PHImageManager](https://developer.apple.com/documentation/photokit/phimagemanager)

     [How to get Original Image and media type from PHAsset?](https://stackoverflow.com/questions/35264023/how-to-get-original-image-and-media-type-from-phasset)

     - parameter url: The url as received in `UIImagePickerControllerReferenceURL`
     - parameter resultHandler: Callback with the created `Image` object.
     - parameter movie: The created movie.
    */
    override class func create(fromAlAssetUrl url: URL, resultHandler: @escaping (_ movie: Movie) -> Void) {
        if let asset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {

            // Immediately kick off thumbnail generation.
            Image.cachingImageManager.startCachingImages(for: [asset],
                                                         targetSize: Image.thumbnailSize,
                                                         contentMode: .default,
                                                         options: Image.requestOptions)

            // We will always export MPEG4 / H.264 video, so set this hard.
            let mimeType = "video/mpeg"
            let filename = "\(UUID().uuidString).mp4"

            resultHandler(Movie(id: asset.localIdentifier, filename: filename,
                                mimeType: mimeType, created: nil))
        }
    }

    /**
     Fetch the original data stream of an image usable for uploading to a service.

     - parameter resultHandler: A block that Photos calls after loading the asset’s data and
        preparing the export session.
     - parameter exportSession: An `AVAssetExportSession` object that you can use for writing the
        video asset’s data to a file.
     - parameter info: A dictionary providing information about the status of the request.
    */
    func fetchMovieData(_ resultHandler: @escaping (_ exportSession: AVAssetExportSession?, _ info: [AnyHashable : Any]?) -> Void) {

        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            Image.cachingImageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                if let avAsset = avAsset {
                    let presets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)

                    if presets.count > 0 {
                        Image.cachingImageManager.requestExportSession(forVideo: asset,
                                                                       options: options,
                                                                       exportPreset: presets[0],
                                                                       resultHandler: resultHandler)
                    }
                }
            }
        }
    }
}
