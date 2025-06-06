
import SwiftUI
import SwiftUIIntrospect
import OrbotKit

class SettingsViewModel: ObservableObject {
    @Published var isPasscodeOn = AppSettings.isPasscodeEnabled
    @Published var isWifiOnlyOn = Settings.wifiOnly
    @Published var isOnionRoutingOn = false
    
    weak var delegate: ViewControllerNavigationDelegate?
    
    func navigateToServerList() {
        delegate?.pushServerList()
    }
    
    func navigateToFolderList() {
        
        delegate?.pushFolderList()
    }
    func navigateToProofMode(){
        let proofModeSettingsViewController = ProofModeSettingsViewController()
        delegate?.pushViewController(proofModeSettingsViewController)
    }
    
    func togglePasscode(_ value: Bool) {
        if value {
            let passcodeSetupController = PasscodeSetupController()
            delegate?.pushViewController(passcodeSetupController)
        }
    }
    
    
    func toggleOrbot(completion: @escaping (Bool) -> Void) {
        guard !isOnionRoutingOn else {
            OrbotManager.shared.stop()
            Settings.useOrbot = false
            isOnionRoutingOn = false
            completion(false)
            return
        }
        guard OrbotManager.shared.installed else {
            OrbotManager.shared.alertOrbotNotInstalled()
            Settings.useOrbot = false
            isOnionRoutingOn = false
            completion(false)
            return
        }
        if Settings.orbotApiToken.isEmpty {
            OrbotManager.shared.alertToken {
                OrbotManager.shared.start()
                Settings.useOrbot = true
                self.isOnionRoutingOn = true
                completion(true)
            }
        } else {
            OrbotManager.shared.start()
            Settings.useOrbot = true
            isOnionRoutingOn = true
            completion(true)
        }
    }
    
    func openOrbot() {
        OrbotKit.shared.open(.show)
    }
    
    func orbotTorStatus() -> String {
        if OrbotManager.shared.status == .started {
            if Settings.useTor {
                return NSLocalizedString("Tor enabled and connected", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled and Tor connected", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled but is connected", comment: "")
            }
        } else if OrbotManager.shared.status == .starting {
            if Settings.useTor {
                return NSLocalizedString("Tor is enabled and starting...", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled and Tor is starting...", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled but starting...", comment: "")
            }
        } else {
            if Settings.useTor {
                return NSLocalizedString("Tor is enabled but disconnected", comment: "")
            } else if Settings.useOrbot {
                return NSLocalizedString("Orbot enabled but Tor is disconnected", comment: "")
            } else {
                return NSLocalizedString("Tor is not enabled and disconnected", comment: "")
            }
        }
    }
}

// Reusable Switch Toggle Component
struct ToggleSwitch: View {
    var title: String
    var subtitle: String?
    var isDisabled:Bool = false
    @Binding var isOn: Bool
    var action: ((Bool) -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading,spacing: 1) {
                Text(title)
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    if #available(iOS 14.0, *) {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption2))
                            .foregroundColor(.settingSubtitle)
                    } else {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption))
                            .foregroundColor(.settingSubtitle)
                    }
                    
                }
            }.padding(.vertical, 6)
            Spacer()
            if #available(iOS 15.0, *) {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .disabled(isDisabled)
                    .tint(.accent)
                    .onChange(of: isOn) { value in
                        action?(value)
                    }
            } else if #available(iOS 14.0, *) {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .disabled(isDisabled)
                    .accentColor(isOn ? .accentColor : .gray30)
                    .onChange(of: isOn) { value in
                        action?(value)
                    }
            } else {
                
            }
        }
    }
}

// Clickable Sub-item Component
struct SubItem: View {
    var title: String
    var subtitle: String?
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading,spacing: 1) {
                Text(title)
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    if #available(iOS 14.0, *) {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption2))
                            .foregroundColor(.settingSubtitle)
                    } else {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption))
                            .foregroundColor(.settingSubtitle)
                    }
                }
            }
            .padding(.vertical, 6)
        }.buttonStyle(PlainButtonStyle())
    }
}
struct HideItemSeparator: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.listRowSeparator(.hidden) // Works in iOS 15+
        } else {
            content.listRowBackground(Color.clear) // Hides background in iOS 14
        }
    }
}
struct ListSpacingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.listSectionSpacing(1) // iOS 17+ uses listSectionSpacing
        } else {
            content
                .environment(\.defaultMinListHeaderHeight, 0) // iOS 16 and below
                .introspect(.list, on: .iOS(.v15)) { tableView in
                    tableView.sectionHeaderHeight = 0
                    tableView.sectionFooterHeight = 0
                }
        }
    }
}


