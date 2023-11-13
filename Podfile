source 'https://github.com/CocoaPods/Specs.git'

# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
    pod 'YapDatabase', :git => 'https://github.com/tladesignz/YapDatabase.git' #'~> 4.0'
    pod 'Eureka', '~> 5.3'
    pod 'ImageRow', '~> 4.1'
    pod 'UIImage-Resize', '~> 1.0'
    pod 'AlignedCollectionViewFlowLayout', '~> 1.1'
    pod 'DownloadButton', '~> 0.1'
    pod 'MBProgressHUD', '~> 1.2'
    pod 'ReachabilitySwift', '~> 5.0'
    pod 'UIImageViewAlignedSwift', '~> 0.8' #:git => 'https://github.com/mirego/UIImageViewAlignedSwift.git'
    pod 'FontBlaster', '~> 5.2'
    pod 'CrossroadRegex', :git => 'https://github.com/crossroadlabs/Regex.git', tag: '1.2.0'
    pod 'CleanInsightsSDK', '~> 2.6'
    pod 'LegacyUTType', '~> 0.1'
    pod 'LibProofMode/PrivacyProtected',
        # :git => 'https://gitlab.com/guardianproject/proofmode/libproofmode-ios.git', :branch => 'main'
        :git => 'https://gitlab.com/threeletteracronym/libproofmode-ios.git', :branch => 'external_passphrase'
        #:path => '../libproofmode-ios'
end

def app_only
    pod 'SwiftyDropbox', :git => 'https://github.com/tladesignz/SwiftyDropbox.git', :branch => 'session_config' #'~> 9.2'
    pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git', :branch => 'swift-5'
    pod 'SDCAlertView', '~> 12.0'
    pod 'TLPhotoPicker', :git => 'https://github.com/tladesignz/TLPhotoPicker.git' # '~> 2.1'
    pod 'OrbotKit', '~> 0.2'
end

target 'Save' do
    shared_pods
    app_only
end

target 'ShareExtension' do
    shared_pods
end

target 'Save Screenshots' do
    shared_pods
    app_only
end

# Fix Xcode 15 compile issues.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.respond_to?(:name) and !target.name.start_with?("Pods-")
      target.build_configurations.each do |config|
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
      end
    end
  end
end
