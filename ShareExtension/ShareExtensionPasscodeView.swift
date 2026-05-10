//
//  ShareExtensionPasscodeView.swift
//  ShareExtension
//
//  Passcode gate for the Share Extension. Visual design mirrors the main app's
//  PasscodeEntryView / PasscodeContentWrapper / PasscodeDots / NumericKeypad.
//  Self-contained: no dependency on Save-target types beyond KeychainHelper.
//

import SwiftUI
import CommonCrypto

// MARK: - Brand colours (hex values taken from the asset catalog)
// Accent  → Shared/Assets.xcassets/Colors/Accent.colorset    #00B4A6
// RedBtn  → Shared/Assets.xcassets/Colors/red-button.colorset #DC341E
private let brandAccent = Color(red: 0/255,   green: 180/255, blue: 166/255)
private let brandRed    = Color(red: 220/255, green: 52/255,  blue: 30/255)

// MARK: - Keychain check

/// Returns `true` when a passcode hash exists in the shared Keychain.
func shareExtensionPasscodeIsSet() -> Bool {
    KeychainHelper.retrieve(key: "passcode_hash") != nil
}

// MARK: - PBKDF2 helper (mirrors PBKDF2HashingStrategy in the main app)

/// Hashes `passcode` with `salt` using PBKDF2-SHA256, 65 536 iterations, 32-byte key.
private func pbkdf2Sha256(passcode: String, salt: Data) -> Data? {
    let passwordData = Data(passcode.utf8)
    var hash = Data(count: 32)
    let status: CCCryptorStatus = hash.withUnsafeMutableBytes { hashPtr in
        salt.withUnsafeBytes { saltPtr in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passcode, passwordData.count,
                saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                65536,
                hashPtr.baseAddress?.assumingMemoryBound(to: UInt8.self), 32
            )
        }
    }
    return status == kCCSuccess ? hash : nil
}

// MARK: - Dot indicators (matches PasscodeDots)

private struct ExtPasscodeDots: View {
    let passcodeLength: Int
    let currentLength: Int
    let shouldShake: Bool
    let onAnimationCompleted: () -> Void

    @State private var shakeOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<passcodeLength, id: \.self) { index in
                Circle()
                    .fill(
                        index < currentLength
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : Color.gray.opacity(0.5)
                    )
                    .frame(width: 20, height: 20)
            }
        }
        .offset(x: shakeOffset)
        .onChange(of: shouldShake) { newValue in
            if newValue { runShake() }
        }
    }

    private func runShake() {
        let offsets: [CGFloat] = [30, 20, 10]
        var delay: Double = 0
        for offset in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = -offset }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = offset }
            }
            delay += 0.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { onAnimationCompleted() }
        }
    }
}

// MARK: - Number button (matches NumberButton in NumericKeypad)

private struct ExtNumberButton: View {
    let number: String
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isTapped = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.05)) { isTapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.05)) { isTapped = false }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .stroke(
                        isTapped ? brandAccent.opacity(0.5) : brandAccent,
                        lineWidth: isTapped ? 4 : 2
                    )
                    .scaleEffect(isTapped ? 0.95 : 1.0)
                Text(number)
                    .font(.title)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .frame(width: 72, height: 72)
        }
    }
}

// MARK: - Special button (delete / enter) matches SpecialButton in NumericKeypad

private struct ExtSpecialButton: View {
    let systemImage: String
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Main view

struct ShareExtensionPasscodeView: View {

    let onSuccess: () -> Void
    let onCancel: () -> Void

    private let passcodeLength = 6  // matches AppConfig.default.passcodeLength

    @State private var passcode = ""
    @State private var isProcessing = false
    @State private var shouldShake = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(alignment: .center, spacing: 16) {

                // Cancel button — top-left, same position as close button in main extension
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(16)
                    }
                    Spacer()
                }

                // Logo — matches PasscodeContentWrapper's logo block
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)

                // Title — matches PasscodeContentWrapper title style
                Text(NSLocalizedString("Enter your Passcode", comment: ""))
                    .font(.montserrat(.semibold, for: .headline))
                    .padding(.top, 30)

                // Dot indicators — matches PasscodeDots
                ExtPasscodeDots(
                    passcodeLength: passcodeLength,
                    currentLength: passcode.count,
                    shouldShake: shouldShake,
                    onAnimationCompleted: {
                        // Clear passcode AFTER shake (dots stay filled during animation — matches main app)
                        passcode = ""
                        shouldShake = false
                        isProcessing = false
                    }
                )
                .padding(.vertical, 50)

                // Numeric keypad — matches NumericKeypad layout
                keypad
                    .padding(.horizontal, 15)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 40)
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    // MARK: Keypad

    private var keypad: some View {
        let keys = ["1","2","3","4","5","6","7","8","9","delete","0","enter"]
        return VStack(spacing: 24) {
            ForEach(0..<4) { row in
                HStack(spacing: 24) {
                    ForEach(0..<3) { col in
                        let key = keys[row * 3 + col]
                        keyCell(key)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func keyCell(_ key: String) -> some View {
        switch key {
        case "delete":
            ExtSpecialButton(
                systemImage: "delete.backward",
                backgroundColor: brandRed.opacity(0.3)
            ) {
                guard !isProcessing, !passcode.isEmpty else { return }
                passcode.removeLast()
            }
        case "enter":
            ExtSpecialButton(
                systemImage: "arrow.right.to.line",
                backgroundColor: brandAccent.opacity(0.8)
            ) {
                guard !isProcessing, !passcode.isEmpty else { return }
                verify()
            }
        default:
            ExtNumberButton(number: key) {
                guard !isProcessing, passcode.count < passcodeLength else { return }
                passcode += key
                if passcode.count == passcodeLength { verify() }
            }
            .disabled(isProcessing)
        }
    }

    // MARK: Verification

    private func verify() {
        isProcessing = true
        let entered = passcode

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            let authenticated: Bool
            if let storedHash = KeychainHelper.retrieve(key: "passcode_hash"),
               let salt      = KeychainHelper.retrieve(key: "passcode_salt"),
               let computed  = pbkdf2Sha256(passcode: entered, salt: salt) {
                authenticated = computed == storedHash
            } else {
                // No hash found — passcode not yet set; let through.
                authenticated = true
            }

            DispatchQueue.main.async {
                if authenticated {
                    isProcessing = false
                    onSuccess()
                } else {
                    // Keep passcode visible so dots shake while still filled — matches main app.
                    // passcode and isProcessing are cleared in onAnimationCompleted.
                    shouldShake = true
                }
            }
        }
    }
}
