#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gift_player_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gift_player_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Play SVGA, GIF, WebP and PAG gifts in Flutter.'
  s.description      = <<-DESC
Native half of the gift_player_flutter Flutter plugin: PAG playback through libpag (Metal), rendered into a Flutter texture.
                       DESC
  s.homepage         = 'https://github.com/SvgaGifts-org/Gift-Player-flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'SvgaGifts' => 'svgagifts@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  # libpag (Apache-2.0): the PAG engine. Same version the web package pins.
  s.dependency 'libpag', '4.5.85'
  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = { 'gift_player_flutter_privacy' => ['Classes/PrivacyInfo.xcprivacy'] }
end
