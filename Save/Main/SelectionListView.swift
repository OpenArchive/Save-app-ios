//
//  Created by Richard Puckett on 6/5/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

import SelectionList
import SnapKit

class SelectionListView: CommonView {
    let container = UIView()
    let header = Header1()
    let selectionList = SelectionList()
    
    var model: SelectionListModel! {
        didSet { update() }
    }
    
    convenience init(model: SelectionListModel) {
        self.init()
        self.model = model
        self.update()
    }
    
    override func setup() {
        super.setup()
        
        addSubview(container)
        container.backgroundColor = .clear
        container.addSubview(header)
        container.addSubview(selectionList)
        
        selectionList.allowsMultipleSelection = false
        selectionList.selectedIndex = 0
        selectionList.addTarget(self, action: #selector(didChangeSelection), for: .valueChanged)
        selectionList.setupCell = { (cell: UITableViewCell, index: Int) in
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.tintColor = .accent
            cell.textLabel?.textColor = .header2
            cell.textLabel?.font = .normalSmall
        }
        self.selectionList.tableView.rowHeight = UIFont.normalSmall.pointSize * 2
        
        DispatchQueue.main.async {
            self.selectionList.tableView.backgroundColor = .clear
            self.selectionList.tableView.separatorStyle = .none
        }
    }
    
    override func setConstraints() {
        container.snp.makeConstraints { (make) in
            make.top.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(AppStyle.appCornerRadius * 2)
            make.bottom.equalToSuperview().inset(6)
        }
        
        header.snp.makeConstraints { (make) in
            make.leading.top.trailing.equalToSuperview()
        }
        
        selectionList.snp.makeConstraints { (make) in
            make.top.equalTo(header.snp.bottom).offset(5)
            make.leading.equalToSuperview().offset(-20)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    @objc func didChangeSelection() {
        log.debug("CLICK!")
        if selectionList.selectedIndex == 0 {
        }
    }
    
    func update() {
        header.text = model.title
        selectionList.items = model.items
        selectionList.selectedIndex = 0
    }
}
