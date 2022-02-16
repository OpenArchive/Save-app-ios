# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
    pod 'YapDatabase', '~> 4.0'
    pod 'Alamofire', '~> 4.9'
    pod 'FilesProvider', :git => 'https://github.com/ayuzhin/FileProvider.git' # '~> 0.26'
    pod 'SwiftyDropbox', '~> 7.0'
    pod 'Localize', '~> 2.3'
    pod 'Eureka', '~> 5.3'
    pod 'ImageRow', '~> 4.0'
    pod 'UIImage-Resize', '~> 1.0'
    pod 'AlignedCollectionViewFlowLayout', '~> 1.1'
    pod 'DownloadButton', '~> 0.1'
    pod 'MBProgressHUD', '~> 1.2'
    pod 'ReachabilitySwift', '~> 5.0'
    pod 'FormatterKit', '~> 1.9'
    pod 'UIImageViewAlignedSwift', '~> 0.8' #:git => 'https://github.com/mirego/UIImageViewAlignedSwift.git'
    pod 'FontBlaster', '~> 5.2'
    pod 'CrossroadRegex', :git => 'https://github.com/crossroadlabs/Regex.git', tag: '1.2.0'
    pod 'Tor', '~> 406.9'
    pod 'IPtProxyUI', '~> 1.7'
end

def app_only
    pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git', :branch => 'swift-5'
    pod 'TUSafariActivity', '~> 1.0'
    pod 'ARChromeActivity', '~> 1.0'
    pod 'SDCAlertView', '~> 12.0'
    pod 'TLPhotoPicker', '~> 2.1'
end

target 'OpenArchive' do
    shared_pods
    app_only
end

target 'ShareExtension' do
    shared_pods
end

target 'OpenArchive Screenshots' do
    shared_pods
    app_only
end
