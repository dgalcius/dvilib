Gem::Specification.new do |s|
  s.name = %q{dvilib}
  s.version = "0.0.1a"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["D. Galcius"]
  s.date = %q{2015-10-23}
  s.email = %q{deimi@vtex.lt}
  s.files = ["./lib/dvilib.rb", "./lib/dvilib/layer.rb", "./lib/dvilib/lsr.rb", "./lib/dvilib/opcode.rb", "./lib/dvilib/tfm.rb", "./lib/dvilib/util.rb", "./lib/dvilib/version.rb", "./lib/dvilib/tfm/format.rb"]
  s.homepage = %q{}
#  s.require_paths = ["lib"]
#  s.rubygems_version = %q{1.3.1}
  s.summary = %q{dvi parsing library}
  s.description = %q{dvi parsing library}
#  s.test_files = ["test.r"]
  s.license       = 'MIT'

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
