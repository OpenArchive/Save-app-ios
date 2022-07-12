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

    func buttonPressed()
}

class SlideViewController: UIViewController {

    @IBOutlet weak var headingLb: UILabel!
    @IBOutlet weak var textLb: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var illustrationImg: UIImageViewAligned!

    var index: Int?

    var slide: Slide?

    weak var delegate: SlideViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        headingLb.text = slide?.heading

        textLb.text = slide?.text

        if slide?.buttonText?.isEmpty ?? true {
            button.widthAnchor.constraint(equalToConstant: 0).isActive = true
        }
        else {
            button.setTitle(slide?.buttonText)
        }

        illustrationImg.image = slide?.illustration
        illustrationImg.alignment = .topLeft
    }

    @IBAction func buttonPressed() {
        delegate?.buttonPressed()
    }
}

struct Slide {

    private var _heading: () -> String
    private var _text: () -> String
    private var _buttonText: () -> String?
    private var _illustration: () -> UIImage?

    var heading: String {
        _heading()
    }

    var text: String {
        _text()
    }

    var buttonText: String? {
        _buttonText()
    }

    var illustration: UIImage? {
        _illustration()
    }


    init(heading: @escaping () -> String, text: @escaping () -> String, buttonText: (() -> String?)? = nil, illustration: @escaping () -> UIImage?) {
        _heading = heading
        _text = text
        _buttonText = buttonText ?? { nil }
        _illustration = illustration
    }

    init(heading: String, text: @escaping () -> String, buttonText: (() -> String?)? = nil, illustration: String) {
        self.init(heading: { heading }, text: text, buttonText: buttonText, illustration: { UIImage(named: illustration) })
    }

    init(heading: String, text: String, buttonText: String? = nil, illustration: String) {
        self.init(heading: heading, text: { text }, buttonText: { buttonText }, illustration: illustration)
    }
}
