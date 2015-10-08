Pod::Spec.new do |s|
  s.name         = "MVLMQTTKit"
  s.version      = "0.5.2"
  s.summary      = "Objective-C client for MQTT 3.1"
  s.homepage     = "https://github.com/Movile/MQTTKit"
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.author       = { "Jeff Mesnil" => "jmesnil@gmail.com" }
  s.ios.platform = :ios, '7.0'
  s.ios.deployment_target = "7.0"
  s.source       = { :git => "https://github.com/Movile/MQTTKit.git", :tag => s.version.to_s }

  s.source_files  = 'MQTTKit/*.{h,m}'
  s.public_header_files = 'MQTTKit/MQTTKit.h'
  s.requires_arc = true

  s.dependency 'Mosquitto' 
  s.dependency 'MVLOpenSSL'

end
