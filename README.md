# ☄️ comet.nvim

A sleek, generic two-panel picker and task UI for Neovim.

**comet.nvim** provides an elegant interface featuring a searchable list on the
left and an output/preview panel on the right. It is perfect for building custom
menus, task runners, build system integrations, or any workflow that requires
executing actions and displaying real-time output.

## ✨ Features

- **🌗 Two-Panel Layout**: Left panel for fuzzy-searching and selecting items;
  right panel for viewing action output.
- **📂 Nested Sub-menus**: Easily push sub-selections onto the left panel to
  create step-by-step interactive flows.
- **✅ Multi-select Support**: Built-in multi-select capabilities for sub-menus
  with `<Tab>`.
- **🎨 Output Highlighting**: Automatically highlights specific output patterns
  (e.g., `Build succeeded`, `Error`, `✓`, `✗`) for instant visual feedback.
- **⌨️ Intuitive Navigation**: Seamlessly navigate lists and toggle focus
  between the input and output panels.

---

## 📦 Installation

Install `comet.nvim` using your preferred package manager.

**[lazy.nvim](https://github.com/folke/lazy.nvim):**

```lua
{
  "gin31259461/comet.nvim",
}
```

**[packer.nvim](https://github.com/wbthomason/packer.nvim):**

```lua
use { 'gin31259461/comet.nvim' }
```

---

## 🚀 Quick Start

Here is a basic example of how to configure and open the Comet UI:

```lua
local comet = require("comet")

local my_commands = {
  {
    name = "Run Tests",
    icon = "🧪",
    desc = "Run all unit tests",
    action = function(ctx)
      ctx.clear()
      ctx.write("$ jest --watchAll=false")
      -- Simulate some output
      vim.defer_fn(function()
        ctx.append("✓ Test suite passed!")
      end, 500)
    end,
  },
  {
    name = "Build Project",
    icon = "🔨",
    icon_hl = "WarningMsg",
    desc = "Compile the source code",
    action = function(ctx)
      ctx.clear()
      ctx.append("Build FAILED")
    end,
  }
}

-- Bind it to a key
vim.keymap.set("n", "<leader>c", function()
  comet.open(my_commands, { title = "My Tasks", insert_mode = true })
end, { desc = "Open Comet UI" })
```

---

## 🛠️ API & Configuration

### `require("comet").open(commands, opts)`

Opens the UI with a given set of commands.

- `commands`: An array of **Command Spec** objects (see below).
- `opts`: Options table.
  - `title` _(string)_: Title for the left panel.
  - `insert_mode` _(boolean)_: If `true`, automatically enters insert mode in
    the search prompt.

### 📋 Command Spec

Each item in your `commands` list must follow this structure:

```lua
{
  name = "String",        -- Display name of the item
  icon = "String",        -- Icon to display next to the name
  icon_hl = "String",     -- (Optional) Highlight group for the icon. Defaults to "String".
  desc = "String",        -- (Optional) Hidden description used for fuzzy filtering.
  action = function(ctx)  -- Callback executed when the item is selected.
    -- Do things with ctx
  end
}
```

### The `ctx` Object

When an `action` is triggered, it receives a `ctx` (context) object to control
the UI:

| Method                    | Description                                                     |
| :------------------------ | :-------------------------------------------------------------- |
| `ctx.write(lines)`        | Appends a string or array of strings to the right output panel. |
| `ctx.append(line)`        | Appends a single line to the output panel.                      |
| `ctx.clear()`             | Clears the output panel entirely.                               |
| `ctx.select(items, opts)` | Replaces the left panel with a new list of items (Nested Menu). |

#### Sub-selections (`ctx.select`)

You can create nested menus by calling `ctx.select`.

- `items`: Array of strings or Command Spec tables.
- `opts`:
  - `title` _(string)_: Title for the sub-menu.
  - `multi_select` _(boolean)_: Enable selecting multiple items with `<Tab>`.
  - `on_select` _(function)_: Callback when an item (or items) is chosen.
    Receives `(item_or_items, ctx)`.
  - `on_cancel` _(function)_: (Optional) Callback if the user presses `<Esc>` to
    exit the sub-menu.

**Example of a Multi-Select Sub-menu:**

```lua
action = function(ctx)
  local files = { "main.lua", "utils.lua", "config.lua" }

  ctx.select(files, {
    title = "Select Files to Lint",
    multi_select = true,
    on_select = function(selected_files, sub_ctx)
      sub_ctx.clear()
      sub_ctx.write("Linting selected files...")
      for _, file in ipairs(selected_files) do
         sub_ctx.append("✓ " .. file .. " looks good!")
      end
    end
  })
end
```

---

## ⌨️ Keymaps

The UI comes with sensible default bindings to ensure a smooth, keyboard-driven
experience.

### Input / List Panels

| Key               |      Mode       | Action                                            |
| :---------------- | :-------------: | :------------------------------------------------ |
| `<C-j>` / `<C-k>` | Normal / Insert | Move selection down/up                            |
| `<Down>` / `<Up>` | Normal / Insert | Move selection down/up                            |
| `j` / `k`         |     Normal      | Move selection down/up                            |
| `<CR>`            | Normal / Insert | Execute selected item                             |
| `<Tab>`           | Normal / Insert | Toggle multi-select mark (if enabled in sub-menu) |
| `<C-l>`           | Normal / Insert | Focus the right output panel                      |
| `<Esc>` / `q`     | Normal / Insert | Go back (pop sub-menu) or Close UI entirely       |

### Output Panel

| Key           |  Mode  | Action                                                              |
| :------------ | :----: | :------------------------------------------------------------------ |
| `<C-h>`       | Normal | Return focus to the left input/list panel                           |
| `<Esc>` / `q` | Normal | Return focus to the left input/list panel (does _not_ close the UI) |
