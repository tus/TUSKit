# Be sure to run `pod lib lint TUSKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TUSKit'
  s.version          = '3.1.5'
  s.summary          = 'TUSKit client in Swift'
  s.swift_version = '5.0'


  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Swift client for https://tus.io called TUSKit. Mac and iOS compatible.
                       DESC

  s.homepage         = 'https://github.com/tus/tus-ios-client'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tjeerd in t Veen' => 'tjeerd@twinapps.co' }
  s.source           = { :git => 'https://github.com/tus/tus-ios-client.git', :tag => s.version.to_s }
  s.platform         = :ios

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target  = '10.9'

  s.source_files = 'Sources/TUSKit/**/*'

end
