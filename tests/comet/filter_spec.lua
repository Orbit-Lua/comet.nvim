local filter = require("comet.filter")
local state = require("comet.state")

describe("comet.filter", function()
  before_each(function()
    state.clear()
    state.init({}, {}, { list_h = 10 })
  end)

  after_each(function()
    state.clear()
  end)

  it("matches sub-menu table item descriptions", function()
    local S = state.get()
    table.insert(S.sub_stack, {
      all_items = {
        { name = "Debug", desc = "symbols and tracing" },
        { name = "Release", desc = "optimized build" },
      },
      items = {},
      selected = 1,
      title = "Configuration",
      page_key = "Build",
      saved_query = "",
      multi_select = false,
      marked = {},
    })

    filter.filter_sub("optimized")

    local sub = state.current_sub()
    assert.are.equal(1, #sub.items)
    assert.are.equal("Release", sub.items[1].name)
  end)
end)
