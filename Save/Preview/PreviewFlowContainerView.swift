//
//  PreviewFlowContainerView.swift
//  Save
//
//  Single SwiftUI tree for preview → darkroom / batch (no nested UIKit stack).
//

import SwiftUI
import YapDatabase

/// Routes inside the preview screen (one `PreviewViewController`, one navigation bar).
enum PreviewInnerRoute: Equatable {
    case preview
    case darkroom(Int)
    case batchEdit([String])
}

final class PreviewSessionModel: ObservableObject {
    @Published var route: PreviewInnerRoute = .preview
    weak var viewController: PreviewViewController?

    func goDarkroom(_ index: Int) {
        route = .darkroom(index)
        viewController?.syncNavigationChrome()
    }

    func goBatchEdit(assetIds: [String]) {
        route = .batchEdit(assetIds)
        viewController?.syncNavigationChrome()
    }

    func returnToPreview() {
        route = .preview
        viewController?.syncNavigationChrome()
    }
}

struct PreviewFlowContainerView: View {
    @ObservedObject var session: PreviewSessionModel

    var body: some View {
        Group {
            switch session.route {
            case .preview:
                PreviewView(
                    onNavigateToDarkroom: { session.goDarkroom($0) },
                    onNavigateToBatchEdit: { session.goBatchEdit(assetIds: $0.map(\.id)) },
                    onAddAssets: { session.viewController?.showMediaPickerSheet() },
                    onUploadComplete: { session.viewController?.popFromMainNavigation() }
                )
            case .darkroom(let index):
                DarkroomView(
                    initialIndex: index,
                    onDismiss: { session.returnToPreview() },
                    onRemoveAsset: { session.returnToPreview() }
                )
                .onAppear {
                    let sc = SelectedCollection()
                    BatchInfoAlert.presentIfNeeded(
                        viewController: session.viewController,
                        additionalCondition: sc.count > 1
                    )
                }
            case .batchEdit(let ids):
                BatchEditResolvedView(assetIds: ids) {
                    session.returnToPreview()
                }
            }
        }
        .animation(.default, value: session.route)
    }
}

// MARK: - Batch edit (resolve assets from IDs for stable routing)

private struct BatchEditResolvedView: View {
    let assetIds: [String]
    let onDismiss: () -> Void

    @State private var assets: [Asset] = []
    @State private var loadFailed = false

    var body: some View {
        Group {
            if loadFailed {
                Text(NSLocalizedString("No media to preview", comment: ""))
                    .font(.montserrat(.medium, for: .headline))
                    .foregroundColor(.gray70)
            } else if assets.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BatchEditView(assets: assets, onDismiss: onDismiss)
            }
        }
        .onAppear {
            resolveAssets()
        }
    }

    private func resolveAssets() {
        Db.bgRwConn?.read { tx in
            let loaded: [Asset] = assetIds.compactMap { id in
                tx.object(for: id, in: Asset.collection)
            }
            DispatchQueue.main.async {
                if loaded.isEmpty {
                    loadFailed = true
                } else {
                    assets = loaded
                }
            }
        }
    }
}
