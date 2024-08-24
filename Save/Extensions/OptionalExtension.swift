//
//  Created by Richard Puckett on 11/30/23.
//

import Foundation

extension Optional {
    var orNil: String {
        if self == nil { return "nil" }
        
        if "\(Wrapped.self)" == "String" { return "\"\(self!)\"" }
        
        return "\(self!)"
    }
}
