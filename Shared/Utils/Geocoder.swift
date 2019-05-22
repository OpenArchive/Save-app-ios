//
//  Geocoder.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 09.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import CoreLocation
import Photos
import Contacts

/**
 Facility to fetch addresses from given `CLLocation`s or `PHAsset` metadata.

 Since the geocoder web service is rate-limited, we need to queue these requests
 and work on them one after the other.

 We use a 1-second loop to check for work
 */
class Geocoder {

    /**
     - parameter address: A localized address string for a given location.
        Will be `nil` if `PHAsset` didn't contain a location or if reverse
        geocoding was unsuccessful.
    */
    typealias CompletionHandler = (_ address: String?) -> Void

    private class Work {
        let location: CLLocation
        let completionHandler: CompletionHandler

        init(_ location: CLLocation, _ completionHandler: @escaping CompletionHandler) {
            self.location = location
            self.completionHandler = completionHandler
        }
    }


    static let shared = Geocoder()

    private let gc = CLGeocoder()

    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(String(describing: Geocoder.self))")

    private var working = false

    private var work = [Work]()

    /**
     Fetch the address for a `CLLocation` object. (Known as "reverse geocoding".)

     - parameter location: The `CLLocation` to fetch the address for.
     - paramter completionHandler: The handler to call after completion.
    */
    func fetchAddress(from location: CLLocation, completionHandler: @escaping CompletionHandler) {
        work.append(Work(location, completionHandler))

        queue.async(execute: next)
    }

    /**
     Fetch the address for a `PHAsset` object. (Known as "reverse geocoding".)

     This will try to extract a location from a "moment" collection, that asset
     belongs to, if the asset itself doesn't have a location.

     - parameter location: The `PHAsset` to fetch the address for.
     - parameter completionHandler: The handler to call after completion.
     */
    func fetchAddress(from phasset: PHAsset, completionHandler: @escaping CompletionHandler) {
        var location = phasset.location

        // Try to get the location from the moment collection.
        if location == nil {
            let moments = PHAssetCollection.fetchAssetCollectionsContaining(phasset, with: .moment, options: nil)

            for i in 0 ..< moments.count {
                location = moments.object(at: i).approximateLocation

                if location != nil {
                    break
                }
            }
        }

        if location != nil {
            fetchAddress(from: location!, completionHandler: completionHandler)
        }
        else {
            completionHandler(nil)
        }
    }


    // MARK: Private Methods

    @objc private func next() {
        if working || work.count < 1 {
            return
        }

        working = true

        let object = work.removeFirst()

        gc.reverseGeocodeLocation(object.location, preferredLocale: nil) { placemarks, error in
            var prettyAddress: String? = nil

            if let address = placemarks?.first?.postalAddress?.mutableCopy() as? CNMutablePostalAddress {
                address.street = "" // Remove too much detail.

                prettyAddress = Formatters.address.string(from: address)
            }
            else {
                prettyAddress = Formatters.location.string(from: object.location)
            }

            object.completionHandler(prettyAddress)

            self.working = false

            self.queue.async(execute: self.next)
        }
    }
}
