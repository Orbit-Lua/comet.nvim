-- Command pages own transient input and the lifetime of completion requests.
local state = require("comet.state")
local window = require("comet.ui.window")
local render = require("comet.ui.render")
local api = vim.api
local M = {}

local function active()
  if not state.is_open() then
    return
  end
  local page = state.current_sub()
  if page and page.kind == "command" then
    return state.get(), page
  end
end

local function cancel(page)
  page.revision = (page.revision or 0) + 1
  if page.cancel_completion then
    page.cancel_completion()
    page.cancel_completion = nil
  end
end

function M.open(ctx, opts)
  assert(
    type(opts.complete) == "function" and type(opts.submit) == "function",
    "command complete and submit callbacks are required"
  )
  ctx:select({}, { title = opts.title or "Command" })
  local page = state.current_sub()
  page.kind, page.command, page.command_ctx = "command", opts, ctx
  local input = state.get().input_buf
  page.undo_levels = vim.bo[input].undolevels
  vim.bo[input].undolevels = -1
  if type(opts.initial) == "string" and not opts.initial:find("[\r\n]") then
    window.put_input_query(opts.initial)
    local S = state.get()
    api.nvim_win_set_cursor(S.input_win, { 1, #S.prompt + #opts.initial })
  end
  M.update()
end

--- Read the typed text after the prompt and the cursor offset in that text.
---@param S CometState
---@return string text
---@return integer cursor zero-based byte offset, clamped to the text
local function read_input(S)
  local line = api.nvim_buf_get_lines(S.input_buf, 0, 1, false)[1] or ""
  local text = line:sub(#S.prompt + 1)
  local column = api.nvim_win_get_cursor(S.input_win)[2] - #S.prompt
  return text, math.max(0, math.min(#text, column))
end

---@class CometCompletionTarget
---@field S CometState
---@field page SubMenuState
---@field revision integer
---@field buffer integer
---@field win integer
---@field text string
---@field cursor integer

--- True while the page, its revision and its input still match the request.
---@param target CometCompletionTarget
---@return boolean
local function still_current(target)
  local S, page = target.S, target.page
  if
    not state.is_open()
    or state.get() ~= S
    or state.current_sub() ~= page
    or page.revision ~= target.revision
    or not api.nvim_buf_is_valid(target.buffer)
    or not api.nvim_win_is_valid(target.win)
  then
    return false
  end

  local text, cursor = read_input(S)
  return text == target.text and cursor == target.cursor
end

---@param page SubMenuState
local function show_failure(page)
  page.completion_error = true
  page.items = { { name = "Completion unavailable; keep typing to retry" } }
  page.all_items = page.items
  render.list()
end

---@param target CometCompletionTarget
---@param items? CometCompletionItem[]
---@param err? any
local function apply_completion(target, items, err)
  local page = target.page
  page.items = {}
  for _, item in ipairs(items or {}) do
    if type(item.label) == "string" and type(item.text) == "string" then
      page.items[#page.items + 1] = { name = item.label, completion = item }
    end
  end
  page.all_items = page.items
  page.completion_input = { text = target.text, cursor = target.cursor }
  page.selected = math.min(page.selected, math.max(1, #page.items))
  if err then
    show_failure(page)
  else
    render.list()
  end
end

--- Call the consumer's completion provider for one input revision.
---@param target CometCompletionTarget
local function request_completion(target)
  if not still_current(target) then
    return
  end

  local page = target.page
  local ok, stop = pcall(
    page.command.complete,
    { text = target.text, cursor = target.cursor },
    function(items, err)
      vim.schedule(function()
        if still_current(target) then
          apply_completion(target, items, err)
        end
      end)
    end
  )
  if not ok then
    show_failure(page)
  elseif type(stop) == "function" then
    if still_current(target) then
      page.cancel_completion = stop
    else
      stop()
    end
  end
end

function M.update()
  local S, page = active()
  if not S then
    return false
  end
  cancel(page)
  local text, cursor = read_input(S)
  ---@type CometCompletionTarget
  local target = {
    S = S,
    page = page,
    revision = page.revision,
    buffer = S.input_buf,
    win = S.input_win,
    text = text,
    cursor = cursor,
  }
  page.items, page.all_items, page.selected = {}, {}, 1
  page.completion_error = nil
  render.list()
  vim.defer_fn(function()
    request_completion(target)
  end, 80)
  return true
end

function M.accept()
  local S, page = active()
  if not S then
    return false
  end
  local item = page.items[page.selected]
  if not item or not item.completion or not page.completion_input then
    return true
  end
  local completion, input = item.completion, page.completion_input
  local text, cursor = read_input(S)
  if text ~= input.text or cursor ~= input.cursor then
    return true
  end
  local first, last =
    completion.start or input.cursor, completion.finish or input.cursor
  if
    first < 0
    or last < first
    or last > #input.text
    or completion.text:find("[\r\n]")
  then
    return true
  end
  cancel(page)
  api.nvim_buf_set_text(
    S.input_buf,
    0,
    #S.prompt + first,
    0,
    #S.prompt + last,
    { completion.text }
  )
  api.nvim_win_set_cursor(
    S.input_win,
    { 1, #S.prompt + first + #completion.text }
  )
  M.update()
  return true
end

function M.submit()
  local S, page = active()
  if not S then
    return false
  end
  local text = read_input(S)
  cancel(page)
  page.items, page.all_items, page.completion_input = {}, {}, nil
  window.put_input_query("")
  render.list()
  if vim.trim(text) ~= "" then
    -- Consumer errors must not echo the submitted command or credentials.
    local ok = pcall(page.command.submit, text, page.command_ctx)
    if not ok then
      page.command_ctx:append("Command submission failed")
      page.command_ctx:set_status("error")
    end
  end
  return true
end

function M.leave()
  local S, page = active()
  if not S then
    return
  end
  cancel(page)
  page.items, page.all_items, page.completion_input = {}, {}, nil
  window.put_input_query("")
  vim.bo[S.input_buf].undolevels = page.undo_levels
end

function M.close()
  if not state.is_open() then
    return
  end
  local S = state.get()
  for index, page in ipairs(S.sub_stack) do
    if page.kind == "command" then
      for child = index, #S.sub_stack do
        local entry = S.sub_stack[child]
        if entry.kind == "command" then
          cancel(entry)
          entry.items, entry.all_items, entry.completion_input = {}, {}, nil
        end
      end
      while #S.sub_stack >= index do
        table.remove(S.sub_stack)
      end
      S.last_query = page.saved_query or ""
      S.current_page_key = #S.sub_stack > 0 and S.sub_stack[1].page_key
        or S.root_title
      vim.bo[S.input_buf].undolevels = page.undo_levels
      return
    end
  end
end

return M
