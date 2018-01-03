

gem: dvilib.gemspec
	gem build $<

#install: dvilib-0.0.1a.gem
#	sudo gem install $<

install: dvilib-0.0.1b.gem
	gem install $<

clean:
	rm -f dvilib-0.0.1b.gem
