import SwiftUI

struct ScanDIDView: View {
    @EnvironmentObject var didState: DIDState
    let spaceDid: String
    @Environment(\.presentationMode) var presentationMode
    @State private var typedDID: String = ""
    @State private var showScannerView = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Input section
                VStack(alignment: .leading, spacing: 8) {
                   
                    HStack {
                        TextField("DID Access Key", text: $typedDID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.montserrat(.semibold, for: .callout))
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
                
                // Bottom buttons
                HStack(spacing: 16) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }.font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.backButton)
                        .cornerRadius(8)
                    
                    Button("Add") {
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
        }
    }
    
    // MARK: - Helper
    private func addDID() async {
        let trimmed = typedDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        await didState.addDID(for: spaceDid, did: trimmed)
        await didState.loadDIDs(for: spaceDid)
        presentationMode.wrappedValue.dismiss()
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
