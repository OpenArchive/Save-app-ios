//
//  WorkingOverlay.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//


import UIKit

/**
 An overlay which has 75% opacity and an activity indicator in the middle of
 the screen. Effectively hinders users to interact with the scene.
 
 Recommended usage:
 
 ```swift
    private lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(view)
    }()
 
    // Show
    workingOverlay.isHidden = false
 
    // Hide again
    workingOverlay.isHidden = true

    // Optional text below activity indicator:
    workingOverlay.message = "foobar"

    // Additional tap handler for complete view area:
    workingOverlay.tapHandler = {
        // Do things...
    }
 ```
 */
open class WorkingOverlay: UIView {

    /**
     The owner view, if any
     */
    var view: UIView?
    
    override open var isHidden: Bool {
        willSet {
            if newValue {
                activityIndicator.stopAnimating()
            }
            else {
                if superview == nil, let view = view {
                    _ = addToSuperview(view)
                }
                superview?.endEditing(true)
                superview?.bringSubviewToFront(self)
                activityIndicator.startAnimating()
            }
        }
        didSet {
            if isHidden, superview != nil {
                self.removeFromSuperview()
            }
        }
    }
    
    /**
     Shows an optional message below the activity indicator.
     */
    public var message: String? {
        get {
            return label.text
        }
        set {
            label.text = newValue
        }
    }
    
    /**
     Set a handler that will be called when the view is tapped.
     */
    public var tapHandler: (()->())? {
        didSet {
            gestureRecognizers?.removeAll()

            if tapHandler != nil {
                addGestureRecognizer(UITapGestureRecognizer(
                    target: self, action: #selector(didTapView(_:))))
            }
        }
    }
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.color = .black
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(indicator)
        indicator.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        return indicator
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8).isActive = true
        
        return label
    }()
    
    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        
        alpha = 0.75
        backgroundColor = .white
        isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /**
     Attaches this object to the given superview and adapts its size, by
     leveraging layout constraints, so its exactly the same.
     
     - parameter superview: The superview to attach to. Should be the base
        view of the current view controller.
     - returns: self for convenience
    */
    public func addToSuperview(_ superview: UIView) -> WorkingOverlay {
        view = superview

        superview.addSubview(self)

        leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true

        return self
    }
    
    /**
     Callback for UITapGestureRecognizer. Calls the handler, if there is one.
     */
    @objc private func didTapView(_ sender: UITapGestureRecognizer) {
        tapHandler?()
    }
}
