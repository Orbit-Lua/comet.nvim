# AGENTS Instructions

## Scope and ownership

`comet.nvim` is a dependency-free Lua command palette. Consumers call
`require("comet").open(commands, opts)`; the plugin does not register a user
command. Keep its API generic. Put project-specific command behavior in the
consuming plugin, such as `dotnet-cli.nvim`.

| Change | Owner |
| --- | --- |
| `setup()`/`open()` and launch sequence | `lua/comet/init.lua` |
| Option defaults and merging | `lua/comet/config.lua` |
| Session, page, output-buffer, and task identity | `lua/comet/state.lua` |
| Command context methods and nested selection | `lua/comet/context.lua` |
| Movement, execution, cancellation, multi-select | `lua/comet/action.lua` |
| Root and submenu filtering | `lua/comet/filter.lua` |
| Floating windows, focus, resize, teardown | `lua/comet/ui/window.lua` |
| Keymaps and autocmds | `lua/comet/ui/events.lua` |
| Rows, icons, output text, status titles | `lua/comet/ui/render.lua` |
| `:checkhealth comet` | `lua/comet/health.lua` |

`plugin/comet.lua` is the loader guard. Plenary specs live in `tests/comet/`;
`tests/minimal_init.lua` adds this checkout and a local Plenary installation to
`runtimepath`.

## Behavior to preserve

- Keep `setup()`, `open()`, command specs, and `CometCtx` methods compatible
  unless the task explicitly changes the API. Do not add a global command for a
  consumer's workflow.
- Opening the active `session_id` toggles the UI closed; opening a different
  session switches to it. Output buffers and running tasks belong to a session
  and page. With `remember_page = true`, reopening restores the page stack,
  selection, and query.
- A submenu can contain strings or tables. Multi-select uses `<Tab>` and passes
  a list to `on_select`. `<Esc>`/`q` leaves output focus or pops a submenu
  before closing the root.
- `block_while_running = true` blocks another action only on a page with an
  active task. `<C-c>` cancels that page's task. Completion from an old or
  canceled job must not change a newer task's status.
- `ctx:update(items)` applies only while its originating view is active; an
  asynchronous result must not overwrite another page. Explicit item icons take
  precedence over the optional session `default_icon`.
- Interactive jobs use `ctx:start_async_task(job_id)` and
  `ctx:terminal(job_id)`; input from `i`/`a` in the output panel goes to that
  job. Keep output buffers and task status usable after closing and reopening
  the palette.
- Preserve zero runtime plugin dependencies. `plenary.nvim`, StyLua, and
  Luacheck are development tools only.

Keep the public option and keymap descriptions in `README.md` aligned with
implementation changes. Keep changes inside the owning module; avoid an
unrelated UI or state refactor for a focused fix.

## Validation

From this repository root:

```sh
make all
```

`make all` runs `make fmt` (rewrites Lua files), `make lint`
(`luacheck lua --globals vim`), and `make test` (Plenary specs), in that order.
Use `make lint` and `make test` for focused iteration;
`stylua --check lua/ --config-path=.stylua.toml` checks formatting without
rewriting.

Add focused specs in `tests/comet/` for changed filtering, action dispatch,
session isolation, context updates, rendering, job lifecycle, input, and focus
behavior. Test a real floating-window path when the change depends on it. For
documentation-only changes, check local links and `git diff --check` instead of
running mutating formatting. `tests/minimal_init.lua` searches Neovim's
lazy.nvim data directory and `~/.local/share/nvim/lazy/plenary.nvim` for
Plenary.

Preserve unrelated working-tree changes. Report checks run and any skipped check
with the missing tool or exact failure.
