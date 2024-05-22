local M = {
  curr_input_mode = nil,
  reading = {},
  ac_kana_first_char = nil,
}

local g_kana_tree = require 'state/kana-tree/logic'
local g_katakana_conv = require 'state/conv-map/katakana'
local g_common = require 'common'

local InputMode = {
  Reading = 1,
  AcKana = 2,
}

function M.init(dfa, util)
  g_kana_tree.init()
  M.dfa = dfa
  M.util = util
end

function M.go_to_ac_kana_mode()
  M.curr_input_mode = InputMode.AcKana
end

local function remove_inverted_triangle(following_chars_len)
  g_common.delete_n_chars_before_cursor(#'▽', following_chars_len)
end

local function get_reading_len()
  local reading_len = 0
  for _, c in ipairs(M.reading) do
    reading_len = reading_len + #c
  end
  return reading_len
end

local function handle_sticky_shift()
  if M.curr_input_mode == InputMode.Reading then
    -- if reading is empty, go back to direct input mode and type ';'
    if #M.reading == 0 then
      g_common.delete_n_chars_before_cursor(#'▽')
      M.dfa.go_to_direct_input_hwc_state()
      return ';'

    else
      -- if currently entering reading, finalize the reading of kanji
      -- and start entering accompanying kana
      M.curr_input_mode = InputMode.AcKana
      M.util.set_dfa_state(M.util.DFAState.InputReading_AcKana)
      return '*'
    end
  else
    error('should not be visited. check code (input-reading 1)')
  end
end

local function delete_ac_kana_part()
  local x = #'*' + g_kana_tree.curr_depth
  g_common.delete_n_chars_before_cursor(x, 0)
end

function M.handle_ctrl_j()
  remove_inverted_triangle(get_reading_len())
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_cr()
  if M.curr_input_mode == InputMode.AcKana then
    g_common.delete_n_chars_before_cursor(
      #'▽' + get_reading_len() + #'*' + g_kana_tree.curr_depth,
      0,
      g_common.join_str_array(M.reading)
    )
  else
    g_common.delete_n_chars_before_cursor(
      #'▽' + get_reading_len() + g_kana_tree.curr_depth,
      0
    )
  end
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_bs()
  if #M.reading > 0 then
    if M.curr_input_mode == InputMode.Reading then
      -- delete the last char
      table.remove(M.reading, #M.reading)
      vim.api.nvim_feedkeys(M.util.bs, "in", true)

    elseif M.curr_input_mode == InputMode.AcKana then
      -- delete '*' and go back to reading mode
      g_common.delete_n_chars_before_cursor(1, 0)
      M.curr_input_mode = InputMode.Reading
    else
      error('should not be visited. check code (input-reading 2)')
    end
  else
    -- go back to direct input kana if there is no char to delete
    remove_inverted_triangle(0)
    M.dfa.go_to_direct_input_kana_state()
  end
end

function M.handle_esc()
  if M.curr_input_mode == InputMode.Reading then
    -- clear the reverse triangle, reading and incomplete spelling
    local x = #'▽' + get_reading_len() + g_kana_tree.curr_depth
    g_common.delete_n_chars_before_cursor(x, 0)
    M.reading = {}

    M.dfa.go_to_direct_input_kana_state()

  elseif M.curr_input_mode == InputMode.AcKana then
    -- go back to input reading mode
    M.curr_input_mode = InputMode.Reading
    delete_ac_kana_part()
    g_kana_tree.go_to_root()
  end
end

local function handle_input_reading_mode(c)
  if c == 'l' then
    remove_inverted_triangle()
    M.dfa.go_to_direct_input_hwc_state()
    return ''

  elseif c == 'L' then
    remove_inverted_triangle()
    M.dfa.go_to_direct_input_fwc_state()
    return ''

  elseif c == 'q' then
    local katakana = ''
    for _, kc in ipairs(M.reading) do
      katakana = katakana .. g_katakana_conv.map(kc)
    end

    -- remove hiragana and incomplete spelling
    -- and write hiragana in katakana
    g_common.delete_n_chars_before_cursor(
      #'▽' + get_reading_len() + g_kana_tree.curr_depth,
      0,
      katakana
    )

    M.dfa.go_to_direct_input_kana_state()
    return ''

  elseif c == ';' then
    return handle_sticky_shift()

  elseif c == ' ' then
    if #M.reading == 0 then
      M.dfa.go_to_direct_input_kana_state()
      return ' '
    else
      -- ignore if still in the middle of entering kana
      if not g_kana_tree.at_the_root_node() then
        return ''
      else
        -- delete reading and go to select kanji state
        local candidate = M.dfa.go_to_select_kanji_state({
          reading = M.reading,
          ac_kana_letter = '',
          ac_kana_first_char = ' ', -- ' ' means None
        })
        -- if there are candidates, show the first candidate
        if candidate then
          local replacement = '▼' .. candidate
          local target = '▽' .. g_common.join_str_array(M.reading)

          g_common.delete_n_chars_before_cursor(#target, 0, replacement)
        end
        return ''
      end
    end
    M.dfa.go_to_select_kanji_state.enter({
      reading = M.reading,
      ac_kana_letter = '',
      ac_kana_first_char = ' ',  -- ' ' means None
    })
  else
    local res = g_kana_tree.traverse(g_kana_tree, M.handle_input, c)
    local value = res["value"]
    local is_letter = res["is_letter"]

    if is_letter then
      table.insert(M.reading, value)
    end
    return value
  end
end

local function handle_input_ac_kana(c)
  if g_kana_tree.at_the_root_node() then
    M.ac_kana_first_char = c
  end

  local res = g_kana_tree.traverse(g_kana_tree, M.handle_input, c, true)
  local value = res["value"]
  local is_letter = res["is_letter"]
  local depth = res["depth"]

  if is_letter then
    local candidate = M.dfa.go_to_select_kanji_state({
      reading = M.reading,
      ac_kana_letter = value,
      ac_kana_first_char = M.ac_kana_first_char,
    })
    -- if there are candidates, show the first candidate
    if candidate then
      local replacement = '▼' .. candidate

      local reading = g_common.join_str_array(M.reading)
      local ak = depth  -- ak = #'*' + depth - 1
      local all_len = #('▽' .. reading) + ak

      g_common.delete_n_chars_before_cursor(all_len, 0, replacement, ak)
    else
      -- otherwise, start entering ac_kana again
      g_common.delete_n_chars_before_cursor(depth - 1, 0)
    end
    return ''

  else
    return value
  end
end

function M.handle_input(c)
  if M.curr_input_mode == InputMode.Reading then
    return handle_input_reading_mode(c)

  elseif M.curr_input_mode == InputMode.AcKana then
    return handle_input_ac_kana(c)

  else
    error('should not be visited. check code (input-reading 3)')
  end
end

function M.enter(inst)
  inst = inst or {}
  if inst.ac_kana_letter and #inst.ac_kana_letter ~= 0 then
    -- there was no candidate and came back from select kanji state
    M.curr_input_mode = InputMode.AcKana
    M.ac_kana_first_char = nil
  else
    g_kana_tree.go_to_root()
    g_kana_tree.set_hiragana()

    M.curr_input_mode = InputMode.Reading
    M.reading = inst.reading or {}
  end
  M.util.set_dfa_state(M.util.DFAState.InputReading_Reading)
end

return M

