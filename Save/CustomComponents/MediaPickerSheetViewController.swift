//
//  MediaPickerSheetViewController.swift
//  Save
//
//  Created by navoda on 2025-03-25.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import UIKit

class MediaPopupViewController: UIViewController {
    
    var onCameraTap: (() -> Void)?
    var onGalleryTap: (() -> Void)?
    var onFilesTap: (() -> Void)?
    
    private let backgroundView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupBackgroundTap()
        setupPopup()
    }
    
    private func setupBackgroundTap() {
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        backgroundView.addGestureRecognizer(tap)
    }

    private func setupPopup() {
        let popupView = UIView()
        popupView.backgroundColor = .gray10
        popupView.layer.cornerRadius = 20
        popupView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        popupView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(popupView)
        
        NSLayoutConstraint.activate([
            popupView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            popupView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            popupView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            popupView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "Add media from"
        titleLabel.font = .montserrat(forTextStyle: .callout, with: .traitUIOptimized)
        titleLabel.textAlignment = .left
        
        let camera = createOption(imageName: "camera", text: "Camera", action: #selector(cameraTapped))
        let gallery = createOption(imageName: "gallery", text: "Photo Gallery", action: #selector(galleryTapped))
        let files = createOption(imageName: "doc", text: "Files", action: #selector(filesTapped))
        
        let iconsStack = UIStackView(arrangedSubviews: [camera, gallery, files])
        iconsStack.axis = .horizontal
        iconsStack.alignment = .center
        iconsStack.distribution = .equalSpacing
        iconsStack.spacing = 24
        
        let contentStack = UIStackView(arrangedSubviews: [titleLabel, iconsStack])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        popupView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: popupView.leadingAnchor, constant: 40),
            contentStack.trailingAnchor.constraint(equalTo: popupView.trailingAnchor, constant: -40),
            contentStack.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: popupView.bottomAnchor, constant: -40)
        ])
    }

    private func createOption(imageName: String, text: String, action: Selector) -> UIView {
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 54).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGesture)

        let label = UILabel()
        label.text = text
        label.font = .montserrat(forTextStyle: .footnote)
        label.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }

    @objc private func cameraTapped() {
        dismiss(animated: true) {
            self.onCameraTap?()
        }
    }

    @objc private func galleryTapped() {
        dismiss(animated: true) {
            self.onGalleryTap?()
        }
    }

    @objc private func filesTapped() {
        dismiss(animated: true) {
            self.onFilesTap?()
        }
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
