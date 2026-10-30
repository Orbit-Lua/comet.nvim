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

function M.update()
  local S, page = active()
  if not S then
    return false
  end
  cancel(page)
  local revision, buffer, win = page.revision, S.input_buf, S.input_win
  local text = (api.nvim_buf_get_lines(buffer, 0, 1, false)[1] or ""):sub(
    #S.prompt + 1
  )
  local cursor =
    math.max(0, math.min(#text, api.nvim_win_get_cursor(win)[2] - #S.prompt))
  local function current()
    if
      not state.is_open()
      or state.get() ~= S
      or state.current_sub() ~= page
      or page.revision ~= revision
      or not api.nvim_buf_is_valid(buffer)
      or not api.nvim_win_is_valid(win)
    then
      return false
    end
    local line = api.nvim_buf_get_lines(buffer, 0, 1, false)[1] or ""
    return line:sub(#S.prompt + 1) == text
      and math.max(
          0,
          math.min(#text, api.nvim_win_get_cursor(win)[2] - #S.prompt)
        )
        == cursor
  end
  page.items, page.all_items, page.selected = {}, {}, 1
  page.completion_error = nil
  render.list()
  local function failed()
    page.completion_error = true
    page.items = { { name = "Completion unavailable; keep typing to retry" } }
    page.all_items = page.items
    render.list()
  end
  vim.defer_fn(function()
    if not current() then
      return
    end
    local ok, stop = pcall(
      page.command.complete,
      { text = text, cursor = cursor },
      function(items, err)
        vim.schedule(function()
          if not current() then
            return
          end
          page.items = {}
          for _, item in ipairs(items or {}) do
            if type(item.label) == "string" and type(item.text) == "string" then
              page.items[#page.items + 1] =
                { name = item.label, completion = item }
            end
          end
          page.all_items = page.items
          page.completion_input = { text = text, cursor = cursor }
          page.selected = math.min(page.selected, math.max(1, #page.items))
          if err then
            failed()
          else
            render.list()
          end
        end)
      end
    )
    if not ok then
      failed()
    elseif type(stop) == "function" then
      if current() then
        page.cancel_completion = stop
      else
        stop()
      end
    end
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
  local line = api.nvim_buf_get_lines(S.input_buf, 0, 1, false)[1] or ""
  if line:sub(#S.prompt + 1) ~= input.text then
    return true
  end
  if
    math.max(
      0,
      math.min(#input.text, api.nvim_win_get_cursor(S.input_win)[2] - #S.prompt)
    ) ~= input.cursor
  then
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
  local text = (api.nvim_buf_get_lines(S.input_buf, 0, 1, false)[1] or ""):sub(
    #S.prompt + 1
  )
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
