local M = {}

---@type CometOpts
M.defaults = {
  session_id = "Comet",
  -- root_title is optional and will default to session_id if not provided
  insert_mode = true,
  block_while_running = true,
  remember_page = true,
  show_icons = true,
  default_icon = nil,
}

--- Lua type of each accepted option. `root_title` and `default_icon` default
--- to nil, so the defaults table cannot supply their types.
---@type table<string, type>
local shape = {
  session_id = "string",
  root_title = "string",
  insert_mode = "boolean",
  block_while_running = "boolean",
  remember_page = "boolean",
  show_icons = "boolean",
  default_icon = "string",
}

---@type CometOpts
M.values = vim.deepcopy(M.defaults)

--- Raise an error that names the first unknown key or wrong type.
---@param opts any
M.validate = function(opts)
  if opts == nil then
    return
  end
  if type(opts) ~= "table" then
    error(("comet: opts: expected table, got %s"):format(type(opts)), 0)
  end

  for key, value in pairs(opts) do
    local expected = shape[key]
    if expected == nil then
      error(("comet: opts.%s: unknown option"):format(tostring(key)), 0)
    end
    if type(value) ~= expected then
      local message = "comet: opts.%s: expected %s, got %s"
      error(message:format(key, expected, type(value)), 0)
    end
  end
end

--- Set global default options. Invalid options leave the previous values.
---@param opts? CometOpts
M.setup = function(opts)
  M.validate(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

--- Merge validated incoming options with the global defaults.
---@param opts? CometOpts
---@return CometOpts
M.resolve = function(opts)
  M.validate(opts)
  -- If `open` is called with local opts, override the global `M.values`
  return vim.tbl_deep_extend("force", vim.deepcopy(M.values), opts or {})
end

return M
