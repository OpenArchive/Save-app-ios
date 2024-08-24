//
//  PasscodeLockViewController.swift
//  Save
//
//  Created by Richard Puckett on 8/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

protocol PasscodeLockViewControllerDelegate: AnyObject {
    func passcodeEntered(passcode: String, mode: OAPasscodeLockViewController.Mode)
}

class OAPasscodeLockViewController: UIViewController, UITextViewDelegate {
    
    enum Mode {
        case set
        case enter
    }
    
    weak var delegate: PasscodeLockViewControllerDelegate?
    
    var mode: Mode = .enter
    private let passcodeLength = 4
    private var enteredPasscode = ""
    
    private lazy var passcodeLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter Passcode"
        label.textAlignment = .center
        return label
    }()
    
    private lazy var passcodeView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        return stackView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .saveBackground
        
        view.addSubview(passcodeLabel)
        view.addSubview(passcodeView)
        
        passcodeLabel.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(view.safeAreaInsets.top + 50)
            make.leading.trailing.equalToSuperview()
        }
        
        passcodeView.snp.makeConstraints { (make) in
            make.top.equalTo(passcodeLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(60)
        }
        
        setupPasscodeView()
        
        passcodeView.arrangedSubviews.first?.becomeFirstResponder()
    }
    
    private func updateUIForMode() {
        switch mode {
            case .set:
                passcodeLabel.text = "Set Passcode"
            case .enter:
                passcodeLabel.text = "Enter Passcode"
        }
    }
    
    private func setupPasscodeView() {
        for _ in 0..<passcodeLength {
            let dotView = NoCursorTextView()
            dotView.backgroundColor = .white
            dotView.layer.cornerRadius = AppStyle.appCornerRadius
            dotView.borderWidth = AppStyle.borderWidth
            dotView.borderColor = .saveBorder
            dotView.font = UIFont(name: "CourierNewPSMT", size: 48)!
            dotView.textAlignment = .center
            dotView.textColor = .black
            dotView.keyboardType = .numberPad
            dotView.isSecureTextEntry = true
            dotView.delegate = self
            
            passcodeView.addArrangedSubview(dotView)
        }
    }
    
    private func updatePasscodeView() {
        for (index, dotView) in passcodeView.subviews.enumerated() {
            dotView.backgroundColor = index < enteredPasscode.count ? .black : .lightGray
        }
    }
    
    @discardableResult
    private func moveFocusBackwards() -> Bool {
        if let idx = passcodeView.arrangedSubviews.firstIndex(where: { $0.isFirstResponder }) {
            let newIndex = idx - 1
            
            if newIndex >= 0 {
                passcodeView.arrangedSubviews[idx].backgroundColor = .white
                passcodeView.arrangedSubviews[newIndex].backgroundColor = .red
                passcodeView.arrangedSubviews[newIndex].becomeFirstResponder()
                return true
            }
        }
        
        return false
    }
    
    @discardableResult
    private func moveFocusForwards() -> Bool {
        if let idx = passcodeView.arrangedSubviews.firstIndex(where: { $0.isFirstResponder }) {
            let newIndex = idx + 1
            
            if newIndex < passcodeLength {
                passcodeView.arrangedSubviews[idx].backgroundColor = .white
                passcodeView.arrangedSubviews[newIndex].backgroundColor = .red
                passcodeView.arrangedSubviews[newIndex].becomeFirstResponder()
                return true
            }
        }
        
        return false
    }
    
    // We'll handle delete keys here.
    //
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        log.debug("text = [\(text)]")
        
        if text.isEmpty {
            moveFocusBackwards()
            return true
        }
        
        if !moveFocusForwards() {
            let code = passcodeView.arrangedSubviews.reduce("", { (x, y) in
                if let ty = y as? UITextView {
                    return x + ty.text
                }
                
                return x
            })
            
            log.debug("code = \(code)")
            
            delegate?.passcodeEntered(passcode: code, mode: mode)
        }
        
        return true
    }
    
//    func textViewDidChange(_ textView: UITextView) {
//        log.debug("Changed!")
//        
//
//    }
}

class NoCursorTextView: UITextView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init() {
        super.init(frame: .zero, textContainer: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func caretRect(for position: UITextPosition) -> CGRect {
        return CGRect.zero
    }
    
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return []
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.copy(_:)) || action == #selector(UIResponderStandardEditActions.selectAll(_:)) || action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return false
        }
        
        // Default
        return super.canPerformAction(action, withSender: sender)
    }
}
