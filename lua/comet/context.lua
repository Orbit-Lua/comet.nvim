-- The Command Context Builder

---@class CometCtx
---@field target_buf integer
---@field target_page_key string
---@field page_id string
---@field session_id string
---@field _state CometState Session that created this context
---@field _trigger_name string Page key of a submenu opened from this context
---@field _selected_sub? SubMenuState Submenu opened by this context
---@field write fun(self: CometCtx, lines: string[]|string)
---@field clear fun(self: CometCtx)
---@field done fun(self: CometCtx)
---@field error fun(self: CometCtx)
---@field append fun(self: CometCtx, line: string)
---@field start_async_task fun(self: CometCtx, job_id: integer, abort_fn: function|nil)
---@field terminal fun(self: CometCtx, job_id: integer, opts?: table)
---@field update fun(self: CometCtx, items: any[])
---@field set_status fun(self: CometCtx, status: string)
---@field select fun(self: CometCtx, items: any[], opts: CometSelectOpts)
---@field command fun(self: CometCtx, opts: table) Open a transient command page.

---@class CometSelectOpts
---@field title? string
---@field multi_select? boolean
---@field on_select fun(item_or_items: any, ctx: CometCtx)
---@field on_cancel? fun()

local render = require("comet.ui.render")
local state = require("comet.state")
local window = require("comet.ui.window")
local M = {}

---@param self CometCtx
---@param page_key string
local function bind_page(self, page_key)
  local S = self._state
  self.target_page_key = page_key
  self.page_id = state.page_id(self.session_id, page_key)
  self.target_buf = state.output_buf_cache[self.page_id] or S.output_buf
end

--- Set the result of this page's task, unless a newer job owns it or the
--- task was aborted.
---@param self CometCtx
---@param job_id? integer
---@param status "done"|"error"
local function finish_task(self, job_id, status)
  local task = state.running_tasks[self.page_id]
  if task and (not job_id or task.id == job_id) and task.status ~= "abort" then
    task.status = status
    vim.schedule(render.update_output_title)
  end
end

---@param items CometItem[]
---@return CometItem[] copy with `_idx` on each table item
local function indexed_copy(items)
  local copy = vim.deepcopy(items)
  for index, item in ipairs(copy) do
    if type(item) == "table" then
      item._idx = index
    end
  end
  return copy
end

---@param self CometCtx
---@param sub SubMenuState
---@param items CometItem[]
---@return boolean
local function update_sub(self, sub, items)
  if sub.page_key ~= self.target_page_key then
    return false
  end
  sub.all_items = indexed_copy(items)
  require("comet.filter").filter_sub(self._state.last_query)
  sub.selected = math.min(sub.selected, math.max(1, #sub.items))
  render.list()
  return true
end

---@param self CometCtx
---@param items CometCommand[]
---@return boolean
local function update_root(self, items)
  local S = self._state
  if self.target_page_key ~= S.root_title then
    return false
  end
  S.commands = vim.deepcopy(items)
  require("comet.filter").filter_commands(S.last_query)
  S.selected = math.min(S.selected, math.max(1, #S.filtered))
  render.list()
  return true
end

--- Methods copied onto each context. Each reads its session through
--- `self._state`, so a context keeps working on the session that made it.
local methods = {}

function methods.write(self, lines)
  render.out_write(self.target_buf, lines)
end

function methods.clear(self)
  render.out_clear(self.target_buf)
end

function methods.append(self, line)
  render.out_write(self.target_buf, line)
end

function methods.start_async_task(self, job_id, abort_fn)
  local S = self._state
  state.running_tasks[self.page_id] = {
    abort_fn = function()
      local abort = abort_fn or S.default_abort_fn
      abort(job_id, self)
    end,
    status = "running",
    id = job_id,
  }
  vim.schedule(render.update_output_title)
end

function methods.done(self, job_id)
  finish_task(self, job_id, "done")
end

function methods.error(self, job_id)
  finish_task(self, job_id, "error")
end

function methods.terminal(self, job_id, opts)
  opts = opts or {}
  local task = state.running_tasks[self.page_id]
  if not task then
    self:start_async_task(job_id, opts.abort_fn)
    task = state.running_tasks[self.page_id]
  end
  task.input_fn = opts.on_input
    or function(text)
      vim.fn.chansend(job_id, text .. "\n")
    end
  task.input_prompt = opts.prompt or "stdin> "
  window.focus_output()
end

function methods.set_status(self, status)
  local task = state.running_tasks[self.page_id]
  if not task then
    task = { status = status }
    state.running_tasks[self.page_id] = task
  else
    task.status = status
  end
  vim.schedule(render.update_output_title)
end

function methods.update(self, items)
  if not state.is_open() or state.get() ~= self._state then
    return false
  end
  local sub = state.current_sub()
  if self._selected_sub and sub ~= self._selected_sub then
    return false
  end
  if sub then
    return update_sub(self, sub, items)
  end
  return update_root(self, items)
end

function methods.select(self, items, opts)
  local S = self._state
  local saved = window.take_input_query()
  local all = indexed_copy(items)
  local sub_title = opts.title or "Select"

  -- Nested pages share the output buffer of the first submenu page.
  if #S.sub_stack == 0 then
    bind_page(self, self._trigger_name)
  else
    bind_page(self, S.sub_stack[1].page_key)
  end

  ---@type SubMenuState
  local selected_sub = {
    all_items = all,
    items = vim.deepcopy(all),
    selected = 1,
    on_select = opts.on_select,
    on_cancel = opts.on_cancel,
    title = sub_title,
    page_key = self.target_page_key,
    saved_query = saved,
    multi_select = opts.multi_select or false,
    marked = {},
  }
  table.insert(S.sub_stack, selected_sub)
  self._selected_sub = selected_sub

  window.switch_output_buf(self.target_page_key)
  self.target_buf = S.output_buf

  pcall(
    vim.api.nvim_win_set_config,
    S.input_win,
    { title = " " .. sub_title .. " ", title_pos = "center" }
  )
  render.list()
  window.focus_input()
end

function methods.command(self, opts)
  require("comet.command").open(self, opts)
end

--- Create a new API Context specifically bound to a page key buffer
---@param trigger_name string
---@param page_key? string
---@return CometCtx
M.make = function(trigger_name, page_key)
  local S = state.get()
  local target_page_key = page_key or S.current_page_key
  local page_id = state.page_id(S.session_id, target_page_key)

  ---@type CometCtx
  local ctx = {
    target_buf = state.output_buf_cache[page_id] or S.output_buf,
    target_page_key = target_page_key,
    page_id = page_id,
    session_id = S.session_id,
    _state = S,
    _trigger_name = trigger_name,
  }
  for name, method in pairs(methods) do
    ctx[name] = method
  end
  return ctx
end

return M
