# AGENTS.md

## Project Overview

`comet.nvim` is a Lua Neovim plugin that provides a floating two-panel command
palette. Users pass command specs to `require("comet").open()`: the left panel
filters and selects commands or submenu items, and the right panel stores command
output buffers by page.

The plugin has no runtime plugin dependencies. Tests use Plenary through
`tests/minimal_init.lua`.

## Repository Layout

- `plugin/comet.lua` is the plugin loader guard. It does not register commands.
- `lua/comet/init.lua` exposes `setup()` and `open()`.
- `lua/comet/config.lua` owns default options and option merging.
- `lua/comet/state.lua` owns public type annotations and runtime state.
- `lua/comet/action.lua` owns selection movement, execution, cancellation,
  escape handling, and multi-select marking.
- `lua/comet/context.lua` builds the command callback context.
- `lua/comet/filter.lua` owns root and submenu filtering.
- `lua/comet/ui/window.lua` owns floating windows, buffers, focus, and teardown.
- `lua/comet/ui/events.lua` owns keymaps and autocmds.
- `lua/comet/ui/render.lua` owns list rendering, output writes, extmarks, and
  output titles.
- `lua/comet/health.lua` owns `:checkhealth comet`.
- `tests/comet/` contains Plenary specs.

## Setup Commands

Install the development tools outside this repository:

```bash
stylua --version
luacheck --version
nvim --version
```

Plenary must be available on the local Neovim runtime path. The test bootstrap
looks first under Neovim's data directory, then under:

```text
~/.local/share/nvim/lazy/plenary.nvim
```

There is no package install step for this repository.

## Development Workflow

Run all commands from the repository root.

Useful loops:

```bash
make fmt
make lint
make test
```

Full pre-handoff check:

```bash
make all
```

`make all` runs formatting, linting, and the Plenary test suite.

## Testing Instructions

Run the full test suite with:

```bash
make test
```

The underlying command is:

```bash
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/comet { minimal_init = 'tests/minimal_init.lua' }"
```

Add or update focused specs in `tests/comet/` for behavior changes. Prefer
testing state, filtering, action dispatch, and context behavior directly unless
the change specifically needs a full floating-window UI path.

## Code Style

- Format Lua with StyLua using `.stylua.toml`.
- Lint runtime Lua with `luacheck lua --globals vim`.
- Keep line width near 80 columns, two-space indentation, Unix line endings, and
  double quotes when StyLua prefers them.
- Keep runtime modules dependency-free unless the user explicitly accepts a new
  dependency.
- Preserve the public behavior of `setup()`, `open()`, command specs, and
  `CometCtx` methods unless the requested change requires an API change.
- Keep UI responsibilities split between `ui/window.lua`, `ui/events.lua`, and
  `ui/render.lua`.

## API Notes

Root commands are tables with `name`, optional `icon`, optional `icon_hl`,
optional `desc`, and an `action(ctx)` callback.

`CometCtx` supports:

- `write(lines)`, `append(line)`, and `clear()` for output buffers.
- `start_async_task(job_id, abort_fn?)`, `done()`, and `error()` for task state.
- `select(items, opts)` for nested selection pages.

Submenu items can be strings or tables. In multi-select mode, `<Tab>` marks
items and `on_select` receives the selected item list.

## UI Behavior To Preserve

- Opening the same `session_id` while Comet is open toggles the UI closed.
- Opening a different `session_id` closes the current UI and opens the new one.
- Output buffers are cached by page key.
- `remember_page = true` preserves submenu stack, selection, query, and current
  output page across closes.
- `block_while_running = true` prevents running another command on a page with
  an active task.
- `<Esc>` or `q` pops a submenu first, then closes at the root.
- `<C-c>` stops the running task for the current output page.

## Validation Before Handoff

Run:

```bash
make all
```

If a tool is unavailable, mention the exact command that could not be run and
the reason from the shell output.

## Change Guidance

- Keep edits focused on the existing module boundaries.
- Avoid broad refactors unless they are required for the requested behavior.
- Do not add global user commands unless explicitly requested.
- Avoid changing keymaps or public option names without updating README examples
  and tests.
- Do not rewrite user output buffers, task persistence, or cancellation behavior
  casually; those are user-visible workflow details.
