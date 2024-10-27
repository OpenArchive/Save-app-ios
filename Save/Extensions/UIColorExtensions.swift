//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension UIColor {
    static var uniformBlack = UIColor.black.withAlphaComponent(0.25)
    static var uniformWhite = UIColor.white.withAlphaComponent(0.75)
    static var lightWhite = UIColor.white.withAlphaComponent(0.50)
    
    static var networkConnected = UIColor.uniformWhite
    static var networkDisconnected = UIColor (red: 145/255.0, green: 170/255.0, blue: 180/255.0, alpha: 1)
    
    convenience init?(hexString: String?) {
        let input: String! = (hexString ?? "")
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        var alpha: CGFloat = 1.0
        var red: CGFloat = 0
        var blue: CGFloat = 0
        var green: CGFloat = 0
        switch (input.count) {
            case 3 /* #RGB */:
                red = Self.colorComponent(from: input, start: 0, length: 1)
                green = Self.colorComponent(from: input, start: 1, length: 1)
                blue = Self.colorComponent(from: input, start: 2, length: 1)
                break
            case 4 /* #ARGB */:
                alpha = Self.colorComponent(from: input, start: 0, length: 1)
                red = Self.colorComponent(from: input, start: 1, length: 1)
                green = Self.colorComponent(from: input, start: 2, length: 1)
                blue = Self.colorComponent(from: input, start: 3, length: 1)
                break
            case 6 /* #RRGGBB */:
                red = Self.colorComponent(from: input, start: 0, length: 2)
                green = Self.colorComponent(from: input, start: 2, length: 2)
                blue = Self.colorComponent(from: input, start: 4, length: 2)
                break
            case 8 /* #AARRGGBB */:
                alpha = Self.colorComponent(from: input, start: 0, length: 2)
                red = Self.colorComponent(from: input, start: 2, length: 2)
                green = Self.colorComponent(from: input, start: 4, length: 2)
                blue = Self.colorComponent(from: input, start: 6, length: 2)
                break
            default:
                NSException.raise(NSExceptionName("Invalid color value"), format: "Color value \"%@\" is invalid.  It should be a hex value of the form #RBG, #ARGB, #RRGGBB, or #AARRGGBB", arguments:getVaList([hexString ?? ""]))
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    static func colorComponent(from string: String!, start: Int, length: Int) -> CGFloat {
        let substring = (string as NSString)
            .substring(with: NSRange(location: start, length: length))
        let fullHex = length == 2 ? substring : "\(substring)\(substring)"
        var hexComponent: UInt64 = 0
        Scanner(string: fullHex)
            .scanHexInt64(&hexComponent)
        return CGFloat(Double(hexComponent) / 255.0)
    }
    
    var asUInt: UInt {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let r = UInt(red * 255.0) << 16
            let g = UInt(green * 255.0) << 8
            let b = UInt(blue * 255.0)
            
            return r + g + b
        }
        
        return 0
    }
    
    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage/100, 1.0),
                           green: min(green + percentage/100, 1.0),
                           blue: min(blue + percentage/100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }
    
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor
        
        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        //
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        
        guard let components = RGBCGColor?.components else {
            return nil
        }
        
        guard components.count >= 3 else {
            return nil
        }
        
        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        
        return (brightness > threshold)
    }
    
    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }
    
    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }
}
