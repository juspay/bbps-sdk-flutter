#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bbps_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bbps_sdk_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Juspay BBPS SDK.'
  s.description      = <<-DESC
Flutter plugin for Juspay BBPS SDK.
                       DESC
  s.homepage         = 'https://juspay.in/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Juspay' => 'support@juspay.in' }
  s.source           = { :path => '.' }
  s.source_files = 'bbps_sdk_flutter/Sources/bbps_sdk_flutter/**/*.swift'
  s.resource_bundles = {'bbps_sdk_flutter_privacy' => ['bbps_sdk_flutter/Sources/bbps_sdk_flutter/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.dependency 'BBPSSDK', '>= 0.0.5'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
end
