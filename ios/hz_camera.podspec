Pod::Spec.new do |s|
  s.name             = 'hz_camera'
  s.version          = '0.0.1'
  s.summary          = 'xhw camera Flutter plugin.'
  s.description      = <<-DESC
xhw camera Flutter plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'wa143825@outlook.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'
	# 引用框架库
	s.frameworks = "CoreLocation", "NetworkExtension", "ExternalAccessory", "VideoToolbox", "CoreMedia", "AVFoundation"
	s.vendored_frameworks = 'Framework/*.framework'
	# 引用动态库 .lib、tbd ，去掉头尾的lib、tbd
	s.libraries = "bz2.1.0.5", "iconv.2.4.0", "z", "c++"
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386','ENABLE_BITCODE' => 'NO' }
  s.swift_version = '5.0'
end
