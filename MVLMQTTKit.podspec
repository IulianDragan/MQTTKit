Pod::Spec.new do |s|
  s.name         = "MVLMQTTKit"
  s.version      = "0.3.7"
  s.summary      = "Objective-C client for MQTT 3.1"
  s.homepage     = "https://github.com/Movile/MQTTKit"
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.author       = { "Jeff Mesnil" => "jmesnil@gmail.com" }
  s.ios.platform = :ios, '8.0'
  s.ios.deployment_target = "8.0"
  s.source       = { :git => "https://github.com/Movile/MQTTKit.git", :tag => s.version.to_s }

  s.source_files  = 'libmosquitto/*.{h,c}', 'MQTTKit/*.{h,m}'
  s.public_header_files = 'MQTTKit/MQTTKit.h'
  s.compiler_flags = '-DWITH_THREADING=1 -DWITH_TLS=1'
  s.requires_arc = true
  
  s.dependency 'OpenSSL-Universal', '1.0.1.j-2'
end
