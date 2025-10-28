import SwiftUI

struct ScanDIDView: View {
    @EnvironmentObject var didState: DIDState
    let spaceDid: String
    @Environment(\.presentationMode) var presentationMode
    @State private var typedDID: String = ""
    @State private var showScannerView = false
    @State private var showToast = false
    @State private var errorMsg = ""
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
             
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Enter a DID access key manually, or scan a QR code to add one.", comment: "")).foregroundColor(.gray70).font(.montserrat(.medium, for: .subheadline)).padding(.horizontal)
                    HStack {
                        CustomTextField(placeholder: NSLocalizedString("Enter DID Key", comment: ""),text: $typedDID)
                        Button(action: {
                            showScannerView = true
                        }) {
                            Image(systemName: "qrcode.viewfinder")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Spacer()
                
                
                HStack(spacing: 16) {
                  
                    Button("Next") {
                        Task {
                            await addDID()
                        }
                    }.font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(typedDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .disabled(typedDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showScannerView) {
                QRCodeScannerView { scannedValue in
                    typedDID = scannedValue
                    showScannerView = false
                }
            }
        }.toast(isShowing: $showToast, message: errorMsg)
    }
    
    // MARK: - Helper
    private func addDID() async {
        let trimmed = typedDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if(didState.dids.contains(trimmed)){
            showToast = true
            errorMsg = NSLocalizedString("DID is already added.", comment: "")
            
        }else if(!DIDKeyManager().isValidDid(trimmed)){
            showToast = true
            errorMsg = NSLocalizedString("Invalid DID format. Please scan a valid DID key (format: did:key:z...).", comment: "")
        }
        else{
            showToast = false
            errorMsg = ""
            await didState.addDID(for: spaceDid, did: trimmed)
            await didState.loadDIDs(for: spaceDid)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - QR Code Scanner View
struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Position the QR code within the frame to scan")
                    .font(.montserrat(.semibold, for: .subheadline))
                    .foregroundColor(.secondary)
                    .padding()
                
                BarcodeScannerView { scannedValue in
                    onCodeScanned(scannedValue)
                }
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
