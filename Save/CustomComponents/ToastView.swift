//
//  ToastView.swift
//  Save
//
//  Created by navoda on 2025-10-15.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
// Toast View
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.montserrat(.medium, for: .subheadline))
            .foregroundColor(Color(UIColor.systemBackground))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.gray70)
            .cornerRadius(8)
            .padding(.horizontal, 20)
    }
}

// Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                        .padding(.bottom, 50)
                }
                .animation(.spring(), value: isShowing)
            }
        }
    }
}

// Extension for easy usage
extension View {
    func toast(isShowing: Binding<Bool>, message: String, duration: TimeInterval = 2.0) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, duration: duration))
    }
}
extension UIViewController {
    func showToast(message: String, duration: TimeInterval = 2.0) {
        
        let toastView = ToastContainerView(message: message, duration: duration)
        let hostingController = UIHostingController(rootView: toastView)
      
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
      
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
        }
    }
}

// MARK: - Toast Container View
struct ToastContainerView: View {
    let message: String
    let duration: TimeInterval
    @State private var isShowing = false
    
    var body: some View {
        ZStack {
            Color.clear // Transparent background
            
            if isShowing {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            withAnimation(.spring()) {
                isShowing = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation {
                    isShowing = false
                }
            }
        }
        .ignoresSafeArea()
    }
}
