//
//  UIImage+Utils.swift
//  Save
//
//  Created by Benjamin Erhart on 30.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import UIImage_Resize

extension UIImage {

    func resize(to size: CGSize) -> UIImage? {
        // Avoid crash in library, if image is broken.
        guard !isEmpty else {
            return nil
        }

        return resizedImage(to: size)
    }

    func resizeFit(to size: CGSize, scaleIfSmaller: Bool = true) -> UIImage? {
        // Avoid crash in library, if image is broken.
        guard !isEmpty else {
            return nil
        }

        return resizedImageToFit(in: size, scaleIfSmaller: scaleIfSmaller)
    }

    private var isEmpty: Bool {
        cgImage?.width ?? 0 < 1 || cgImage?.height ?? 0 < 1
    }
}


