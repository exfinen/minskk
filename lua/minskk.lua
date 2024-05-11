local M = {}

local SkkMode = {
  LowerCase = 1,
  Kana = 2,
}

local KanaMode = {
  DirectInput = 1,
  InputReading = 2, -- ▽
  InputAccompanyingKana = 3, -- ▼
  SelectKanji = 4, -- ▼
}

local g_kana_tree = require 'kana-tree-logic'
local g_ffi = require 'ffi'

local g_is_enabled = false
local g_curr_skk_mode = nil
local g_curr_kana_mode = nil
local g_reading = ''
local g_accompaying_kana = ''

local g_curr_kanji_index = 1
local g_prev_kanji_len = 0
local g_kanji_list = {}

g_ffi.cdef[[
  size_t get_kanji(const char* buf, const size_t buf_size);
]]

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local rust_lib = g_ffi.load(this_file_dir .. "../minskk-core/target/debug/libminskk.dylib")

local function build_kanji_list()
  -- call rust function w/ reading and accompanying kane to get the list
  --[[
    local buf_size = 50
    local buf = g_ffi.new("char[?]", buf_size)

    local num_chars = rust_lib.get_kanji(buf, buf_size)
    if num_chars > buf_size then
      buf = g_ffi.new("char[?]", num_chars)
      num_chars = rust_lib.get_kanji(buf, num_chars)
    end
    return g_ffi.string(buf, num_chars)
  ]]

  -- clear reading and accopanying kana
  g_reading = ''
  g_accompaying_kana = ''

  g_kanji_list = {
    "漢字A",
    "漢字B",
    "漢字C",
  }
end

