# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
    pod 'YapDatabase', '~> 3.1'
    pod 'Alamofire', '~> 4.8'
    pod 'FilesProvider', '~> 0.26'
    pod 'Localize', '~> 2.2'
    pod 'Eureka', '~> 5.0'
    pod 'ImageRow', git: 'https://github.com/EurekaCommunity/ImageRow.git'
    pod 'MaterialComponents/Buttons', '~> 81'
    pod 'MaterialComponents/Tabs', '~> 81'
    pod 'UIImage-Resize', '~> 1.0'
    pod 'AlignedCollectionViewFlowLayout', '~> 1.1'
    pod 'DownloadButton', '~> 0.1'
    pod 'MBProgressHUD', '~> 1.1'
    pod 'ReachabilitySwift', '~> 4.3'
    pod 'TLPhotoPicker', '~> 1.8'
    pod 'FormatterKit', '~> 1.8'
    pod 'UIImageViewAlignedSwift', '~> 0.7'
    pod 'FontBlaster', '~> 4.1'
end

target 'OpenArchive' do
  shared_pods

  pod 'FavIcon', '~> 3.0'
  pod 'TUSafariActivity', '~> 1.0'
  pod 'ARChromeActivity', '~> 1.0'
  pod 'SDCAlertView', '~> 10.0'
end

target 'ShareExtension' do
  shared_pods
end
