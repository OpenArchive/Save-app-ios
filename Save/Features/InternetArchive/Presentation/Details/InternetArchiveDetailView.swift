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
        InternetArchiveDetailContent(
            state: viewModel.store.dispatcher.state,
            dispatch: viewModel.store.dispatch
        )
    }
}

struct InternetArchiveDetailContent: View {
    
    let state: InternetArchiveDetailState
    let dispatch: Dispatch<InternetArchiveDetailAction>
    
    @State private var showAlert = false
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text(NSLocalizedString("Account", comment:""))
                .font(.headlineFont2)
                .padding(.horizontal)
            
            Text(state.userName)
                .font(.footnoteFontMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .foregroundColor(.gray70)
                .background(Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray70, lineWidth: 1)
                )
                .padding(.horizontal)
            
            Text(state.screenName)
                .font(.footnoteFontMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.gray70)
                .padding()
                .background(Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray70, lineWidth: 1)
                )
                .padding(.horizontal)
            
            
            Text(state.email)
                .font(.footnoteFontMedium)
                .foregroundColor(.gray70)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray70, lineWidth: 1)
                )
                .padding(.horizontal)
            
            
            HStack {
                Spacer()
                Button(action: {
                    showAlert = true
                    dispatch(.HandleBackButton(status: true))
                }) {
                    Text(LocalizedStringKey("Remove from App"))
                        .font(.headlineFont2)
                        .foregroundColor(.redButton)
                        .padding()
                }
                
                
                Spacer()
            }.padding(.top,20)
            
            Spacer()
        }
        .padding(.top, 30).overlay(
            Group {
                if showAlert {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Are you sure?", comment: ""),
                                    message: NSLocalizedString("Removing this server will delete all associated data.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Remove", comment: ""),
                                    iconImage: Image("trash_icon"),
                                    primaryButtonAction: {
                                        dispatch(.Remove)
                                        showAlert = false
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonIsOutlined: false,
                                    secondaryButtonAction: {
                                        showAlert = false
                                        dispatch(.HandleBackButton(status: false))
                                        
                                    },
                                    showCheckbox: false,
                                    isRemoveAlert: true
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        )
                }
            }
        )
        
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