local function get_next_kanji()
  local kanji = g_kanji_list[g_curr_kanji_index]
  g_prev_kanji_len = #kanji

  g_curr_kanji_index = (g_curr_kanji_index % #g_kanji_list) + 1
  return kanji
end

local function insert_word()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local current_buf = vim.api.nvim_get_current_buf()
  local text_to_insert = M.get_kanji()

  vim.api.nvim_buf_set_text(current_buf, row - 1, col, row - 1, col, { text_to_insert })
  vim.api.nvim_win_set_cursor(0, { row, col + #text_to_insert })
end

local function alert(message)
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
    end, 3000)
  end)
end

local function go_to_lowercase_mode()
  g_curr_skk_mode = SkkMode.LowerCase
  alert("Lowercase")
end

local function go_to_kana_mode()
  g_curr_skk_mode = SkkMode.Kana
  g_curr_kana_mode = KanaMode.DirectInput

  -- reset the kana tree
  g_kana_tree.go_to_root()
  g_kana_tree.set_hiragana()

  alert("ひらがな")
end

local function delete_chars_before_cursor(n, offset)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.schedule(function()
    vim.api.nvim_buf_set_text(
      0,
      row - 1, col - n - (offset or 0),
      row - 1, col - (offset or 0),
      {}
    )
  end)
end

local function go_to_select_kanji_mode_and_return_first_kanji()
  -- delete ▽ + reading
  local reading_len = #g_reading
  if g_accompaying_kana ~= '' then
    reading_len = reading_len + #'*' + #g_accompaying_kana
  end
  delete_chars_before_cursor(#'▽' + reading_len)

  alert("Select Kanji " .. g_reading .. ' ' .. tostring(#g_reading))

  build_kanji_list()
  g_curr_kanji_index = 1
  g_curr_kana_mode = KanaMode.SelectKanji

  local kanji = get_next_kanji()
  return '▼' .. kanji
end

local function remove_kanji_selection_marker()
  delete_chars_before_cursor(#'▼', g_prev_kanji_len)
end

local function handle_space()
  if g_curr_kana_mode == KanaMode.DirectInput then
    return ' '

  elseif g_curr_kana_mode == KanaMode.InputReading then
    -- start selecting kanji matching the entered reading
    return go_to_select_kanji_mode_and_return_first_kanji()

  elseif g_curr_kana_mode == KanaMode.InputAccompanyingKana then
    -- accompanying kana was not entered 
    -- start selecting kanji matching the entered reading
    return go_to_select_kanji_mode_and_return_first_kanji()

  elseif g_curr_kana_mode == KanaMode.SelectKanji then
    -- delete previously displayed kanji
    delete_chars_before_cursor(g_prev_kanji_len)

    -- return the next kanji
    return get_next_kanji()
  else
    error('should not be visited. check code (5)')
  end
end

local function handle_sticky_shift()
  if g_curr_kana_mode == KanaMode.DirectInput then
    -- start entering reading
    g_curr_kana_mode = KanaMode.InputReading
    alert("Input Reading")
    return '▽'

  elseif g_curr_kana_mode == KanaMode.InputReading then
    -- if currently entering reading, finalize the reading of kanji
    -- and start entering accompanying kana
    g_curr_kana_mode = KanaMode.InputAccompanyingKana
    alert("Input Accompanying Kana")
    -- should replace ▽ with ▼
    return '*'

  elseif g_curr_kana_mode == KanaMode.InputAccompanyingKana then
    -- should allow only 1 kana to enter
    -- finalize the kanji and start entering the next word
    remove_kanji_selection_marker()
    g_curr_kana_mode = KanaMode.InputReading
    alert("Input Reading")
    return '▽'

  elseif g_curr_kana_mode == KanaMode.SelectKanji then
    -- finalize the kanji and start entering the next word
    remove_kanji_selection_marker()
    g_curr_kana_mode = KanaMode.InputReading
    alert("Input Reading")
    return '▽'
  else
    error('should not be visited. check code (6)')
  end
end

local function reading_buf_filter(letter)
  if g_curr_kana_mode == KanaMode.DirectInput then
    return letter

  elseif g_curr_kana_mode == KanaMode.InputReading then
    g_reading = g_reading .. letter
    return letter

  elseif g_curr_kana_mode == KanaMode.InputAccompanyingKana then
    -- only one letter can be in g_accompanying_kana
    if g_accompaying_kana == '' then
      -- accompanying kana is set. start selecting kanji
      g_accompaying_kana = letter
      return go_to_select_kanji_mode_and_return_first_kanji()

    else
      -- accompanying kana has already be given
      -- finalize kanji and treat the letter as direct input
      remove_kanji_selection_marker()
      g_curr_kana_mode = KanaMode.DirectInput
      alert("Direct Input")
      return letter
    end

  elseif g_curr_kana_mode == KanaMode.SelectKanji then
    -- finalize kanji and treat the letter as direct input
    remove_kanji_selection_marker()
    g_curr_kana_mode = KanaMode.DirectInput
    alert("Direct Input")
    return letter

  else
    error('should not be visited. check code (6)')
  end
end

local function input_filter(c)
  if g_curr_skk_mode == SkkMode.LowerCase then
    -- no processing is needed. return what is typed
    return c

  elseif g_curr_skk_mode == SkkMode.Kana then
    if c == ' ' then
      return handle_space()

    elseif c == 'l' then
      go_to_lowercase_mode()
      return ''

    elseif c == 'q' then
      g_kana_tree.set_katakana()
      alert("カタカナ")
      return ''

    elseif c == ';' then
      return handle_sticky_shift()

    else
      local res = g_kana_tree.traverse(c)

      if res["type"] == g_kana_tree.TraverseResult.GotLetter then
        local depth = res["depth"]
        local letter = res["value"]

        delete_chars_before_cursor(depth - 1)
        letter = reading_buf_filter(letter)

        return letter

      elseif res["type"] == g_kana_tree.TraverseResult.MovedNext then
        -- show intermediate conversion process
        return c

      elseif res["type"] == g_kana_tree.TraverseResult.Failed then
        local depth = res["depth"]
        -- ignore if the char is not the beginning of any valid path
        if depth == 0 then
          return ''
        else
          -- otherwise, delete the chars typed so far
          delete_chars_before_cursor(depth)
          -- and start traversing again from the root
          g_kana_tree.go_to_root()
          return input_filter(c)
        end
      else
        error('should not be visited. check code (3)')
      end
    end
  else
    error('should not be visited. check code (4)')
  end
end

function M.turn_on()
  if g_is_enabled then
    go_to_kana_mode()
    return
  else
    g_is_enabled = true
    go_to_lowercase_mode()
  end
end

local function turn_off()
  g_is_enabled = false
  alert("Turned Off")
end

local function on_key_press(key)
  if vim.fn.mode() ~= "i" then
    return
  end

  if key == vim.api.nvim_replace_termcodes("<Esc>", true, false, true) then
    turn_off()
    return
  end
end

local function handle_ctrl_j()
  if g_curr_kana_mode == KanaMode.SelectKanji then
    remove_kanji_selection_marker()
  end
  go_to_kana_mode()
end

function M.setup()
  vim.api.nvim_set_keymap("n", "<C-j>", "<ESC>:MinSKKTurnOn<CR>", {})
  vim.keymap.set("i", "<C-j>", function() handle_ctrl_j() end, {})

  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    callback = M.turn_on,
  })

  vim.api.nvim_create_autocmd("InsertCharPre", {
    pattern = "*",
    callback = function()
      if g_is_enabled then
        vim.v.char = input_filter(vim.v.char)
      end
    end,
  })

  local ns_id = vim.api.nvim_create_namespace("minskk_namespace")
  vim.on_key(on_key_press, ns_id)

  g_kana_tree.init()
end

vim.cmd [[
  command! MinSKKTurnOn lua require 'minskk'.turn_on()
]]

return M

