Pod::Spec.new do |s|
  s.name             = "TUSKit"
  s.version          = "1.3.10"
  s.summary          = "An iOS implementation of the tus resumable video upload protocol."
  s.description      = <<-DESC
                       An iOS implementation of the tus resumable video upload protocol.

                       DESC
  s.homepage         = "https://github.com/tus/tus-ios-client"
  s.license          = 'MIT'
  s.author           = { "Michael Avila" => "me@michaelavila.com","Mark Robert Masterson" => "mrobertmasterson@gmail.com", "Mark Robert Masterson" => "mark@masterson.io"  }
  s.source           = { :git => "https://github.com/tus/tus-ios-client.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
end

