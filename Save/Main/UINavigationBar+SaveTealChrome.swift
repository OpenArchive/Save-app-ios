//
//  UINavigationBar+SaveTealChrome.swift
//  Save
//

import UIKit

extension UINavigationBar {

    /// Opaque teal bar, white titles and bar buttons (matches `MainTopNavigationBar` / `menu-background`).
    static func save_applyTealChrome(to bar: UINavigationBar) {
        let teal = UIColor(named: "menu-background")
            ?? UIColor(red: 0, green: 180 / 255, blue: 166 / 255, alpha: 1)

        let titleFont = UIFont(name: "Montserrat-SemiBold", size: 18)
            ?? UIFont.systemFont(ofSize: 18, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = teal
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: titleFont,
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: titleFont,
        ]
        appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.doneButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]

        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            bar.compactScrollEdgeAppearance = appearance
        }
        bar.tintColor = .white
        bar.barTintColor = teal
    }
}

/// Chromeless primary actions on teal bars (Preview **UPLOAD**/**DONE**, Browse **ADD**, private server **Confirm**).
enum SaveNavigationBarButtons {

    /// System `UIBarButtonItem` titles pick up a light “pill” in light mode on newer iOS; use a clear `UIButton`.
    static func makeChromelessPrimaryActionBarButtonItem(
        title: String,
        target: Any?,
        action: Selector,
        accessibilityIdentifier: String? = nil
    ) -> UIBarButtonItem {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.addTarget(target, action: action, for: .touchUpInside)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.sizeToFit()
        let item = UIBarButtonItem(customView: button)
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        return item
    }
}

extension UIViewController {

    /// Inline title, optional back-button visibility, empty back label — for screens on the teal `MainNavigationController` stack.
    func save_configureTealStackNavigationItem(hidesBackButton: Bool = false) {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = hidesBackButton
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }

    /// iOS 26+ liquid glass on bar buttons; custom items already set `hidesSharedBackground` where built via `SaveNavigationBarButtons`.
    @available(iOS 26.0, *)
    func save_hidesSharedBackgroundOnNavigationBarButtons() {
        navigationItem.leftBarButtonItems?.forEach { $0.hidesSharedBackground = true }
        navigationItem.rightBarButtonItems?.forEach { $0.hidesSharedBackground = true }
        navigationItem.leftBarButtonItem?.hidesSharedBackground = true
        navigationItem.rightBarButtonItem?.hidesSharedBackground = true
    }
}
