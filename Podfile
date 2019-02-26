# Uncomment the next line to define a global platform for your project
platform :ios, '9.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
    pod 'YapDatabase', '~> 3.1'
    pod 'Alamofire', '~> 4.8'
    pod 'FilesProvider', '~> 0.25'
    pod 'Localize', '~> 2.1'
    pod 'Eureka', '~> 4.3'
    pod 'ImageRow', git: 'https://github.com/EurekaCommunity/ImageRow.git'
    pod 'MaterialComponents/Buttons', '~> 74.0'
    pod 'MaterialComponents/Tabs', '~> 74.0'
    pod 'UIImage-Resize', '~> 1.0'
end

target 'OpenArchive' do
  shared_pods

  pod 'FavIcon', '~> 3.0'
  pod 'TUSafariActivity', '~> 1.0'
  pod 'ARChromeActivity', '~> 1.0'
end

target 'ShareExtension' do
  shared_pods
end
