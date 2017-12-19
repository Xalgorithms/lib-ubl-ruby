# coding: utf-8
Gem::Specification.new do |s|  
  s.name        = 'xa-ubl'
  s.version     = '0.0.6'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Don Kelly"]
  s.email       = ["karfai@gmail.com"]
  s.summary     = "XA UBL"
  s.description = "Shared gem for parsing UBL"

  s.add_dependency 'nokogiri'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'fuubar'
  
  s.files        = Dir.glob("{bin,lib}/**/*")
  s.require_path = 'lib'
end  
