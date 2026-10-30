package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
local validate = require("tests.validate")
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local ok, err = pcall(function()
  local pattern = arg[1] or "tests/comet"
  local files = pattern:match("%.lua$") and { pattern }
    or vim.fn.glob(pattern .. "/*_spec.lua", false, true)
  assert(#files > 0, "No specs found: " .. pattern)
  for i, file in ipairs(files) do
    local completion = root .. "/" .. i .. ".json"
    local result = vim
      .system({
        vim.v.progpath,
        "--headless",
        "--noplugin",
        "-i",
        "NONE",
        "-u",
        "tests/minimal_init.lua",
        "-l",
        "tests/spec.lua",
        file,
        completion,
      }, { text = true })
      :wait(60000)
    io.stdout:write(result.stdout or "")
    io.stderr:write(result.stderr or "")
    assert(result.code == 0, file .. ": failed or timed out")
    assert(
      vim.fn.filereadable(completion) == 1,
      file .. ": missing executed result"
    )
    validate.check(
      vim.json.decode(table.concat(vim.fn.readfile(completion), "\n"))
    )
  end
end)
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
