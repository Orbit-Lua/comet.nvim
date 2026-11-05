-- Neovim Events and Keymap Registrations

local action = require("comet.action")
local filter = require("comet.filter")
local render = require("comet.ui.render")
local state = require("comet.state")
local window = require("comet.ui.window")
local api = vim.api

---@param mode string|string[]
---@param lhs string
---@param fn function|string
---@param buf integer
local function km(mode, lhs, fn, buf)
  vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true })
end

local M = {}

--- Inject output panel specific keybinds dynamically onto dynamically created buffers
---@param buf integer
M.apply_output_keymaps = function(buf)
  local function km_fixed_buf(mode, lhs, fn)
    km(mode, lhs, fn, buf)
  end

  km_fixed_buf("n", "<Esc>", window.unfocus_output)
  km_fixed_buf("n", "q", window.unfocus_output)
  km_fixed_buf("n", "<C-h>", window.unfocus_output)
  km_fixed_buf("n", "<C-l>", window.focus_output)
  km_fixed_buf({ "n", "i" }, "<C-i>", "<Nop>")
  km_fixed_buf("n", "<C-c>", action.stop_job)
  km_fixed_buf("n", "i", action.send_task_input)
  km_fixed_buf("n", "a", action.send_task_input)
end

---@param delta integer
---@return fun()
local function mover(delta)
  return function()
    action.move(delta)
  end
end

--- Keys shared by the input and list buffers.
---@param buf integer
local function map_common(buf)
  km({ "n", "i" }, "<Esc>", action.handle_esc, buf)
  km("n", "q", action.handle_esc, buf)
  km({ "n", "i" }, "<C-c>", action.stop_job, buf)
  km({ "n", "i" }, "<C-l>", window.focus_output, buf)
  km({ "n", "i" }, "<C-h>", window.unfocus_output, buf)
  km({ "n", "i" }, "<C-i>", "<Nop>", buf)
end

---@param buf integer
local function map_input(buf)
  km({ "i", "n" }, "<C-j>", mover(1), buf)
  km({ "i", "n" }, "<C-k>", mover(-1), buf)
  km({ "i", "n" }, "<C-n>", mover(1), buf)
  km({ "i", "n" }, "<C-p>", mover(-1), buf)

  km("i", "<Down>", mover(1), buf)
  km("i", "<Up>", mover(-1), buf)
  km("i", "<CR>", action.run_selected, buf)

  km("n", "j", mover(1), buf)
  km("n", "k", mover(-1), buf)
  km("n", "<S-g>", action.move_to_bottom, buf)
  km("n", "gg", action.move_to_top, buf)
  km("n", "<CR>", action.run_selected, buf)
  km({ "n", "i" }, "<Tab>", action.toggle_mark, buf)
end

---@param buf integer
local function map_list(buf)
  km("n", "j", mover(1), buf)
  km("n", "k", mover(-1), buf)
  km("n", "<CR>", action.run_selected, buf)
  km("n", "<Tab>", action.toggle_mark, buf)
end

--- Filter the current page from the typed query.
---@param S CometState
local function on_query_changed(S)
  if require("comet.command").update() then
    return
  end
  local line = api.nvim_get_current_line()
  local query = line:sub(#S.prompt + 1)
  S.last_query = query

  if state.current_sub() then
    state.current_sub().selected = 1
    filter.filter_sub(query)
  else
    S.selected = 1
    filter.filter_commands(query)
  end
  render.list()
end

--- Keep the cursor after the prompt.
---@param S CometState
local function on_cursor_moved(S)
  local cursor = api.nvim_win_get_cursor(0)
  if cursor[2] < #S.prompt then
    pcall(api.nvim_win_set_cursor, 0, { cursor[1], #S.prompt })
  end
  require("comet.command").update()
end

--- Close the palette when any of its windows closes. Reads the latest state,
--- because a reopened palette replaces the state that set up this handler.
---@param closed? integer
local function on_win_closed(closed)
  if not state.is_open() then
    return
  end
  local cur_S = state.get()
  if
    cur_S.input_win
    and (
      closed == cur_S.input_win
      or closed == cur_S.list_win
      or closed == cur_S.output_win
    )
  then
    vim.schedule(window.close)
  end
end

---@param S CometState
local function create_autocmds(S)
  local aug = api.nvim_create_augroup("CometUI", { clear = true })

  api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = aug,
    buffer = S.input_buf,
    callback = function()
      on_query_changed(S)
    end,
  })

  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = aug,
    buffer = S.input_buf,
    callback = function()
      on_cursor_moved(S)
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    group = aug,
    callback = function(ev)
      on_win_closed(tonumber(ev.match))
    end,
  })

  api.nvim_create_autocmd("VimResized", {
    group = aug,
    callback = function()
      if state.is_open() then
        window.resize_layout()
      end
    end,
  })
end

--- Bootstrap all event handlers onto the active layout
M.setup = function()
  local S = state.get()
  if not S then
    return
  end

  map_common(S.input_buf)
  map_common(S.list_buf)
  map_input(S.input_buf)
  map_list(S.list_buf)
  create_autocmds(S)
end

return M
