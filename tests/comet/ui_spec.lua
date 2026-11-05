-- Drives real floating windows through comet.open and the buffer-local
-- keymaps that events.setup installs.
local comet = require("comet")
local state = require("comet.state")
local window = require("comet.ui.window")
local api = vim.api

---@param buf integer
---@param mode string
---@param lhs string
local function press(buf, mode, lhs)
  local key = api.nvim_replace_termcodes(lhs, true, true, true)
  for _, map in ipairs(api.nvim_buf_get_keymap(buf, mode)) do
    if api.nvim_replace_termcodes(map.lhs, true, true, true) == key then
      assert(map.callback, "mapping has no callback: " .. lhs)
      return map.callback()
    end
  end
  error(("no %s mapping for %s"):format(mode, lhs))
end

---@param text string
local function type_query(text)
  local S = state.get()
  api.nvim_buf_set_lines(S.input_buf, 0, -1, false, { S.prompt .. text })
  api.nvim_exec_autocmds("TextChangedI", { buffer = S.input_buf })
end

local function list_lines()
  return api.nvim_buf_get_lines(state.get().list_buf, 0, -1, false)
end

local function output_lines()
  return api.nvim_buf_get_lines(state.get().output_buf, 0, -1, false)
end

local function input_title()
  local title = api.nvim_win_get_config(state.get().input_win).title
  return vim.trim(title[1][1])
end

local commands = {
  {
    name = "Alpha build",
    action = function(ctx)
      ctx:append("alpha ran")
    end,
  },
  {
    name = "Beta pick",
    action = function(ctx)
      ctx:select({ "one", "two" }, {
        title = "Pick one",
        on_select = function(item, child)
          child:append("picked " .. item)
        end,
      })
    end,
  },
}

local opts = { session_id = "ui-spec", insert_mode = false }

describe("comet floating UI", function()
  before_each(function()
    state.persisted_states, state.running_tasks = {}, {}
    comet.open(commands, opts)
  end)

  after_each(function()
    if state.is_open() then
      window.close()
    end
  end)

  it("opens three floating windows", function()
    local S = state.get()
    for _, win in ipairs({ S.input_win, S.list_win, S.output_win }) do
      assert.is_true(api.nvim_win_is_valid(win))
      assert.are.equal("editor", api.nvim_win_get_config(win).relative)
    end
    assert.are.equal(S.input_win, api.nvim_get_current_win())
  end)

  it("filters the list from typed input", function()
    type_query("beta")
    local lines = table.concat(list_lines(), "\n")
    assert.is_truthy(lines:find("Beta pick", 1, true))
    assert.is_falsy(lines:find("Alpha build", 1, true))
  end)

  it("runs the selected action with <CR> and moves with <C-j>", function()
    local S = state.get()
    press(S.input_buf, "i", "<CR>")
    assert.are.same({ "alpha ran" }, vim.tbl_filter(function(line)
      return line ~= ""
    end, output_lines()))

    press(S.input_buf, "i", "<C-j>")
    assert.are.equal(2, state.get().selected)
  end)

  it("pops a submenu with <Esc> and then closes", function()
    local S = state.get()
    type_query("beta")
    press(S.input_buf, "n", "<CR>")
    assert.are.equal("Pick one", input_title())

    press(S.input_buf, "n", "<CR>")
    assert.is_truthy(table.concat(output_lines(), "\n"):find("picked one"))

    press(S.input_buf, "n", "<Esc>")
    assert.are.equal("ui-spec", input_title())
    assert.is_true(state.is_open())

    press(S.input_buf, "n", "q")
    assert.is_false(state.is_open())
  end)

  it("moves focus to the output panel and back", function()
    local S = state.get()
    press(S.input_buf, "n", "<C-l>")
    assert.are.equal(S.output_win, api.nvim_get_current_win())
    press(S.output_buf, "n", "<Esc>")
    assert.are.equal(S.input_win, api.nvim_get_current_win())
  end)

  it("closes when the same session opens again", function()
    comet.open(commands, opts)
    assert.is_false(state.is_open())
  end)

  it("closes when one of its windows closes", function()
    api.nvim_win_close(state.get().list_win, true)
    assert.is_true(vim.wait(1000, function()
      return not state.is_open()
    end))
  end)
end)
