//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class SliderView: CommonView {
    let title = Header1()
    let value = Header2()
    let slider = UISlider()
    
    @objc func didChangeSlider(_ slider: UISlider) {
        var formattedValue = String(slider.value)
        
        if let formatter = formatter {
            formattedValue = formatter(slider.value)
        }
        
        value.text = formattedValue
    }
    
    var formatter: ((_ value: Any) -> String)?
    
    var model: FormSliderModel! {
        didSet {
            title.text = model.title
            
            formatter = model.formatter
            
            if let formatter = formatter {
                value.text = formatter(slider.value)
            } else {
                value.text = String(slider.value)
            }
            
            slider.addTarget(self, action: #selector(didChangeSlider(_:)), for: .valueChanged)
            
            if let target = model.target, let selector = model.selector {
                slider.addTarget(target, action: selector, for: .valueChanged)
            }
        }
    }
    
    override func setup() {
        addSubview(title)
        addSubview(value)
        addSubview(slider)
    }
    
    override func setConstraints() {
        title.snp.makeConstraints { (make) in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        value.snp.makeConstraints { (make) in
            make.trailing.equalToSuperview().inset(AppStyle.appCornerRadius)
            make.centerY.equalTo(title)
        }
        
        slider.snp.makeConstraints { (make) in
            make.top.equalTo(title.snp.bottom).offset(-4)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
    }
}
