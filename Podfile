source 'https://github.com/CocoaPods/Specs.git'

deployment_target = '15.6'

# Uncomment the next line to define a global platform for your project
platform :ios, deployment_target

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks! :linkage => :dynamic

def shared_pods
    pod 'YapDatabase', :git => 'https://github.com/tladesignz/YapDatabase.git' #'~> 4.0'
    pod 'Eureka', '~> 5.3'
    pod 'MBProgressHUD', '~> 1.2'
    pod 'FontBlaster', '~> 5.2'
    pod 'UIImage-Resize', '~> 1.0'
    pod 'AlignedCollectionViewFlowLayout', '~> 1.1'
    pod 'UIImageViewAlignedSwift', '~> 0.8' #:git => 'https://github.com/mirego/UIImageViewAlignedSwift.git'
    pod 'ReachabilitySwift', '~> 5.0'
    pod 'CrossroadRegex', :git => 'https://github.com/crossroadlabs/Regex.git', tag: '1.2.0'
    pod 'LegacyUTType', '~> 0.1'
    pod 'GoogleAPIClientForREST/Drive', '~> 3.3'
    pod 'SnapKit'
    pod 'SwiftUIIntrospect', '~> 1.0'
    pod 'LibProofMode',
        :git => 'https://gitlab.com/guardianproject/proofmode/libproofmode-ios.git', :branch => 'main'
        #:path => '../libproofmode-ios'
    pod "Factory"
    pod 'Firebase/Core'
    pod 'Firebase/Crashlytics'
end

def app_only
    pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git', :branch => 'swift-5'
    pod 'SDCAlertView'
    pod 'TLPhotoPicker', :git => 'https://github.com/tladesignz/TLPhotoPicker.git' # '~> 2.1'
    pod 'GoogleSignIn', '~> 7.0'
    pod 'OrbotKit', '~> 1.2'
end

target 'Save' do
    inherit! :search_paths
    shared_pods
    app_only
end

target 'Save Test' do
    inherit! :search_paths
    shared_pods
    app_only
end

target 'Screenshots' do
  inherit! :search_paths
  shared_pods
end

target 'ShareExtension' do
    inherit! :search_paths
    shared_pods
end

target 'Unit Tests' do
    inherit! :search_paths
    shared_pods
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
    end
  end
end
