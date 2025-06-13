
import SwiftUI
import SwiftUIIntrospect
import OrbotKit


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
                            AnyView(ToggleSwitch(title: NSLocalizedString("Turn on Onion Routing", comment: ""),subtitle: NSLocalizedString("Transfer via the Tor Network only", comment: ""), isDisabled:false, isOn: $viewModel.isOnionRoutingOn).overlay(
                                
                                Group {
                                    if true {
                                        Color.black.opacity(0.001)
                                            .onTapGesture {
                                                viewModel.toggleOrbot { result in
                                                    //  showTorAlert = result
                                                }
                                            }
                                    }
                                }
                            )
                            ),
                            AnyView(Group {
                                if viewModel.isOnionRoutingOn {
                                    SubItem(title: NSLocalizedString("Open Orbot", comment: ""), subtitle: "") {
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
