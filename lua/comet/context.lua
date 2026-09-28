-- The Command Context Builder

---@class CometCtx
---@field target_buf integer
---@field target_page_key string
---@field page_id string
---@field session_id string
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

---@class CometSelectOpts
---@field title? string
---@field multi_select? boolean
---@field on_select fun(item_or_items: any, ctx: CometCtx)
---@field on_cancel? fun()

local render = require("comet.ui.render")
local state = require("comet.state")
local window = require("comet.ui.window")
local M = {}

--- Create a new API Context specifically bound to a page key buffer
---@param trigger_name string
---@param page_key? string
---@return CometCtx
M.make = function(trigger_name, page_key)
  local S = state.get()
  local target_page_key = page_key or S.current_page_key
  local session_id = S.session_id
  local page_id = state.page_id(session_id, target_page_key)
  local target_buf = state.output_buf_cache[page_id] or S.output_buf

  local function bind_page(self, next_page_key)
    self.target_page_key = next_page_key
    self.page_id = state.page_id(session_id, next_page_key)
    self.target_buf = state.output_buf_cache[self.page_id] or S.output_buf
  end

  ---@type CometCtx
  local ctx = {
    target_buf = target_buf,
    target_page_key = target_page_key,
    page_id = page_id,
    session_id = session_id,

    write = function(self, lines)
      render.out_write(self.target_buf, lines)
    end,
    clear = function(self)
      render.out_clear(self.target_buf)
    end,
    append = function(self, line)
      render.out_write(self.target_buf, line)
    end,

    start_async_task = function(self, job_id, abort_fn)
      state.running_tasks[self.page_id] = {
        abort_fn = function()
          local abort = abort_fn or S.default_abort_fn
          abort(job_id, self)
        end,
        status = "running",
        id = job_id,
      }
      vim.schedule(render.update_output_title)
    end,

    done = function(self, job_id)
      local task = state.running_tasks[self.page_id]
      if
        task
        and (not job_id or task.id == job_id)
        and task.status ~= "abort"
      then
        task.status = "done"
        vim.schedule(render.update_output_title)
      end
    end,

    error = function(self, job_id)
      local task = state.running_tasks[self.page_id]
      if
        task
        and (not job_id or task.id == job_id)
        and task.status ~= "abort"
      then
        task.status = "error"
        vim.schedule(render.update_output_title)
      end
    end,

    terminal = function(self, job_id, opts)
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
    end,

    set_status = function(self, status)
      local task = state.running_tasks[self.page_id]
      if not task then
        task = { status = status }
        state.running_tasks[self.page_id] = task
      else
        task.status = status
      end
      vim.schedule(render.update_output_title)
    end,

    update = function(self, items)
      if not state.is_open() or state.get() ~= S then
        return false
      end
      local sub = state.current_sub()
      if self._selected_sub and sub ~= self._selected_sub then
        return false
      end
      if sub then
        if sub.page_key ~= self.target_page_key then
          return false
        end
        sub.all_items = vim.deepcopy(items)
        for i, item in ipairs(sub.all_items) do
          if type(item) == "table" then
            item._idx = i
          end
        end
        local filter = require("comet.filter")
        filter.filter_sub(S.last_query)
        sub.selected = math.min(sub.selected, math.max(1, #sub.items))
        render.list()
      else
        if self.target_page_key ~= S.root_title then
          return false
        end
        S.commands = vim.deepcopy(items)
        require("comet.filter").filter_commands(S.last_query)
        S.selected = math.min(S.selected, math.max(1, #S.filtered))
        render.list()
      end
      return true
    end,

    select = function(self, items, opts)
      local saved = window.take_input_query()
      local all = vim.deepcopy(items)
      for i, it in ipairs(all) do
        if type(it) == "table" then
          it._idx = i
        end
      end

      local sub_title = opts.title or "Select"

      -- Routing Logic: Determine which cache buffer we use for nested contexts
      if #S.sub_stack == 0 then
        bind_page(self, trigger_name)
      else
        bind_page(self, S.sub_stack[1].page_key)
      end

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
    end,
  }

  return ctx
end

return M