@available(iOS 14.0, *)
struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var selectedTheme: String
    @State private var showActionSheet = false
    @State private var showPasscodeAlert = false
    @State private var showTorAlert = false
    @State private var passcodeToggleState: Bool
    @State private var isProgrammaticallyChangingPasscodeToggle = false
    @State private var showCompressionSheet = false
    private static let compressionOptions = [
        NSLocalizedString("Better Quality", comment: ""),
        NSLocalizedString("Smaller Size", comment: "")
    ]
    @State private var selectedCompressionOption: String = Settings.highCompression
        ? SettingsView.compressionOptions[1]  // "Smaller Size"
        : SettingsView.compressionOptions[0]  // "Better Quality"

    init() {
        _selectedTheme = State(initialValue: AppSettings.theme)
        _passcodeToggleState = State(initialValue: AppSettings.isPasscodeEnabled)
    }
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                List {
                    let sections: [(String, [AnyView])] = [
                        (NSLocalizedString("Share", comment: ""),
                         [
                            AnyView(ToggleSwitch(title: NSLocalizedString("Lock app with passcode", comment: ""), isOn: $passcodeToggleState) { value in
                                
                                guard !isProgrammaticallyChangingPasscodeToggle else {
                                    return
                                }
                                if value {
                                    viewModel.togglePasscode(value)
                                } else {
                                    if AppSettings.isPasscodeEnabled {
                                        showPasscodeAlert = true
                                    }
                                }
                            })
                         ]),
                        
                        (NSLocalizedString("Archive", comment: ""),
                         [
                            AnyView(ToggleSwitch(title: NSLocalizedString("Only upload media when you are connected to Wi-Fi", comment: ""), isOn: $viewModel.isWifiOnlyOn) { value in
                                Settings.wifiOnly = value
                                NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: value)
                            }),
                            AnyView(SubItem(title: NSLocalizedString("Media Servers", comment: ""), subtitle: NSLocalizedString("Manage your servers", comment: "")) {
                                viewModel.navigateToServerList()
                            }),
                            AnyView(SubItem(title: NSLocalizedString("Archived Folders", comment: ""), subtitle: NSLocalizedString("Manage your archived folders", comment: "")) {
                                viewModel.navigateToFolderList()
                            })
                         ]),
                        
                        (NSLocalizedString("Verify", comment: ""),
                         [
                            AnyView(SubItem(title: NSLocalizedString("ProofMode", comment: ""), subtitle: nil) {
                                viewModel.navigateToProofMode()
                            })
                         ]),
                        
                        (NSLocalizedString("Encrypt", comment: ""),
                         [
                            AnyView(ToggleSwitch(title: NSLocalizedString("Turn on Onion Routing", comment: ""),subtitle: NSLocalizedString("Transfer via the Tor Network only", comment: ""), isDisabled:true, isOn: $viewModel.isOnionRoutingOn).overlay(
                             
                                Group {
                                    if true {
                                        Color.black.opacity(0.001)
                                            .onTapGesture {
                                                viewModel.toggleOrbot { result in
                                                    showTorAlert = result
                                                }
                                            }
                                    }
                                }
                            )
                                   ),
                            AnyView(Group {
                                if viewModel.isOnionRoutingOn {
                                    SubItem(title: NSLocalizedString("Tor Status", comment: ""), subtitle: viewModel.orbotTorStatus()) {
                                        viewModel.openOrbot()
                                    }
                                }
                            })
                            
                         ]),
                        
                        (NSLocalizedString("General", comment: ""),
                         [
                            AnyView(
                                SubItem(title: NSLocalizedString("Media Compression", comment: ""),
                                        subtitle: selectedCompressionOption) {
                                    showCompressionSheet = true
                                }
                                .actionSheet(isPresented: $showCompressionSheet) {
                                    ActionSheet(
                                        title: Text(NSLocalizedString("Media Compression", comment: "")),
                                        buttons: compressionSheetButtons()
                                    )
                                }
                            ),
                            AnyView(
                                SubItem(title: NSLocalizedString("Theme", comment: ""),
                                        subtitle: selectedTheme) {
                                            showActionSheet = true
                                        }
                                    .actionSheet(isPresented: $showActionSheet) {
                                        ActionSheet(title: Text(NSLocalizedString("Theme", comment: "")),
                                                    buttons: actionSheetButtons())
                                    }
                            ),
                            AnyView(SubItem(title: NSLocalizedString("Save by OpenArchive", comment: ""), subtitle: NSLocalizedString("Discover the Save app", comment: "")) {
                                if let url = URL(string: "https://www.open-archive.org/save") {
                                    UIApplication.shared.open(url)
                                }
                            }),
                            AnyView(SubItem(title: NSLocalizedString("Terms & Privacy Policy", comment: ""), subtitle: NSLocalizedString("Read our Terms & Privacy Policy", comment: "")) {
                                if let url = URL(string: "https://www.open-archive.org/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }),
                            AnyView(SubItem(title: NSLocalizedString("Version", comment: ""), subtitle: Bundle.main.version) {
                                print("version tapped")
                            }),
                         ])
                    ]
                    
                    ForEach(sections, id: \.0) { section in
                        Section(
                            header: Text(section.0)
                                .font(Font(UIFont.montserrat(forTextStyle: .headline,with:.traitUIOptimized)))
                                .kerning(0.01)
                                .foregroundColor(.accentColor)
                            
                            ,
                            footer: Divider()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, -16)
                                .background(Color.menuDivider)
                            
                        ) {
                            ForEach(section.1.indices, id: \.self) { index in
                                section.1[index]
                                    .modifier(HideItemSeparator())
                            }
                        }.background(Color(UIColor.clear))
                            .modifier(HideItemSeparator())
                    }
                } .background(Color(UIColor.systemBackground))
                    .listStyle(.plain)
                    .modifier(ListSpacingModifier())
                
                
                
            }
        }.onAppear {
            viewModel.isPasscodeOn = AppSettings.isPasscodeEnabled
            passcodeToggleState = AppSettings.isPasscodeEnabled
        }.overlay(
            Group {
                if showPasscodeAlert {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Disable Passcode", comment: ""),
                                    message: NSLocalizedString("Are you sure you want to disable the passcode?", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Yes", comment: ""),
                                    iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                                    primaryButtonAction: {
                                        AppSettings.passcodeEnabled = false
                                        viewModel.isPasscodeOn = false
                                        passcodeToggleState = false
                                        showPasscodeAlert = false
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonIsOutlined: false,
                                    
                                    secondaryButtonAction: {
                                        isProgrammaticallyChangingPasscodeToggle = true
                                        passcodeToggleState = true
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isProgrammaticallyChangingPasscodeToggle = false
                                        }
                                        
                                        showPasscodeAlert = false
                                    },
                                    
                                    showCheckbox: false, isRemoveAlert: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        )
                }
                if showTorAlert {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Onion routing under development", comment: ""),
                                    message: NSLocalizedString("This feature is currently under development. For now, you can use Orbot or any VPN of your choice to enhance your privacy and security.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                                    iconImage: Image(systemName: "info.circle"),
                                    primaryButtonAction: {
                                        showTorAlert = false
                                    }
                                    
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        )
                }
            })
        
    }
    
    private let interfaceStyleOptions = [
        NSLocalizedString("System", comment: ""),
        NSLocalizedString("Light", comment: ""),
        NSLocalizedString("Dark", comment: "")]
    
    private func actionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = interfaceStyleOptions.enumerated().map { index, option in
                .default(Text(option)) {
                    selectedTheme = option
                    applyTheme(for: index)
                }
        }
        buttons.append(.cancel())
        return buttons
    }
    private func compressionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = SettingsView.compressionOptions.map { option in
            .default(Text(option)) {
                selectedCompressionOption = option
                Settings.highCompression = (option == SettingsView.compressionOptions[1])
            }
        }
        buttons.append(.cancel())
        return buttons
    }
    private func applyTheme(for index: Int) {
        if index == 1 {
            Utils.setLightMode()
        } else if index == 2 {
            Utils.setDarkMode()
        } else {
            Utils.setUnspecifiedMode()
        }
    }
}


protocol ViewControllerNavigationDelegate: AnyObject {
    func pushViewController(_ viewController: UIViewController)
    func pushServerList()
    func pushFolderList()
    func pushDetailServer(space:Space)
}
extension ViewControllerNavigationDelegate {
    func pushDetailServer(space:Space) {
        
    }
    func pushServerList(){
        
    }
    func pushFolderList(){
        
    }
    func pushViewController(_ viewController: UIViewController){
        
    }
}
