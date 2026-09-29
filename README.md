# comet.nvim

<!-- markdownlint-disable MD013 -->

[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10%2B-57A143?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io/)
[![Lua plugin](https://img.shields.io/badge/Lua-plugin-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org/)
[![GPL-3.0 license](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square)](LICENSE)

`comet.nvim` is a two-panel command palette for Neovim. Search and select
actions on the left; keep each action's output on the right. It suits project
commands and interactive local jobs that benefit from a small UI and persistent
output. It has no runtime plugin dependencies and registers no user command by
default.

## Requirements

- Neovim **0.10 or newer** is recommended for the UI and autocmd behavior.
- A font with the glyphs you choose if you use icon fields; icons are optional.
- For development only:
  [plenary.nvim](https://github.com/nvim-lua/plenary.nvim), `stylua`, and
  `luacheck`.

## Quick start

Install with [lazy.nvim](https://github.com/folke/lazy.nvim) and add a mapping
that opens a small command list:

```lua
{
  "Orbit-Lua/comet.nvim",
  config = function()
    local comet = require("comet")

    vim.keymap.set("n", "<leader>tt", function()
      comet.open({
        {
          name = "Say hello",
          desc = "Write a line in the output panel",
          action = function(ctx)
            ctx:clear()
            ctx:append("Hello from Comet")
          end,
        },
      }, {
        session_id = "Project Tasks",
        default_icon = "󰈚 ",
      })
    end, { desc = "Open project tasks" })
  end,
}
```

Press `<leader>tt`, then `<CR>` on **Say hello**. The right panel should show
`Hello from Comet`. Open the same session again to close it. Give separate
workspaces different `session_id` values to keep their pages, task state, and
output separate.

## What the palette supports

- Fuzzy filtering of root actions and submenu items, including item
  descriptions.
- Nested selection pages with optional `<Tab>` multi-select.
- Output buffers and remembered page, selection, and query per session.
- Async job status, `<C-c>` cancellation, and line input for interactive jobs.
- Dynamic list updates through `ctx:update(items)`; updates from a page that is
  no longer visible are ignored.
- Per-item icons and an optional session `default_icon` for rows without one,
  including string items.

### Commands and context

Each root command has a name and an `action(ctx)` callback. `icon`, `icon_hl`,
and `desc` are optional:

```lua
{
  name = "Build",
  icon = "󰒓 ",
  desc = "Build the selected project",
  action = function(ctx)
    ctx:select({ "Debug", "Release" }, {
      title = "Build configuration",
      on_select = function(configuration, child)
        child:append("Selected " .. configuration)
      end,
    })
  end,
}
```

| Context method | Use |
| --- | --- |
| `ctx:append(line)` / `ctx:write(lines)` | Append a line or string/list of lines to this page's output. |
| `ctx:clear()` | Clear this page's output. |
| `ctx:select(items, opts)` | Open a nested selection page. Use `multi_select = true` when the callback should receive a list of marked items. |
| `ctx:update(items)` | Replace the active list. Returns `false` if this context's page is no longer visible. |
| `ctx:start_async_task(job_id, abort_fn?)` | Track a running Neovim job; Comet uses `jobstop` by default when stopped. |
| `ctx:terminal(job_id, opts?)` | Allow line input for that job from the output panel; `opts.on_input` can provide another transport. |
| `ctx:done(job_id?)` / `ctx:error(job_id?)` | Mark the task result. Pass the job ID when a stopped job might finish after a newer one. |
| `ctx:set_status(status)` | Set the status displayed in the output title. |

Submenu items may be strings or tables with `name` and optional `desc`/`icon`.
`ctx:select()` calls `on_select(item, child_ctx)`; in multi-select mode it calls
`on_select(items, child_ctx)`.

For an interactive job, start it with `vim.fn.jobstart`, call
`ctx:start_async_task(job_id)`, then `ctx:terminal(job_id)`. Focus the output
panel and press `i` or `a` to send a line to the job. Pass `on_input` to
`ctx:terminal` if input uses another transport.

## Keymaps

| Key | Action |
| --- | --- |
| `<CR>` | Run the selected action. |
| `<C-j>`, `<C-n>`, `<Down>` / `<C-k>`, `<C-p>`, `<Up>` | Move through results. |
| `gg`, `G` | Jump to the first or last result in normal mode. |
| `<Tab>` | Mark an item in a multi-select page. |
| `<C-l>` / `<C-h>` | Focus the output panel / return to the input panel. |
| `i`, `a` in the output panel | Prompt for a line of input when a terminal job is active. |
| `<C-c>` | Stop the current page's running job. |
| `<Esc>`, `q` | Leave the output panel, pop a submenu, or close the palette. |

## Configuration

`setup(opts)` sets global defaults; options passed to `open(commands, opts)`
override them for that call. Calling `setup()` is optional.

| Option | Default | Effect |
| --- | --- | --- |
| `session_id` | `"Comet"` | Namespace for remembered UI state, output, and tasks. |
| `root_title` | `session_id` | Title of the root page. |
| `insert_mode` | `true` | Enter insert mode when the palette opens. |
| `block_while_running` | `true` | Prevent starting another action on the current page while a task runs. |
| `remember_page` | `true` | Restore the page stack, selection, and query on reopen. |
| `show_icons` | `true` | Render provided icons. |
| `default_icon` | unset | Fallback icon for an item without its own icon. |

Run `:checkhealth comet` to inspect Neovim compatibility.

## Development

From the repository root, run `make all` to format Lua source, lint it, and
execute Plenary specs under `tests/comet/`. `make fmt`, `make lint`, and
`make test` run the stages separately. See [AGENTS.md](AGENTS.md) for editing and
validation rules.

This project is licensed under [GPL-3.0](LICENSE).
