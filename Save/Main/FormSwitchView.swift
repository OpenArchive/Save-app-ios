//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class FormSwitchView: CommonView {
    let header = Header1()
    let subHeader = Header2()
    let toggle: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.isEnabled = true
        toggle.clipsToBounds = true
        toggle.onTintColor = .switchOn
        return toggle
    }()
    
    @objc func didChangeSwitch(_ toggle: UISwitch) {
        feedbackGenerator.impactOccurred(intensity: AppStyle.hapticIntensity)
    }
    
    var model: FormSwitchModel! {
        didSet { update() }
    }
    
    convenience init(model: FormSwitchModel) {
        self.init()
        self.model = model
        self.update()
    }
    
    override func setup() {
        let container = UIView()
        
        addSubview(container)
        container.backgroundColor = .clear
        container.addSubview(header)
        container.addSubview(subHeader)
        container.addSubview(toggle)
        
        container.snp.makeConstraints { (make) in
            make.top.equalToSuperview().inset(AppStyle.appCornerRadius)
            make.leading.trailing.equalToSuperview().inset(AppStyle.appCornerRadius * 2)
            make.bottom.equalToSuperview().inset(10)
        }
        
        header.snp.makeConstraints { (make) in
            make.leading.equalToSuperview()
            make.centerY.equalTo(toggle)
            make.trailing.equalTo(toggle.snp.leading).offset(-10)
        }
        
        subHeader.snp.makeConstraints { (make) in
            make.top.equalTo(toggle.snp.bottom)
            make.leading.equalTo(header) // .offset(12)
            make.trailing.equalTo(header)
            make.bottom.equalToSuperview()
        }
        
        toggle.addTarget(self, action: #selector(didChangeSwitch), for: .valueChanged)
        toggle.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview().inset(5)
        }
    }
    
    func update() {
        header.text = model.title
        subHeader.text = model.subTitle
        
        toggle.isOn = model.isOn
        toggle.isEnabled = model.isEnabled
        toggle.addTarget(self, action: #selector(toggleDidChangeValue), for: .valueChanged)
    }
    
    @objc func toggleDidChangeValue() {
        model.isOn = toggle.isOn
        model.callbackOnChange?()
    }
}
