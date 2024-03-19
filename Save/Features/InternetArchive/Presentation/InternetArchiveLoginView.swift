//
//  InternetArchiveView.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import Factory

struct InternetArchiveLoginView: View  {
    
    @ObservedObject var viewModel: InternetArchiveLoginViewModel
    
    var body: some View {
        InternetArchiveLoginContent(store: viewModel.store).environmentObject(viewModel.state)
    }
}

struct InternetArchiveLoginContent: View {
    
    @EnvironmentObject var state: InternetArchiveLoginViewState
    var store: any Store<InternetArchiveLoginViewModel.Action>
    @State private var isShowPassword = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        VStack(alignment: .center) {
            HStack {
                Image("InternetArchiveLogo")
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Internet Archive")).font(.headline)
                    Text(LocalizedStringKey("Upload your media to a public server.")).font(.subheadline)
                }
            }.padding()
            
            Spacer()
            
            TextField(LocalizedStringKey("Enter a username..."), text: state.userName)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(.leading)
                .padding(.trailing)
            
            
            HStack {
                if (isShowPassword) {
                    TextField(LocalizedStringKey("Password"), text: state.password)
                } else {
                    SecureField(LocalizedStringKey("Password"), text: state.password)
                }
                Button(action: { isShowPassword = !isShowPassword}) {
                    Image(systemName: isShowPassword ? "eye.slash" : "eye").foregroundColor(.gray)
                }
            }.padding().overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding(.leading)
            .padding(.trailing)
            
            Spacer()
            
            if (state.isLoginError) {
                Text(LocalizedStringKey("Invalid username or password")).foregroundColor(.red).padding()
            }
            
            HStack(alignment: .center) {
                Text(LocalizedStringKey("No Account?"))
                Button(action: {
                    store.dispatch(.CreateAccount)
                }) {
                    Text(LocalizedStringKey("Create Account"))
                }.foregroundColor(.accent)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                Button(action: {
                    store.notify(.Cancel)
                }, label: {
                    Text(LocalizedStringKey("Cancel"))
                }).padding().frame(maxWidth: .infinity).foregroundColor(.accent)
                
                Button(action: {
                    store.dispatch(.Login)
                }, label: {
                    
                    if (state.isBusy) {
                        ActivityIndicator(style: .medium, animate: .constant(true))
                    } else {
                        Text(LocalizedStringKey("Login"))
                    }
                })
                .padding()
                .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
                .background(Color.accent)
                .foregroundColor(.black)
                .cornerRadius(12)
            }.padding()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InternetArchiveLoginView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = Container.shared.internetArchiveViewModel(StoreScope())
        
        InternetArchiveLoginView(viewModel: viewModel)
    }
}
