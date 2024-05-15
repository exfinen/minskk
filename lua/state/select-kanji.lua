local M = {
  curr_candidate_index = 0,
  prev_candidate_len = 0,
  kanji_list = {},
}

local g_common = require 'common'

local g_ffi = require 'ffi'

g_ffi.cdef[[
  size_t get_kanji(const char* buf, const size_t buf_size);
]]

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local rust_lib = g_ffi.load(this_file_dir .. "../../minskk-core/target/debug/libminskk.dylib")

local function build_candidates(reading, accompanying_kana)
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

  M.candidates = {
    "漢字A",
    "漢字B",
    "漢字C",
  }
end

local function get_curr_candidate()
  return M.candidates[M.curr_candidate_index + 1]
end

local function get_next_candidate()
  M.prev_candidate_len = #get_curr_candidate()

  -- update curr_candidate index
  M.curr_candidate_index = (M.curr_candidate_index + 1) % #M.candidates

  return get_curr_candidate()
end

local function get_prev_candidate()
  M.prev_candidate_len = #get_curr_candidate()

  -- update curr_candidate index
  if M.curr_candidate_index == 0 then
    M.curr_candidate_index = #M.candidates - 1
  else
    M.curr_candidate_index = M.curr_candidate_index - 1
  end

  return get_curr_candidate()
end

local function finalize()
  g_common.remove_inverted_triangle(M.prev_candidate_len)
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_ctrl_j()
  finalize()
end

function M.handle_cr()
  finalize()
end

function M.handle_bs()
  -- show the previuos kanji candidate
  local kanji = get_prev_candidate()
  g_common.delete_n_chars_before_cursor(M.prev_candidate_len, 0, kanji)
end

function M.handle_esc()
  -- go back to the input reading state w/o accompanying_kana 
  local a = '▼' .. get_curr_candidate()
  local b = '▽' .. g_common.join_str_array(M.reading)
  g_common.delete_n_chars_before_cursor(#a, 0, b)

  M.dfa.go_to_input_reading_state({
    reading = M.reading
  })
end

function M.handle_input(c)
  if c == ' ' then
    -- show the next kanji candidate
    local kanji = get_next_candidate()
    g_common.delete_n_chars_before_cursor(M.prev_candidate_len, 0, kanji)
    return ''

  elseif c == ';' then
    -- select the current kanji and start entering the next word
    g_common.remove_inverted_triangle(M.prev_candidate_len)
    M.dfa.go_to_input_reading_state()
    return '▽'

  else
    return ''
  end
end

function M.enter(inst)
  -- TODO handle empty list case
  build_candidates(inst.reading, inst.accompanying_kana)

  M.curr_candidate_index = #M.candidates - 1 -- point to the last element in the beginning
  M.prev_candidate_len = 0

  M.reading = inst.reading
  M.accompanying_kana = inst.accompanying_kana

  g_common.alert('Select Kanji')

  return get_next_candidate()
end

return M

