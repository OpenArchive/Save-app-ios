//
//  InternetArchiveDetailView.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//
import SwiftUI

struct InternetArchiveDetailView : View {
    
    @ObservedObject var viewModel: InternetArchiveDetailViewModel
    
    var body: some View {
        InternetArchiveDetailContent(state: viewModel.store.dispatcher.state, dispatch: viewModel.store.dispatch)
    }
}

struct InternetArchiveDetailContent: View {
    
    let state: InternetArchiveDetailState
    let dispatch: Dispatch<InternetArchiveDetailAction>
    
    @State private var showAlert = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("Username")).font(.caption).padding(.horizontal).padding(.top)
            Text(state.userName).font(.body)
                .padding()
            
            Text(LocalizedStringKey("Screen Name")).font(.caption).padding(.horizontal)
            Text(state.screenName).font(.body)
                .padding()
            
            Text(LocalizedStringKey("Email")).font(.caption).padding(.horizontal)
            Text(state.email).font(.body)
                .padding()
            
            HStack {
                Spacer()
                Button(action: {
                    showAlert = true
                }) {
                    Image(systemName: "trash")
                    Text(LocalizedStringKey("Remove from App")).alert(isPresented: $showAlert) {
                        Alert(
                            title: Text(LocalizedStringKey("Are you sure?")),
                            message: Text(
                                String(
                                    format:
                                        NSLocalizedString("Removing this server will remove all contained thumbnails from the %@ app.", comment: "Placeholder is app name"),
                                    arguments: [Bundle.main.displayName]
                                )
                            ),
                            primaryButton: .destructive(Text(LocalizedStringKey("Remove Server"))) {
                                dispatch(.Remove)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }.foregroundColor(.red).padding()
                Spacer()
            }
            Spacer()
        }
    }
}

struct InternetArchiveDetailView_Previews: PreviewProvider {
    static let state = InternetArchiveDetailState(
        screenName: "ABC User", 
        userName: "@abc_user1",
        email: "abc@example.com"
    )
    
    static var previews: some View {
        InternetArchiveDetailContent(state: state) { _ in }
    }
}
