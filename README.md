# comet.nvim

*A small command palette for Neovim tasks with persistent output panels.*

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?style=flat-square&logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-plugin-2C2D72?style=flat-square&logo=lua&logoColor=white)
![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square)

[Features](#features) - [Installation](#installation) - [Usage](#usage) - [Development](#development)

`comet.nvim` opens a focused two-panel floating UI: search and select commands on
the left, stream command output on the right. It is designed for project tasks,
build steps, scripts, and small interactive workflows that should stay inside
Neovim without becoming a full task runner.

> [!NOTE]
> The plugin exposes a Lua API. It does not register a user command by default;
> call `require("comet").open()` from your own mappings, commands, or plugin
> config.

## Features

- Searchable command list with optional icons and descriptions.
- Output buffers are cached per page, so results remain available while moving
  through nested selections.
- Nested submenus through `ctx:select()`, including optional multi-select mode.
- Async task tracking with status in the output title and `<C-c>` stop support.
- Session memory for current page, selection, and query.
- Zero runtime plugin dependencies.

## Requirements

- Neovim 0.10 or newer is recommended.
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is only needed for
  running the test suite.
- Development tooling uses `stylua` and `luacheck`.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "your-user/comet.nvim",
  config = function()
    require("comet").setup({
      session_id = "Tasks",
    })
  end,
}
```

For local development, point your plugin manager at this checkout or add the
repository root to `runtimepath`.

## Usage

Create commands and open the palette from a mapping:

```lua
local comet = require("comet")

vim.keymap.set("n", "<leader>tt", function()
  comet.open({
    {
      name = "Run tests",
      icon = "T",
      desc = "Run the project test suite",
      action = function(ctx)
        ctx:clear()
        ctx:append("$ make test")

        local function append_data(data)
          local lines = vim.tbl_filter(function(line)
            return line ~= ""
          end, data)
          if #lines > 0 then
            ctx:append(table.concat(lines, "\n"))
          end
        end

        local job = vim.fn.jobstart({ "make", "test" }, {
          stdout_buffered = false,
          stderr_buffered = false,
          on_stdout = function(_, data)
            vim.schedule(function()
              append_data(data)
            end)
          end,
          on_stderr = function(_, data)
            vim.schedule(function()
              append_data(data)
            end)
          end,
          on_exit = function(_, code)
            vim.schedule(function()
              if code == 0 then
                ctx:done()
              else
                ctx:error()
              end
            end)
          end,
        })

        ctx:start_async_task(job)
      end,
    },
    {
      name = "Build target",
      desc = "Choose a build configuration",
      action = function(ctx)
        ctx:select({ "Debug", "Release" }, {
          title = "Configuration",
          on_select = function(item, child_ctx)
            child_ctx:write("Selected " .. item)
          end,
        })
      end,
    },
  }, {
    session_id = "Project Tasks",
  })
end)
```

## Configuration

Global defaults are set with `setup()` and can be overridden per `open()` call:

```lua
require("comet").setup({
  session_id = "Comet",
  root_title = nil,
  insert_mode = true,
  block_while_running = true,
  remember_page = true,
  show_icons = true,
})
```

| Option | Default | Description |
| --- | --- | --- |
| `session_id` | `"Comet"` | Session name and default root title. |
| `root_title` | `session_id` | Optional title for the root page. |
| `insert_mode` | `true` | Enter insert mode when the palette opens. |
| `block_while_running` | `true` | Prevent a new command while the current page has a running task. |
| `remember_page` | `true` | Restore page stack, selection, and query between opens. |
| `show_icons` | `true` | Render command icons when provided. |

## Command API

Each root command is a table:

```lua
{
  name = "Command name",
  icon = "C",
  icon_hl = "String",
  desc = "Optional text used by filtering",
  action = function(ctx) end,
}
```

The command context provides:

| Method | Purpose |
| --- | --- |
| `ctx:write(lines)` | Append a string or list of lines to the output buffer. |
| `ctx:append(line)` | Append a string to the output buffer. |
| `ctx:clear()` | Clear the output buffer. |
| `ctx:start_async_task(job_id, abort_fn?)` | Mark a job as running and optionally provide custom cancellation. |
| `ctx:done()` | Mark the current task as done. |
| `ctx:error()` | Mark the current task as failed. |
| `ctx:select(items, opts)` | Push a nested selection page. |

`ctx:select()` accepts string items or tables with `name` and `desc`. Pass
`multi_select = true` to enable marking items with `<Tab>`; the `on_select`
callback then receives a list of selected items.

## Keymaps

| Key | Action |
| --- | --- |
| `<CR>` | Run the selected item. |
| `<C-j>`, `<C-n>`, `<Down>` | Move down. |
| `<C-k>`, `<C-p>`, `<Up>` | Move up. |
| `gg`, `G` | Jump to top or bottom in normal mode. |
| `<Tab>` | Toggle a mark in multi-select mode. |
| `<C-l>` | Focus the output panel. |
| `<C-h>`, `q`, `<Esc>` | Return from output focus, pop a submenu, or close the UI. |
| `<C-c>` | Stop the running task for the current output page. |

## Health Check

Run Neovim's health command to verify the recommended version:

```vim
:checkhealth comet
```

## Development

Run commands from the repository root:

```bash
make fmt
make lint
make test
make all
```

`make all` formats Lua files, runs `luacheck`, and executes the Plenary specs
under `tests/comet/`.
