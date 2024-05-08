-- local augroup = vim.api.nvim_create_augroup("MinSkk", { clear = true })

local ffi = require("ffi")

ffi.cdef[[
  size_t get_kanji(const char* buf, const size_t buf_size);
]]

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local rust_lib = ffi.load(this_file_dir .. "../minskk-core/target/debug/libminskk.dylib")

local function get_kanji()
    local buf_size = 50
    local buf = ffi.new("char[?]", buf_size)

    local num_chars = rust_lib.get_kanji(buf, buf_size)
    if num_chars > buf_size then
      buf = ffi.new("char[?]", num_chars)
      num_chars = rust_lib.get_kanji(buf, num_chars)
    end
    return ffi.string(buf, num_chars)
end

local function insert_word()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local current_buf = vim.api.nvim_get_current_buf()
    local text_to_insert = get_kanji()

    vim.api.nvim_buf_set_text(current_buf, row - 1, col, row - 1, col, { text_to_insert })
    vim.api.nvim_win_set_cursor(0, { row, col + #text_to_insert })
end

local function test()
  local n = 42
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
  insert_word = insert_word,
}

