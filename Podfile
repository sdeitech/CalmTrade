# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'
use_frameworks!

target 'CalmTrade' do
  # Firebase – all on the SAME major version
  pod 'FirebaseAuth', '~> 11.8.0'
  pod 'FirebaseFirestore', '~> 11.8.0'
  pod 'FirebaseAnalytics', '~> 11.8.0'
  pod 'FirebaseCrashlytics', '~> 11.8.0'

  # DO NOT add GoogleUtilities manually – Firebase pulls what it needs
  # pod 'GoogleUtilities'  <-- remove this

  # Other dependencies
  pod 'GoogleSignIn'
  pod 'FBSDKLoginKit'
  pod 'IQKeyboardManagerSwift'
  pod 'SwiftGifOrigin', '~> 1.7.0'
  pod 'PolarBleSdk', '~> 6.7'
  pod 'KRProgressHUD'
  pod 'Socket.IO-Client-Swift'

  target 'CalmTradeTests' do
    inherit! :search_paths
  end

  target 'CalmTradeUITests' do
  end
end

