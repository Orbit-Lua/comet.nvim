local config = require("comet.config")

describe("comet.config", function()
  before_each(function()
    -- Reset to pristine defaults before each test
    config.setup({})
  end)

  it("has sensible defaults", function()
    local cfg = config.resolve()
    assert.are.equal("Comet", cfg.session_id)
    assert.is_true(cfg.insert_mode)
    assert.is_true(cfg.remember_page)
    assert.is_true(cfg.show_icons)
  end)

  it("merges user options in global setup", function()
    config.setup({
      insert_mode = true,
      session_id = "Global Tasks",
    })

    local cfg = config.resolve()
    assert.is_true(cfg.insert_mode)
    assert.are.equal("Global Tasks", cfg.session_id)
    assert.is_true(cfg.remember_page) -- Keeps default
  end)

  it("overrides global defaults when local opts are passed to open()", function()
    -- Global setup
    config.setup({
      insert_mode = true,
      session_id = "Global Tasks",
    })

    -- Local override (simulating what happens inside M.open(commands, opts))
    local cfg = config.resolve({ session_id = "Local Override", remember_page = false })

    assert.is_true(cfg.insert_mode) -- Falls back to global setup
    assert.are.equal("Local Override", cfg.session_id) -- Overridden by local opts
    assert.is_false(cfg.remember_page) -- Overridden by local opts
  end)
end)

describe("comet option validation", function()
  local comet = require("comet")
  local state = require("comet.state")
  local window = require("comet.ui.window")

  local commands = {
    { name = "Noop", action = function() end },
  }

  local function error_of(fn)
    local ok, err = pcall(fn)
    assert.is_false(ok)
    return err
  end

  after_each(function()
    if state.is_open() then
      window.close()
    end
    config.setup()
  end)

  it("accepts no options, empty options and the dotnet-cli options", function()
    config.setup()
    config.setup({})
    local cfg = config.resolve({
      session_id = "dotnet_manager:/repo",
      root_title = "Dotnet Manager",
      default_icon = "x ",
      insert_mode = false,
    })
    assert.are.equal("Dotnet Manager", cfg.root_title)
  end)

  it("names an unknown key and a wrong type", function()
    assert.are.equal(
      "comet: opts.show_icon: unknown option",
      error_of(function()
        config.setup({ show_icon = true })
      end)
    )
    assert.are.equal(
      "comet: opts.remember_page: expected boolean, got string",
      error_of(function()
        comet.setup({ remember_page = "yes" })
      end)
    )
    assert.are.equal(
      "comet: opts: expected table, got string",
      error_of(function()
        config.setup("Comet")
      end)
    )
  end)

  it("keeps the previous values after a rejected setup", function()
    config.setup({ session_id = "Kept" })
    error_of(function()
      config.setup({ session_id = "Lost", insert_mode = 1 })
    end)
    assert.are.equal("Kept", config.resolve().session_id)
  end)

  it("opens no window for rejected open options", function()
    local before = #vim.api.nvim_list_wins()
    error_of(function()
      comet.open(commands, { session_id = "A", bogus = true })
    end)
    assert.is_false(state.is_open())
    assert.are.equal(before, #vim.api.nvim_list_wins())
  end)

  it("leaves an open palette as it was after rejected open options", function()
    comet.open(commands, { session_id = "A", insert_mode = false })
    local wins = #vim.api.nvim_list_wins()
    error_of(function()
      comet.open(commands, { session_id = "B", show_icons = "no" })
    end)
    assert.is_true(state.is_open())
    assert.are.equal("A", state.get().session_id)
    assert.are.equal(wins, #vim.api.nvim_list_wins())
  end)
end)
