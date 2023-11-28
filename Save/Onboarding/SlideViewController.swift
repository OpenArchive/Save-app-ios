//
//  SlideViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import UIImageViewAlignedSwift

protocol SlideViewControllerDelegate: AnyObject {

    func text2Pressed()
}

class SlideViewController: UIViewController {

    @IBOutlet weak var illustrationImg: UIImageViewAligned!
    @IBOutlet weak var headingLb: UILabel!
    @IBOutlet weak var textLb: UILabel!
    @IBOutlet weak var text2Lb: UILabel!

    var index: Int?

    var slide: Slide?

    weak var delegate: SlideViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        headingLb.text = slide?.heading(headingLb)

        textLb.text = slide?.text(textLb)

        if slide?.text2(text2Lb)?.isEmpty ?? true {
            text2Lb.isHidden = true
        }
        else {
            text2Lb.attributedText = slide?.text2(text2Lb)
        }

        illustrationImg.image = slide?.illustration(illustrationImg)
        illustrationImg.alignment = .topLeft
    }

    @IBAction func text2Pressed() {
        delegate?.text2Pressed()
    }

    struct Slide {

        var heading: (_ view: UILabel) -> String
        var text: (_ view: UILabel) -> String
        var text2: (_ view: UILabel) -> NSAttributedString?
        var illustration: (_ view: UIImageViewAligned) -> UIImage?


        init(
            heading: @escaping (_ view: UILabel) -> String,
            text: @escaping (_ view: UILabel) -> String,
            text2: ((_ view: UILabel) -> NSAttributedString?)? = nil,
            illustration: @escaping (_ view: UIImageViewAligned) -> UIImage?)
        {
            self.heading = heading
            self.text = text
            self.text2 = text2 ?? { _ in nil }
            self.illustration = illustration
        }

        init(heading: String, text: @escaping (_ view: UILabel) -> String,
             text2: ((_ view: UILabel) -> NSAttributedString?)? = nil, illustration: String)
        {
            self.init(heading: { _ in heading }, text: text, text2: text2, illustration: { _ in UIImage(named: illustration) })
        }

        init(heading: String, text: String, text2: NSAttributedString? = nil, illustration: String) {
            self.init(heading: heading, text: { _ in text }, text2: { _ in text2 }, illustration: illustration)
        }
    }
}
