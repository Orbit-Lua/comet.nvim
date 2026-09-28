local render = require("comet.ui.render")
local state = require("comet.state")

describe("comet list icons", function()
  local buffer

  after_each(function()
    state.clear()
    if buffer and vim.api.nvim_buf_is_valid(buffer) then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
  end)

  it("uses the session fallback for iconless table and string items", function()
    state.init({
      { name = "Plain" },
      "String",
      { name = "Explicit", icon = "X" },
    }, { default_icon = "D" }, { list_h = 3 })
    buffer = vim.api.nvim_create_buf(false, true)
    state.get().list_buf = buffer
    render.list()
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    assert.are.same({ "  D  Plain", "  D  String", "  X  Explicit" }, lines)
  end)
end)
