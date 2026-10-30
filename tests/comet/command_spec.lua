local comet = require("comet")
local state = require("comet.state")
local action = require("comet.action")
local window = require("comet.ui.window")

describe("command-entry pages", function()
  local requests, submitted, canceled
  local function open()
    comet.open({
      {
        name = "Command Line",
        action = function(ctx)
          ctx:command({
            title = "Command Line",
            complete = function(request, callback)
              requests[#requests + 1] =
                { request = request, callback = callback }
              return function()
                canceled = canceled + 1
              end
            end,
            submit = function(text)
              submitted[#submitted + 1] = text
            end,
          })
        end,
      },
    }, { session_id = "command-test", insert_mode = false })
    action.run_selected()
  end
  local function input(text)
    local S = state.get()
    vim.api.nvim_buf_set_lines(S.input_buf, 0, -1, false, { S.prompt .. text })
    vim.api.nvim_win_set_cursor(S.input_win, { 1, #S.prompt + #text })
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = S.input_buf })
  end
  local function wait_requests(count)
    assert.is_true(vim.wait(1000, function()
      return #requests >= count
    end))
  end
  before_each(function()
    requests, submitted, canceled = {}, {}, 0
    state.persisted_states, state.running_tasks = {}, {}
    open()
  end)
  after_each(function()
    window.close()
    for _, buffer in pairs(state.output_buf_cache) do
      if vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
    state.output_buf_cache, state.persisted_states, state.running_tasks =
      {}, {}, {}
  end)

  it(
    "accepts completion with Tab behavior and submits only on Enter behavior",
    function()
      input("dotnet bui")
      wait_requests(1)
      requests[1].callback({
        { label = "build", text = "build", start = 7, finish = 10 },
      })
      assert.is_true(vim.wait(500, function()
        return #state.current_items() == 1
      end))
      action.toggle_mark()
      assert.equals(
        state.get().prompt .. "dotnet build",
        vim.api.nvim_buf_get_lines(state.get().input_buf, 0, 1, false)[1]
      )
      assert.equals(0, #submitted)
      action.run_selected()
      assert.same({ "dotnet build" }, submitted)
      assert.equals("", state.get().last_query)
    end
  )

  it(
    "rejects old results after input changes, page departure, and reopening",
    function()
      input("first")
      wait_requests(1)
      local first = requests[1]
      input("second")
      wait_requests(2)
      requests[2].callback({ { label = "new", text = "new" } })
      first.callback({ { label = "old", text = "old" } })
      assert.is_true(vim.wait(500, function()
        return #state.current_items() == 1
      end))
      assert.equals("new", state.current_items()[1].name)
      action.handle_esc()
      first.callback({ { label = "obsolete page", text = "old" } })
      window.close()
      open()
      first.callback({ { label = "obsolete session", text = "old" } })
      vim.wait(100, function()
        return false
      end)
      assert.equals(0, #state.current_items())
      assert.is_true(canceled > 0)
    end
  )

  it("does not retain command input when the panel closes", function()
    input("secret sentinel")
    window.close()
    assert.is_nil(
      vim.inspect(state.persisted_states):find("secret sentinel", 1, true)
    )
    open()
    assert.equals("", state.get().last_query)
  end)

  it("keeps existing multi-select Tab behavior", function()
    action.handle_esc()
    require("comet.context")
      .make("Select")
      :select({ "a", "b" }, { multi_select = true, on_select = function() end })
    action.toggle_mark()
    assert.is_true(state.current_sub().marked.a)
  end)

  it("keeps a running task cancelable after completion fails", function()
    local stopped = false
    state.current_sub().command_ctx:start_async_task(99, function()
      stopped = true
    end)
    input("dotnet bui")
    wait_requests(1)
    requests[1].callback({}, "fixture completion failure")
    assert.is_true(vim.wait(500, function()
      return state.current_sub().completion_error
    end))
    local page = state.current_sub().command_ctx.page_id
    assert.equals("running", state.running_tasks[page].status)
    action.run_selected()
    assert.equals(0, #submitted)
    action.stop_job()
    assert.is_true(stopped)
    assert.equals("abort", state.running_tasks[page].status)
  end)

  it("does not recover submitted input through undo", function()
    input("secret sentinel")
    action.run_selected()
    vim.api.nvim_buf_call(state.get().input_buf, function()
      vim.cmd("silent! undo")
    end)
    local text = table.concat(
      vim.api.nvim_buf_get_lines(state.get().input_buf, 0, -1, false),
      "\n"
    )
    assert.is_nil(text:find("secret sentinel", 1, true))
  end)

  it(
    "removes transient command ancestors when a child selection closes",
    function()
      state.current_sub().command.submit = function(_, ctx)
        ctx:select({ "child" }, { on_select = function() end })
      end
      input("temporary command")
      action.run_selected()
      window.close()
      assert.equals(0, #state.persisted_states["command-test"].sub_stack)
      assert.is_nil(
        vim.inspect(state.persisted_states):find("temporary command", 1, true)
      )
    end
  )
end)
