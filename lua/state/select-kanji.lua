local M = {
  curr_candidate_index = 0,
  candidates = {},
}

local g_common = require 'common'

local g_ffi = require 'ffi'

g_ffi.cdef[[
  int build(const char* dict_file_path);
  void look_up(char** chars, char ac_kana, const size_t num_chars);
  void get_results(char** results, const size_t buf_size, const size_t offset, size_t* num_results);
]]

local file_dir = debug.getinfo(1, 'S').source:match("@?(.*/)")

local lib_ext
if g_ffi.os == 'OSX' then
  lib_ext = 'dylib'
elseif g_ffi.os == 'Linux' or g_ffi.os == 'POSIX' then
  lib_ext = 'so'
else
  error(g_ffi.os .. ' is not supported')
end

local g_dict = g_ffi.load(file_dir .. '../../rust/target/release/libminskk.' .. lib_ext)

function M.build_dict(dict_file_path)
  local ffi_dict_file_path = g_ffi.new('char[?]', #dict_file_path + 1)
  g_ffi.copy(ffi_dict_file_path, dict_file_path, #dict_file_path)

  local res = g_dict.build(ffi_dict_file_path)

  if res ~= 0 then
    local msg = 'MinSKK: '

    if res == 1 then
      msg = msg .. dict_file_path .. ' not found'
    elseif res == 2 then
      msg = msg .. dict_file_path .. ' is malformed'
    else
      error('should not be visited. check code (select-kanji 1)')
    end
    M.util.status.show_alert(msg, 5000)
  end
end

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

local function look_up(reading, ac_kana_letter, ac_kana_first_char)
  local chars = g_ffi.new("char*[?]", #reading)

  for i = 1, #reading do
      -- + 1 for null termination. no need to set 0 since luajit zero-fills the array
      chars[i-1] = g_ffi.new("char[?]", #reading[i] + 1)
      g_ffi.copy(chars[i-1], reading[i])
  end

  local ac_kana = g_ffi.new("char[1]", ac_kana_first_char:byte())
  g_dict.look_up(chars, ac_kana[0], #reading)

  local buf_size = 50
  local offset = 0
  local num_bufs = 10
  local num_results = g_ffi.new("size_t[1]", num_bufs)

  local results = g_ffi.new("char*[?]", num_bufs)
  for i = 1, num_bufs do
      results[i-1] = g_ffi.new("char[?]", buf_size)
  end

  g_dict.get_results(
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

local function remove_inverted_triangle()
  local following_chars_len = #get_curr_candidate()
  g_common.delete_n_chars_before_cursor(#'▼', following_chars_len)
end

local function get_next_candidate()
  -- update curr_candidate index
  M.curr_candidate_index = (M.curr_candidate_index + 1) % #M.candidates

  return get_curr_candidate()
end

local function get_prev_candidate()
  -- update curr_candidate index
  if M.curr_candidate_index == 0 then
    M.curr_candidate_index = #M.candidates - 1
  else
    M.curr_candidate_index = M.curr_candidate_index - 1
  end

  return get_curr_candidate()
end

function M.handle_ctrl_j()
  remove_inverted_triangle()
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_cr()
  remove_inverted_triangle()
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_bs()
  -- show the previuos kanji candidate
  local candidate = get_prev_candidate()
  g_common.delete_n_chars_before_cursor(#get_curr_candidate(), 0, candidate)
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
    -- show the next candidate
    local curr_candidate_len = #get_curr_candidate()
    local candidate = get_next_candidate()
    g_common.delete_n_chars_before_cursor(curr_candidate_len, 0, candidate)
    return ''

  elseif c == ';' then
    -- select the current candidate
    remove_inverted_triangle()

    -- start entering the next readings
    M.dfa.go_to_input_reading_state()
    return '▽'

  else
    remove_inverted_triangle()
    M.dfa.go_to_direct_input_kana_state()
    vim.api.nvim_feedkeys(c, "in", true)
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
  M.reading = inst.reading

  M.util.set_dfa_state(M.util.DFAState.SelectKanji)

  return get_next_candidate()
end

return M

