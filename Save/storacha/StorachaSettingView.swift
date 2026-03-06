import SwiftUI
import Combine

enum StorachaSettingAction {
    case manageAccounts
    case mySpaces
    case joinSpace
}

struct StyledButton: View {
    let title: String
    let subtitle: String
    let icon: String?
    let action: () -> Void
    let isDisabled: Bool
    
    init(title: String, subtitle: String, icon: String? = nil, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isDisabled ? .gray50 : Color(.accent))
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(isDisabled ? .gray50 : Color(.label))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.montserrat(.medium, for: .subheadline))
                        .foregroundColor(isDisabled ? .gray50 : .gray70)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image("forward_arrow")
                    .renderingMode(.template)
                    .foregroundColor(isDisabled ? .gray50 : Color(.label))
                    .frame(width: 24, height: 24)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isDisabled ? .gray10 : (Color(.systemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDisabled ? Color.gray50 : Color.gray30, lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .padding(.horizontal)
    }
}

struct StorachaSettingView: View {
    @ObservedObject var appState: StorachaAppState
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    var manageAccountsAction: ((StorachaSettingAction) -> Void)?
    
    init(
        appState: StorachaAppState,
        disableBackAction: ((Bool) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil,
        manageAccountsAction: ((StorachaSettingAction) -> Void)? = nil
    ) {
        self.appState = appState
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        self.manageAccountsAction = manageAccountsAction
    }

    var body: some View {
        ZStack {
            
            VStack(spacing: 20) {
                
                VStack(spacing: 16) {
                    Image("storachaLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 60)
                    
                    Text(NSLocalizedString("Storacha lets you store media securely using decentralized technologies (IPFS, UCAN, and DIDs).", comment: ""))
                        .font(.montserrat(.medium, for: .subheadline))
                        .foregroundColor(.gray70)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineLimit(nil)
                }
                .padding(.vertical, 10)
                
                StyledButton(
                    title: NSLocalizedString("Manage Accounts", comment: ""),
                    subtitle: NSLocalizedString("Create or edit accounts",comment: ""),
                    icon: "person.circle",
                    isDisabled: appState.isBusy
                ) {
                    manageAccountsAction?(.manageAccounts)
                }
                
                StyledButton(
                    title: NSLocalizedString("My Spaces", comment: ""),
                    subtitle: NSLocalizedString("Access your spaces",comment: ""),
                    icon: "folder",
                    isDisabled : appState.isBusy || (!appState.hasValidSession && appState.delegatedSpaceCount < 1)

                ) {
                    manageAccountsAction?(.mySpaces)
                }
                
                StyledButton(
                    title: NSLocalizedString("Join Space",comment: ""),
                    subtitle: NSLocalizedString("Join an existing shared space",comment: ""),
                    icon: "plus",
                    isDisabled: appState.isBusy
                ) {
                    manageAccountsAction?(.joinSpace)
                }
                
                StorachaInfoCard()
                
                Spacer(minLength: 20)
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            
            if appState.isBusy {
                Color.black
                    .opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                .padding(24)
                
            }
        }
        .onAppear {
            disableBackAction?(appState.isBusy)
        }
        .onReceive(Just(appState.isBusy)) { isBusy in
            disableBackAction?(isBusy)
        }
    }
  
}

struct StorachaInfoCard: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray70)
                    .font(.system(size: 16))
                    .padding(.top, 2)

                StorachaContentDescription()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

struct StorachaContentDescription: View {
    var body: some View {
        Text(NSLocalizedString("Files uploaded to the Storacha (Filecoin/IPFS) network are publicly accessible through their CID and may remain permanently available across decentralized nodes. ", comment: "ProofMode description"))
            .font(.montserrat(.medium, for: .caption))
            .foregroundColor(.gray70)
        +
        Text("[\(NSLocalizedString("Learn more.", comment: "Learn more link"))](https://docs.storacha.network/how-to/upload/)")
            .font(.montserrat(.medium, for: .caption))
            .foregroundColor(.accent)
            .underline()
    }
}
