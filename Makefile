build:
	@./script/build.sh

install: build
	@./script/install.sh

uninstall:
	@./script/uninstall.sh

clean:
	@rm -rf ./source
