local M = {
  curr_input_mode = nil,
  reading = '',
  accompanying_kana = '',
}

local g_kana_tree = require 'state/kana-tree/logic'
local g_kana_tree_common = require 'state/kana-tree/common'
local g_common = require 'common'

local InputMode = {
  Reading = 1,
  AccompanyingKana = 2,
}

function M.init(dfa)
  g_kana_tree.init()
  M.dfa = dfa
end

function M.enter()
  g_kana_tree.go_to_root()
  g_kana_tree.set_hiragana()

  M.curr_input_mode = InputMode.Reading
  M.reading = ''
  M.accompaying_kana = ''

  g_common.alert('Input Reading (Reading)')
end

function M.go_to_accompanying_kana_mode()
  M.curr_input_mode = InputMode.AccompanyingKana
end

local function get_reading_len()
  local reading_len = #M.reading
  if #M.accompanying_kana ~= 0 then
    reading_len = reading_len + #'*' + #M.accompanying_kana
  end
  return reading_len
end

local function handle_sticky_shift()
  if M.curr_input_mode == InputMode.Reading then
    -- if reading is empty, go back to direct input mode and type ';'
    if M.reading == '' then
      g_common.delete_n_chars_before_cursor(#'▽')
      M.dfa.go_to_direct_input_hfc_state()
      return ';'

    else
      -- if currently entering reading, finalize the reading of kanji
      -- and start entering accompanying kana
      M.curr_input_mode = InputMode.AccompanyingKana
      g_common.alert('Input Reading (Accompanying Kana)')

      -- TODO replace ▽ with ▼

      return '*'
    end

  elseif M.curr_input_mode == InputMode.AccompanyingKana then
    -- should allow only 1 kana to enter
    -- finalize the kanji and start entering the next word
    local reading_len = get_reading_len()
    g_common.remove_kanji_selection_marker(reading_len)

    M.curr_input_mode = InputMode.InputReading
    g_common.alert("Input Reading")
    return '▽'

  else
    error('should not be visited. check code (input-reading.lua 1)')
  end
end

function M.handle_ctrl_j()
  g_common.remove_inverted_triangle(get_reading_len())
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_cr()
  g_common.remove_inverted_triangle(get_reading_len())
  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_bs()
  g_common.alert("BS in Input Reading")
end

function M.handle_input(c)
  if c == 'l' then
    M.dfa.direct_input_hfc.enter()
    return ''

  elseif c == 'q' then
    M.dfa.go_to_direct_input_kana_state()
    return ''

  elseif c == ';' then
    return handle_sticky_shift()

  elseif c == ' ' then
    if #M.reading == 0 then
      M.dfa.go_to_direct_input_kana_state()
      return ' '
    else
      -- delete reading and go to select kanji state
      local kanji = M.dfa.go_to_select_kanji_state()
      local replacement = '▼' .. kanji

      local reading_len = get_reading_len()

      g_common.delete_n_chars_before_cursor(#'▽' + reading_len, 0, replacement)
      -- need to move cursor to the end of the replacement
      return ''
    end
  else
    local res = g_kana_tree_common.traverse(g_kana_tree, M.handle_input, c)
    local value = res["value"]
    local is_letter = res["is_letter"]

    if M.curr_input_mode == InputMode.Reading then
      if is_letter then
        M.reading = M.reading .. value
      end
      return value

    elseif M.curr_input_mode == InputMode.AccompanyingKana then
      if not is_letter then
        return value
      else
        if #M.accompanying_kana == 0 then
          M.accompanying_kana = value
          return value
        else
          return M.dfa.go_to_select_kanji_state.enter(true, value)
        end
      end
    else
      error('should not be visited. check code (input-reading.lua 2)')
    end
  end
end

--[[
local function reading_buf_filter(letter)

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
      go_to_direct_input_mode()
      return letter
    end

  elseif g_curr_kana_mode == KanaMode.SelectKanji then
    -- finalize kanji and treat the letter as direct input
    remove_kanji_selection_marker()
    go_to_direct_input_mode()
    return letter

  else
    error('should not be visited. check code (6)')
  end
end
]]

return M

