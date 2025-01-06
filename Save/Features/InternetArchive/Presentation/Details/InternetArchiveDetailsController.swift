//
//  InternetArchiveDetailsController.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import Factory

class InternetArchiveDetailsController : ViewModelController<InternetArchiveDetailState, InternetArchiveDetailAction, InternetArchiveDetailViewModel, InternetArchiveDetailView> {
    
    private static func createViewModel(_ space: Space) -> InternetArchiveDetailViewModel {
        return Container.shared.internetArchiveDetailViewModel(space)
    }
    
    required init(space: Space) {
        let viewModel = InternetArchiveDetailsController.createViewModel(space)
        super.init(viewModel: viewModel, rootView: InternetArchiveDetailView(viewModel: viewModel))
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.title = NSLocalizedString("Edit Internet Archive" ,comment: "")
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
        }
        viewModel?.store.listen { [weak self] action in
            switch action {
            case .Removed:
                fallthrough
            case .Cancel:
                self?.dismiss(completion: nil)
            case .Remove:
                self?.navigationController?.popViewController(animated: true)
            default: break
            }
        }
    }
}
