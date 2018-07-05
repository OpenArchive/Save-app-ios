//
//  Image.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class Image: Asset {

    let image: UIImage

    init(image: UIImage, created: Date?) {

        self.image = image

        super.init(created: created)
    }

    convenience init(_ image: UIImage) {
        self.init(image: image, created: nil)
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        self.image = decoder.decodeObject() as! UIImage

        super.init(coder: decoder)
    }

    override func encode(with coder: NSCoder) {
        coder.encode(image)

        super.encode(with: coder)
    }

}
