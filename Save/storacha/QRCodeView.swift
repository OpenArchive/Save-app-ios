//
//  QRCodeView.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import SwiftUI

struct QRCodeView: View {
    @ObservedObject var store: AccountsStore<AccountsAppState, AccountsAppAction>
    var onComplete: (() -> Void)?

    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
           

            if isLoading {
                if #available(iOS 14.0, *) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
                Text("Loading your spaces...")
                    .font(.montserrat(.semibold, for: .headline))
                    .foregroundColor(.gray70)
            } else {
                Image("storacha-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 80)
                    .padding(.top, 20)
                Image(uiImage: generateQRCode(from: "storacha-access"))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: 240, height: 240)

                Text("This is your QR code to request access, Please ask the admin to scab your code to gain access to space")
                    .font(.montserrat(.medium, for: .caption))
                    .foregroundColor(.gray70)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    let randomNumber = Int.random(in: 1000...9999)
                    let name = "OA Pro \(randomNumber)"
                    let did = "did:key:dummy:\(UUID().uuidString)"
                    store.dispatch(.addSpace(name: name, did: did))
                    onComplete?()
                }
            }
        }
    }

    func generateQRCode(from string: String) -> UIImage {
        let data = Data(string.utf8)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            if let outputImage = filter.outputImage {
                let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
                let context = CIContext()
                if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return UIImage()
    }
}


class QRCodeViewController: UIViewController {
    private let store: AccountsStore<AccountsAppState, AccountsAppAction>

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let qrView = QRCodeView(store: store) { [weak self] in
            self?.navigateToSpaces()
        }

        let hosting = UIHostingController(rootView: qrView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    private func navigateToSpaces() {
        let spaceListVC = SpaceListViewController(store: store)
        navigationController?.pushViewController(spaceListVC, animated: true)
    }
}
