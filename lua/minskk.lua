local M = {}

local g_kana_tree = require 'kana-tree-logic'
local g_ffi = require 'ffi'

local g_is_enabled = false
local g_curr_skk_mode = nil

local SkkMode = {
  LowerCase = 1,
  Kana = 2,
}

g_ffi.cdef[[
  size_t get_kanji(const char* buf, const size_t buf_size);
]]

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local rust_lib = g_ffi.load(this_file_dir .. "../minskk-core/target/debug/libminskk.dylib")

function M.get_kanji()
    local buf_size = 50
    local buf = g_ffi.new("char[?]", buf_size)

    local num_chars = rust_lib.get_kanji(buf, buf_size)
    if num_chars > buf_size then
      buf = g_ffi.new("char[?]", num_chars)
      num_chars = rust_lib.get_kanji(buf, num_chars)
    end
    return g_ffi.string(buf, num_chars)
end

function M.insert_word()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local current_buf = vim.api.nvim_get_current_buf()
  local text_to_insert = M.get_kanji()

  vim.api.nvim_buf_set_text(current_buf, row - 1, col, row - 1, col, { text_to_insert })
  vim.api.nvim_win_set_cursor(0, { row, col + #text_to_insert })
end

function M.test()
  local n = 12345
  vim.api.nvim_create_user_command('MinSkk', function()
    vim.api.nvim_echo({{tostring(n), "Normal"}}, false, {})
  end, {})
end

function M.alert(message)
  vim.schedule(function ()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { message })

    local width = math.max(20, #message + 4)
    local height = 1
    local opts = {
      style = "minimal",
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = "single",
      noautocmd = false,
    }
    local win = vim.api.nvim_open_win(buf, false, opts)

    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, 1000)
  end)
end

function M.go_to_lowercase_mode()
  g_curr_skk_mode = SkkMode.LowerCase
  M.alert("Lowercase")
end

function M.go_to_kana_mode()
  g_curr_skk_mode = SkkMode.Kana

  -- reset the kana tree
  g_kana_tree.go_to_root()
  g_kana_tree.set_hiragana()

  M.alert("ひらがな")
end

function M.input_filter(c)
  if g_curr_skk_mode == SkkMode.Kana then
    local res = g_kana_tree.traverse(c)

    if res["type"] == g_kana_tree.TraverseResult.Letter then
      return res["value"]

    elseif res["type"] == g_kana_tree.TraverseResult.ToLowerCase then
      M.go_to_lowercase_mode()

    elseif res["type"] == g_kana_tree.TraverseResult.ToKatakana then
      g_kana_tree.set_katakana()
      M.alert("かたかな")

    elseif res["type"] == g_kana_tree.TraverseResult.None then
    end

  elseif g_curr_skk_mode == SkkMode.LowerCase then
    return c
  end

  return ""
end

function M.on_key_press(key)
  if vim.fn.mode() ~= "i" then
    return
  end

  if key == vim.api.nvim_replace_termcodes("<Esc>", true, false, true) then
    M.turn_off()
    return
  end
end

function M.turn_on()
  if g_is_enabled then
    M.go_to_kana_mode()
    return
  else
    g_is_enabled = true
    M.go_to_lowercase_mode()
  end
end

function M.turn_off()
  g_is_enabled = false
  M.alert("Turned Off")
end

function M.handle_ctrl_j()
  M.go_to_kana_mode()
end

function M.setup()
  vim.api.nvim_set_keymap("n", "<C-j>", "<ESC>:MinSKKTurnOn<CR>", {})
  vim.keymap.set("i", "<C-j>", function() M.handle_ctrl_j() end, {})

  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    callback = M.turn_on,
  })

  vim.api.nvim_create_autocmd("InsertCharPre", {
    pattern = "*",
    callback = function()
      if g_is_enabled then
        vim.v.char = M.input_filter(vim.v.char)
      end
    end,
  })

  local ns_id = vim.api.nvim_create_namespace("minskk_namespace")
  vim.on_key(M.on_key_press, ns_id)

  g_kana_tree.init()
end

vim.cmd [[
  command! MinSKKTurnOn lua require 'minskk'.turn_on()
]]

return M

