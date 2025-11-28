import SwiftUI

struct ScanDIDView: View {
    @EnvironmentObject var didState: DIDState
    let spaceDid: String
    @Environment(\.presentationMode) var presentationMode
    @State private var typedDID: String = ""
    @State private var showScannerView = false
    @State private var showToast = false
    @State private var errorMsg = ""
    @State private var isAddingDID = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        NSLocalizedString("add_member_instruction", comment: "")
                            .parseMarkdownBold(
                                regularFont: .montserrat(.regular, for: .footnote),
                                boldFont: .montserrat(.bold, for: .footnote),
                                color: .gray70
                            )
                            .padding(.horizontal)
                        
                        HStack {
                            CustomTextField(placeholder: NSLocalizedString("Enter DID Key", comment: ""), text: $typedDID)
                            Button(action: {
                                showScannerView = true
                            }) {
                                Image("qr_code")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray70)
                                    )
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await addDID()
                            }
                        }) {
                            Text(NSLocalizedString("Next", comment: ""))
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width / 2)
                        .disabled(typedDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingDID)
                        .padding()
                        .background(typedDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingDID ? Color.gray.opacity(0.3) : Color.accentColor)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .font(.montserrat(.semibold, for: .headline))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Loading Overlay
                if isAddingDID {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text(NSLocalizedString("Adding DID...", comment: ""))
                                    .font(.montserrat(.medium, for: .callout))
                                    .foregroundColor(.white)
                            }
                            .padding(24)
                        )
                }
            }
            .sheet(isPresented: $showScannerView) {
                QRCodeScannerView(
                    isPresented: $showScannerView,
                    onCodeScanned: { scannedValue in
                        typedDID = scannedValue
                        showScannerView = false
                    }
                )
            }
        }
        .toast(isShowing: $showToast, message: errorMsg)
    }
    
    // MARK: - Helper
    private func addDID() async {
        let trimmed = typedDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if didState.dids.contains(trimmed) {
            showToast = true
            errorMsg = NSLocalizedString("DID is already added.", comment: "")
        } else if !DIDKeyManager().isValidDid(trimmed) {
            showToast = true
            errorMsg = NSLocalizedString("Invalid DID format. Please scan a valid DID key (format: did:key:z...).", comment: "")
        } else {
            showToast = false
            errorMsg = ""
            
            // Show loading overlay
            isAddingDID = true
            
            await didState.addDID(for: spaceDid, did: trimmed)
            await didState.loadDIDs(for: spaceDid)
            
            // Hide loading overlay
            isAddingDID = false
            
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - QR Code Scanner View
struct QRCodeScannerView: View {
    @Binding var isPresented: Bool
    let onCodeScanned: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Position the QR code within the frame to scan")
                    .font(.montserrat(.semibold, for: .subheadline))
                    .foregroundColor(.secondary)
                    .padding()
                
                BarcodeScannerView(
                    onScan: { scannedValue in
                        onCodeScanned(scannedValue)
                    },
                    isPresented: $isPresented
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(12)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
