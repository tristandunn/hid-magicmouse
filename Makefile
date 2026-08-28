.DEFAULT_GOAL := status

build:
	@./script/build.sh

clean:
	@rm -rf ./source ./.work

export:
	@./script/patches.sh export

install: build
	@./script/install.sh

rebase:
	@./script/patches.sh rebase $(KERNEL)

status:
	@./script/patches.sh status $(KERNEL)

uninstall:
	@./script/uninstall.sh

verify:
	@./script/patches.sh verify $(KERNEL)
