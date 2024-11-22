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
    @State private var keyboardOffset: CGFloat = 0
    @State private var isShowPassword = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        VStack(alignment: .center) {
            HStack {
                Circle().fill(colorScheme == .dark ? Color.white : Color.pillBackground)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image("InternetArchiveLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    ).padding(.trailing, 6)
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Internet Archive")).font(.headline)
                    Text(LocalizedStringKey("Upload your media to a free public or paid private account on the Internet Archive.")).font(.subheadline)
                    
                }
            }.padding()
            
            Spacer()
            
            TextField(LocalizedStringKey("Username"), text: state.userName)
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
                    Text(LocalizedStringKey("Create one"))
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
        }.padding(.bottom, keyboardOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: setupKeyboardObservers)
            .onDisappear(perform: removeKeyboardObservers)
            .animation(.easeOut(duration: 0.3))
    }
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardOffset = keyboardFrame.height + GeneralConstants.constraint_30
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardOffset = GeneralConstants.constraint_zero
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

struct InternetArchiveLoginView_Previews: PreviewProvider {
    static let state = InternetArchiveLoginState(
        userName: "abcuser",
        password: "abc",
        isLoginError: true,
        isValid: true,
        isBusy: false
    )
    
    static var previews: some View {
        InternetArchiveLoginContent(
            state: InternetArchiveLoginState.Bindings(
                userName: Binding.constant(state.userName),
                password: Binding.constant(state.password),
                isLoginError: state.isLoginError,
                isBusy: state.isBusy,
                isValid: state.isValid
            )
        ) { _ in }
    }
}
