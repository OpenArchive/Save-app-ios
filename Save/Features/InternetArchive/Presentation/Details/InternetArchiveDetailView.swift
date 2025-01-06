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
    @Environment(\.colorScheme) var colorScheme
    @State private var showAlert = false
    
    var body: some View {
           VStack(alignment: .leading) {
               Spacer().frame(maxHeight: 20)
               HStack {
                   Circle().fill(colorScheme == .dark ? Color.white : Color.pillBackground)
                       .frame(width: 50, height: 50)
                       .overlay(
                           Image("InternetArchiveLogo")
                               .resizable()
                               .aspectRatio(contentMode: .fit)
                               .frame(width: 25, height: 25)
                       ).padding(.trailing, 6)
                  
                   Text(LocalizedStringKey("Upload your media to a free public or paid private account on the Internet Archive.")).font(.subheadline) .lineLimit(nil)
                       .fixedSize(horizontal: false, vertical: true)
                       .multilineTextAlignment(.leading)
                   
               }
             
               .padding()

              
               Group {
                   Text(LocalizedStringKey("Username"))
                       .font(.caption)
                       .foregroundColor(.gray)
                       .padding(.horizontal)
                       .padding(.top, 4)

                   Text(state.userName)
                       .font(.body)
                       .frame(maxWidth: .infinity, alignment: .leading)
                       .padding()
                       .background(
                           RoundedRectangle(cornerRadius: 8)
                               .fill(Color(UIColor.systemBackground))
                              
                               .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
                       )
                       .padding(.horizontal)
               }

            
               Group {
                   Text(LocalizedStringKey("Screen Name"))
                       .font(.caption)
                       .foregroundColor(.gray)
                       .padding(.horizontal)

                   Text(state.screenName)
                       .font(.body)
                       .frame(maxWidth: .infinity, alignment: .leading)
                       .padding()
                       .background(
                           RoundedRectangle(cornerRadius: 8)
                               .fill(Color(UIColor.systemBackground))
                               .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
                       )
                       .padding(.horizontal)
               }

             
               Group {
                   Text(LocalizedStringKey("Email"))
                       .font(.caption)
                       .foregroundColor(.gray)
                       .padding(.horizontal)

                   Text(state.email)
                       .font(.body)
                       .padding()
                       .frame(maxWidth: .infinity, alignment: .leading)
                       .background(
                           RoundedRectangle(cornerRadius: 8)
                               .fill(Color(UIColor.systemBackground))
                               .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
                       )
                       .padding(.horizontal)
               }

               Spacer()

              
               HStack {
                   Spacer()
                   Button(action: {
                       showAlert = true
                   }) {
                       Text(LocalizedStringKey("Remove Media"))
                           .font(.body)
                           .bold()
                           .frame(maxWidth: .infinity)
                           .padding()
                           .background(Color.red)
                           .foregroundColor(.white)
                           .cornerRadius(8)
                           .padding(.horizontal)
                   }
                   .alert(isPresented: $showAlert) {
                       Alert(
                           title: Text(LocalizedStringKey("Remove from App")),
                           message: Text(LocalizedStringKey("Are you sure you want to remove this server from the app?")),
                           primaryButton: .destructive(Text("Remove")) {
                               dispatch(.Remove)
                           },
                           secondaryButton: .cancel()
                       )
                   }
                   Spacer()
               }
           
               .padding(.bottom)
           }    .background(
            colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground)
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
