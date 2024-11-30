import SwiftUI

struct PinLoginView: View {
    @State private var enteredPin: [String] = []
    private let pinLength = 6
    @State private var errorMessage: String?
    var completion: (Bool) -> Void // Callback for validation result
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack {
            
            
            Image("save-open-archive-logo")
                .resizable()
                .scaledToFit()
                .frame( height: 80)
                .padding()
            Spacer(minLength: 30)
            Text("Enter Your Passcode")
                .fontWeight(.medium)
                .padding(.bottom, 20)
            
            HStack(spacing: 10) {
                ForEach(0..<pinLength, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPin.count
                              ? (colorScheme == .dark ? Color.white : Color.black)
                              : Color.gray.opacity(0.5))
                        .frame(width: 15, height: 15)
                }
            }
            .padding(.bottom, 30)
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom)
            }
            
            VStack(spacing: 15) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            NumberButton(number: "\(number)") {
                                handleTap(number: "\(number)")
                            }
                        }
                    }
                }
                HStack(spacing: 20) {
                    NumberButton(number: "Exit") {
                        completion(false) // Exit logic
                    }
                    NumberButton(number: "0") {
                        handleTap(number: "0")
                    }
                    NumberButton(symbol: "delete.left") {
                        handleDelete()
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
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
            return
        }
        
        guard let privateKey = SecureEnclave.loadKey() else {
            errorMessage = "Unable to access Secure Enclave. Please try again."
            return
        }
        
        guard let decryptedPin = SecureEnclave.decrypt(encryptedPinData, with: privateKey) else {
            errorMessage = "Failed to decrypt the PIN. Please try again."
            return
        }
        
        if decryptedPin == enteredPin.joined() {
            print("PIN verified successfully!")
            errorMessage = nil // Clear any existing error
            completion(true) // Call the completion handler with success
        } else {
            errorMessage = "Incorrect PIN. Please try again."
            enteredPin.removeAll() // Clear the entered PIN
        }
    }
    
}

struct NumberButton: View {
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
