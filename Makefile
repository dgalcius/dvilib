

gem: dvilib.gemspec
	gem build $<

install: dvilib-0.0.1a.gem
	sudo gem install $<