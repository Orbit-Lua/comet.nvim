# Comet.nvim

A two-panel picker and task UI library for Neovim 0.10+.

comet.nvim opens a floating UI with a searchable command list on the left and
an output panel on the right. It is meant for plugins that need menus, task
runners, build actions, previews, or nested selection flows.

It has no runtime plugin dependencies.

## Features

- Searchable two-panel floating layout.
- Root commands and nested sub-menus.
- Output buffers cached by page, so output survives close and reopen.
- Async task tracking with stop, done, abort, and error status.
- Optional page memory for query, selection, and sub-menu depth.
- Optional multi-select inside sub-menus.
- Built-in output highlighting for common success and error text.

## Installation

lazy.nvim:

```lua
{ "Orbit-Lua/comet.nvim" }
```

packer.nvim:

```lua
use({ "Orbit-Lua/comet.nvim" })
```

## Quick Start

```lua
local comet = require("comet")

local commands = {
  {
    name = "Run Tests",
    icon = "",
    desc = "Run the test suite",
    action = function(ctx)
      ctx:clear()
      ctx:write("$ make test")

      local job_id = vim.fn.jobstart({ "make", "test" }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
          vim.schedule(function()
            ctx:write(data)
          end)
        end,
        on_stderr = function(_, data)
          vim.schedule(function()
            ctx:write(data)
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

      ctx:start_async_task(job_id)
    end,
  },
  {
    name = "Build",
    icon = "",
    desc = "Build the project",
    action = function(ctx)
      ctx:clear()
      ctx:append("$ make")
      ctx:append("Build succeeded")
    end,
  },
}

vim.keymap.set("n", "<leader>c", function()
  comet.open(commands, {
    session_id = "Project Tasks",
    remember_page = true,
  })
end, { desc = "Open task UI" })
```

## Setup

`setup()` changes defaults for later `open()` calls.

```lua
require("comet").setup({
  insert_mode = true,
  block_while_running = true,
  remember_page = true,
  show_icons = true,
})
```

## API

### `comet.open(commands, opts)`

Opens the UI.

`commands` is an array of command specs:

```lua
{
  name = "Run Tests",
  icon = "", -- optional
  icon_hl = "String",
  desc = "Optional search text",
  action = function(ctx) end,
}
```

`opts` accepts:

- `session_id`: session key and default root title. Default: `"Comet"`.
- `root_title`: title for the root list. Default: `session_id`.
- `insert_mode`: enter insert mode after opening. Default: `true`.
- `block_while_running`: block duplicate runs on a busy page. Default: `true`.
- `remember_page`: restore page, selection, and query. Default: `true`.
- `show_icons`: render command and sub-menu item icons. Default: `true`.

### Context

Each command action receives a context bound to the current output buffer.
The context can be used later from scheduled callbacks or job handlers.

- `ctx:write(lines)`: append a string or list of strings.
- `ctx:append(line)`: append one string.
- `ctx:clear()`: clear the output buffer.
- `ctx:start_async_task(job_id, abort_fn)`: mark a job as running.
- `ctx:done()`: mark the started task as done.
- `ctx:error()`: mark the started task as failed.
- `ctx:select(items, opts)`: open a nested sub-menu.

### Sub-Menus

Use `ctx:select()` to replace the left list with another selection step.

```lua
ctx:select({ "Debug", "Release" }, {
  title = "Configuration",
  on_select = function(item, child_ctx)
    child_ctx:write("Selected " .. item)
  end,
})
```

Sub-menu options:

- `title`: input window title.
- `multi_select`: allow marking multiple items with `<Tab>`.
- `on_select`: callback for the selected item or item list.
- `on_cancel`: optional callback when the menu is popped with `<Esc>`.

All nested levels under one root command share that root command's output
buffer. Table items in sub-menus may also define `name`, `icon`, `icon_hl`,
and `desc`; `desc` is included in filtering.

## Keymaps

Input and list panels:

- `<C-j>`, `<Down>`: move down.
- `<C-k>`, `<Up>`: move up.
- `j`, `k`: move in normal mode.
- `<CR>`: run the selected item.
- `<Tab>`: toggle a mark in multi-select menus.
- `<C-l>`: focus the output panel.
- `<C-c>`: stop the running task on the current page.
- `<Esc>`, `q`: pop a sub-menu or close the UI.

Output panel:

- `<C-h>`: return to the input panel.
- `<C-c>`: stop the running task on the current page.
- `<Esc>`, `q`: return to the input panel.

## Development

```bash
make ready
```

This formats Lua, runs Luacheck, and runs the headless Plenary tests.

Use `:checkhealth comet` inside Neovim for local environment diagnostics.
