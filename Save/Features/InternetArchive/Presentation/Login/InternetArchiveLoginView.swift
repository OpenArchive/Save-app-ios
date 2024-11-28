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
        GeometryReader { reader in
            ScrollView {
                VStack {
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
                    }
                    .padding()
                    
                    
                    Spacer()
                    
                    TextField(LocalizedStringKey("Username"), text: state.userName)
                        .autocapitalization(.none)
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
                    //
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
                        })
                        .padding()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.accent)
                        
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
                        .frame(maxWidth: .infinity)
                        .background(Color.accent)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding()
                } .frame(minHeight: reader.size.height)
                
                
            }
            
            .keyboardAware()
            
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
struct GeometryGetter: View {
    @Binding var rect: CGRect
    
    var body: some View {
        GeometryReader { geometry in
            Group { () -> AnyView in
                DispatchQueue.main.async {
                    self.rect = geometry.frame(in: .global)
                }
                
                return AnyView(Color.clear)
            }
        }
    }
}

public class KeyboardInfo: ObservableObject {
    
    public static var shared = KeyboardInfo()
    
    @Published public var height: CGFloat = 0
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardChanged), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardChanged), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardChanged), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    @objc func keyboardChanged(notification: Notification) {
        if notification.name == UIApplication.keyboardWillHideNotification {
            self.height = 0
        } else {
            self.height = (((notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0.0))
        }
    }
    
}

struct KeyboardAware: ViewModifier {
    @ObservedObject private var keyboard = KeyboardInfo.shared
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, self.keyboard.height)
            .edgesIgnoringSafeArea(self.keyboard.height > 0 ? .bottom : [])
            .animation(.easeOut)
    }
}

extension View {
    public func keyboardAware() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAware())
    }
}
