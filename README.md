# comet.nvim

A two-panel command palette for Neovim: search actions on the left, keep each action's output on the right.

[![Validate](https://github.com/Orbit-Lua/comet.nvim/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/Orbit-Lua/comet.nvim/actions/workflows/validate.yml?query=branch%3Amain)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

comet.nvim suits project commands and interactive local jobs that need a small UI and persistent output.
It has no runtime plugin dependencies.
It registers no user command; your configuration opens it.

## Install

Requirements:

- Neovim 0.10 or newer. CI tests Neovim 0.12.
- Optional: a font with the glyphs that you use as icons.

Install with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "Orbit-Lua/comet.nvim" }
```

## Usage

Map a key that opens a list of commands:

```lua
vim.keymap.set("n", "<leader>tt", function()
  require("comet").open({
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
```

Press `<leader>tt`, then `<CR>` on **Say hello**.
The right panel shows `Hello from Comet`.
Open the same session again to close the palette.
Give each workspace its own `session_id` to keep its pages, tasks and output apart.

## Features

- Fuzzy filtering of root actions and submenu items, including item descriptions.
- Nested selection pages with optional `<Tab>` multi-select.
- One output buffer for each page, and a remembered page, selection and query for each session.
- Async job status, `<C-c>` cancellation, and line input for interactive jobs.
- List updates through `ctx:update(items)`. Comet ignores an update from a page that is no longer visible.
- Icons for each item, and an optional session `default_icon` for items without one.

## Commands and context

Each root command has a `name` and an `action(ctx)` callback.
`icon`, `icon_hl` and `desc` are optional:

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
| `ctx:append(line)` / `ctx:write(lines)` | Append a line, or a string or list of lines, to this page's output. |
| `ctx:clear()` | Clear this page's output. |
| `ctx:select(items, opts)` | Open a nested selection page. Set `multi_select = true` to pass a list of marked items to the callback. |
| `ctx:update(items)` | Replace the active list. Returns `false` when this context's page is no longer visible. |
| `ctx:start_async_task(job_id, abort_fn?)` | Track a running Neovim job. Comet stops it with `jobstop` by default. |
| `ctx:terminal(job_id, opts?)` | Accept line input for that job from the output panel. `opts.on_input` can supply another transport. |
| `ctx:done(job_id?)` / `ctx:error(job_id?)` | Set the task result. Pass the job ID when a stopped job can finish after a newer one. |
| `ctx:set_status(status)` | Set the status in the output title. |
| `ctx:command(opts)` | Open a command-entry page. See below. |

Submenu items are strings, or tables with `name` and optional `desc` and `icon`.
`ctx:select()` calls `on_select(item, child_ctx)`.
In multi-select mode, it calls `on_select(items, child_ctx)`.

For an interactive job:

1. Start the job with `vim.fn.jobstart`.
2. Call `ctx:start_async_task(job_id)`, then `ctx:terminal(job_id)`.
3. Focus the output panel and press `i` or `a` to send a line to the job.

### Command-entry pages

`ctx:command(opts)` opens a transient page with free text input and completion.

| Option | Use |
| --- | --- |
| `complete(request, reply)` | Required. Compute suggestions and call `reply(items, error)`. Return a function to cancel obsolete work. |
| `submit(text, ctx)` | Required. Run the submitted input. |
| `title` | Page title. Default `Command`. |
| `initial` | Transient initial input, such as a command prefix. |

- The request holds `text` and a zero-based UTF-8 byte `cursor`.
- Each suggestion holds `label`, replacement `text`, and optional `start` and `finish`.
- `start` and `finish` are zero-based, end-exclusive UTF-8 byte offsets. Without them, the suggestion inserts at the request cursor.
- Comet ignores a reply from an older input, cursor, page or session.
- `<Tab>` accepts the selected suggestion. `<CR>` submits the input as typed.
- Comet clears the input after a submission, and does not restore it after the palette closes.
- When a command page closes, the next open shows its parent page.
- Your callbacks own command parsing, provider errors, execution and credential handling.

## Keymaps

| Key | Action |
| --- | --- |
| `<CR>` | Run the selected action. |
| `<C-j>`, `<C-n>`, `<Down>` / `<C-k>`, `<C-p>`, `<Up>` | Move through the results. |
| `gg`, `G` | Jump to the first or last result in normal mode. |
| `<Tab>` | Mark an item on a multi-select page. |
| `<C-l>` / `<C-h>` | Focus the output panel / return to the input panel. |
| `i`, `a` in the output panel | Send a line of input to the active terminal job. |
| `<C-c>` | Stop the running job of the current page. |
| `<Esc>`, `q` | Leave the output panel, close a submenu, or close the palette. |

## Configuration

`setup(opts)` sets the global defaults.
Options passed to `open(commands, opts)` override them for that call.
`setup()` is optional.

| Option | Default | Effect |
| --- | --- | --- |
| `session_id` | `"Comet"` | Namespace for remembered UI state, output and tasks. |
| `root_title` | `session_id` | Title of the root page. |
| `insert_mode` | `true` | Start in insert mode when the palette opens. |
| `block_while_running` | `true` | Block a new action on a page while its task runs. |
| `remember_page` | `true` | Restore the page stack, selection and query on reopen. |
| `show_icons` | `true` | Show item icons. |
| `default_icon` | unset | Icon for an item without its own icon. |

`setup()` and `open()` raise an error for an unknown option or a value of the wrong type.
The error names the option, such as `comet: opts.show_icon: unknown option`.
After a rejected `setup()`, the previous defaults stay.
A rejected `open()` changes no window.

Run `:checkhealth comet` to check Neovim compatibility.

## License

[GPL-3.0](LICENSE)
