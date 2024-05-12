local M = {
  curr_kanji_index = 1,
  prev_kanji_len = 0,
  kanji_list = {},
}

local g_common = require 'common'

local g_ffi = require 'ffi'

g_ffi.cdef[[
  size_t get_kanji(const char* buf, const size_t buf_size);
]]


function M.init(dfa)
  M.dfa = dfa
end

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local rust_lib = g_ffi.load(this_file_dir .. "../../minskk-core/target/debug/libminskk.dylib")

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

  M.kanji_list = {
    "漢字A",
    "漢字B",
    "漢字C",
  }
end

local function get_next_kanji()
  local kanji = M.kanji_list[M.curr_kanji_index]
  M.prev_kanji_len = #kanji

  M.curr_kanji_index = (M.curr_kanji_index % #M.kanji_list) + 1
  return kanji
end

local function finalize()
  g_common.remove_inverted_triangle(M.prev_kanji_len)
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_ctrl_j()
  finalize()
end

function M.handle_cr()
  finalize()
end

function M.handle_input(c)
  if c == ' ' then
    local kanji = get_next_kanji()
    g_common.delete_n_chars_before_cursor(M.prev_kanji_len, 0, kanji)
    return ''

  elseif c == ';' then
    -- select the current kanji and start entering the next word
    g_common.remove_inverted_triangle(M.prev_kanji_len)
    M.dfa.go_to_input_reading_state()
    return '▽'

  else
    return ''
  end
end

function M.enter(exit_immediately, letter)
  M.curr_kanji_index = 1
  M.prev_kanji_len = 0
  build_kanji_list()

  --g_common.alert('Select Kanji')

  local kanji = get_next_kanji()

  if exit_immediately then
    -- TODO type letter after moving to direct input kana state
    M.dfa.go_to_direct_input_kana_state(letter)
  end
  return kanji
end

return M

