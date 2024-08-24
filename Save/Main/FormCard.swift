////
////  Created by Richard Puckett on 5/24/24.
////  Copyright © 2024 Open Archive. All rights reserved.
////
//
//import UIKit
//
//import SelectionList
//import SnapKit
//
//class FormCard: CommonView {
//    var title: String! {
//        didSet {
//            titleView.text = title
//        }
//    }
//    var titleView = UILabel()
//    let contentView: UIStackView = {
//        let stack = UIStackView()
//        stack.spacing = 10
//        stack.axis = .vertical
//        stack.alignment = .fill
//        stack.distribution = .fill
//        return stack
//    }()
//    
//    override func setup() {
//        super.setup()
//        
//        clipsToBounds = true
//        backgroundColor = .clear
//        
//        titleView.font = .boldExtraLarge
//        titleView.textColor = UIColor(hexString: "#00B4A6")
//        
//        contentView.backgroundColor = .formCardBackground
//        contentView.layer.borderWidth = AppStyle.borderWidth
//        contentView.layer.borderColor = .saveBorder.cgColor
//        contentView.layer.cornerRadius = AppStyle.appCornerRadius
//        
//        addSubview(titleView)
//        addSubview(contentView)
//    }
//    
//    override func setConstraints() {
//        super.setConstraints()
//        
//        log.debug("setConstraints")
//        
//        titleView.snp.makeConstraints { (make) in
//            make.top.equalToSuperview()
//            make.leading.trailing.equalToSuperview().inset(AppStyle.appCornerRadius * 2)
//        }
//        
//        contentView.snp.makeConstraints { (make) in
//            make.bottom.equalToSuperview()
//            make.top.equalTo(titleView.snp.bottom).offset(3)
//            make.leading.trailing.equalToSuperview()
//        }
//    }
//    
//    func addSelectionList(getModel: (inout SelectionListModel) -> ()) -> Self {
//        var model = SelectionListModel()
//        getModel(&model)
//        
//        let v = SelectionListView(model: model)
//        contentView.addArrangedSubview(v)
//        
//        return self
//    }
//    
//    func addSwitch(getModel: (inout FormSwitchModel) -> ()) -> Self {
//        var model = FormSwitchModel()
//        getModel(&model)
//        
//        let v = FormSwitchView(model: model)
//        contentView.addArrangedSubview(v)
//        
//        return self
//    }
//    
//    func build() {
//    }
//    
//    func setTitle(_ title: String) -> Self {
//        self.title = title
//        return self
//    }
//}
