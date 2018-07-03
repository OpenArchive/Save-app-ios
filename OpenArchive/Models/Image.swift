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

    init(image: UIImage, created: Date?, desc: String?, author: String?, location: String?,
         tags: [String]?, license: String?) {

        self.image = image

        super.init(created: created, desc: desc, author: author, location: location, tags: tags,
                   license: license)
    }

    convenience init(_ image: UIImage) {
        self.init(image: image, created: nil, desc: nil, author: nil, location: nil, tags: nil,
                  license: nil)
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
