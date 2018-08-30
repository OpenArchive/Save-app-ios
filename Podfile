# Uncomment the next line to define a global platform for your project
platform :ios, '9.0'

def shared_pods
    pod 'YapDatabase', '~> 3.1'
    pod 'Alamofire', '~> 4.7'
end

target 'OpenArchive' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  shared_pods

  pod 'TUSafariActivity', '~> 1.0'
  pod 'ARChromeActivity', '~> 1.0'
end

target 'ShareExtension' do
  use_frameworks!

  shared_pods
end
