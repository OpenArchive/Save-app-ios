source 'https://github.com/CocoaPods/Specs.git'

# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
    pod 'YapDatabase', :git => 'https://github.com/difftim/YapDatabase.git' #'~> 4.0'
    pod 'Eureka', '~> 5.3'
    pod 'ImageRow', '~> 4.1'
    pod 'UIImage-Resize', '~> 1.0'
    pod 'AlignedCollectionViewFlowLayout', '~> 1.1'
    pod 'DownloadButton', '~> 0.1'
    pod 'MBProgressHUD', '~> 1.2'
    pod 'ReachabilitySwift', '~> 5.0'
    pod 'FormatterKit', '~> 1.9'
    pod 'UIImageViewAlignedSwift', '~> 0.8' #:git => 'https://github.com/mirego/UIImageViewAlignedSwift.git'
    pod 'FontBlaster', '~> 5.2'
    pod 'CrossroadRegex', :git => 'https://github.com/crossroadlabs/Regex.git', tag: '1.2.0'
    pod 'CleanInsightsSDK', '~> 2.6'
    pod 'LegacyUTType', '~> 0.1'
end

def app_only
    pod 'SwiftyDropbox', :git => 'https://github.com/tladesignz/SwiftyDropbox.git', :branch => 'session_config' #'~> 9.1'
    pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git', :branch => 'swift-5'
    pod 'TUSafariActivity', '~> 1.0'
    pod 'ARChromeActivity', '~> 1.0'
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

# Fix Xcode 14 code signing issues with bundles.
# See https://github.com/CocoaPods/CocoaPods/issues/8891#issuecomment-1249151085
post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
      target.build_configurations.each do |config|
          config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end
  end
end
