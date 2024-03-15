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
    
    @EnvironmentObject var state: InternetArchiveLoginState
    var store: any Store<InternetArchiveLoginViewModel.Action>
    
    var body: some View {
        
        VStack {
            Text("Hello Internet Archive")
            
            TextField("Username", text: $state.userName).padding()
            TextField("Password", text: $state.password).padding()
            
            if (state.isLoginError) {
                Text("Invalid username or password").foregroundColor(.red)
            }
            
            HStack {
                Button(action: {
                    store.notify(.Cancel)
                }, label: {
                    Text("Cancel")
                }).padding()
                Button(action: {
                    store.dispatch(.Login)
                }, label: {
                    Text("Login")
                }).padding()
            }.alignmentGuide(.bottom, computeValue: { dimension in
                dimension.height
            })
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
