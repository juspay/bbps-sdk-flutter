# NPCI Common Library (CL), required by HyperUPI.
#
# HyperUPI.framework links against @rpath/CommonLibrary.framework/CommonLibrary
# but its podspec declares no dependency on it, so without this the app builds
# fine and then dies at launch with:
#   dyld: Library not loaded: @rpath/CommonLibrary.framework/CommonLibrary
#
# NOTE: this is the UAT build of CL 1.8. Swap the source URL for the production
# CL build before shipping to production.
Pod::Spec.new do |s|
  s.name             = 'CommonLibrary'
  s.version          = '1.8.0'
  s.summary          = 'NPCI Common Library (UAT) used by HyperUPI.'
  s.description      = 'NPCI Common Library binary distribution required by the HyperUPI micro-SDK.'
  s.homepage         = 'https://www.npci.org.in/'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'NPCI' => 'support@npci.org.in' }
  s.source           = { :http => 'https://public.releases.juspay.in/release/ios/npci/CL_1.8_iOS_UAT_24012024.zip' }
  s.platform         = :ios, '13.0'
  s.ios.vendored_frameworks = 'CommonLibrary.xcframework'
end
