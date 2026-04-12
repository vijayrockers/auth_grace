Pod::Spec.new do |s|
  s.name             = 'auth_grace'
  s.version          = '0.0.4'
  s.summary          = 'Smart biometric auth with grace period.'
  s.description      = 'Skips the biometric prompt if the phone was recently unlocked, exactly like GPay.'
  s.homepage         = 'https://github.com/vijayrockers/auth_grace'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'vijayrockers' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
