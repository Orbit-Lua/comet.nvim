set shell := ["sh", "-cu"]
set windows-shell := ["cmd.exe", "/d", "/c"]

all: fmt-check lint test

fmt-check:
    stylua --check lua --config-path=.stylua.toml

lint:
    luacheck lua --globals vim

test:
    nvim --headless --clean -i NONE -l tests/run.lua

test-spec spec:
    nvim --headless --clean -i NONE -l tests/run.lua "{{ spec }}"
