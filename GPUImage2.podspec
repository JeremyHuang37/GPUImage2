Pod::Spec.new do |s|
  s.name     = 'GPUImage2'
  s.version  = '0.1.0'
  s.license  = 'BSD'
  s.summary  = 'An open source iOS framework for GPU-based image and video processing.'
  s.homepage = 'https://github.com/BradLarson/GPUImage2'
  s.author   = { 'Brad Larson' => 'contact@sunsetlakesoftware.com' }

  s.source   = { :git => 'git@github.com:JeremyHuang37/GPUImage2.git' }

  s.source_files = 'framework/Source/**/*.{h,m,swift}'
  s.resources = 'framework/Source/Operations/Shaders/*.{fsh}'
  s.requires_arc = true
  s.xcconfig = { 'CLANG_MODULES_AUTOLINK' => 'YES', 'OTHER_SWIFT_FLAGS' => "$(inherited) -DGLES"}
  
  s.ios.deployment_target = '10.0'
  s.ios.exclude_files = 'framework/Source/Mac', 'framework/Source/Linux', 'framework/Source/Operations/Shaders/ConvertedShaders_GL.swift'
  s.frameworks   = ['OpenGLES', 'CoreMedia', 'QuartzCore', 'AVFoundation']

end
