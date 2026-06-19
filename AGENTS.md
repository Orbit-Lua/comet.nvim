# Comet.nvim

Guidance for agents working in this repository.

## Project

comet.nvim is a zero-dependency Neovim 0.10+ UI library for plugin authors.
It provides a floating picker with an input and list on the left, plus an
output panel on the right. It supports async task output, nested sub-menus,
filtering, configurable icons, multi-select, and page memory across close and
reopen cycles.

## Layout

```text
lua/comet/
  init.lua        public API
  config.lua      defaults and option resolution
  state.lua       types, live state, and persistent caches
  action.lua      key-driven mutations
  context.lua     context passed to command callbacks
  filter.lua      root and sub-menu filtering
  health.lua      checkhealth provider
  ui/
    window.lua    floating windows, buffers, focus, close
    events.lua    keymaps and autocmds
    render.lua    list rendering, output writes, highlights

plugin/comet.lua  plugin load guard
tests/            minimal init and Plenary specs
```

## Core Flow

Open:

```text
comet.open(commands, opts)
  -> config.resolve(opts)
  -> state.init(commands, opts, layout)
  -> window.create_layout(width, height)
  -> events.setup()
  -> render.list()
  -> render.update_output_title()
```

Run:

```text
<CR>
  -> action.run_selected()
  -> context.make(trigger_name)
  -> item.action(ctx)
  -> ctx writes output, starts tasks, or opens sub-menus
```

Close:

```text
window.close()
  -> persist page state when remember_page is enabled
  -> clear the CometUI augroup
  -> close floating windows
  -> delete input and list buffers
  -> keep cached output buffers
  -> state.clear()
```

## State Rules

- Live UI state is the private `S` table in `state.lua`.
- `S` is nil when the UI is closed.
- Do not keep `S` in long-lived upvalues or async callbacks.
- Call `state.get()` only after checking `state.is_open()` when the UI may
  have closed.
- Output buffers are cached in `state.output_buf_cache` and must not be
  deleted on close.
- Running task metadata is stored in `state.running_tasks` by page key.
- Page memory is stored in `state.persisted_states` by session id.
- `ctx.target_buf` and `ctx.target_page_key` are captured at dispatch time.
  They are safe for scheduled callbacks and job handlers.

## Page Keys

- Root pages use `root_title`.
- The first sub-menu under a root command uses the triggering command name.
- Deeper sub-menus reuse the first sub-menu page key.
- All nested levels under one root command share one output buffer.

## Module Boundaries

- `init.lua` exposes `setup()` and `open()`.
- `config.lua` owns defaults and merge behavior.
- `state.lua` owns public type annotations and runtime state.
- `action.lua` owns selection, execution, stop, escape, and mark toggles.
- `context.lua` builds the callback context.
- `filter.lua` owns matching for root commands and active sub-menus.
- `ui/window.lua` owns Neovim windows, buffers, focus, and teardown.
- `ui/events.lua` owns keymaps and autocmds.
- `ui/render.lua` owns buffer writes, extmarks, and titles.

## Development Rules

- Use Lua 5.1 syntax compatible with LuaJIT.
- Do not add external runtime dependencies.
- Keep public types in `state.lua`.
- Avoid `require` cycles. Use lazy `require()` only when needed.
- Guard win and buf API calls with validity checks or `pcall`.
- Put UI autocmds in the `CometUI` augroup.
- Do not add global commands unless the project explicitly needs them.
- Keep output buffer persistence intact.

## Validation

```bash
make ready
```

This runs StyLua, Luacheck, and the Plenary test suite.
