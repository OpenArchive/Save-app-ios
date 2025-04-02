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

class SlideViewController: UIViewController,UITextViewDelegate {
    @IBOutlet weak var imageMultplier: NSLayoutConstraint!
    
    @IBOutlet weak var texttopContraint: NSLayoutConstraint!
    @IBOutlet weak var headingTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var illustrationImg: UIImageViewAligned!
    @IBOutlet weak var headingLb: UILabel!
  @IBOutlet weak var textLb: UILabel!
   @IBOutlet weak var text2Lb: UILabel!
    @IBOutlet weak var subtitleTextView: UITextView!
    var index: Int?

    var slide: Slide?

    weak var delegate: SlideViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UIScreen.main.bounds.height <= 667 {
            imageMultplier.constant = 0.5
            headingTopConstraint.constant = 10
            texttopContraint.constant = 8
        } else {
          
            imageMultplier.constant = 0.6
            headingTopConstraint.constant = 30
        }
       
        guard let text = slide?.heading(headingLb) else { return  }
        
        let style: UIFont.TextStyle = .title1
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        
        let baseFont = UIFont(name: "Montserrat-ExtraBold", size: size)
        ?? UIFont.boldSystemFont(ofSize: size)
        
        let font = UIFontMetrics(forTextStyle: style).scaledFont(for: baseFont)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 1.2,
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        headingLb.attributedText = attributedString
        if let slide = slide {
            subtitleTextView.attributedText = slide.text(subtitleTextView)
            subtitleTextView.isEditable = false
            subtitleTextView.isSelectable = true
            subtitleTextView.isScrollEnabled = false
            subtitleTextView.adjustsFontForContentSizeCategory = true
            subtitleTextView.dataDetectorTypes = .link
            subtitleTextView.textContainer.lineFragmentPadding = 0
            subtitleTextView.textContainerInset = .zero
        }
        illustrationImg.image = slide?.illustration(illustrationImg)
        
        let heading = headingLb.text?.lowercased() ?? ""
        
        let isArchive = heading == NSLocalizedString("Archive", comment: "").lowercased()
        let isVerify = heading == NSLocalizedString("Verify", comment: "").lowercased()

        if isArchive {
            self.imageTopConstraint.constant = 0
            self.illustrationImg.alignment = .topLeft

        } else if isVerify {
            self.imageTopConstraint.constant = 18
            self.illustrationImg.alignment = .topLeft
        } else {
            self.imageTopConstraint.constant = 18
            self.illustrationImg.alignment = .center
        }
  
        
      
    }
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
           UIApplication.shared.open(URL)
           return false
       }

    @IBAction func text2Pressed() {
        delegate?.text2Pressed()
    }

    struct Slide {

        var heading: (_ view: UILabel) -> String
        var text: (_ view: UITextView) -> NSAttributedString
        var illustration: (_ view: UIImageViewAligned) -> UIImage?
        var linkUrl: URL?

        // Primary initializer
        init(
            heading: @escaping (_ view: UILabel) -> String,
            text: @escaping (_ view: UITextView) -> NSAttributedString,
            illustration: @escaping (_ view: UIImageViewAligned) -> UIImage?,
            linkUrl: URL? = nil
        ) {
            self.heading = heading
            self.text = text
            self.illustration = illustration
            self.linkUrl = linkUrl
           
        }

        // Convenience initializer for a string-based headingmember
        init(
            heading: String,
            text: @escaping (_ view: UITextView) -> NSAttributedString,
            illustration: String,
            linkUrl: URL? = nil
        ) {
            self.init(
                heading: { _ in heading },
                text: text,
                illustration: { _ in UIImage(named: illustration) },
                linkUrl: linkUrl
            )
        }

        // Convenience initializer for a plain string text
        init(
            heading: String,
            text: String,
            illustration: String,
            linkUrl: URL? = nil
        ) {
            self.init(
                heading: heading,
                text: { _ in
                    NSAttributedString(string: text, attributes: [
                        .font: UIFont.systemFont(ofSize: 16)
                    ])
                },
                illustration: illustration,
                linkUrl: linkUrl
            )
        }

        // Convenience initializer for attributed string text
        init(
            heading: String,
            text: NSAttributedString,
            illustration: String,
            linkUrl: URL? = nil
        ) {
            self.init(
                heading: heading,
                text: { _ in text },
                illustration: illustration,
                linkUrl: linkUrl
            )
        }
    }

}
