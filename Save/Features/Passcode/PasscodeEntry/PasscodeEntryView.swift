import SwiftUI

struct PasscodeEntryView: View {
    
    @State private var enteredPin: [String] = []
    @State private var shouldShake = false
    @State private var errorMessage: String?
    private let pinLength = 6
    
    var onPasscodeSuccess: () -> Void
    var onExit: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        VStack {
            
            // MARK: Logo Section
            Image("save-open-archive-logo")
                .resizable()
                .scaledToFit()
                .frame( height: 80)
                .padding()
            
            Spacer(minLength: 30)
            
            // MARK: Title Section
            Text("Enter Your Passcode")
                .fontWeight(.medium)
                .padding(.bottom, 20)
            
            // MARK: Passcode Dots
            PasscodeDots(
                passcodeLength: pinLength,
                currentPasscodeLength: enteredPin.count,
                shouldShake: shouldShake
            ).padding(.bottom, 30)
            
            
            VStack(spacing: 15) {
                NumericKeypad(
                    isEnabled: true,
                    onNumberClick: { number in
                        handleTap(number: number)
                    }
                )
            }
            .padding()
            
            Spacer()
            
            HStack {
                
                Button(action: onExit) {
                    Text("Exit")
                }
                
                Spacer()
                
                Button(action: handleDelete) {
                    Text("Delete")
                }
                
            }.padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
        }
        .padding()
        .alert(isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }
    
    private func handleTap(number: String) {
        if enteredPin.count < pinLength {
            enteredPin.append(number)
        }
        if enteredPin.count == pinLength {
            validatePin()
        }
    }
    
    private func handleDelete() {
        if !enteredPin.isEmpty {
            enteredPin.removeLast()
        }
    }
    
    private func validatePin() {
        guard let encryptedPinData = UserDefaults.standard.data(forKey: Keys.encryptedAppPin) else {
            errorMessage = "No PIN is set. Please set up a PIN first."
            triggerShakeAnimation()
            enteredPin.removeAll()
            return
        }
        
        guard let privateKey = SecureEnclave.loadKey() else {
            errorMessage = "Unable to access Secure Enclave. Please try again."
            triggerShakeAnimation()
            return
        }
        
        guard let decryptedPin = SecureEnclave.decrypt(encryptedPinData, with: privateKey) else {
            errorMessage = "Failed to decrypt the PIN. Please try again."
            triggerShakeAnimation()
            return
        }
        
        if decryptedPin == enteredPin.joined() {
            print("PIN verified successfully!")
            errorMessage = nil // Clear any existing error
            onPasscodeSuccess() // Call the completion handler with success
        } else {
            errorMessage = "Incorrect PIN. Please try again."
            enteredPin.removeAll() // Clear the entered PIN
            triggerShakeAnimation()
        }
    }
    
    private func triggerShakeAnimation() {
        shouldShake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            shouldShake = false // Reset shake after animation completes
        }
    }
}

struct NumericKeypad: View {
    var isEnabled: Bool
    var onNumberClick: (String) -> Void
    
    private let keys = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", " "]
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { key in
                        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Spacer()
                                .frame(width: 72, height: 72)
                        } else {
                            NumberButton(number: key) {
                                onNumberClick(key)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct NumberButton: View {
    var number: String
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.accent, lineWidth: 2)
                    .frame(width: 72, height: 72)
                
                Text("\(number)")
                    .font(.title)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                
            }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var shouldShake: Bool
    var animatableData: CGFloat {
        get { CGFloat(shouldShake ? 1 : 0) }
        set { }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        guard shouldShake else { return ProjectionTransform(.identity) }
        let translation = CGFloat(sin(Double(animatableData) * .pi * 2) * 10)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct NumberButton2: View {
    var number: String?
    var symbol: String?
    var action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.accent, lineWidth: 2)
                    .frame(width: 70, height: 70)
                if let number = number {
                    Text(number)
                        .font(.title)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                }
                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.title)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                }
            }
        }
    }
}

struct PasscodeDots: View {
    
    let passcodeLength: Int
    let currentPasscodeLength: Int
    let shouldShake: Bool
    
    @State private var shakeOffset: CGFloat = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        if #available(iOS 14.0, *) {
            HStack(spacing: 12) {
                ForEach(0..<passcodeLength, id: \.self) { index in
                    Circle()
                        .fill(index < currentPasscodeLength
                              ? (colorScheme == .dark ? Color.white : Color.black)
                              : Color.gray.opacity(0.5)
                        )
                        .frame(width: 20, height: 20)
                }
            }
            .offset(x: shakeOffset)
            .onChange(of: shouldShake) { newValue in
                if newValue {
                    shakeAnimation()
                }
            }
        } else {
            // Fallback on earlier versions
            Text("")
        }
    }
    private func shakeAnimation() {
        let offsets: [CGFloat] = [30, 20, 10]
        var delay: Double = 0
        
        for offset in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    shakeOffset = -offset
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    shakeOffset = offset
                }
            }
            
            delay += 0.2 // Increase the delay for the next shake
        }
        
        // Reset to the original position after the final shake
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 0
            }
        }
    }
}
