
import SwiftUI
import SwiftUIIntrospect

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
    @State private var passcodeToggleState: Bool
    @State private var isProgrammaticallyChangingPasscodeToggle = false
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
                            AnyView(ToggleSwitch(title: NSLocalizedString("Turn on Onion Routing", comment: ""),subtitle: NSLocalizedString("Transfer via the Tor Network only", comment: ""), isDisabled:true, isOn: $viewModel.isOnionRoutingOn)),
                            
                         ]),
                        
                        (NSLocalizedString("General", comment: ""),
                         [
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
