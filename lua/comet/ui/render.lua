-- Handles writing to buffers, list rendering, and syntax highlighting

local state = require("comet.state")
local api = vim.api
local M = {}

local OUT_HL_PATTERNS = {
  { pat = "^%$ ", line_hl = "Comment" },
  { pat = "✓", line_hl = "DiagnosticOk" },
  { pat = "✗", line_hl = "DiagnosticError" },
  { pat = "Build succeeded", line_hl = "DiagnosticOk" },
  { pat = "Build FAILED", line_hl = "DiagnosticError" },
  { pat = "[Ww]arning%s", line_hl = "DiagnosticWarn" },
  { pat = "[Aa]bort%s", line_hl = "DiagnosticWarn" },
  { pat = "%[Process Terminated by User%]", line_hl = "DiagnosticWarn" },
  { pat = "[Ee]rror%s", line_hl = "DiagnosticError" },
  { pat = "Restored%s", line_hl = "DiagnosticOk" },
  { pat = "Passed!", line_hl = "DiagnosticOk" },
  { pat = "Failed!", line_hl = "DiagnosticError" },
}

--- Extmark patterns onto target buffer
---@param target_buf integer
---@param start_line integer
---@param end_line integer
M.highlight_output = function(target_buf, start_line, end_line)
  if not state.is_open() then
    return
  end

  local S = state.get()
  if not (S.out_ns and target_buf and api.nvim_buf_is_valid(target_buf)) then
    return
  end

  local lines = api.nvim_buf_get_lines(target_buf, start_line, end_line, false)
  for i, line in ipairs(lines) do
    local row = start_line + i - 1
    for _, rule in ipairs(OUT_HL_PATTERNS) do
      if line:find(rule.pat) then
        api.nvim_buf_set_extmark(target_buf, S.out_ns, row, 0, {
          line_hl_group = rule.line_hl,
        })
        break
      end
    end
  end
end

--- Clear and reapply highlights for the entire buffer
---@param target_buf integer
M.rehighlight_output = function(target_buf)
  local S = state.get()
  if not (S.out_ns and target_buf and api.nvim_buf_is_valid(target_buf)) then
    return
  end

  api.nvim_buf_clear_namespace(target_buf, S.out_ns, 0, -1)
  local line_count = api.nvim_buf_line_count(target_buf)
  M.highlight_output(target_buf, 0, line_count)
end

--- Update the output window title to reflect status
M.update_output_title = function()
  if not state.is_open() then
    return
  end

  local S = state.get()
  if not (S.output_win and api.nvim_win_is_valid(S.output_win)) then
    return
  end

  local title = " Output "
  if S.current_page_key ~= S.root_title then
    title = title .. S.current_page_key
  else
    title = title .. "Main"
  end

  local page_id = state.page_id(S.session_id, S.current_page_key)
  local status = state.running_tasks[page_id]
      and state.running_tasks[page_id].status
    or nil
  local is_focused = api.nvim_get_current_win() == S.output_win

  if status == "running" then
    title = title .. " [C-c: Stop]"
  elseif status == "done" then
    title = title .. " [Done]"
  elseif status == "abort" then
    title = title .. " [Abort]"
  elseif status == "error" then
    title = title .. " [Error]"
  end

  title = title .. (is_focused and "(focused) " or " ")

  pcall(
    api.nvim_win_set_config,
    S.output_win,
    { title = title, title_pos = "center" }
  )
end

