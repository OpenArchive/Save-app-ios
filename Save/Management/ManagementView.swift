//
//  ManagementView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import SwiftUIIntrospect

struct ManagementView: View {
    @StateObject private var viewModel = ManagementViewModel()
    
    var onDone: (() -> Void)?
    var onTitleChange: ((String, String) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.uploads.isEmpty {
                emptyStateView
            } else {
                uploadsList
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            UIDevice.current.isProximityMonitoringEnabled = true
            onTitleChange?(viewModel.titleText, viewModel.subtitleText)
        }
        .onDisappear {
            viewModel.dismiss()
            onDone?()
            UIApplication.shared.isIdleTimerDisabled = false
            UIDevice.current.isProximityMonitoringEnabled = false
        }
        .onChange(of: viewModel.titleText) { _ in
            onTitleChange?(viewModel.titleText, viewModel.subtitleText)
        }
        .onChange(of: viewModel.subtitleText) { _ in
            onTitleChange?(viewModel.titleText, viewModel.subtitleText)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text(NSLocalizedString("No uploads in queue", comment: ""))
                .font(.montserrat(.medium, for: .headline))
                .foregroundColor(Color(UIColor.secondaryLabel))
            Spacer()
        }
    }
    
    private var uploadsList: some View {
        List {
            ForEach(viewModel.uploads, id: \.id) { upload in
                UploadRow(
                    upload: upload,
                    onDelete: {
                        viewModel.deleteUpload(upload)
                    },
                    onShowError: {
                        showError(for: upload)
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color(UIColor.systemBackground))
            }
            .onMove { source, destination in
                let canMove = source.allSatisfy { viewModel.canMoveUpload(viewModel.uploads[$0]) }
                guard canMove else { return }
                viewModel.moveUpload(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .background(Color(UIColor.systemBackground))
        .modifier(ListBackgroundModifier())
        .environment(\.editMode, .constant(.active))
        .introspect(.list, on: .iOS(.v15)) { tableView in
            tableView.backgroundColor = .systemBackground
            tableView.backgroundView = nil
            tableView.layoutMargins = .zero
            tableView.separatorInset = .zero
            tableView.subviews.forEach { $0.backgroundColor = .systemBackground }
        }
    }
    
    private func showError(for upload: Upload) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController?.top else {
            return
        }
        UploadErrorAlert.present(rootViewController, upload)
    }
}

private struct ListBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

#if DEBUG
struct ManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ManagementView()
    }
}
#endif
