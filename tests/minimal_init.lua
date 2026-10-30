local plenary = vim.env.COMET_TEST_PLENARY
  or (vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
assert(vim.fn.isdirectory(plenary) == 1, "Plenary is required: " .. plenary)
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.g.comet_test_root = root
for _, name in ipairs({ "CONFIG", "DATA", "STATE", "CACHE" }) do
  vim.env["XDG_" .. name .. "_HOME"] = root .. "/" .. name:lower()
end
vim.env.NVIM_LOG_FILE = root .. "/nvim.log"
vim.o.shadafile = "NONE"
vim.o.swapfile = false
vim.opt.runtimepath = { vim.fn.getcwd(), vim.env.VIMRUNTIME, plenary }
vim.opt.packpath = {}
package.path = vim.fn.getcwd() .. "/?.lua;" .. package.path
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    vim.fn.delete(root, "rf")
  end,
})
vim.cmd("runtime plugin/plenary.vim")
