local M = {
  curr_input_mode = nil,
  reading = {},
  accompanying_kana = '',
}

local g_kana_tree = require 'state/kana-tree/logic'
local g_kana_tree_common = require 'state/kana-tree/common'
local g_common = require 'common'

local InputMode = {
  Reading = 1,
  AccompanyingKana = 2,
}

function M.init(dfa, util)
  g_kana_tree.init()
  M.dfa = dfa
  M.util = util
end

function M.enter(inst)
  g_kana_tree.go_to_root()
  g_kana_tree.set_hiragana()

  M.curr_input_mode = InputMode.Reading
  M.reading = inst.reading or {}
  M.accompaying_kana = ''

  g_common.alert('Input Reading (Reading)')
end

function M.go_to_accompanying_kana_mode()
  M.curr_input_mode = InputMode.AccompanyingKana
end

local function get_reading_len()
  local reading_len = 0
  for _, c in ipairs(M.reading) do
    reading_len = reading_len + #c
  end
  if #M.accompanying_kana ~= 0 then
    reading_len = reading_len + #'*' + #M.accompanying_kana
  end
  return reading_len
end

local function handle_sticky_shift()
  if M.curr_input_mode == InputMode.Reading then
    -- if reading is empty, go back to direct input mode and type ';'
    if #M.reading == 0 then
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
  if #M.reading > 0 then
    -- delete the last char
    table.remove(M.reading, 1)
    vim.api.nvim_feedkeys(M.util.bs, "in", true)
  else
    -- go back to direct input kana state if there is no char to delete
    g_common.remove_inverted_triangle(0)
    M.dfa.go_to_direct_input_kana_state()
  end
end

function M.handle_esc()
  -- clear the reverse triangle and reading
  local x = #'▽' + get_reading_len()
  g_common.delete_n_chars_before_cursor(x, 0)
  M.reading = {}
  M.accompanying_kana = ''

  M.dfa.go_to_direct_input_kana_state()
end

function M.handle_input(c)
  if c == 'l' then
    M.dfa.go_to_direct_input_hfc_state()
    return ''

  elseif c == 'q' then
    -- TODO convert reading to katakana
    local katakana = ''
    for _, kc in ipairs(M.reading) do
      katakana = katakana .. g_kana_tree.to_katakana(kc)
    end

    -- replace hiragana with katakana
    local reading_len = get_reading_len()
    g_common.delete_n_chars_before_cursor(reading_len, 0, katakana)

    -- remove ▽
    g_common.remove_inverted_triangle(reading_len)

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
        local kanji = M.dfa.go_to_select_kanji_state({
          reading = M.reading,
          accompanying_kana = M.accompanying_kana,
        })
        local replacement = '▼' .. kanji

        local reading_len = get_reading_len()

        g_common.delete_n_chars_before_cursor(#'▽' + reading_len, 0, replacement)
        -- need to move cursor to the end of the replacement
        return ''
      end
    end
  else
    local res = g_kana_tree_common.traverse(g_kana_tree, M.handle_input, c)
    local value = res["value"]
    local is_letter = res["is_letter"]

    if M.curr_input_mode == InputMode.Reading then
      if is_letter then
        table.insert(M.reading, value)
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

return M

