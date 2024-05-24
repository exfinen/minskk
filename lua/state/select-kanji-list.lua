local M = {
  candidates = {},
  curr_index = 0,
  reading = {},
}

local g_common = require 'common'

local selector_to_offset = {
  a = 0,
  s = 1,
  d = 2,
  f = 3,
  j = 4,
}
local selectors = {'a', 's', 'd', 'f', 'j'}

local function show_selector()
  local selector = ''
  local last_index = math.min(#M.candidates - 1, M.curr_index + #selectors - 1)

  local letter_index = 1
  for i=M.curr_index, last_index do
    local space = #selector > 0 and ' ' or ''
    selector = string.format('%s%s%s: %s',
      selector, space, selectors[letter_index], M.candidates[i + 1]
    )
    letter_index = letter_index + 1
  end
  g_common.alert(selector, 5000)
end

function M.init(dfa, util)
  M.dfa = dfa
  M.util = util
end

function M.enter(inst)
  M.util.set_dfa_state(M.util.DFAState.SelectKanjiList)
  M.candidates = inst.candidates
  M.curr_index = 0
  M.reading = inst.reading

  show_selector()
end

function M.handle_ctrl_j()
  -- select the current head and go to direct kana
end

function M.handle_cr()
  -- select the current head
end

function M.handle_bs()
  -- go back to previous selector
  -- if now showing the first selector, go back to select kanji
end

local function get_candidate_head()
  return M.candidates[M.curr_index + 1]
end

function M.handle_esc()
  -- go back to input reading
  local a = '▼' .. get_candidate_head()
  local b = '▽' .. g_common.join_str_array(M.reading)
  g_common.delete_n_chars_before_cursor(#a, 0, b)

  M.dfa.go_to_input_reading_state({
    reading = M.reading
  })
end

function M.handle_input(c)
  if c == ' ' then
    local prev_candidate_head = get_candidate_head()

    -- update the currrent index
    M.curr_index = M.curr_index + #selectors
    if M.curr_index > #M.candidates - 1 then
      M.curr_index = 0
    end

    show_selector()

    -- update the candidate head
    g_common.delete_n_chars_before_cursor(
      #prev_candidate_head, 0, get_candidate_head()
    )
    return ''

  elseif selector_to_offset[c] then
    local offset = selector_to_offset[c]

    if M.curr_index + offset < #M.candidates then
      -- select candidate
      local candidate = M.candidates[M.curr_index + offset + 1]
      local candidate_head_len = #M.candidates[M.curr_index + 1]

      g_common.delete_n_chars_before_cursor(
        #'▼' + candidate_head_len,
        0,
        candidate
      )
    end
    return ''
  end
end

return M

