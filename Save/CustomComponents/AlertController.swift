import UIKit
import SwiftUI

class CustomAlertViewController: UIViewController {
    private lazy var alertView = UIHostingController(
        rootView: CustomAlertView(
            title: self.titleText,
            message: self.messageText,
            primaryButtonTitle: self.primaryButtonTitle, iconImage:iconImage,
            iconTint : self.iconTint,
            primaryButtonAction: { [weak self] in
                self?.primaryButtonAction()
                self?.dismiss(animated: true)
            },
            secondaryButtonTitle: self.secondaryButtonTitle,
            secondaryButtonIsOutlined:self.secondaryButtonIsOutlined, secondaryButtonAction: { [weak self] in
                self?.secondaryButtonAction?()
                self?.dismiss(animated: true)
            },
            showCheckbox: self.showCheckbox,
            isRemoveAlert: self.isRemoveAlert
        )
    )
    
    private let titleText: String
    private let messageText: String
    private let primaryButtonTitle: String
    private let primaryButtonAction: () -> Void
    private let secondaryButtonTitle: String?
    private let secondaryButtonAction: (() -> Void)?
    private let secondaryButtonIsOutlined:Bool
    private let showCheckbox: Bool
    private let iconImage:Image
    private var iconTint: Color = .gray
    private var isRemoveAlert:Bool = false
    
    init(title: String, message: String, primaryButtonTitle: String, primaryButtonAction: @escaping () -> Void, secondaryButtonTitle: String? = nil, secondaryButtonAction: (() -> Void)? = nil, showCheckbox: Bool = false, secondaryButtonIsOutlined: Bool = false,iconImage:Image = Image("icon"),iconTint:Color = .gray,isRemoveAlert:Bool = false) {
        
        self.titleText = title
        self.messageText = message
        self.iconImage = iconImage
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonAction = primaryButtonAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryButtonAction = secondaryButtonAction
        self.showCheckbox = showCheckbox
        self.secondaryButtonIsOutlined = secondaryButtonIsOutlined
        self.iconTint = iconTint
        self.isRemoveAlert = isRemoveAlert
        
        super.init(nibName: nil, bundle: nil)
        
        // Set up modal presentation style
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.gray.withAlphaComponent(0.9)
        
        
        addChild(alertView)
        alertView.view.backgroundColor = UIColor.clear
        alertView.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(alertView.view)
        alertView.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            alertView.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertView.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            alertView.view.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width)
        ])
    }
}
