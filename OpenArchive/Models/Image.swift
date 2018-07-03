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

    convenience required init(coder aDecoder: NSCoder) {
        self.init(image: aDecoder.decodeObject() as! UIImage, created: aDecoder.decodeObject() as? Date)
    }

    override func encode(with aCoder: NSCoder) {
        aCoder.encode(image)

        super.encode(with: aCoder)
    }

}
