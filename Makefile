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
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/comet { minimal_init = 'tests/minimal_init.lua' }"
