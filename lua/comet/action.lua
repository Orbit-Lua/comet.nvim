-- Actions bound to User Interactions (Enter, Esc, Move)

local context = require("comet.context")
local filter = require("comet.filter")
local render = require("comet.ui.render")
local state = require("comet.state")
local window = require("comet.ui.window")
local api = vim.api
local M = {}

--- Shift selection in the left panel
---@param delta integer +1 for down, -1 for up
M.move = function(delta)
  local n = #state.current_items()
  if n == 0 then
    return
  end
  local S = state.get()
  local sub = state.current_sub()

  if sub then
    sub.selected = (sub.selected - 1 + delta) % n + 1
  else
    S.selected = (S.selected - 1 + delta) % n + 1
  end

  render.list()
end

M.move_to_top = function()
  local S = state.get()
  local sub = state.current_sub()

  if sub then
    sub.selected = 1
  else
    S.selected = 1
  end

  render.list()
end

M.move_to_bottom = function()
  local S = state.get()
  local sub = state.current_sub()
  local n = #state.current_items()

  if sub then
    sub.selected = n
  else
    S.selected = n
  end

  render.list()
end

--- Handle `<Esc>` or `q`: Either pop the menu stack or close the UI
M.handle_esc = function()
  local S = state.get()
  require("comet.command").leave()
  if #S.sub_stack > 0 then
    local popped = table.remove(S.sub_stack)
    if popped.on_cancel then
      popped.on_cancel()
    end

    local parent_title = S.root_title
    local parent_key = S.root_title

    if #S.sub_stack > 0 then
      local parent = S.sub_stack[#S.sub_stack]
      parent_title = parent.title
      parent_key = S.sub_stack[1].page_key
    end

    pcall(
      api.nvim_win_set_config,
      S.input_win,
      { title = " " .. parent_title .. " ", title_pos = "center" }
    )

    window.switch_output_buf(parent_key)
    window.put_input_query(popped.saved_query or "")

    if #S.sub_stack > 0 then
      filter.filter_sub(S.last_query)
    else
      filter.filter_commands(S.last_query or "")
    end

    render.list()
  else
    window.close()
  end
end

--- Safely stop a running job using its context
M.stop_job = function()
  local S = state.get()
  local page_id = state.page_id(S.session_id, S.current_page_key)
  if not (S and S.current_page_key and state.running_tasks[page_id]) then
    return
  end

  local task = state.running_tasks[page_id]
  if task.abort_fn and task.status == "running" then
    task.abort_fn()
    task.status = "abort"
    render.update_output_title()
  end
end

--- Prompt for one line and send it to the interactive task on this page.
M.send_task_input = function()
  local S = state.get()
  local page_id = state.page_id(S.session_id, S.current_page_key)
  local task = state.running_tasks[page_id]
  if not (task and task.status == "running" and task.input_fn) then
    return
  end

  vim.ui.input({ prompt = task.input_prompt or "stdin> " }, function(input)
    if input == nil then
      return
    end
    local current = state.running_tasks[page_id]
    if current == task and task.status == "running" then
      task.input_fn(input)
    end
  end)
end

--- Warn and return true when a task on this page blocks a new action.
---@param S CometState
---@param page_id string
---@return boolean
local function blocked_by_task(S, page_id)
  local task = state.running_tasks[page_id]
  if not (S.block_while_running and task and task.status == "running") then
    return false
  end

  vim.api.nvim_echo({
    {
      " Task is still running. Press <C-c> to stop it first.",
      "DiagnosticWarn",
    },
  }, false, {})
  return true
end

---@param item CometItem
---@return string
local function item_name(item)
  return type(item) == "table" and (item.name or "Item") or tostring(item)
end

--- Return the marked items in list order, or the focused item when none is
--- marked, and the name of the resulting trigger.
---@param sub SubMenuState
---@param item CometItem
---@return CometItem[] items
---@return string trigger_name
local function marked_items(sub, item)
  if vim.tbl_count(sub.marked) == 0 then
    return { item }, item_name(item)
  end

  local selected = {}
  for _, candidate in ipairs(sub.all_items) do
    local key = type(candidate) == "table" and candidate._idx or candidate
    if sub.marked[key] then
      selected[#selected + 1] = candidate
    end
  end
  if #selected > 1 then
    return selected, "Multi(" .. #selected .. ")"
  end
  return selected, item_name(selected[1])
end

---@param sub SubMenuState
---@param item CometItem
local function run_multi_select(sub, item)
  local selected, trigger_name = marked_items(sub, item)
  local on_select = sub.on_select
  local callback_page_key = sub.page_key
  window.switch_output_buf(callback_page_key)
  render.list()

  if on_select and #selected > 0 then
    on_select(selected, context.make(trigger_name, callback_page_key))
  end
end

---@param S CometState
---@param item CometItem
local function run_item(S, item)
  local sub = state.current_sub()
  if not sub then
    if item.action then
      item.action(context.make(item_name(item), S.root_title))
    end
    return
  end

  if sub.multi_select then
    run_multi_select(sub, item)
    return
  end
  if sub.on_select then
    sub.on_select(item, context.make(item_name(item)))
  end
  render.list()
end

--- Return focus to the input window after an action, if the palette still
--- owns the current window.
---@param S CometState
---@param was_insert boolean
local function restore_focus(S, was_insert)
  if
    not (state.is_open() and S.input_win and api.nvim_win_is_valid(S.input_win))
  then
    return
  end

  local cur = api.nvim_get_current_win()
  if cur == S.input_win or cur == S.list_win or cur == S.output_win then
    api.nvim_set_current_win(S.input_win)
    if was_insert then
      vim.cmd("startinsert")
    end
  end
end

--- Execute the currently focused item
M.run_selected = function()
  local S = state.get()
  local page_id = state.page_id(S.session_id, S.current_page_key)
  if blocked_by_task(S, page_id) then
    return
  end

  local was_insert = api.nvim_get_mode().mode == "i"
  if require("comet.command").submit() then
    return
  end
  local item = state.current_items()[state.current_selected()]
  if not item then
    return
  end

  run_item(S, item)
  vim.schedule(function()
    restore_focus(S, was_insert)
  end)
end

local function get_mark_key(item)
  return type(item) == "table" and item._idx or item
end

--- Update multi-select title counter
local function update_multi_title()
  local S = state.get()
  local sub = state.current_sub()
  if not sub or not sub.multi_select then
    return
  end

  local count = vim.tbl_count(sub.marked)
  local title = sub.title
  if count > 0 then
    title = title .. " (" .. count .. " selected)"
  end

  pcall(
    api.nvim_win_set_config,
    S.input_win,
    { title = " " .. title .. " ", title_pos = "center" }
  )
end

--- Toggle checkbox for current item in multi-select mode
M.toggle_mark = function()
  if require("comet.command").accept() then
    return
  end
  local sub = state.current_sub()
  if not sub or not sub.multi_select then
    return
  end
  local items, sel = sub.items, sub.selected
  if sel < 1 or sel > #items then
    return
  end

  local key = get_mark_key(items[sel])
  if sub.marked[key] then
    sub.marked[key] = nil
  else
    sub.marked[key] = true
  end

  update_multi_title()
  M.move(1)
end

return M
