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
        InternetArchiveLoginContent(
            state: viewModel.state(),
            dispatch: viewModel.store.dispatch
        )
    }
}

struct InternetArchiveLoginContent: View {
    
    let state: InternetArchiveLoginState.Bindings
    let dispatch: Dispatch<InternetArchiveLoginAction>
    
    @State private var isShowPassword = false
    
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
                    dispatch(.CreateAccount)
                }) {
                    Text(LocalizedStringKey("Create Account"))
                }.foregroundColor(.accent)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                Button(action: {
                    dispatch(.Cancel)
                }, label: {
                    Text(LocalizedStringKey("Cancel"))
                }).padding().frame(maxWidth: .infinity).foregroundColor(.accent)
                
                Button(action: {
                    dispatch(.Login)
                }, label: {
                    
                    if (state.isBusy) {
                        ActivityIndicator(style: .medium, animate: .constant(true)).foregroundColor(.black)
                    } else {
                        Text(LocalizedStringKey("Login"))
                    }
                })
                .disabled(!state.isValid)
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
    static let state = InternetArchiveLoginState()
    
    static var previews: some View {
        InternetArchiveLoginContent(
            state: InternetArchiveLoginState.Bindings(
                userName: Binding.constant(state.userName),
                password: Binding.constant(state.password),
                isLoginError: true,
                isBusy: false,
                isValid: true
            )
        ) { _ in }
    }
}
