Pod::Spec.new do |s|
  s.name             = "TUSKit"
  s.version          = "1.3.13"
  s.summary          = "The tus client for iOS."
  s.description      = <<-DESC
                       An iOS implementation of the tus resumable video upload protocol.
                       DESC
  s.homepage         = "https://github.com/tus/tus-ios-client"
  s.license          = 'MIT'
  s.author           = { "Michael Avila" => "me@michaelavila.com", "Mark Robert Masterson" => "mark@masterson.io" }
  s.source           = { :git => "https://github.com/tus/tus-ios-client.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.requires_arc = true
  s.module_name = 'TUSKit'
  s.module_map = 'Supporting Files/module.modulemap'
  s.source_files = 'TUSKit/*.{h,m}', 'Supporting Files/*.{h}'
end

