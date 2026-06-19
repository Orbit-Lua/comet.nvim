local action = require("comet.action")
local state = require("comet.state")

describe("comet.action", function()
  before_each(function()
    state.clear()
    state.output_buf_cache = {}
    state.running_tasks = {}
    state.init({}, {}, { list_h = 5 })

    local S = state.get()
    S.list_buf = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    state.clear()
    state.output_buf_cache = {}
    state.running_tasks = {}
  end)

  it("keeps multi-select sub-menu active and writes to its output buffer", function()
    local callback_page_key
    local callback_items

    local S = state.get()
    table.insert(S.sub_stack, {
      all_items = { "Debug", "Release" },
      items = { "Debug", "Release" },
      selected = 2,
      title = "Configuration",
      page_key = "Build",
      saved_query = "rel",
      multi_select = true,
      marked = { Debug = true, Release = true },
      on_select = function(items, ctx)
        callback_items = items
        callback_page_key = ctx.target_page_key
        ctx:write("Selected " .. table.concat(items, ","))
      end,
    })

    action.run_selected()

    assert.are.equal(1, #S.sub_stack)
    assert.are.equal("Configuration", state.current_sub().title)
    assert.are.equal("Build", S.current_page_key)
    assert.are.equal("Build", callback_page_key)
    assert.are.same({ "Debug", "Release" }, callback_items)

    local output_buf = state.output_buf_cache.Build
    assert.is_true(vim.api.nvim_buf_is_valid(output_buf))
    assert.are.same(
      { "Selected Debug,Release" },
      vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
    )
  end)
end)
