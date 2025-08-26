//
//  StorachaLoginView.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//
//
//  StorachaLoginView.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct StorachaLoginView: View {
    @ObservedObject var state: StorachaAppState
    var dispatch: (StorachaLoginAction) -> Void
    @Environment(\.colorScheme) var colorScheme

    enum Field {
        case email
    }
    
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
   
    init(
        state: StorachaAppState,
        dispatch: @escaping (StorachaLoginAction) -> Void,
        disableBackAction: ((Bool) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.dispatch = dispatch
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
    }
    
    var body: some View {
        GeometryReader { reader in
            if #available(iOS 14.0, *) {
                
                VStack {
                    HStack {
                        Circle().fill(.gray10)
                            .frame(width: 53, height: 53)
                            .overlay(
                                Image("storacha")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                            ).padding(.trailing, 6)
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("Access your admin portal using your registered email address.")) .font(.montserrat(.medium, for: .subheadline))
                        }
                    }
                    .padding(.top,50).padding(.leading,20).padding(.trailing,40)
                    
                    Text(LocalizedStringKey("Account")).font(.montserrat(.semibold, for: .headline)).foregroundColor(.gray70).padding(.top,50).frame(maxWidth: .infinity, alignment: .leading).padding(.leading,20)
                    ZStack(alignment: .leading) {
                        if state.email.isEmpty {
                            Text("Email")
                                .italic()
                                .font(.montserrat(.medium, for: .footnote))
                                .foregroundColor(.textEmpty)
                                .padding(.leading, 5)
                        }
                        
                        
                        TextField("", text:$state.email)
                            .autocapitalization(.none)
                            .font(.montserrat(.medium, for: .footnote))
                            .foregroundColor(.gray70)
                        
                    }
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.7)))
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    
                    
                    if (state.isLoginError) {
                        Text(LocalizedStringKey("Incorrect email")).foregroundColor(.red).padding(.top,1) .padding(.leading,20).font(.montserrat(.medium, for: .caption2))
                            .padding(.trailing,20) .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack(alignment: .center) {
                        Text(LocalizedStringKey("No Account?")).foregroundColor(.gray70).font(.montserrat(.semibold, for: .callout))
                        Button(action: {
                            dispatch(.createAccount)
                        }) {
                            Text(LocalizedStringKey("Create one"))
                        }.foregroundColor(.accent).font(.montserrat(.semibold, for: .callout))
                    }.padding(.top,40)
                    
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        Button(action: {
                            dispatch(.cancel)
                        }, label: {
                            Text(LocalizedStringKey("Back"))
                        })
                        .padding()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(state.isBusy ? .gray50 : (colorScheme == .dark ? Color.white : Color.black))
                        .font(.montserrat(.semibold, for: .headline))
                        .disabled(state.isBusy)
                        
                        Button(action: {
                            if (!state.isBusy) {
                                dispatch(.login)
                            }
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
                        .background(!state.isValid ? .gray50 :  Color.accent)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .font(.montserrat(.semibold, for: .headline))
                        
                    }
                    .padding(.bottom,40).padding(.leading,20).padding(.trailing,20)
                } .frame(minHeight: reader.size.height)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                
                
                
            } else {
                // Fallback on earlier versions
            }
            
        }.background(Color(.systemBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
        
    }
}
