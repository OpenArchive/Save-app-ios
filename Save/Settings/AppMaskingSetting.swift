

import SwiftUI
import Foundation
struct AppMaskingSetting: View {
    
    @State private var selectedIcon: AppIcon = .default
    @State private var presentingErrorAlert = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Form {
            Section(
                header: Text("App Icon").font(.headline),
                footer: Text(NSLocalizedString("You can customize the app icon to fit in with your home theme", comment: ""))
            ) {
                ForEach(AppIcon.allCases, id: \.self) { appIcon in
                    Toggle(isOn: Binding(
                        get: { selectedIcon == appIcon },
                        set: { newValue in
                            if newValue {
                                tryToUpdateIcon(with: appIcon)
                            }
                        }
                    )) {
                        HStack {
                            appIcon.icon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            if #available(iOS 14.0, *) {
                                Text(appIcon.description)
                                    .font(.title3)
                            } else {
                                Text(appIcon.description)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                   
                }
            }
        }
        .alert(isPresented: $presentingErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            getCurrentIcon()
        }
    }
}

// MARK: - Helpers
private extension AppMaskingSetting {
    func getCurrentIcon() {
        if let iconName = UIApplication.shared.alternateIconName {
            selectedIcon = AppIcon(from: iconName)
        } else {
            selectedIcon = .default
        }
    }
    
    func tryToUpdateIcon(with icon: AppIcon?) {
        guard let icon = icon else { return }
        Task {
            do {
                try await CommonUtils.updateAppIcon(with: icon.name)
                selectedIcon = icon
            } catch {
                errorMessage = error.localizedDescription
                presentingErrorAlert = true
            }
        }
    }
}

// MARK: - CommonUtils
@MainActor
class CommonUtils {
    static func updateAppIcon(with iconName: String?) async throws {
        guard UIApplication.shared.alternateIconName != iconName else {
            return
        }
        do {
            try await UIApplication.shared.setAlternateIconName(iconName)
        } catch {
            throw error
        }
    }
}

// MARK: - Hosting Controller
class SwiftUIHosting {
    static func createAppMaskingViewController() -> UIViewController {
        let settingsView = AppMaskingSetting()
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.title = "App Masking"
        return hostingController
    }
}
#Preview {
    AppMaskingSetting()
}

