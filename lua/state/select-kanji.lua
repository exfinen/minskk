local M = {
  curr_candidate_index = 0,
  prev_candidate_len = 0,
  candidates = {},
}

local g_common = require 'common'

local g_ffi = require 'ffi'

g_ffi.cdef[[
  void look_up(char** chars, char ac_kana, const size_t num_chars);
  void get_results(char** results, const size_t buf_size, const size_t offset, size_t* num_results);
]]

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

local this_file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")
local dict_lib = g_ffi.load(this_file_dir .. "../../rust/target/debug/libminskk.dylib")

local function look_up(reading, ac_kana_letter, ac_kana_first_char)
  local chars = g_ffi.new("char*[?]", #reading)

  for i = 1, #reading do
      -- + 1 for null termination. no need to set 0 since luajit zero-fills the array
      chars[i-1] = g_ffi.new("char[?]", #reading[i] + 1)
      g_ffi.copy(chars[i-1], reading[i])
  end

  local ac_kana = g_ffi.new("char[1]", ac_kana_first_char:byte())
  dict_lib.look_up(chars, ac_kana[0], #reading)

  local buf_size = 50
  local offset = 0
  local num_bufs = 10
  local num_results = g_ffi.new("size_t[1]", num_bufs)

  local results = g_ffi.new("char*[?]", num_bufs)
  for i = 1, num_bufs do
      results[i-1] = g_ffi.new("char[?]", buf_size)
  end

  dict_lib.get_results(
    results,
    buf_size,
    offset,
    num_results
  );

  M.candidates = {};

  for i = 1, tonumber(num_results[0]) do
    local candidate = g_ffi.string(results[i-1])
    table.insert(M.candidates, candidate .. ac_kana_letter)
  end
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
  -- go back to the input reading state w/o ac_kana 
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
    -- select the current candidate
    g_common.remove_inverted_triangle(M.prev_candidate_len)

    -- start entering the next readings
    M.dfa.go_to_input_reading_state()
    return '▽'

  else
    -- select the current candidate
    g_common.remove_inverted_triangle(M.prev_candidate_len)

    -- start entering kana directly
    M.dfa.go_to_direct_input_kana_state()
    return ''
  end
end

-- returns the first candidate to display
-- or returns nil and goes back to input reading state
-- in case no candidate is found
function M.enter(inst)
  look_up(
    inst.reading,
    inst.ac_kana_letter,
    inst.ac_kana_first_char
  )
  if #M.candidates == 0 then
    -- TODO support word registration
    M.dfa.go_to_input_reading_state(inst)
    return nil
  end

  M.curr_candidate_index = #M.candidates - 1 -- point to the last element in the beginning
  M.prev_candidate_len = 0
  M.reading = inst.reading

  M.util.set_dfa_state(M.util.DFAState.SelectKanji)

  return get_next_candidate()
end

return M