--- Append lines to the target buffer
---@param target_buf integer
---@param lines string|string[]
M.out_write = function(target_buf, lines)
  if not (target_buf and api.nvim_buf_is_valid(target_buf)) then
    return
  end
  if type(lines) == "string" then
    lines = vim.split(lines, "\n")
  end

  local to_write = {}
  for i, l in ipairs(lines) do
    if i < #lines or l ~= "" then
      table.insert(to_write, (l:gsub("\r", "")))
    end
  end
  if #to_write == 0 then
    return
  end

  vim.bo[target_buf].modifiable = true
  local n = api.nvim_buf_line_count(target_buf)
  local start = n
  if n == 1 and api.nvim_buf_get_lines(target_buf, 0, 1, false)[1] == "" then
    start = 0
  end
  api.nvim_buf_set_lines(target_buf, start, -1, false, to_write)
  vim.bo[target_buf].modifiable = false

  if state.is_open() then
    M.highlight_output(target_buf, start, start + #to_write)

    local S = state.get()
    if
      S.output_win
      and api.nvim_win_is_valid(S.output_win)
      and api.nvim_win_get_buf(S.output_win) == target_buf
    then
      local new_n = api.nvim_buf_line_count(target_buf)
      pcall(api.nvim_win_set_cursor, S.output_win, { new_n, 0 })
    end
  end
end

--- Clear target buffer
---@param target_buf integer
M.out_clear = function(target_buf)
  if not (target_buf and api.nvim_buf_is_valid(target_buf)) then
    return
  end

  vim.bo[target_buf].modifiable = true
  api.nvim_buf_set_lines(target_buf, 0, -1, false, {})
  vim.bo[target_buf].modifiable = false

  if state.is_open() then
    local S = state.get()
    if S.out_ns then
      api.nvim_buf_clear_namespace(target_buf, S.out_ns, 0, -1)
    end
  end
end

---@param item CometItem
---@return integer|CometItem
local function get_mark_key(item)
  return type(item) == "table" and item._idx or item
end

---@param S CometState
---@param item CometItem
---@return string?
local function item_icon(S, item)
  if not S.show_icons then
    return nil
  end
  if type(item) == "table" and item.icon and item.icon ~= "" then
    return item.icon
  end
  return S.default_icon
end

--- Build the list lines and the byte width of each row's mark column.
---@param S CometState
---@param items CometItem[]
---@param sub? SubMenuState
---@return string[] lines
---@return integer[] mark_offsets
local function list_lines(S, items, sub)
  local lines, mark_offsets = {}, {}
  for idx, item in ipairs(items) do
    local mark = ""
    if sub and sub.multi_select then
      mark = sub.marked[get_mark_key(item)] and "✓ " or "  "
    end
    mark_offsets[idx] = #mark
    local icon = item_icon(S, item)
    local icon_text = icon and icon ~= "" and (icon .. "  ") or ""
    local name = type(item) == "string" and item or item.name
    table.insert(lines, "  " .. mark .. icon_text .. name)
  end

  while #lines < S.list_h do
    table.insert(lines, "")
  end
  return lines, mark_offsets
end

---@class CometListRow
---@field row integer zero-based line
---@field item CometItem
---@field line string
---@field mark_offset integer
---@field selected boolean
---@field marked boolean

--- Highlight the selection, the mark, the icon and the name of one row.
---@param S CometState
---@param row CometListRow
local function highlight_row(S, row)
  if row.selected then
    api.nvim_buf_set_extmark(
      S.list_buf,
      S.ns,
      row.row,
      0,
      { line_hl_group = "Visual" }
    )
  end

  if row.marked and row.mark_offset > 0 then
    api.nvim_buf_set_extmark(
      S.list_buf,
      S.ns,
      row.row,
      2,
      { end_col = 2 + row.mark_offset, hl_group = "DiagnosticOk" }
    )
  end

  local item = row.item
  local icon = item_icon(S, item)
  local name_start = 2 + row.mark_offset
  if icon and icon ~= "" then
    local icon_hl = type(item) == "table" and item.icon_hl or "String"
    local icon_end = name_start + #icon
    api.nvim_buf_set_extmark(S.list_buf, S.ns, row.row, name_start, {
      end_col = icon_end,
      hl_group = icon_hl or "String",
    })
    name_start = icon_end + 2
  end
  api.nvim_buf_set_extmark(S.list_buf, S.ns, row.row, name_start, {
    end_col = #row.line,
    hl_group = row.selected and "CursorLineNr" or "Normal",
  })
end

--- Render the left panel list based on current state
M.list = function()
  local S = state.get()
  if not (S.list_buf and api.nvim_buf_is_valid(S.list_buf)) then
    return
  end

  local items = state.current_items()
  local sel = state.current_selected()
  local sub = state.current_sub()

  api.nvim_buf_clear_namespace(S.list_buf, S.ns, 0, -1)
  vim.bo[S.list_buf].modifiable = true

  local lines, mark_offsets = list_lines(S, items, sub)
  api.nvim_buf_set_lines(S.list_buf, 0, -1, false, lines)

  for i, item in ipairs(items) do
    highlight_row(S, {
      row = i - 1,
      item = item,
      line = lines[i],
      mark_offset = mark_offsets[i] or 0,
      selected = i == sel,
      marked = sub and sub.multi_select and sub.marked[get_mark_key(item)]
        or false,
    })
  end

  vim.bo[S.list_buf].modifiable = false

  if
    S.list_win
    and api.nvim_win_is_valid(S.list_win)
    and sel > 0
    and sel <= #items
  then
    pcall(api.nvim_win_set_cursor, S.list_win, { sel, 0 })
  end
end

return M
