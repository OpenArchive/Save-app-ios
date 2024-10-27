//
//  Created by Richard Puckett on 1/19/23.
//

import UIKit

extension NSMutableAttributedString {
    var fontSize: CGFloat { return 14 }
    var sectionTitleFont: UIFont { return .montserrat(forTextStyle: .title2) }
    var bodyFont: UIFont { return .montserrat(forTextStyle: .body) }
    var thinFont: UIFont { return UIFont(name: "HelveticaNeue-Thin", size: 13)! }
    var italicsFont: UIFont { return UIFont(name: "HelveticaNeue-Italic", size: 13)! }
    var smallLink: UIFont { return .normalMedium }
    
    func smallLink(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: smallLink,
            .foregroundColor : UIColor.saveLabel,
            .underlineStyle : NSUnderlineStyle.single.rawValue
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func fixedTitle(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont(name: "CourierNewPS-BoldMT", size: 13)!,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func fixedNormal(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont(name: "CourierNewPSMT", size: 13)!,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func fixedNormalLarge(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont(name: "CourierNewPSMT", size: 17)!,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func body(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: bodyFont,
            .foregroundColor : UIColor.red
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func sectionTitle(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: sectionTitleFont,
            .foregroundColor : UIColor.saveSectionHeader
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func bold(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.boldMedium,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func italics(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: italicsFont,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func thin(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: thinFont,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func normal(_ value: String, color: UIColor = UIColor.saveLabel) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalMedium,
            .foregroundColor : color
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func primaryNormal(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont(name: "HelveticaNeue", size: 18)!,
            .foregroundColor : UIColor.black.withAlphaComponent(0.75),
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func primaryHighlighted(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont(name: "HelveticaNeue", size: 18)!,
            .foregroundColor : UIColor.black.withAlphaComponent(0.50),
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func selected(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalMedium,
            .foregroundColor : UIColor.black.withAlphaComponent(0.75)
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func boldMedium(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.boldMedium,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func boldLarge(_ value: String, color: UIColor = UIColor.saveLabel) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.boldLarge,
            .foregroundColor : color
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func normalMedium(_ value: String, color: UIColor = UIColor.saveLabel) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalMedium,
            .foregroundColor : color
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func normalLarge(_ value: String, color: UIColor = UIColor.saveLabel) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalLarge,
            .foregroundColor : color
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func normalSmall(_ value: String, color: UIColor = UIColor.saveLabel) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalSmall,
            .foregroundColor : color
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func normalExtraSmall(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalExtraSmall,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func destructiveButton(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalMedium,
            .foregroundColor : UIColor.saveLabel
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
    
    func secondaryButton(_ value: String) -> NSMutableAttributedString {
        let attributes:[NSAttributedString.Key : Any] = [
            .font: UIFont.normalMedium,
            .foregroundColor : UIColor.black.withAlphaComponent(0.75)
        ]
        
        self.append(NSAttributedString(string: value, attributes: attributes))
        
        return self
    }
}
