ifeq ($(OS),Windows_NT)
    LUACHECK := luacheck.bat
else
    LUACHECK := luacheck
endif

all: fmt lint test

fmt:
	echo "===> Formatting"
	stylua lua/ --config-path=.stylua.toml

lint:
	echo "===> Linting"
	$(LUACHECK) lua --globals vim

test:
	just test
