local context = require("comet.context")
local state = require("comet.state")

describe("comet.context", function()
  before_each(function()
    state.clear()
    state.output_buf_cache = {}
    state.running_tasks = {}
  end)

  after_each(function()
    state.clear()
    state.output_buf_cache = {}
    state.running_tasks = {}
  end)

  it("isolates task identities by session and page", function()
    state.init({}, { session_id = "first" }, { list_h = 5 })
    local first = context.make("Build")
    first:start_async_task(10)

    state.init({}, { session_id = "second" }, { list_h = 5 })
    local second = context.make("Build")
    second:start_async_task(20)

    assert.are_not.equal(first.page_id, second.page_id)
    assert.are.equal("first", first.session_id)
    assert.are.equal("second", second.session_id)
    assert.are.equal(10, state.running_tasks[first.page_id].id)
    assert.are.equal(20, state.running_tasks[second.page_id].id)
  end)

  it("attaches an input handler to the page task", function()
    state.init({}, {}, { list_h = 5 })
    local ctx = context.make("Watch")
    local received

    ctx:start_async_task(42)
    ctx:terminal(42, {
      on_input = function(text)
        received = text
      end,
    })
    state.running_tasks[ctx.page_id].input_fn("continue")

    assert.are.equal("continue", received)
  end)

  it("updates the active command list and task status", function()
    state.init({}, {}, { list_h = 5 })
    local ctx = context.make("Commands")
    ctx:update({ { name = "Reloaded", action = function() end } })
    ctx:set_status("running")

    assert.are.equal("Reloaded", state.get().commands[1].name)
    assert.are.equal("running", state.running_tasks[ctx.page_id].status)
  end)

  it("ignores an update from a picker that is no longer visible", function()
    state.init({ { name = "Root" } }, {}, { list_h = 5 })
    local ctx = context.make("Build")
    local old = { page_key = "Build", items = {}, all_items = {}, selected = 1 }
    local current = { page_key = "Build", items = {}, all_items = {}, selected = 1 }
    ctx._selected_sub = old
    table.insert(state.get().sub_stack, current)
    assert.is_false(ctx:update({ { name = "Stale" } }))
    assert.are.same({}, current.all_items)
  end)

  it("does not let an old or aborted job change the current task status", function()
    state.init({}, {}, { list_h = 5 })
    local ctx = context.make("Run")
    ctx:start_async_task(1)
    state.running_tasks[ctx.page_id].status = "abort"
    ctx:error(1)
    assert.are.equal("abort", state.running_tasks[ctx.page_id].status)

    ctx:start_async_task(2)
    ctx:done(1)
    ctx:error(1)
    assert.are.equal("running", state.running_tasks[ctx.page_id].status)
    ctx:done(2)
    assert.are.equal("done", state.running_tasks[ctx.page_id].status)
  end)
end)
