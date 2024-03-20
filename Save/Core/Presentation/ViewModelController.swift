//
//  ViewModelController.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

class ViewModelController<State, Action, ViewModel: StoreViewModel<State, Action>, View: SwiftUI.View> : UIHostingController<View> {
    
    let viewModel: ViewModel?
    
    init(viewModel: ViewModel, rootView: View) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.viewModel = nil
        super.init(coder: aDecoder)
    }
    
    
    /**
     Dismisses ourselves, animated.
     Handles being in a `UINavigationController` gracefully.
     
     Can be a callback for simple "Cancel", "Done" etc. buttons.

     - parameter completion: Block to be executed after animation has ended.
     */
    @objc
    public func dismiss(completion: (() -> Void)?) {
        if let nav = navigationController, navigationController?.viewControllers.first != self {
            nav.popViewController(animated: true)

            if let completion = completion {
                nav.transitionCoordinator?.animate(alongsideTransition: nil, completion: { _ in
                    completion()
                })
            }
        }
        else {
            dismiss(animated: true, completion: completion)
        }
    }
}
