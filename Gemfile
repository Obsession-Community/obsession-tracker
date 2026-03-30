source "https://rubygems.org"

ruby "~> 3.2.2"

# Fastlane for iOS/Android automation
gem "fastlane", "~> 2.229"

# CocoaPods for iOS dependency management
# Using bundler ensures we use the correct Ruby version (rbenv)
gem "cocoapods", "~> 1.15"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
