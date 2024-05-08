-- local augroup = vim.api.nvim_create_augroup("MinSkk", { clear = true })

local ffi = require("ffi")

ffi.cdef[[
  int test();
]]

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local rust_lib = ffi.load(this_file_dir .. "../minskk-core/target/debug/libminskk.dylib")

local function test()
  local n = rust_lib.test()
  vim.api.nvim_create_user_command('MinSkk', function()
    vim.api.nvim_echo({{tostring(n), "Normal"}}, false, {})
  end, {})
end

local function setup()
  vim.api.nvim_create_user_command('MinSkk', 'echo "me%hello"', {})
end

local function reload()
  vim.api.nvim_create_user_command('MinSkk', 'echo "??"', {})
end

return {
  setup = setup,
  reload = reload,
  test = test,
}

