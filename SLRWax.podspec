#
# Be sure to run `pod lib lint SLRWax.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "SLRWax"
  s.version          = "0.1.0"
  s.summary          = "Wax"
  s.description      = "Wax 64Bit"
  s.homepage         = "https://github.com/chuangyi0128/SLRWax"
  s.license          = 'MIT'
  s.author           = { "SongLi" => "chuangyi0128@gmail.com" }
  s.source           = { :git => "https://github.com/chuangyi0128/SLRWax.git", :tag => s.version.to_s }

  s.platform     = :ios, '5.0'
  s.requires_arc = false

  s.source_files = 'SLRWax',
                'SLRWax/*.{h,m}',
                'SLRWax/extensions/**/*.{h,m,c}',
                'SLRWax/lua/*.{h,m,c}',
  s.ios.library = 'z','xml2'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '${SDK_DIR}/usr/include/libxml2' }

  s.subspec 'AOPAspect' do |ss|
    ss.requires_arc = true
    ss.ios.private_header_files = 'SLRWax/AOPAspect/*.h'
    ss.ios.source_files = 'SLRWax/AOPAspect/*.{h,m}'
  end

end
